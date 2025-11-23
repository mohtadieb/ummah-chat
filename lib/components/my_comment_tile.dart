/*
COMMENT TILE

This is the comment tile widget which belongs below a post. It's similar to the
post tile widget, but styled more like Instagram comments.

--------------------------------------------------------------------------------

To use this widget, you need:

- the comment
- a function (for when the user taps and wants to go to the user profile of this
  comment)

Displays a single comment with options to delete, report, or block depending on ownership.
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../helper/time_ago_text.dart';
import '../models/comment.dart';
import '../services/auth/auth_service.dart';
import '../services/database/database_provider.dart';
import 'my_confirmation_box.dart';

class MyCommentTile extends StatefulWidget {
  final Comment comment;
  final void Function()? onUserTap;
  final BuildContext scaffoldContext; // add this

  const MyCommentTile({
    super.key,
    required this.comment,
    required this.onUserTap,
    required this.scaffoldContext, // add required
  });

  @override
  State<MyCommentTile> createState() => _MyCommentTileState();
}

class _MyCommentTileState extends State<MyCommentTile> {
  // providers
  late final listeningProvider = Provider.of<DatabaseProvider>(context);
  late final databaseProvider = Provider.of<DatabaseProvider>(
    context,
    listen: false,
  );

  /// Show options for this comment: delete (own), report/block (others)
  void _showOptions(BuildContext context) {
    // check if this comment is owned by the user or not
    final currentUserId = AuthService().getCurrentUserId();
    final isOwnComment = widget.comment.userId == currentUserId;

    // show options
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              // THIS COMMENT BELONGS TO USER
              if (isOwnComment) ...[
                // delete comment button
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text("Delete"),
                  onTap: () async {
                    // pop option box
                    Navigator.pop(context);

                    // handle delete action
                    await databaseProvider.deleteComment(
                      widget.comment.id,
                      widget.comment.postId,
                    );
                  },
                ),
                // THIS COMMENT DOES NOT BELONG TO USER
              ] else ...[
                // report comment button
                ListTile(
                  leading: const Icon(Icons.report),
                  title: const Text("Report"),
                  onTap: () {
                    // pop option box
                    Navigator.pop(context);
                    _reportPostConfirmationBox();
                  },
                ),

                // block user button
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text("Block"),
                  onTap: () {
                    // pop option box
                    Navigator.pop(context);
                    _blockUserConfirmationBox();
                  },
                ),
              ],

              // Always show cancel
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text("Cancel"),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
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
      // Similar spacing to IG comments
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: colorScheme.surface, // keep consistent with post background
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
                // username + comment in one line (Instagram style)
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

                // time ago (small & subtle)
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
