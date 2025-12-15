// lib/pages/create_post_page.dart

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:image_cropper/image_cropper.dart';

import '../services/database/database_provider.dart';

class CreatePostPage extends StatefulWidget {
  final String? communityId;
  final String? communityName;

  const CreatePostPage({
    super.key,
    this.communityId,
    this.communityName,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _captionController = TextEditingController();

  late final DatabaseProvider databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);

  List<AssetEntity> _selectedAssets = [];
  // if user crops an image, we store the cropped file here at the same index
  List<File?> _editedFiles = [];

  bool _isUploading = false;
  int _currentIndex = 0; // which media is shown big

  @override
  void initState() {
    super.initState();
    // ⛔️ No auto-gallery open anymore – user can post text-only or add media manually.
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // GALLERY PICKER
  // ------------------------------------------------------------
  Future<void> _openGallery() async {
    try {
      final perm = await PhotoManager.requestPermissionExtend();

      if (!perm.isAuth) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please allow photo access in your settings to add photos/videos.'.tr(),
            ),
          ),
        );

        // ❌ Do NOT pop the page anymore – user can still make text-only posts.
        return;
      }

      final result = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 10,
          requestType: RequestType.common, // images + videos
        ),
      );

      if (!mounted) return;

      if (result == null || result.isEmpty) {
        // User cancelled – just stay on the page, keep any previous selection.
        return;
      }

      setState(() {
        _selectedAssets = result;
        _editedFiles =
        List<File?>.filled(result.length, null, growable: true);
        _currentIndex = 0;
      });
    } catch (e, s) {
      debugPrint('Error opening gallery: $e\n$s');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open gallery. Check app permissions.'.tr()),
        ),
      );

      // Do NOT pop; user can still do text-only posts.
    }
  }

  // ------------------------------------------------------------
  // CROPPING
  // ------------------------------------------------------------
  Future<File?> _cropImage(File imageFile) async {
    final color = Theme.of(context).colorScheme;

    final cropped = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop'.tr(),
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: color.primary,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop'.tr(),
        ),
      ],
    );

    if (cropped == null) return null;
    return File(cropped.path);
  }

  Future<void> _cropCurrentAsset() async {
    if (_selectedAssets.isEmpty) return;

    final index = _currentIndex;
    final asset = _selectedAssets[index];

    if (asset.type != AssetType.image) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cropping is only available for photos.'.tr())),
      );
      return;
    }

    final originalFile = await asset.file;
    if (originalFile == null) return;

    final cropped = await _cropImage(originalFile);
    if (cropped == null) return;

    if (!mounted) return;

    setState(() {
      if (_editedFiles.length != _selectedAssets.length) {
        _editedFiles =
        List<File?>.filled(_selectedAssets.length, null, growable: true);
      }
      _editedFiles[index] = cropped;
    });
  }

  // ------------------------------------------------------------
  // SHARE: TRUE MULTI-MEDIA UPLOAD + TEXT-ONLY SUPPORT
  // ------------------------------------------------------------
  Future<void> _sharePost() async {
    final caption = _captionController.text.trim();

    // require at least a small caption
    if (caption.replaceAll(RegExp(r'\s+'), '').length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Caption must have at least 5 characters.'.tr())),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final List<File> imageFiles = [];
      final List<File> videoFiles = [];

      for (int i = 0; i < _selectedAssets.length; i++) {
        final asset = _selectedAssets[i];

        if (asset.type == AssetType.video) {
          final file = await asset.file;
          if (file != null) {
            videoFiles.add(file);
          }
        } else {
          // use cropped version if available, otherwise original gallery file
          File? file = _editedFiles.length == _selectedAssets.length
              ? _editedFiles[i]
              : null;

          file ??= await asset.file;
          if (file != null) {
            imageFiles.add(file);
          }
        }
      }

      // 🔸 Only throw if user DID select something, but we somehow could not resolve any files.
      if (_selectedAssets.isNotEmpty &&
          imageFiles.isEmpty &&
          videoFiles.isEmpty) {
        throw Exception('No media files resolved from gallery selection.'.tr());
      }

      // ✅ This now supports:
      //  - text + media
      //  - text-only (imageFiles + videoFiles both empty)
      await databaseProvider.postMultiMediaMessage(
        caption,
        imageFiles: imageFiles,
        videoFiles: videoFiles,
        communityId: widget.communityId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post uploaded successfully!'.tr())),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error uploading multi-media post: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share. Please try again.'.tr())),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isGalleryEmpty = _selectedAssets.isEmpty;

    return Scaffold(
      backgroundColor: color.surface,
      // default resizeToAvoidBottomInset = true, good for keyboard
      appBar: AppBar(
        backgroundColor: color.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.communityName != null
              ? 'new_post_in'.tr(namedArgs: {'name': widget.communityName!})
              : 'New post'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            // Only disabled while uploading; logic/validation is in _sharePost
            onPressed: _isUploading ? null : _sharePost,
            child: _isUploading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(
              'Share'.tr(),
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- BIG PREVIEW AREA OR "ADD MEDIA" CTA ---
                    if (!isGalleryEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildMainPreview(color, isDark),

                                // Dark gradient overlay (bottom)
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    height: 80,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withValues(
                                              alpha: isDark ? 0.55 : 0.35),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Index chip (e.g., 1 / 3)
                                if (_selectedAssets.length > 1)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.55),
                                        borderRadius:
                                        BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${_currentIndex + 1}/${_selectedAssets.length}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Video label
                                if (_selectedAssets[_currentIndex].type ==
                                    AssetType.video)
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.6),
                                        borderRadius:
                                        BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.videocam,
                                              size: 16,
                                              color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Video'.tr(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight:
                                              FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? color.surfaceContainerHighest
                                .withValues(alpha: 0.6)
                                : color.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                              color.outline.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 28,
                                color: color.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No photos or videos added'.tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: color.onSurface
                                      .withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'You can share a text-only post, or add media below.'.tr(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: color.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _openGallery,
                                icon: const Icon(
                                    Icons.add_photo_alternate_outlined),
                                label: Text(
                                    'Add photos / videos'.tr()),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // --- TOOLBAR (Crop / Filters / Cover) ---
                    if (!isGalleryEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0),
                        child: Row(
                          children: [
                            _ToolChip(
                              icon: Icons.crop_rounded,
                              label: 'Crop'.tr(),
                              onTap: _cropCurrentAsset,
                            ),
                            const SizedBox(width: 8),
                            _ToolChip(
                              icon: Icons.tune_rounded,
                              label: 'Filters'.tr(),
                              onTap: () {
                                // TODO: hook filters later
                              },
                            ),
                            const SizedBox(width: 8),
                            _ToolChip(
                              icon: Icons.photo_library_rounded,
                              label: 'Cover'.tr(),
                              onTap: () {
                                // TODO: cover frame picker later
                              },
                            ),
                          ],
                        ),
                      ),

                    if (!isGalleryEmpty) const SizedBox(height: 6),

                    // --- THUMBNAIL STRIP ---
                    if (!isGalleryEmpty)
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                          itemCount:
                          _selectedAssets.length + 1, // +1 for "add more"
                          separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            if (index == _selectedAssets.length) {
                              // "Add more" tile
                              return GestureDetector(
                                onTap: _openGallery,
                                child: Container(
                                  width: 70,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? color.surfaceVariant
                                        .withValues(alpha: 0.6)
                                        : color.surfaceVariant,
                                    borderRadius:
                                    BorderRadius.circular(14),
                                    border: Border.all(
                                      color: color.outline
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.add_rounded,
                                        size: 28),
                                  ),
                                ),
                              );
                            }

                            final entity = _selectedAssets[index];
                            final isSelected = index == _currentIndex;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _currentIndex = index;
                                });
                              },
                              child: Container(
                                width: 70,
                                decoration: BoxDecoration(
                                  borderRadius:
                                  BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? color.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius:
                                  BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: AssetEntityImage(
                                          entity,
                                          isOriginal: false,
                                          thumbnailSize:
                                          const ThumbnailSize
                                              .square(200),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      if (entity.type ==
                                          AssetType.video)
                                        const Positioned(
                                          right: 4,
                                          bottom: 4,
                                          child: Icon(
                                            Icons.videocam_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    if (!isGalleryEmpty) const Divider(height: 20),

                    // --- CAPTION AREA (ALWAYS SHOWN) ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 0, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Placeholder avatar – later you can pass real user photo
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: color.primary
                                .withValues(alpha: 0.15),
                            child: Icon(
                              Icons.person_rounded,
                              color: color.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _captionController,
                              maxLines: null,
                              maxLength: 2200,
                              decoration: InputDecoration(
                                hintText: "Write a caption...".tr(),
                                filled: true,
                                fillColor: isDark
                                    ? color.surfaceContainerHighest
                                    .withValues(alpha: 0.8)
                                    : color.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding:
                                const EdgeInsets.all(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainPreview(ColorScheme color, bool isDark) {
    final asset = _selectedAssets[_currentIndex];
    final editedFile = (_editedFiles.length == _selectedAssets.length)
        ? _editedFiles[_currentIndex]
        : null;

    if (asset.type == AssetType.video) {
      // for now, still show thumbnail for video
      return AssetEntityImage(
        asset,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize.square(900),
        fit: BoxFit.cover,
      );
    }

    if (editedFile != null) {
      return Image.file(
        editedFile,
        fit: BoxFit.cover,
      );
    }

    return AssetEntityImage(
      asset,
      isOriginal: false,
      thumbnailSize: const ThumbnailSize.square(900),
      fit: BoxFit.cover,
    );
  }
}

// Small pill-shaped tool buttons under the preview
class _ToolChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? color.surfaceContainerHighest.withValues(alpha: 0.8)
              : color.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: color.onSurface.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
