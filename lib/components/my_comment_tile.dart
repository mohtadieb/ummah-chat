/*
COMMENT TILE

This is the comment tile widget which belongs below a post. It's similar to the
post tile widget, but styled more like Instagram comments.
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/time_ago_text.dart';
import '../models/comment.dart';
import '../services/auth/auth_service.dart';
import '../services/database/database_provider.dart';
import 'my_confirmation_box.dart';
import '../components/my_input_alert_box.dart';
import '../services/notification_service.dart'; // 👈 NEW

class MyCommentTile extends StatefulWidget {
  final Comment comment;
  final void Function()? onUserTap;
  final BuildContext scaffoldContext; // context with ScaffoldMessenger

  const MyCommentTile({
    super.key,
    required this.comment,
    required this.onUserTap,
    required this.scaffoldContext,
  });

  @override
  State<MyCommentTile> createState() => _MyCommentTileState();
}

class _MyCommentTileState extends State<MyCommentTile> {
  // providers
  late final listeningProvider = Provider.of<DatabaseProvider>(context);
  late final databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);

  // reply text controller
  final TextEditingController _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  /// Show options for this comment: reply, delete (own), report/block (others)
  void _showOptions(BuildContext context) {
    final currentUserId = AuthService().getCurrentUserId();
    final isOwnComment = widget.comment.userId == currentUserId;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              // REPLY (for everyone)
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text("Reply"),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openReplyBox();
                },
              ),

              if (isOwnComment) ...[
                // OWN COMMENT: delete
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text("Delete"),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    await databaseProvider.deleteComment(
                      widget.comment.id,
                      widget.comment.postId,
                    );
                  },
                ),
              ] else ...[
                // NOT OWN COMMENT: report / block
                ListTile(
                  leading: const Icon(Icons.report),
                  title: const Text("Report"),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reportPostConfirmationBox();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text("Block"),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _blockUserConfirmationBox();
                  },
                ),
              ],

              // Always show cancel
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text("Cancel"),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Open reply input dialog with @username prefilled
  void _openReplyBox() {
    final messenger = ScaffoldMessenger.maybeOf(widget.scaffoldContext);

    // prefill with @username
    _replyController.text = '@${widget.comment.username} ';

    showDialog(
      context: context,
      builder: (dialogContext) => MyInputAlertBox(
        textController: _replyController,
        hintText: "Write a reply",
        onPressedText: "Reply",
        onPressed: () async {
          final text = _replyController.text.trim();

          if (text.replaceAll(RegExp(r'\s+'), '').length < 2) {
            messenger?.showSnackBar(
              const SnackBar(
                content: Text("Reply must be at least 2 characters"),
              ),
            );
            return;
          }

          await _sendReply();
        },
      ),
    );
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    try {
      // 1) Save reply as a normal comment on the same post
      await databaseProvider.addComment(
        widget.comment.postId,
        text,
      );

      // 2) Create notification for the user who wrote the original comment
      final currentUserId = AuthService().getCurrentUserId();

      // don't notify yourself when replying to your own comment
      if (widget.comment.userId != currentUserId) {
        final preview =
        text.length > 80 ? '${text.substring(0, 80)}…' : text;

        // BODY FORMAT:
        // COMMENT_REPLY:<postId>::<commentId>::<preview>
        await NotificationService().createNotificationForUser(
          targetUserId: widget.comment.userId,
          title: 'New reply on your comment',
          body:
          'COMMENT_REPLY:${widget.comment.postId}::${widget.comment.id}::$preview',
        );
      }
    } catch (e) {
      debugPrint('Error sending reply: $e');
    } finally {
      _replyController.clear();
    }
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
            widget.comment.id,
            widget.comment.userId,
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
          await databaseProvider.blockUser(widget.comment.userId);
          ScaffoldMessenger.of(widget.scaffoldContext).showSnackBar(
            const SnackBar(content: Text("User blocked!")),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          GestureDetector(
            onTap: widget.onUserTap,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.secondary,
              child: Icon(
                Icons.person,
                size: 18,
                color: colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Comment content: username + text + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // username + comment
                GestureDetector(
                  onTap: widget.onUserTap,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${widget.comment.username} ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.inversePrimary,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: widget.comment.message,
                          style: TextStyle(
                            color: colorScheme.inversePrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 2),

                // time ago
                TimeAgoText(
                  createdAt: widget.comment.createdAt,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // More options (3 dots)
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: colorScheme.inversePrimary,
              size: 20,
            ),
            onPressed: () => _showOptions(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
