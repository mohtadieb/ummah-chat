/*
POST PAGE

This page displays:
- individual's posts
- comments on this post
*/

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/my_post_tile.dart';
import '../components/my_comment_tile.dart';
import '../models/post.dart';
import '../services/database/database_provider.dart';
import '../helper/navigate_pages.dart';

class PostPage extends StatefulWidget {
  final Post post;

  // 🆕 Behavior flags
  final bool scrollToComments; // scroll down to comments on open
  final bool highlightPost; // briefly highlight the post area
  final bool highlightComments; // briefly highlight the comments area

  const PostPage({
    super.key,
    required this.post,
    this.scrollToComments = false,
    this.highlightPost = false,
    this.highlightComments = false,
  });

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  // providers (kept exactly like you had)
  late final DatabaseProvider listeningProvider =
  Provider.of<DatabaseProvider>(context);
  late final DatabaseProvider databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);

  final TextEditingController _commentController = TextEditingController();

  // scroll controller for list
  final ScrollController _scrollController = ScrollController();

  // 🆕 internal highlight state
  bool _highlightPost = false;
  bool _highlightComments = false;

  @override
  void initState() {
    super.initState();

    // Load comments for this post
    databaseProvider.loadComments(widget.post.id);

    // 🆕 set initial highlight state from widget
    _highlightPost = widget.highlightPost;
    _highlightComments = widget.highlightComments;

    // 🆕 fade highlight away after a short delay
    if (_highlightPost || _highlightComments) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _highlightPost = false;
          _highlightComments = false;
        });
      });
    }

    // 🆕 optional scroll-to-comments on open (used for comment notifications)
    // NOTE: comments load async, so we do a small delayed scroll after first frame.
    if (widget.scrollToComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 350));
        if (!mounted || !_scrollController.hasClients) return;

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // listen to all comments for this post
    final allComments = listeningProvider.getComments(widget.post.id);
    final theme = Theme.of(context);

    final highlightTint = theme.colorScheme.primary.withValues(alpha: 0.10);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        foregroundColor: theme.colorScheme.primary,
      ),
      body: ListView(
        controller: _scrollController,
        children: [
          // 🧵 Post area with subtle highlight
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _highlightPost ? highlightTint : Colors.transparent,
            ),
            child: MyPostTile(
              post: widget.post,
              onUserTap: () => goUserPage(context, widget.post.userId),
              onPostTap: () {}, // already on this post
              scaffoldContext: context,
              isInPostPage: true,
            ),
          ),

          const SizedBox(height: 12),

          // 🗨️ Comments header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              "Comments".tr(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 4),

          // 🧵 Comments block with soft highlight for comment notifications
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            color: _highlightComments ? highlightTint : Colors.transparent,
            child: allComments.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "No comments yet...".tr(),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            )
                : ListView.builder(
              itemCount: allComments.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                final comment = allComments[index];
                return MyCommentTile(
                  comment: comment,
                  onUserTap: () => goUserPage(context, comment.userId),
                  scaffoldContext: context,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
