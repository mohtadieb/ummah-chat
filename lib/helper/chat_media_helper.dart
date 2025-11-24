// lib/helper/chat_media_helper.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';

import '../services/chat/chat_service.dart';

/// Result of picking multiple images + entering a caption.
class ImageSelectionWithCaption {
  final List<XFile> files;
  final String caption;

  ImageSelectionWithCaption({
    required this.files,
    required this.caption,
  });
}

/// Result of picking a single video + entering a caption.
class VideoSelectionWithCaption {
  final XFile file;
  final String caption;

  VideoSelectionWithCaption({
    required this.file,
    required this.caption,
  });
}

class ChatMediaHelper {
  static final ImagePicker _picker = ImagePicker();
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final ChatService _chatService = ChatService();

  // ❗ Adjust this to your actual bucket name – you already use "chat_uploads"
  static const String _bucketName = 'chat_uploads';

  // =======================================================================
  // LEGACY: Simple one-shot image picker + upload + send (still used somewhere)
  // =======================================================================

  /// Old helper: pick an image, upload, and immediately send as a *single* image
  /// message. Left here for backwards compatibility.
  static Future<void> pickAndUploadImage({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
    String? otherUserId,
    required bool isGroup,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1600,
      );

      if (picked == null) return;

      final file = File(picked.path);

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.jpg';
      final storagePath = 'chat/$chatRoomId/$fileName';

      await _supabase.storage.from(_bucketName).upload(storagePath, file);

      final imageUrl =
      _supabase.storage.from(_bucketName).getPublicUrl(storagePath);

      if (isGroup) {
        await _chatService.sendGroupImageMessage(
          chatRoomId: chatRoomId,
          senderId: currentUserId,
          imageUrl: imageUrl,
        );
      } else {
        if (otherUserId == null) return;

        await _chatService.sendImageMessage(
          chatRoomId: chatRoomId,
          senderId: currentUserId,
          receiverId: otherUserId,
          imageUrl: imageUrl,
        );
      }
    } catch (e, st) {
      debugPrint('❌ pickAndUploadImage error: $e\n$st');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to upload image. Please try again.',
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          backgroundColor: colorScheme.errorContainer,
        ),
      );
    }
  }

  // =======================================================================
  // CORE UPLOAD HELPERS (IMAGE + VIDEO)
  // =======================================================================

  /// Multi-image picker from gallery (WhatsApp-style).
  static Future<List<XFile>> pickMultipleImages() async {
    final files = await _picker.pickMultiImage(
      imageQuality: 75,
      maxWidth: 1600,
    );
    return files;
  }

  /// Single image from camera.
  static Future<XFile?> pickSingleImageFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1600,
    );
    return file;
  }

  /// Single video from gallery or camera.
  static Future<XFile?> pickSingleVideo({
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
    return file;
  }

  /// Upload an image file and return the **public URL**, or null on error.
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
      final url =
      _supabase.storage.from(_bucketName).getPublicUrl(storagePath);
      return url;
    } catch (e, st) {
      debugPrint('❌ uploadImageFileAndGetUrl error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to upload image. Please try again.',
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          backgroundColor: colorScheme.errorContainer,
        ),
      );
      return null;
    }
  }

  /// 🆕 Upload video to a known storage path (used for "pending" messages).
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
          content: Text(
            'Failed to upload video. Please try again.',
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          backgroundColor: colorScheme.errorContainer,
        ),
      );
      rethrow;
    }
  }

  // =======================================================================
  // BOTTOM SHEET UI: MULTI-IMAGE + CAPTION
  // =======================================================================

  /// WhatsApp-style bottom sheet that shows:
  /// - grid of picked images
  /// - caption TextField
  /// - Send button
  static Future<ImageSelectionWithCaption?> showMultiImageCaptionSheet({
    required BuildContext context,
    required List<XFile> pickedFiles,
  }) async {
    if (pickedFiles.isEmpty) return null;

    final colorScheme = Theme.of(context).colorScheme;
    final TextEditingController captionController = TextEditingController();

    final result = await showModalBottomSheet<ImageSelectionWithCaption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final files = List<XFile>.from(pickedFiles);

        int getBadgeNumberFor(XFile file) {
          final idx = files.indexOf(file);
          return idx == -1 ? 0 : idx + 1;
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

              // Grid of images with numeric badges
              SizedBox(
                height: 220,
                child: GridView.builder(
                  itemCount: files.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemBuilder: (_, index) {
                    final file = files[index];
                    final badgeNumber = getBadgeNumberFor(file);

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(file.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeNumber.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Caption + send row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: captionController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Add caption...',
                        filled: true,
                        fillColor: colorScheme.tertiary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
                      icon:
                      const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: () {
                        final caption = captionController.text.trim();
                        Navigator.of(ctx).pop(
                          ImageSelectionWithCaption(
                            files: files,
                            caption: caption,
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
  // BOTTOM SHEET UI: SINGLE VIDEO + CAPTION
  // =======================================================================

  static Future<VideoSelectionWithCaption?> showSingleVideoCaptionSheet({
    required BuildContext context,
    required XFile file,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    final TextEditingController captionController = TextEditingController();
    final String fileName = file.path.split('/').last;

    final result = await showModalBottomSheet<VideoSelectionWithCaption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

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

              // Simple video preview tile
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: Icon(
                          Icons.videocam_rounded,
                          size: 60,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      right: 12,
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                        hintText: 'Add caption...',
                        filled: true,
                        fillColor: colorScheme.tertiary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
                      icon:
                      const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: () {
                        final caption = captionController.text.trim();
                        Navigator.of(ctx).pop(
                          VideoSelectionWithCaption(
                            file: file,
                            caption: caption,
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
  // HIGH-LEVEL ATTACHMENT SHEETS (DM + GROUP)
  // =======================================================================

  /// WhatsApp-style attachment menu for DIRECT MESSAGES:
  /// - Photo library (multi)
  /// - Camera (photo)
  /// - Video (gallery)
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
                title: const Text('Photo library'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _handleMultiImageDM(
                    context: context,
                    chatRoomId: chatRoomId,
                    currentUserId: currentUserId,
                    otherUserId: otherUserId,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera (photo)'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _handleCameraPhotoDM(
                    context: context,
                    chatRoomId: chatRoomId,
                    currentUserId: currentUserId,
                    otherUserId: otherUserId,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Video (gallery)'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _handleVideoDM(
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

  /// Attachment menu for GROUP chat:
  /// - Photo library (multi)
  /// - Camera (photo)
  /// - Video (gallery)
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
                title: const Text('Photo library'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _handleMultiImageGroup(
                    context: context,
                    chatRoomId: chatRoomId,
                    currentUserId: currentUserId,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera (photo)'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _handleCameraPhotoGroup(
                    context: context,
                    chatRoomId: chatRoomId,
                    currentUserId: currentUserId,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Video (gallery)'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _handleVideoGroup(
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
  // INTERNAL HANDLERS FOR DM
  // =======================================================================

  static Future<void> _handleMultiImageDM({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
    required String otherUserId,
  }) async {
    final pickedFiles = await pickMultipleImages();
    if (pickedFiles.isEmpty) return;

    final result = await showMultiImageCaptionSheet(
      context: context,
      pickedFiles: pickedFiles,
    );
    if (result == null || result.files.isEmpty) return;

    final batchTime = DateTime.now().toUtc();

    for (final xfile in result.files) {
      final file = File(xfile.path);
      final imageUrl = await uploadImageFileAndGetUrl(
        context: context,
        file: file,
        chatRoomId: chatRoomId,
        currentUserId: currentUserId,
      );
      if (imageUrl == null) continue;

      await _chatService.sendImageMessage(
        chatRoomId: chatRoomId,
        senderId: currentUserId,
        receiverId: otherUserId,
        imageUrl: imageUrl,
        message: result.caption,
        createdAtOverride: batchTime,
      );
    }
  }

  static Future<void> _handleCameraPhotoDM({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
    required String otherUserId,
  }) async {
    final XFile? picked = await pickSingleImageFromCamera();
    if (picked == null) return;

    final result = await showMultiImageCaptionSheet(
      context: context,
      pickedFiles: [picked],
    );
    if (result == null || result.files.isEmpty) return;

    final batchTime = DateTime.now().toUtc();

    final file = File(result.files.first.path);
    final imageUrl = await uploadImageFileAndGetUrl(
      context: context,
      file: file,
      chatRoomId: chatRoomId,
      currentUserId: currentUserId,
    );
    if (imageUrl == null) return;

    await _chatService.sendImageMessage(
      chatRoomId: chatRoomId,
      senderId: currentUserId,
      receiverId: otherUserId,
      imageUrl: imageUrl,
      message: result.caption,
      createdAtOverride: batchTime,
    );
  }

  /// 🆕 DM video handler with:
  /// - Compression
  /// - Pending message (is_uploading = true)
  /// - Upload to known path
  /// - Flip is_uploading = false on success
  static Future<void> _handleVideoDM({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
    required String otherUserId,
  }) async {
    final XFile? picked = await pickSingleVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final result = await showSingleVideoCaptionSheet(
      context: context,
      file: picked,
    );
    if (result == null) return;

    final colorScheme = Theme.of(context).colorScheme;
    final batchTime = DateTime.now().toUtc();
    final caption = result.caption.trim();

    // 1️⃣ Decide final storage path + url BEFORE upload
    final ext = picked.path.split('.').last;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.$ext';
    final storagePath = 'chat/$chatRoomId/videos/$fileName';
    final videoUrl =
    _supabase.storage.from(_bucketName).getPublicUrl(storagePath);

    String? messageId;

    try {
      // 2️⃣ Insert pending message so bubble appears instantly
      messageId = await _chatService.createPendingVideoMessageDM(
        chatRoomId: chatRoomId,
        senderId: currentUserId,
        receiverId: otherUserId,
        videoUrl: videoUrl,
        message: caption,
        createdAtOverride: batchTime,
      );

      // 3️⃣ Compress video for faster playback
      final compressed = await VideoCompress.compressVideo(
        picked.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      final File fileToUpload =
      compressed != null ? File(compressed.path!) : File(picked.path);

      // 4️⃣ Upload to known path
      await _uploadVideoToKnownPath(
        context: context,
        file: fileToUpload,
        storagePath: storagePath,
      );

      // 5️⃣ Mark as finished uploading (badge disappears)
      await _chatService.markVideoMessageUploaded(messageId);
    } catch (e, st) {
      debugPrint('❌ _handleVideoDM error: $e\n$st');

      // Delete pending message so you don't end up with a broken bubble
      if (messageId != null) {
        await _supabase
            .from('messages')
            .delete()
            .eq('id', messageId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to upload video. Please try again.',
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          backgroundColor: colorScheme.errorContainer,
        ),
      );
    } finally {
      await VideoCompress.deleteAllCache();
    }
  }

  // =======================================================================
  // INTERNAL HANDLERS FOR GROUP
  // =======================================================================

  static Future<void> _handleMultiImageGroup({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
  }) async {
    final pickedFiles = await pickMultipleImages();
    if (pickedFiles.isEmpty) return;

    final result = await showMultiImageCaptionSheet(
      context: context,
      pickedFiles: pickedFiles,
    );
    if (result == null || result.files.isEmpty) return;

    final batchTime = DateTime.now().toUtc();

    for (final xfile in result.files) {
      final file = File(xfile.path);
      final imageUrl = await uploadImageFileAndGetUrl(
        context: context,
        file: file,
        chatRoomId: chatRoomId,
        currentUserId: currentUserId,
      );
      if (imageUrl == null) continue;

      await _chatService.sendGroupImageMessage(
        chatRoomId: chatRoomId,
        senderId: currentUserId,
        imageUrl: imageUrl,
        message: result.caption,
        createdAtOverride: batchTime,
      );
    }
  }

  static Future<void> _handleCameraPhotoGroup({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
  }) async {
    final XFile? picked = await pickSingleImageFromCamera();
    if (picked == null) return;

    final result = await showMultiImageCaptionSheet(
      context: context,
      pickedFiles: [picked],
    );
    if (result == null || result.files.isEmpty) return;

    final batchTime = DateTime.now().toUtc();

    final file = File(result.files.first.path);
    final imageUrl = await uploadImageFileAndGetUrl(
      context: context,
      file: file,
      chatRoomId: chatRoomId,
      currentUserId: currentUserId,
    );
    if (imageUrl == null) return;

    await _chatService.sendGroupImageMessage(
      chatRoomId: chatRoomId,
      senderId: currentUserId,
      imageUrl: imageUrl,
      message: result.caption,
      createdAtOverride: batchTime,
    );
  }

  /// 🆕 GROUP video handler with:
  /// - Compression
  /// - Pending message (is_uploading = true)
  /// - Upload to known path
  /// - Flip is_uploading = false on success
  static Future<void> _handleVideoGroup({
    required BuildContext context,
    required String chatRoomId,
    required String currentUserId,
  }) async {
    final XFile? picked = await pickSingleVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final result = await showSingleVideoCaptionSheet(
      context: context,
      file: picked,
    );
    if (result == null) return;

    final colorScheme = Theme.of(context).colorScheme;
    final batchTime = DateTime.now().toUtc();
    final caption = result.caption.trim();

    final ext = picked.path.split('.').last;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.$ext';
    final storagePath = 'chat/$chatRoomId/videos/$fileName';
    final videoUrl =
    _supabase.storage.from(_bucketName).getPublicUrl(storagePath);

    String? messageId;

    try {
      messageId = await _chatService.createPendingGroupVideoMessage(
        chatRoomId: chatRoomId,
        senderId: currentUserId,
        videoUrl: videoUrl,
        message: caption,
        createdAtOverride: batchTime,
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

      await _chatService.markVideoMessageUploaded(messageId);
    } catch (e, st) {
      debugPrint('❌ _handleVideoGroup error: $e\n$st');

      if (messageId != null) {
        await _supabase.from('messages').delete().eq('id', messageId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to upload video. Please try again.',
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
