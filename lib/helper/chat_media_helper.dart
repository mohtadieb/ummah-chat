// lib/helper/chat_media_helper.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';

// Mixed gallery picker (images + videos, multi-select)
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/chat/chat_provider.dart';

/// ✅ Mixed gallery selection (keeps order + type)
class MixedAssetsWithCaption {
  final List<AssetEntity> assets;
  final String caption;

  MixedAssetsWithCaption({
    required this.assets,
    required this.caption,
  });

  bool get isEmpty => assets.isEmpty;
}

/// ✅ Result for camera capture (either image or video) + caption
class CameraCaptureWithCaption {
  final XFile file;
  final bool isVideo;
  final String caption;

  CameraCaptureWithCaption({
    required this.file,
    required this.isVideo,
    required this.caption,
  });
}

class ChatMediaHelper {
  static final ImagePicker _picker = ImagePicker();
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Bucket name used for chat uploads
  static const String _bucketName = 'chat_uploads';

  // =======================================================================
  // PICKERS
  // =======================================================================

  /// ✅ Mixed picker (images + videos) from gallery, multi-select
  static Future<List<AssetEntity>> pickMixedAssetsFromGallery({
    required BuildContext context,
    int maxAssets = 12,
  }) async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) return <AssetEntity>[];

    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: maxAssets,
        requestType: RequestType.common, // images + videos
      ),
    );

    return assets ?? <AssetEntity>[];
  }

  static Future<XFile?> pickSingleImageFromCamera() async {
    return _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1600,
    );
  }

  static Future<XFile?> pickSingleVideoFromCamera() async {
    return _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 3),
    );
  }

  // =======================================================================
  // UPLOAD HELPERS
  // =======================================================================

  static Future<String?> uploadImageFileAndGetUrl({
    required BuildContext context,
    required File file,
    required String chatRoomId,
    required String currentUserId,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    try {
      final ext = file.path.split('.').last;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.$ext';
      final storagePath = 'chat/$chatRoomId/images/$fileName';

      await _supabase.storage.from(_bucketName).upload(storagePath, file);
      return _supabase.storage.from(_bucketName).getPublicUrl(storagePath);
    } catch (e, st) {
      debugPrint('❌ uploadImageFileAndGetUrl error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image. Please try again.'.tr(),
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          backgroundColor: colorScheme.errorContainer,
        ),
      );
      return null;
    }
  }

  static Future<void> _uploadVideoToKnownPath({
    required BuildContext context,
    required File file,
    required String storagePath,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    try {
      await _supabase.storage.from(_bucketName).upload(storagePath, file);
    } catch (e, st) {
      debugPrint('❌ _uploadVideoToKnownPath error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload video. Please try again.'.tr(),
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          backgroundColor: colorScheme.errorContainer,
        ),
      );
      rethrow;
    }
  }

  // =======================================================================
  // UI: MIXED GALLERY CAPTION SHEET (THUMBNAILS)
  // =======================================================================

  static String _formatDurationSeconds(int seconds) {
    final d = Duration(seconds: seconds);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static Future<MixedAssetsWithCaption?> showMixedAssetsCaptionSheet({
    required BuildContext context,
    required List<AssetEntity> pickedAssets,
  }) async {
    if (pickedAssets.isEmpty) return null;

    final colorScheme = Theme.of(context).colorScheme;
    final TextEditingController captionController = TextEditingController();

    final Map<String, Uint8List?> thumbCache = {};

    Future<Uint8List?> _thumbFor(AssetEntity asset) async {
      if (thumbCache.containsKey(asset.id)) return thumbCache[asset.id];
      final bytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(420, 420),
        quality: 80,
      );
      thumbCache[asset.id] = bytes;
      return bytes;
    }

    final result = await showModalBottomSheet<MixedAssetsWithCaption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final assets = List<AssetEntity>.from(pickedAssets);

        return Padding(
          padding: EdgeInsets.only(
            bottom: bottomInset,
            top: 12,
            left: 12,
            right: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 240,
                child: GridView.builder(
                  itemCount: assets.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemBuilder: (_, index) {
                    final asset = assets[index];
                    final isVideo = asset.type == AssetType.video;

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: FutureBuilder<Uint8List?>(
                              future: _thumbFor(asset),
                              builder: (context, snap) {
                                final bytes = snap.data;
                                if (bytes == null) {
                                  return Container(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                }
                                return Image.memory(bytes, fit: BoxFit.cover);
                              },
                            ),
                          ),

                          if (isVideo) ...[
                            Positioned.fill(
                              child: Container(
                                  color:
                                  Colors.black.withValues(alpha: 0.12)),
                            ),
                            const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _formatDurationSeconds(asset.duration),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('${index + 1}'.tr(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: captionController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Add caption...'.tr(),
                        filled: true,
                        fillColor: colorScheme.tertiary,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF128C7E),
                    child: IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.white, size: 20),
                      onPressed: () {
                        Navigator.of(ctx).pop(
                          MixedAssetsWithCaption(
                            assets: assets,
                            caption: captionController.text.trim(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    return result;
  }

  // =======================================================================
  // UI: CAMERA CHOICE + CAMERA CAPTION SHEET
  // =======================================================================

  static Future<String?> _showCameraChoiceSheet(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text('Take photo'.tr()),
                onTap: () => Navigator.of(ctx).pop('photo'),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: Text('Record video'.tr()),
                onTap: () => Navigator.of(ctx).pop('video'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  static Future<CameraCaptureWithCaption?> showCameraCaptureCaptionSheet({
    required BuildContext context,
    required XFile file,
    required bool isVideo,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    final TextEditingController captionController = TextEditingController();
    final String fileName = file.path.split('/').last;

    return showModalBottomSheet<CameraCaptureWithCaption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        Widget preview;
        if (!isVideo) {
          preview = ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(file.path),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          );
        } else {
          preview = Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: bottomInset,
            top: 12,
            left: 12,
            right: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              preview,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: captionController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Add caption...'.tr(),
                        filled: true,
                        fillColor: colorScheme.tertiary,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF128C7E),
                    child: IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.white, size: 20),
                      onPressed: () {
                        Navigator.of(ctx).pop(
                          CameraCaptureWithCaption(
                            file: file,
                            isVideo: isVideo,
                            caption: captionController.text.trim(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // =======================================================================
  // ATTACHMENT SHEETS (DM + GROUP)
  // =======================================================================

  static Future<void> openAttachmentSheetForDM({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
    required String otherUserId,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text('Gallery'.tr()),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _handleMixedGalleryDM(
                    context: context,
                    chatRoomId: chatRoomId,
                    currentUserId: currentUserId,
                    otherUserId: otherUserId,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text('Camera'.tr()),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _handleCameraDM(
                    context: context,
                    chatRoomId: chatRoomId,
                    currentUserId: currentUserId,
                    otherUserId: otherUserId,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  static Future<void> openAttachmentSheetForGroup({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text('Gallery'.tr()),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _handleMixedGalleryGroup(
                    context: context,
                    chatRoomId: chatRoomId,
                    currentUserId: currentUserId,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text('Camera'.tr()),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _handleCameraGroup(
                    context: context,
                    chatRoomId: chatRoomId,
                    currentUserId: currentUserId,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // =======================================================================
  // HANDLERS — MIXED GALLERY
  // =======================================================================

  static Future<void> _handleMixedGalleryDM({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
    required String otherUserId,
  }) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final assets = await pickMixedAssetsFromGallery(
      context: context,
      maxAssets: 12,
    );
    if (assets.isEmpty) return;

    final result = await showMixedAssetsCaptionSheet(
      context: context,
      pickedAssets: assets,
    );
    if (result == null || result.isEmpty) return;

    final batchTime = DateTime.now().toUtc();
    final caption = result.caption.trim();

    for (final asset in result.assets) {
      final file = await asset.file;
      if (file == null) continue;

      if (asset.type == AssetType.image) {
        final imageUrl = await uploadImageFileAndGetUrl(
          context: context,
          file: file,
          chatRoomId: chatRoomId,
          currentUserId: currentUserId,
        );
        if (imageUrl == null) continue;

        await chatProvider.sendImageMessageDM(
          chatRoomId: chatRoomId,
          senderId: currentUserId,
          receiverId: otherUserId,
          imageUrl: imageUrl,
          message: caption,
          createdAtOverride: batchTime,
        );
      } else if (asset.type == AssetType.video) {
        await _sendVideoDMFromFile(
          context: context,
          chatRoomId: chatRoomId,
          currentUserId: currentUserId,
          otherUserId: otherUserId,
          picked: XFile(file.path),
          caption: caption,
          createdAt: batchTime,
        );
      }
    }
  }

  static Future<void> _handleMixedGalleryGroup({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
  }) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final assets = await pickMixedAssetsFromGallery(
      context: context,
      maxAssets: 12,
    );
    if (assets.isEmpty) return;

    final result = await showMixedAssetsCaptionSheet(
      context: context,
      pickedAssets: assets,
    );
    if (result == null || result.isEmpty) return;

    final batchTime = DateTime.now().toUtc();
    final caption = result.caption.trim();

    for (final asset in result.assets) {
      final file = await asset.file;
      if (file == null) continue;

      if (asset.type == AssetType.image) {
        final imageUrl = await uploadImageFileAndGetUrl(
          context: context,
          file: file,
          chatRoomId: chatRoomId,
          currentUserId: currentUserId,
        );
        if (imageUrl == null) continue;

        await chatProvider.sendGroupImageMessage(
          chatRoomId: chatRoomId,
          senderId: currentUserId,
          imageUrl: imageUrl,
          message: caption,
          createdAtOverride: batchTime,
        );
      } else if (asset.type == AssetType.video) {
        await _sendVideoGroupFromFile(
          context: context,
          chatRoomId: chatRoomId,
          currentUserId: currentUserId,
          picked: XFile(file.path),
          caption: caption,
          createdAt: batchTime,
        );
      }
    }
  }

  // =======================================================================
  // HANDLERS — CAMERA (EXPLICIT PHOTO/VIDEO CHOICE)
  // =======================================================================

  static Future<void> _handleCameraDM({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
    required String otherUserId,
  }) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final choice = await _showCameraChoiceSheet(context);
    if (choice == null) return;

    if (choice == 'photo') {
      final XFile? picked = await pickSingleImageFromCamera();
      if (picked == null) return;

      final res = await showCameraCaptureCaptionSheet(
        context: context,
        file: picked,
        isVideo: false,
      );
      if (res == null) return;

      final batchTime = DateTime.now().toUtc();

      final imageUrl = await uploadImageFileAndGetUrl(
        context: context,
        file: File(res.file.path),
        chatRoomId: chatRoomId,
        currentUserId: currentUserId,
      );
      if (imageUrl == null) return;

      await chatProvider.sendImageMessageDM(
        chatRoomId: chatRoomId,
        senderId: currentUserId,
        receiverId: otherUserId,
        imageUrl: imageUrl,
        message: res.caption.trim(),
        createdAtOverride: batchTime,
      );
    } else {
      final XFile? picked = await pickSingleVideoFromCamera();
      if (picked == null) return;

      final res = await showCameraCaptureCaptionSheet(
        context: context,
        file: picked,
        isVideo: true,
      );
      if (res == null) return;

      final batchTime = DateTime.now().toUtc();
      await _sendVideoDMFromFile(
        context: context,
        chatRoomId: chatRoomId,
        currentUserId: currentUserId,
        otherUserId: otherUserId,
        picked: res.file,
        caption: res.caption.trim(),
        createdAt: batchTime,
      );
    }
  }

  static Future<void> _handleCameraGroup({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
  }) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final choice = await _showCameraChoiceSheet(context);
    if (choice == null) return;

    if (choice == 'photo') {
      final XFile? picked = await pickSingleImageFromCamera();
      if (picked == null) return;

      final res = await showCameraCaptureCaptionSheet(
        context: context,
        file: picked,
        isVideo: false,
      );
      if (res == null) return;

      final batchTime = DateTime.now().toUtc();

      final imageUrl = await uploadImageFileAndGetUrl(
        context: context,
        file: File(res.file.path),
        chatRoomId: chatRoomId,
        currentUserId: currentUserId,
      );
      if (imageUrl == null) return;

      await chatProvider.sendGroupImageMessage(
        chatRoomId: chatRoomId,
        senderId: currentUserId,
        imageUrl: imageUrl,
        message: res.caption.trim(),
        createdAtOverride: batchTime,
      );
    } else {
      final XFile? picked = await pickSingleVideoFromCamera();
      if (picked == null) return;

      final res = await showCameraCaptureCaptionSheet(
        context: context,
        file: picked,
        isVideo: true,
      );
      if (res == null) return;

      final batchTime = DateTime.now().toUtc();
      await _sendVideoGroupFromFile(
        context: context,
        chatRoomId: chatRoomId,
        currentUserId: currentUserId,
        picked: res.file,
        caption: res.caption.trim(),
        createdAt: batchTime,
      );
    }
  }

  // =======================================================================
  // VIDEO SENDERS (DM / Group) using your pending flow
  // =======================================================================

  static Future<void> _sendVideoDMFromFile({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
    required String otherUserId,
    required XFile picked,
    required String caption,
    required DateTime createdAt,
  }) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;

    final ext = picked.path.split('.').last;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.$ext';
    final storagePath = 'chat/$chatRoomId/videos/$fileName';
    final videoUrl =
    _supabase.storage.from(_bucketName).getPublicUrl(storagePath);

    String? messageId;

    try {
      messageId = await chatProvider.createPendingVideoMessageDM(
        chatRoomId: chatRoomId,
        senderId: currentUserId,
        receiverId: otherUserId,
        videoUrl: videoUrl,
        message: caption,
        createdAtOverride: createdAt,
      );

      final compressed = await VideoCompress.compressVideo(
        picked.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      final File fileToUpload =
      compressed != null ? File(compressed.path!) : File(picked.path);

      await _uploadVideoToKnownPath(
        context: context,
        file: fileToUpload,
        storagePath: storagePath,
      );

      await chatProvider.markVideoMessageUploaded(messageId);
    } catch (e, st) {
      debugPrint('❌ _sendVideoDMFromFile error: $e\n$st');

      if (messageId != null) {
        await _supabase.from('messages').delete().eq('id', messageId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to upload video. Please try again.'.tr(),
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          backgroundColor: colorScheme.errorContainer,
        ),
      );
    } finally {
      await VideoCompress.deleteAllCache();
    }
  }

  static Future<void> _sendVideoGroupFromFile({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
    required XFile picked,
    required String caption,
    required DateTime createdAt,
  }) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;

    final ext = picked.path.split('.').last;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.$ext';
    final storagePath = 'chat/$chatRoomId/videos/$fileName';
    final videoUrl =
    _supabase.storage.from(_bucketName).getPublicUrl(storagePath);

    String? messageId;

    try {
      messageId = await chatProvider.createPendingGroupVideoMessage(
        chatRoomId: chatRoomId,
        senderId: currentUserId,
        videoUrl: videoUrl,
        message: caption,
        createdAtOverride: createdAt,
      );

      final compressed = await VideoCompress.compressVideo(
        picked.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      final File fileToUpload =
      compressed != null ? File(compressed.path!) : File(picked.path);

      await _uploadVideoToKnownPath(
        context: context,
        file: fileToUpload,
        storagePath: storagePath,
      );

      await chatProvider.markVideoMessageUploaded(messageId);
    } catch (e, st) {
      debugPrint('❌ _sendVideoGroupFromFile error: $e\n$st');

      if (messageId != null) {
        await _supabase.from('messages').delete().eq('id', messageId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to upload video. Please try again.'.tr(),
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          backgroundColor: colorScheme.errorContainer,
        ),
      );
    } finally {
      await VideoCompress.deleteAllCache();
    }
  }
}
