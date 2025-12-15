import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/post.dart';
import '../services/database/database_provider.dart';
import '../components/my_post_media_carousel.dart';

class PostDetailPage extends StatelessWidget {
  final Post post;

  const PostDetailPage({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Post'.tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: name + username
            Row(
              children: [
                // (Optional: profile picture)
                CircleAvatar(
                  radius: 20,
                  child: Text(
                    post.name.isNotEmpty ? post.name[0].toUpperCase() : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '@${post.username}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Caption
            Text(
              post.message,
              style: TextStyle(fontSize: 15),
            ),

            const SizedBox(height: 16),

            // Carousel with ALL media for this post
            PostMediaCarousel(postId: post.id),

            const SizedBox(height: 16),

            // Example: simple like count
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  size: 20,
                  color: Colors.red[400],
                ),
                const SizedBox(width: 4),
                Text('${post.likeCount} likes'),
              ],
            ),

            const SizedBox(height: 24),

            // (Optional) comments section could go here using db.loadComments(post.id)
            // ...
          ],
        ),
      ),
    );
  }
}
