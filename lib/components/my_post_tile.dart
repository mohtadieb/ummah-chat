import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../helper/time_ago_text.dart';
import '../models/post.dart';
import '../services/database/database_provider.dart';
import '../components/my_input_alert_box.dart';
import '../services/auth/auth_service.dart';
import 'my_confirmation_box.dart';

/*

POST TILE

All posts will be displayed using this post tile widget.

--------------------------------------------------------------------------------

To use this widget, you need:

- The post
- a function for onPostTap (to go the individual post to see its comments)
- a function for onUserTap (to go to user's profile page)

*/

class MyPostTile extends StatefulWidget {
  final Post post;
  final void Function()? onUserTap;
  final void Function()? onPostTap;
  final BuildContext scaffoldContext; // add this

  // NEW: flag to know if we're on the dedicated PostPage
  // (used to hide "View all comments" there)
  final bool isInPostPage;

  const MyPostTile({
    super.key,
    required this.post,
    this.onUserTap,
    required this.onPostTap,
    required this.scaffoldContext,
    this.isInPostPage = false, // default: used in feeds / profile, not PostPage
  });

  @override
  State<MyPostTile> createState() => _MyPostTileState();
}

class _MyPostTileState extends State<MyPostTile> {
  // providers
  late final listeningProvider = Provider.of<DatabaseProvider>(context);
  late final databaseProvider = Provider.of<DatabaseProvider>(
    context,
    listen: false,
  );

  // comment text controller
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // load comments for this post
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // user tapped like, or unlike
  void _toggleLikePost() async {
    try {
      await databaseProvider.toggleLike(widget.post.id);
    } catch (e) {
      print(e);
    }
  }

  // open comment box -> user wants to type a new comment
  void _openNewCommentBox() {
    showDialog(
      context: context,
      builder: (context) => MyInputAlertBox(
        textController: _commentController,
        hintText: "Type a comment",
        onPressed: () async {
          final comment = _commentController.text.trim();

          // Require at least 2 non-space characters
          if (comment.replaceAll(RegExp(r'\s+'), '').length < 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              // Show a snackbar or alert
              const SnackBar(
                content: Text("Comment must be at least 2 characters"),
              ),
            );
            return; // Don't post
          }

          await _addComment();
        },
        onPressedText: "Post",
      ),
    );
  }

  // user tapped post to add comment
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

  // load comments
  Future<void> _loadComments() async {
    await databaseProvider.loadComments(widget.post.id);
  }

  // SHOW OPTIONS
  void _showOptions() {
    final currentUserId = AuthService().getCurrentUserId();
    final isOwnPost = widget.post.userId == currentUserId;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (isOwnPost)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text("Delete"),
                onTap: () async {
                  Navigator.pop(context); // Close bottom sheet first

                  // Show confirmation dialog
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Delete Post"),
                      content:
                      const Text("Are you sure you want to delete this post?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );

                  // If confirmed, delete post
                  if (confirm == true) {
                    await databaseProvider.deletePost(widget.post);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Post deleted!")),
                    );
                  }
                },
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.report),
                    title: const Text("Report"),
                    onTap: () {
                      Navigator.pop(context);
                      _reportPostConfirmationBox();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text("Block"),
                    onTap: () {
                      Navigator.pop(context);
                      _blockUserConfirmationBox();
                    },
                  ),
                ],
              ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text("Cancel"),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _reportPostConfirmationBox() {
    showDialog(
      context: context,
      builder: (context) => MyConfirmationBox(
        title: "Report Message",
        content: "Are you sure you want to report this message?",
        confirmText: "Report",
        onConfirm: () async {
          await databaseProvider.reportUser(
            widget.post.id,
            widget.post.userId,
          );
          ScaffoldMessenger.of(widget.scaffoldContext).showSnackBar(
            const SnackBar(content: Text("Message reported!")),
          );
        },
      ),
    );
  }

  void _blockUserConfirmationBox() {
    showDialog(
      context: context,
      builder: (context) => MyConfirmationBox(
        title: "Block User",
        content: "Are you sure you want to block this user?",
        confirmText: "Block",
        onConfirm: () async {
          await databaseProvider.blockUser(widget.post.userId);
          ScaffoldMessenger.of(widget.scaffoldContext).showSnackBar(
            const SnackBar(content: Text("User blocked!")),
          );
        },
      ),
    );
  }

  // BUILD UI
  @override
  Widget build(BuildContext context) {
    // does the current user like this post?
    bool likedByCurrentUser = listeningProvider.isPostLikedByCurrentUser(
      widget.post.id,
    );

    // listen to like count
    int likeCount = listeningProvider.getLikeCount(widget.post.id);

    // listen to comment count
    int commentCount = listeningProvider.getComments(widget.post.id).length;

    return GestureDetector(
      onTap: widget.onPostTap,
      child: Container(
        color:
        Theme.of(context).colorScheme.surface, // IG-style flat background
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER: avatar + name + username + more
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onUserTap,
                    child: Row(
                      children: [
                        // circle avatar instead of big person icon
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .secondary
                              ,
                          child: Icon(
                            Icons.person,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.post.name,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .inversePrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '@${widget.post.username}',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    ,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showOptions,
                    child: Icon(
                      Icons.more_horiz,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                ],
              ),
            ),

            // IMAGE
            if (widget.post.imageUrl != null)
              AspectRatio(
                aspectRatio: 4 / 5, // IG-style aspect ratio
                child: Image.network(
                  widget.post.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Text('Failed to load image'));
                  },
                ),
              )
            else
            // If no image, show a simple text card
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  widget.post.message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.inversePrimary,
                    fontSize: 15,
                  ),
                ),
              ),

            const SizedBox(height: 6),

            // ACTIONS ROW (like, comment, share, bookmark)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _toggleLikePost,
                    icon: likedByCurrentUser
                        ? const Icon(Icons.favorite)
                        : const Icon(Icons.favorite_border),
                    color: likedByCurrentUser
                        ? Colors.red
                        : Theme.of(context).colorScheme.inversePrimary,
                  ),
                  IconButton(
                    onPressed: _openNewCommentBox,
                    icon: const Icon(Icons.mode_comment_outlined),
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                  IconButton(
                    onPressed: widget.onPostTap,
                    icon: const Icon(Icons.send_outlined),
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      // TODO: implement save/bookmark
                    },
                    icon: const Icon(Icons.bookmark_border),
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ],
              ),
            ),

            // LIKES COUNT
            if (likeCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  likeCount == 1 ? '1 like' : '$likeCount likes',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.inversePrimary,
                    fontSize: 14,
                  ),
                ),
              ),

            const SizedBox(height: 4),

            // CAPTION: username + message (Instagram style)
            if (widget.post.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${widget.post.username} ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                          Theme.of(context).colorScheme.inversePrimary,
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: widget.post.message,
                        style: TextStyle(
                          color:
                          Theme.of(context).colorScheme.inversePrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 4),

            // VIEW ALL COMMENTS
            // Only show this in feed / profile pages, NOT on the dedicated PostPage
            if (!widget.isInPostPage && commentCount > 0)
              GestureDetector(
                onTap: widget.onPostTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'View all $commentCount comments',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          ,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 4),

            // TIME AGO
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: TimeAgoText(
                createdAt: widget.post.createdAt,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      ,
                  fontSize: 11,
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
