/*
COMMENT TILE

This is the comment tile widget which belongs below a post. It's similar to the
post tile widget, but styled more like Instagram comments.
*/

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/navigate_pages.dart';
import '../helper/time_ago_text.dart';
import '../models/comment.dart';
import '../services/auth/auth_service.dart';
import '../services/database/database_provider.dart';
import 'my_confirmation_box.dart';
import '../components/my_input_alert_box.dart';

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
    final theme = Theme.of(context);
    final currentUserId = AuthService().getCurrentUserId();
    final isOwnComment = widget.comment.userId == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final cs = theme.colorScheme;

        Widget actionTile({
          required IconData icon,
          required String title,
          required VoidCallback onTap,
          Color? iconColor,
          Color? textColor,
        }) {
          return ListTile(
            leading: Icon(
              icon,
              color: iconColor ?? cs.onSurface,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: textColor ?? cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onTap: onTap,
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Wrap(
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: cs.outline.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),

                actionTile(
                  icon: Icons.reply_rounded,
                  title: "Reply".tr(),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openReplyBox();
                  },
                ),

                if (isOwnComment) ...[
                  actionTile(
                    icon: Icons.delete_outline_rounded,
                    title: "Delete".tr(),
                    iconColor: Colors.redAccent,
                    textColor: Colors.redAccent,
                    onTap: () async {
                      Navigator.pop(sheetContext);

                      await databaseProvider.deleteComment(
                        widget.comment.id,
                        widget.comment.postId,
                      );
                    },
                  ),
                ] else ...[
                  actionTile(
                    icon: Icons.outlined_flag_rounded,
                    title: "Report".tr(),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _reportPostConfirmationBox();
                    },
                  ),
                  actionTile(
                    icon: Icons.block_rounded,
                    title: "Block".tr(),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _blockUserConfirmationBox();
                    },
                  ),
                ],

                actionTile(
                  icon: Icons.close_rounded,
                  title: "Cancel".tr(),
                  onTap: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
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
        hintText: "Write a reply".tr(),
        onPressedText: "Reply".tr(),
        onPressed: () async {
          final text = _replyController.text.trim();

          if (text.replaceAll(RegExp(r'\s+'), '').length < 5) {
            messenger?.showSnackBar(
              SnackBar(
                content: Text("Reply must be at least 5 characters".tr()),
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
      await databaseProvider.replyToComment(
        postId: widget.comment.postId,
        replyText: text,
        parentCommentId: widget.comment.id,
        parentCommentUserId: widget.comment.userId,
        parentCommentUsername: widget.comment.username,
      );
    } catch (e) {
      debugPrint('Error sending reply: $e');
    } finally {
      _replyController.clear();
    }
  }

  void _handleUserTap() {
    final currentUserId = AuthService().getCurrentUserId();

    // 👉 If comment belongs to the logged-in user: go to own profile tab
    if (widget.comment.userId == currentUserId) {
      goToOwnProfileTab(context);
      return;
    }

    // 👉 If it's another user → normal navigation
    if (widget.onUserTap != null) {
      widget.onUserTap!();
    }
  }

  void _reportPostConfirmationBox() {
    showDialog(
      context: context,
      builder: (context) => MyConfirmationBox(
        title: "Report Message".tr(),
        content: "Are you sure you want to report this message?".tr(),
        confirmText: "Report".tr(),
        onConfirm: () async {
          await databaseProvider.reportUser(
            widget.comment.id,
            widget.comment.userId,
          );
          ScaffoldMessenger.of(widget.scaffoldContext).showSnackBar(
            SnackBar(content: Text("Message reported!".tr())),
          );
        },
      ),
    );
  }

  void _blockUserConfirmationBox() {
    showDialog(
      context: context,
      builder: (context) => MyConfirmationBox(
        title: "Block User".tr(),
        content: "Are you sure you want to block this user?".tr(),
        confirmText: "Block".tr(),
        onConfirm: () async {
          await databaseProvider.blockUser(widget.comment.userId);
          ScaffoldMessenger.of(widget.scaffoldContext).showSnackBar(
            SnackBar(content: Text("User blocked!".tr())),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final cardColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.38);
    final borderColor = colorScheme.outline.withValues(alpha: 0.12);
    final usernameColor = colorScheme.onSurface;
    final messageColor = colorScheme.onSurface.withValues(alpha: 0.92);
    final metaColor = colorScheme.onSurfaceVariant;
    final iconColor = colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              GestureDetector(
                onTap: _handleUserTap,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                    backgroundImage: widget.comment.profilePhotoUrl != null &&
                        widget.comment.profilePhotoUrl!.isNotEmpty
                        ? NetworkImage(widget.comment.profilePhotoUrl!)
                        : null,
                    child: (widget.comment.profilePhotoUrl == null ||
                        widget.comment.profilePhotoUrl!.isEmpty)
                        ? Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    )
                        : null,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _handleUserTap,
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                            color: messageColor,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: '${widget.comment.username}  ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: usernameColor,
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text: widget.comment.message,
                              style: TextStyle(
                                color: messageColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TimeAgoText(
                      createdAt: widget.comment.createdAt,
                      style: TextStyle(
                        color: metaColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // More options
              IconButton(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: iconColor,
                  size: 20,
                ),
                onPressed: () => _showOptions(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}