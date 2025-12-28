/*
POST PAGE

This page displays:
- individual's posts
- comments on this post
*/

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/my_post_tile.dart';
import '../components/my_comment_tile.dart';
import '../models/post.dart';
import '../services/database/database_provider.dart';
import '../helper/navigate_pages.dart';

class PostPage extends StatefulWidget {
  /// Normal navigation uses this
  final Post? post;

  /// Push deep links will use this (and we will fetch the Post)
  final String? postId;

  // 🆕 Behavior flags
  final bool scrollToComments; // scroll down to comments on open
  final bool highlightPost; // briefly highlight the post area
  final bool highlightComments; // briefly highlight the comments area

  /// 🆕 Scroll to a specific comment (e.g. for COMMENT_REPLY)
  final String? highlightCommentId;

  const PostPage({
    super.key,
    required this.post,
    this.postId,
    this.scrollToComments = false,
    this.highlightPost = false,
    this.highlightComments = false,
    this.highlightCommentId,
  }) : assert(post != null || postId != null,
  'PostPage requires either `post` or `postId`.');

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

  // 🆕 Post loaded by id (for push deep links)
  Post? _post;
  bool _loadingPost = false;

  // Keys to scroll to a specific comment
  final Map<String, GlobalKey> _commentKeys = {};

  String get _resolvedPostId => (_post?.id ?? widget.post?.id ?? '').toString();

  @override
  void initState() {
    super.initState();

    _highlightPost = widget.highlightPost;
    _highlightComments = widget.highlightComments;

    // Load post if opened via postId
    _post = widget.post;
    _loadPostIfNeeded().then((_) async {
      // Load comments for this post
      if (_resolvedPostId.isNotEmpty) {
        databaseProvider.loadComments(_resolvedPostId);
      }

      // Highlights fade away
      if (_highlightPost || _highlightComments) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          setState(() {
            _highlightPost = false;
            _highlightComments = false;
          });
        });
      }

      // Post frame routing behavior
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // If comment id is provided -> scroll to that comment after comments populate
        if (widget.highlightCommentId != null &&
            widget.highlightCommentId!.trim().isNotEmpty) {
          await _scrollToCommentWhenReady(widget.highlightCommentId!.trim());
          return;
        }

        // Otherwise scroll to comments block if requested
        if (widget.scrollToComments) {
          await Future.delayed(const Duration(milliseconds: 350));
          if (!mounted || !_scrollController.hasClients) return;

          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  Future<void> _loadPostIfNeeded() async {
    if (_post != null) return;
    final pid = (widget.postId ?? '').trim();
    if (pid.isEmpty) return;

    setState(() => _loadingPost = true);

    try {
      final data = await Supabase.instance.client
          .from('posts')
          .select()
          .eq('id', pid)
          .maybeSingle();

      if (!mounted) return;

      if (data == null) {
        debugPrint('⚠️ Post not found for postId=$pid');
        setState(() {
          _loadingPost = false;
          _post = null;
        });
        return;
      }

      setState(() {
        _post = Post.fromMap(data);
        _loadingPost = false;
      });
    } catch (e, st) {
      debugPrint('❌ Failed to load post for postId=$pid: $e\n$st');
      if (!mounted) return;
      setState(() => _loadingPost = false);
    }
  }

  /// Wait for provider comments to include commentId then scroll to it.
  Future<void> _scrollToCommentWhenReady(String commentId) async {
    // Try for ~2 seconds max (comments load async)
    for (int i = 0; i < 10; i++) {
      if (!mounted) return;

      final comments = listeningProvider.getComments(_resolvedPostId);
      final exists = comments.any((c) => c.id == commentId);

      if (exists) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;

        final key = _commentKeys[commentId];
        if (key?.currentContext != null) {
          // Make sure comments section is highlighted for reply taps
          setState(() => _highlightComments = true);

          await Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            alignment: 0.2,
          );

          // fade highlight off
          Future.delayed(const Duration(milliseconds: 900), () {
            if (!mounted) return;
            setState(() => _highlightComments = false);
          });

          return;
        }
      }

      await Future.delayed(const Duration(milliseconds: 200));
    }

    // fallback: at least go to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
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
    final theme = Theme.of(context);

    if (_loadingPost) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(foregroundColor: theme.colorScheme.primary),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final post = _post ?? widget.post;
    if (post == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(foregroundColor: theme.colorScheme.primary),
        body: Center(
          child: Text(
            "This post is no longer available.".tr(),
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
      );
    }

    // listen to all comments for this post
    final allComments = listeningProvider.getComments(post.id);

    final highlightTint = theme.colorScheme.primary.withValues(alpha: 0.10);

    // Build a single list (no nested ListView.builder) so scrolling to comment works reliably
    final itemsCount = 2 + allComments.length; // 0=post, 1=header, rest=comments

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        foregroundColor: theme.colorScheme.primary,
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: itemsCount,
        itemBuilder: (context, index) {
          // 0) Post tile
          if (index == 0) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _highlightPost ? highlightTint : Colors.transparent,
              ),
              child: MyPostTile(
                post: post,
                onUserTap: () => goUserPage(context, post.userId),
                onPostTap: () {},
                scaffoldContext: context,
                isInPostPage: true,
              ),
            );
          }

          // 1) Header + empty state wrapper
          if (index == 1) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  color: _highlightComments ? highlightTint : Colors.transparent,
                  child: allComments.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "No comments yet".tr(),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          }

          // Comments
          final comment = allComments[index - 2];

          // create key for scrolling to specific comment
          _commentKeys.putIfAbsent(comment.id, () => GlobalKey());

          return Container(
            key: _commentKeys[comment.id],
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: MyCommentTile(
              comment: comment,
              onUserTap: () => goUserPage(context, comment.userId),
              scaffoldContext: context,
            ),
          );
        },
      ),
    );
  }
}
