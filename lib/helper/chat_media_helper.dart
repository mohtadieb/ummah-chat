// lib/helper/chat_media_helper.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageSelectionWithCaption {
  final List<XFile> files;
  final String caption;

  ImageSelectionWithCaption({
    required this.files,
    required this.caption,
  });
}

class ChatMediaHelper {
  static final ImagePicker _picker = ImagePicker();
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ✅ 1) Simple multi-image picker (gallery)
  static Future<List<XFile>> pickMultipleImages() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 75,
      maxWidth: 1600,
    );
    return picked;
  }

  // ✅ 2) Upload one file to Supabase and return public URL
  static Future<String?> uploadImageFileAndGetUrl({
    required BuildContext context,
    required File file,
    required String chatRoomId,
    required String currentUserId,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.jpg';
      final storagePath = 'chat/$chatRoomId/$fileName';

      const bucketName = 'chat_uploads'; // ✅ your existing bucket

      await _supabase.storage.from(bucketName).upload(storagePath, file);

      final imageUrl =
      _supabase.storage.from(bucketName).getPublicUrl(storagePath);

      return imageUrl;
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

  // ✅ 3) Reusable bottom sheet: select subset + caption
  static Future<ImageSelectionWithCaption?> showMultiImageCaptionSheet({
    required BuildContext context,
    required List<XFile> pickedFiles,
  }) async {
    if (pickedFiles.isEmpty) return null;

    final colorScheme = Theme.of(context).colorScheme;
    final captionController = TextEditingController();

    // by default, all selected
    final selectedIndices = <int>[
      for (int i = 0; i < pickedFiles.length; i++) i
    ];

    final result = await showModalBottomSheet<ImageSelectionWithCaption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final height = mediaQuery.size.height * 0.7;

        return Padding(
          // make it rise with keyboard
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              int selectedCount = selectedIndices.length;

              return SizedBox(
                height: height,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Selected images',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$selectedCount selected',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Grid of images
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                        itemCount: pickedFiles.length,
                        itemBuilder: (ctx, index) {
                          final file = File(pickedFiles[index].path);
                          final isSelected = selectedIndices.contains(index);
                          final orderNumber = isSelected
                              ? selectedIndices.indexOf(index) + 1
                              : null;

                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                if (isSelected) {
                                  selectedIndices.remove(index);
                                } else {
                                  selectedIndices.add(index);
                                }
                              });
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    file,
                                    fit: BoxFit.cover,
                                  ),
                                ),

                                // grey overlay when unselected
                                if (!isSelected)
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.black.withOpacity(0.4),
                                    ),
                                    child: const Center(
                                      child:
                                      Icon(Icons.add, color: Colors.white),
                                    ),
                                  ),

                                // numbered bubble when selected
                                if (orderNumber != null)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor:
                                      const Color(0xFF128C7E),
                                      child: Text(
                                        orderNumber.toString(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
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

                    // Caption + send
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            // Caption
                            Expanded(
                              child: TextField(
                                controller: captionController,
                                textCapitalization:
                                TextCapitalization.sentences,
                                maxLines: 3,
                                minLines: 1,
                                decoration: InputDecoration(
                                  hintText: 'Add caption...',
                                  hintStyle: TextStyle(
                                    color: colorScheme.primary
                                        .withOpacity(0.7),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.tertiary,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                style: TextStyle(
                                  color: colorScheme.inversePrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Send button
                            GestureDetector(
                              onTap: selectedIndices.isEmpty
                                  ? null
                                  : () {
                                final caption =
                                captionController.text.trim();

                                final selectedFiles = <XFile>[
                                  for (final idx in selectedIndices)
                                    pickedFiles[idx],
                                ];

                                Navigator.of(sheetContext).pop(
                                  ImageSelectionWithCaption(
                                    files: selectedFiles,
                                    caption: caption,
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFF128C7E),
                                child: const Icon(Icons.send,
                                    color: Colors.white, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    return result;
  }
}
