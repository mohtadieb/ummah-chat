import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../components/my_post_tile.dart';
import '../helper/navigate_pages.dart';
import '../models/post.dart';

class PostFeedPage extends StatefulWidget {
  final List<Post> posts;
  final int initialIndex;

  const PostFeedPage({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  @override
  State<PostFeedPage> createState() => _PostFeedPageState();
}

class _PostFeedPageState extends State<PostFeedPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();

    final safeInitialIndex = widget.posts.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.posts.length - 1);

    _currentIndex = safeInitialIndex;
    _pageController = PageController(initialPage: safeInitialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (widget.posts.isEmpty) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: cs.onSurface,
          title: Text('Posts'.tr()),
        ),
        body: Center(
          child: Text(
            'No posts found'.tr(),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.posts.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final post = widget.posts[index];

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: MyPostTile(
                    post: post,
                    onUserTap: () => goUserPage(context, post.userId),
                    onPostTap: () {},
                    scaffoldContext: context,
                    isInPostPage: true,
                  ),
                );
              },
            ),

            Positioned(
              top: 6,
              left: 6,
              right: 6,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${widget.posts.length}',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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
  }
}