import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/time_ago_text.dart';
import '../models/post.dart';
import '../services/database/database_provider.dart';
import '../components/my_input_alert_box.dart';
import '../services/auth/auth_service.dart';
import 'my_confirmation_box.dart';

class MyPostTile extends StatefulWidget {
  final Post post;
  final void Function()? onUserTap;
  final void Function()? onPostTap;
  final BuildContext scaffoldContext;
  final bool isInPostPage;

  const MyPostTile({
    super.key,
    required this.post,
    this.onUserTap,
    required this.onPostTap,
    required this.scaffoldContext,
    this.isInPostPage = false,
  });

  @override
  State<MyPostTile> createState() => _MyPostTileState();
}

class _MyPostTileState extends State<MyPostTile> {
  late final listeningProvider = Provider.of<DatabaseProvider>(context);
  late final databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);

  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    await databaseProvider.loadComments(widget.post.id);
  }

  void _toggleLikePost() async {
    try {
      await databaseProvider.toggleLike(widget.post.id);
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  void _openNewCommentBox() {
    final messenger = ScaffoldMessenger.maybeOf(widget.scaffoldContext);

    showDialog(
      context: context,
      builder: (dialogContext) => MyInputAlertBox(
        textController: _commentController,
        hintText: "Type a comment",
        onPressed: () async {
          final comment = _commentController.text.trim();

          if (comment.replaceAll(RegExp(r'\s+'), '').length < 2) {
            messenger?.showSnackBar(
              const SnackBar(
                content: Text("Comment must be at least 2 characters"),
              ),
            );
            return;
          }

          await _addComment();
        },
        onPressedText: "Post",
      ),
    );
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await databaseProvider.addComment(
        widget.post.id,
        _commentController.text.trim(),
      );
    } catch (e) {
      debugPrint('Error adding comment: $e');
    } finally {
      _commentController.clear();
    }
  }

  void _showOptions() {
    final currentUserId = AuthService().getCurrentUserId();
    final isOwnPost = widget.post.userId == currentUserId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (isOwnPost)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text("Delete"),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final messenger =
                  ScaffoldMessenger.maybeOf(widget.scaffoldContext);

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text("Delete Post"),
                      content: const Text(
                        "Are you sure you want to delete this post?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext, true),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await databaseProvider.deletePost(widget.post);

                    if (!mounted) return;

                    messenger?.showSnackBar(
                      const SnackBar(content: Text("Post deleted")),
                    );
                  }
                },
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.report_outlined),
                    title: const Text("Report"),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _reportPostConfirmationBox();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text("Block user"),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _blockUserConfirmationBox();
                    },
                  ),
                ],
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text("Cancel"),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  void _reportPostConfirmationBox() {
    showDialog(
      context: context,
      builder: (dialogContext) => MyConfirmationBox(
        title: "Report Message",
        content: "Are you sure you want to report this message?",
        confirmText: "Report",
        onConfirm: () async {
          await databaseProvider.reportUser(
            widget.post.id,
            widget.post.userId,
          );
          final messenger =
          ScaffoldMessenger.maybeOf(widget.scaffoldContext);
          messenger?.showSnackBar(
            const SnackBar(content: Text("Message reported")),
          );
        },
      ),
    );
  }

  void _blockUserConfirmationBox() {
    showDialog(
      context: context,
      builder: (dialogContext) => MyConfirmationBox(
        title: "Block User",
        content: "Are you sure you want to block this user?",
        confirmText: "Block",
        onConfirm: () async {
          await databaseProvider.blockUser(widget.post.userId);
          final messenger =
          ScaffoldMessenger.maybeOf(widget.scaffoldContext);
          messenger?.showSnackBar(
            const SnackBar(content: Text("User blocked")),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onUserTap,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.2),
                  child: Text(
                    widget.post.name.isNotEmpty
                        ? widget.post.name[0].toUpperCase()
                        : '@',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${widget.post.username}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _showOptions,
            icon: const Icon(Icons.more_horiz),
            splashRadius: 18,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildImageOrText(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.post.imageUrl != null) {
      // Image post
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Image.network(
            widget.post.imageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: theme.colorScheme.surfaceVariant,
                alignment: Alignment.center,
                child: const Text('Failed to load image'),
              );
            },
          ),
        ),
      );
    }

    // Text-only post
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        widget.post.message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildActionsRow(BuildContext context) {
    final theme = Theme.of(context);

    final likedByCurrentUser =
    listeningProvider.isPostLikedByCurrentUser(widget.post.id);
    final iconColor = theme.colorScheme.onSurface.withOpacity(0.9);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleLikePost,
            icon: likedByCurrentUser
                ? const Icon(Icons.favorite)
                : const Icon(Icons.favorite_border),
            color: likedByCurrentUser ? Colors.red : iconColor,
            splashRadius: 20,
          ),
          IconButton(
            onPressed: _openNewCommentBox,
            icon: const Icon(Icons.mode_comment_outlined),
            color: iconColor,
            splashRadius: 20,
          ),
          IconButton(
            onPressed: widget.onPostTap,
            icon: const Icon(Icons.send_outlined),
            color: iconColor,
            splashRadius: 20,
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              // TODO: implement save/bookmark
            },
            icon: const Icon(Icons.bookmark_border),
            color: iconColor,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final likeCount = listeningProvider.getLikeCount(widget.post.id);
    final commentCount =
        listeningProvider.getComments(widget.post.id).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: widget.onPostTap,
        child: Card(
          elevation: theme.brightness == Brightness.dark ? 0.5 : 1.5,
          shadowColor:
          theme.colorScheme.shadow.withOpacity(theme.brightness == Brightness.dark ? 0.25 : 0.18),
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 10,
              top: 8,
              bottom: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),

                const SizedBox(height: 4),

                // image or text content
                _buildImageOrText(context),

                const SizedBox(height: 6),

                // actions
                _buildActionsRow(context),

                // likes
                if (likeCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      likeCount == 1 ? '1 like' : '$likeCount likes',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),

                const SizedBox(height: 4),

                // caption
// Only show caption if there is an image;
// for pure text posts it's already shown inside _buildImageOrText
                if (widget.post.imageUrl != null && widget.post.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${widget.post.username} ',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: widget.post.message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 4),

                // view all comments
                if (!widget.isInPostPage && commentCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: GestureDetector(
                      onTap: widget.onPostTap,
                      child: Text(
                        'View all $commentCount comments',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 4),

                // time ago
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: TimeAgoText(
                    createdAt: widget.post.createdAt,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary.withOpacity(0.8),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
