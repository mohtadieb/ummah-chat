import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/post_media.dart';
import '../services/database/database_provider.dart';

class PostMediaCarousel extends StatefulWidget {
  final String postId;

  const PostMediaCarousel({
    super.key,
    required this.postId,
  });

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseProvider>(context, listen: false);

    return FutureBuilder<List<PostMedia>>(
      future: db.getPostMedia(widget.postId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AspectRatio(
            aspectRatio: 4 / 5,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final media = snapshot.data ?? [];
        if (media.isEmpty) {
          // No extra media → nothing to show (fallback to post.imageUrl in parent)
          return const SizedBox.shrink();
        }

        final controller = PageController();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: PageView.builder(
                controller: controller,
                itemCount: media.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final item = media[index];

                  if (item.isImage) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        item.url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.broken_image),
                          );
                        },
                      ),
                    );
                  }

                  if (item.isVideo) {
                    // 👉 You can replace this placeholder with your real video player widget
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.black12,
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_circle_fill,
                                size: 64,
                              ),
                              const SizedBox(height: 8),
                              Text('Video'.tr()),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  // Fallback
                  return const SizedBox.shrink();
                },
              ),
            ),

            const SizedBox(height: 8),

            // Dots indicator
            if (media.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(media.length, (index) {
                  final isActive = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    width: isActive ? 16 : 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.black.withOpacity(0.8)
                          : Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
          ],
        );
      },
    );
  }
}
