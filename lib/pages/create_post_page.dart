// lib/pages/create_post_page.dart

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:image_cropper/image_cropper.dart';

import '../models/user_profile.dart';
import '../services/auth/auth_service.dart';
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
  final AuthService _authService = AuthService();

  late final DatabaseProvider databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);

  List<AssetEntity> _selectedAssets = [];
  List<File?> _editedFiles = [];

  bool _isUploading = false;
  int _currentIndex = 0;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _openGallery() async {
    try {
      final perm = await PhotoManager.requestPermissionExtend();

      if (!perm.isAuth) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please allow photo access in your settings to add photos/videos.'
                  .tr(),
            ),
          ),
        );
        return;
      }

      final result = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          maxAssets: 10,
          requestType: RequestType.common,
          textDelegate: const _AppAssetPickerTextDelegate(),
        ),
      );

      if (!mounted) return;
      if (result == null || result.isEmpty) return;

      setState(() {
        _selectedAssets = result;
        _editedFiles = List<File?>.filled(result.length, null, growable: true);
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
    }
  }

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

  Future<void> _sharePost() async {
    final caption = _captionController.text.trim();

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
          File? file =
          _editedFiles.length == _selectedAssets.length ? _editedFiles[i] : null;

          file ??= await asset.file;
          if (file != null) {
            imageFiles.add(file);
          }
        }
      }

      if (_selectedAssets.isNotEmpty && imageFiles.isEmpty && videoFiles.isEmpty) {
        throw Exception('No media files resolved from gallery selection.'.tr());
      }

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

  Widget _buildCurrentUserAvatar(ColorScheme color) {
    final currentUserId = _authService.getCurrentUserId();

    if (currentUserId.isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: color.primary.withValues(alpha: 0.15),
        child: Icon(
          Icons.person_rounded,
          color: color.primary,
        ),
      );
    }

    return FutureBuilder<UserProfile?>(
      future: databaseProvider.getUserProfile(currentUserId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final photoUrl = user?.profilePhotoUrl.trim() ?? '';
        final name = user?.name.trim() ?? '';

        String initials = '?';
        if (name.isNotEmpty) {
          final parts = name.split(' ').where((e) => e.isNotEmpty).toList();
          if (parts.length == 1) {
            initials = parts.first[0].toUpperCase();
          } else if (parts.length >= 2) {
            initials = (parts[0][0] + parts[1][0]).toUpperCase();
          }
        }

        return CircleAvatar(
          radius: 18,
          backgroundColor: color.primary.withValues(alpha: 0.15),
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl.isEmpty
              ? Text(
            initials,
            style: TextStyle(
              color: color.primary,
              fontWeight: FontWeight.w700,
            ),
          )
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final mediaCardColor = isDark
        ? color.surfaceContainerHighest.withValues(alpha: 0.6)
        : color.surfaceContainerHigh;

    final softBorderColor = isDark
        ? color.outline.withValues(alpha: 0.4)
        : color.outlineVariant.withValues(alpha: 0.7);

    final isGalleryEmpty = _selectedAssets.isEmpty;

    return Scaffold(
      backgroundColor: color.surface,
      appBar: AppBar(
        backgroundColor: color.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _sharePost,
            child: _isUploading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(
              'Share'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.primary.withValues(alpha: 0.14),
                              color.secondary.withValues(alpha: 0.55),
                              color.surfaceContainerHigh,
                            ],
                          ),
                          border: Border.all(
                            color: color.outlineVariant.withValues(alpha: 0.45),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.primary.withValues(alpha: 0.14),
                              ),
                              child: Icon(
                                widget.communityName != null
                                    ? Icons.groups_2_rounded
                                    : Icons.edit_rounded,
                                color: color.primary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.communityName != null
                                        ? 'Community post'.tr()
                                        : 'Create'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                      color: color.onSurface
                                          .withValues(alpha: 0.65),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.communityName != null
                                        ? 'new_post_in'.tr(
                                      namedArgs: {
                                        'name': widget.communityName!,
                                      },
                                    )
                                        : 'New post'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.communityName != null
                                        ? 'Share something with this community using text, photos, or video.'
                                        .tr()
                                        : 'Share something with your followers using text, photos, or video.'
                                        .tr(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      color: color.onSurface
                                          .withValues(alpha: 0.72),
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (!isGalleryEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildMainPreview(color, isDark),
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
                                            alpha: isDark ? 0.55 : 0.35,
                                          ),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (_selectedAssets.length > 1)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                        Colors.black.withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${_currentIndex + 1}/${_selectedAssets.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_selectedAssets[_currentIndex].type ==
                                    AssetType.video)
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                        Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.videocam,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Video'.tr(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
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
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: mediaCardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: softBorderColor,
                            ),
                            boxShadow: isDark
                                ? []
                                : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.035),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
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
                                  color:
                                  color.onSurface.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'You can share a text-only post, or add media below.'
                                    .tr(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                  color.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _openGallery,
                                icon:
                                const Icon(Icons.add_photo_alternate_outlined),
                                label: Text('Add photos / videos'.tr()),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (!isGalleryEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            _ToolChip(
                              icon: Icons.crop_rounded,
                              label: 'Crop'.tr(),
                              onTap: _cropCurrentAsset,
                            ),
                          ],
                        ),
                      ),

                    if (!isGalleryEmpty) const SizedBox(height: 6),

                    if (!isGalleryEmpty)
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _selectedAssets.length + 1,
                          separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            if (index == _selectedAssets.length) {
                              return GestureDetector(
                                onTap: _openGallery,
                                child: Container(
                                  width: 70,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? color.surfaceContainerHighest
                                        .withValues(alpha: 0.6)
                                        : color.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color:
                                      color.outline.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.add_rounded, size: 28),
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
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? color.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: AssetEntityImage(
                                          entity,
                                          isOriginal: false,
                                          thumbnailSize:
                                          const ThumbnailSize.square(200),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      if (entity.type == AssetType.video)
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

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCurrentUserAvatar(color),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _captionController,
                              maxLines: null,
                              maxLength: 2200,
                              decoration: InputDecoration(
                                hintText: "Write a caption...".tr(),
                                filled: true,
                                fillColor: mediaCardColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: softBorderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: color.primary.withValues(alpha: 0.8),
                                    width: 1.2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(16),
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

class _AppAssetPickerTextDelegate extends AssetPickerTextDelegate {
  const _AppAssetPickerTextDelegate();

  @override
  String get preview => 'picker_preview'.tr();

  @override
  String get confirm => 'picker_confirm'.tr();

  @override
  String get cancel => 'picker_cancel'.tr();

  @override
  String get edit => 'picker_edit'.tr();

  @override
  String get original => 'picker_original'.tr();

  @override
  String get select => 'picker_select'.tr();

  @override
  String get allAlbums => 'picker_all_albums'.tr();

  @override
  String get recent => 'picker_recent'.tr();

  @override
  String get emptyList => 'picker_empty_list'.tr();

  @override
  String get loadFailed => 'picker_load_failed'.tr();

  @override
  String get unSupportedAssetType => 'picker_unsupported'.tr();

  @override
  String maximumAssetsCount(int count) =>
      'picker_max_assets'.tr(namedArgs: {'count': '$count'});
}

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