import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

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
  List<AssetEntity> _selectedAssets = [];
  bool _isUploading = false;
  int _currentIndex = 0; // which media is shown big

  @override
  void initState() {
    super.initState();
    // Open gallery as soon as page appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openGallery();
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _openGallery() async {
    try {
      // 1. Explicitly ask for permission first
      final perm = await PhotoManager.requestPermissionExtend();

      if (!perm.isAuth) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('Please allow photo access in your settings to share media.'),
          ),
        );

        Navigator.pop(context); // go back instead of being stuck
        return;
      }

      // 2. Open the in-app gallery (images + videos)
      final result = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 10,
          requestType: RequestType.common, // images + videos
        ),
      );

      if (!mounted) return;

      // User cancelled or nothing selected
      if (result == null || result.isEmpty) {
        Navigator.pop(context);
        return;
      }

      // 3. Store selected assets and re-build UI
      setState(() {
        _selectedAssets = result;
        _currentIndex = 0;
      });
    } catch (e, s) {
      debugPrint('Error opening gallery: $e\n$s');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text('Could not open gallery. Check app permissions and setup.'),
        ),
      );

      Navigator.pop(context);
    }
  }

  Future<void> _sharePost() async {
    if (_selectedAssets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one photo or video.')),
      );
      return;
    }

    final caption = _captionController.text.trim();
    if (caption.replaceAll(RegExp(r'\s+'), '').length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caption must have at least 2 characters.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // NOTE: for now we still upload ONLY the first asset.
      // When your backend supports multi-media posts, you can loop _selectedAssets.
      final first = _selectedAssets.first;

      final file = await first.file; // from photo_manager
      if (file == null) {
        throw Exception('Failed to load file from gallery.');
      }

      File? imageFile;
      File? videoFile;

      if (first.type == AssetType.video) {
        videoFile = file;
      } else {
        imageFile = file;
      }

      final db = Provider.of<DatabaseProvider>(context, listen: false);

      await db.postMessage(
        caption,
        imageFile: imageFile,
        videoFile: videoFile,
        communityId: widget.communityId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post uploaded successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error uploading post: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to share. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final isGalleryEmpty = _selectedAssets.isEmpty;

    return Scaffold(
      backgroundColor: color.surface,
      appBar: AppBar(
        backgroundColor: color.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.communityName != null
              ? 'New post in ${widget.communityName}'
              : 'New post',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading || isGalleryEmpty ? null : _sharePost,
            child: _isUploading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text(
              'Share',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: isGalleryEmpty
          ? const Center(child: Text('Opening gallery…'))
          : Column(
        children: [
          // --- BIG PREVIEW AREA ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AssetEntityImage(
                      _selectedAssets[_currentIndex],
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize.square(900),
                      fit: BoxFit.cover,
                    ),

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
                              Colors.black.withValues(alpha: 0.35),
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
                            color: Colors.black.withValues(alpha: 0.45),
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
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam, size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Video',
                                style: TextStyle(
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
          ),

          // --- TOOLBAR (visual only for now) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _ToolChip(
                  icon: Icons.crop_rounded,
                  label: 'Crop',
                  onTap: () {
                    // TODO: hook up cropper if you add one later
                  },
                ),
                const SizedBox(width: 8),
                _ToolChip(
                  icon: Icons.tune_rounded,
                  label: 'Filters',
                  onTap: () {
                    // TODO: open filters page in future
                  },
                ),
                const SizedBox(width: 8),
                _ToolChip(
                  icon: Icons.photo_library_rounded,
                  label: 'Cover',
                  onTap: () {
                    // TODO: choose cover frame for video
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // --- THUMBNAIL STRIP ---
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _selectedAssets.length + 1, // +1 for "add more"
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == _selectedAssets.length) {
                  // "Add more" tile
                  return GestureDetector(
                    onTap: _openGallery,
                    child: Container(
                      width: 70,
                      decoration: BoxDecoration(
                        color: color.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: color.outline.withValues(alpha: 0.5),
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

          const Divider(height: 20),

          // --- CAPTION AREA ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Placeholder avatar – later you can pass real user photo
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                        color.primary.withValues(alpha: 0.15),
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
                          maxLength: 2200, // like IG
                          decoration: InputDecoration(
                            hintText: "Write a caption...",
                            filled: true,
                            fillColor: color.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color.onSurface.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
