import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ummah_chat/models/notification.dart' as models;
import 'package:ummah_chat/pages/profile_page.dart';

import '../helper/navigate_pages.dart';
import '../helper/time_ago_text.dart';
import '../services/notification_service.dart';

// Providers
import 'package:provider/provider.dart';
import '../services/database/database_provider.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  // 👉 Singleton instance
  final NotificationService notificationService = NotificationService();

  late StreamSubscription<List<models.Notification>> _sub;
  List<models.Notification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Listen once to the Supabase stream and keep a local copy
    _sub = notificationService.notificationsStream().listen(
          (data) {
        setState(() {
          _notifications = data;
          _isLoading = false;
        });
      },
      onError: (_) {
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  // --------- OPTIMISTIC HELPERS ---------

  void _optimisticMarkOneAsRead(models.Notification n) async {
    // 1) Update local list immediately
    setState(() {
      final idx = _notifications.indexWhere((x) => x.id == n.id);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      }
    });

    // 2) Then update DB (Supabase will re-sync anyway)
    try {
      await notificationService.markAsRead(n.id);
    } catch (_) {
      // Optional: show SnackBar or revert, but usually Supabase stream will correct it
    }
  }

  void _optimisticMarkAllAsRead() async {
    // 1) Update local list immediately
    setState(() {
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });

    // 2) Then update DB
    try {
      await notificationService.markAllAsRead();
    } catch (_) {
      // Optional: handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        title: Text(
          'Notifications',
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed:
            _notifications.isEmpty ? null : _optimisticMarkAllAsRead,
            icon: Icon(
              Icons.done_all,
              size: 18,
              color: _notifications.isEmpty
                  ? colorScheme.primary
                  : colorScheme.primary,
            ),
            label: Text(
              'Mark all',
              style: TextStyle(
                color: _notifications.isEmpty
                    ? colorScheme.primary
                    : colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(context, colorScheme, dbProvider),
    );
  }

  Widget _buildBody(
      BuildContext context,
      ColorScheme colorScheme,
      DatabaseProvider dbProvider,
      ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none,
                size: 56,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'No notifications yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "When something happens — likes, comments, or new followers — you'll see it here.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final n = _notifications[index];

        final rawBody = n.body ?? '';
        final body = rawBody.trim();
        final isUnread = !n.isRead;

        // ----- TYPE DETECTION -----
        final isFriendRequest = body.startsWith('FRIEND_REQUEST:');
        final isFriendAccepted = body.startsWith('FRIEND_ACCEPTED:');
        final isLike = body.startsWith('LIKE_POST:');
        final isComment = body.startsWith('COMMENT_POST:');
        final isCommentReply = body.startsWith('COMMENT_REPLY:'); // 👈 NEW
        final isFollow = body.startsWith('FOLLOW_USER:');

        String? friendRequesterId;
        String? friendAcceptedUserId;
        String? likePostId;
        String? likePreview;
        String? commentPostId;
        String? commentPreview;
        String? commentReplyPostId;      // 👈 NEW
        String? commentReplyCommentId;   // 👈 NEW
        String? commentReplyPreview;     // 👈 NEW
        String? followUserId;

        // 🧑‍🤝‍🧑 Friend request → sender
        if (isFriendRequest) {
          final parts = body.split(':');
          if (parts.length > 1) {
            friendRequesterId = parts[1].trim();
          }
        }

        // 🧑‍🤝‍🧑 Friend accepted → the one who accepted
        if (isFriendAccepted) {
          final parts = body.split(':');
          if (parts.length > 1) {
            friendAcceptedUserId = parts[1].trim();
          }
        }

        // 👍 Like
        if (isLike) {
          final rest = body.substring('LIKE_POST:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) likePostId = parts[0];
          if (parts.length > 1) likePreview = parts[1];
        }

        // 💬 Comment
        if (isComment) {
          final rest = body.substring('COMMENT_POST:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) commentPostId = parts[0];
          if (parts.length > 1) commentPreview = parts[1];
        }

        // 💬 Comment reply
        if (isCommentReply) {
          final rest = body.substring('COMMENT_REPLY:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) commentReplyPostId = parts[0];
          if (parts.length > 1) commentReplyCommentId = parts[1];
          if (parts.length > 2) commentReplyPreview = parts[2];
        }

        // 👤 Follow (new-style with encoded userId in body)
        if (isFollow) {
          final parts = body.split(':');
          if (parts.length > 1) {
            followUserId = parts[1].trim();
          }
        }

        // ----- SUBTITLE (preview) -----
        String? subtitleText;
        if (isLike) {
          subtitleText = likePreview;
        } else if (isComment) {
          subtitleText = commentPreview;
        } else if (isCommentReply) {
          subtitleText = commentReplyPreview;
        } else if (!isFriendRequest &&
            !isFriendAccepted &&
            !isFollow &&
            rawBody.isNotEmpty &&
            !rawBody.contains(':')) {
          // legacy / generic text-only notifications (no routing codes)
          subtitleText = rawBody;
        }

        // ----- LEADING ICON (per type) -----
        final leadingIconData = _iconForNotificationType(
          isFriendRequest: isFriendRequest,
          isFriendAccepted: isFriendAccepted,
          isLike: isLike,
          isComment: isComment,
          isCommentReply: isCommentReply, // 👈 NEW
          isFollow: isFollow,
        );

        final leading = Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isUnread
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.secondary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            leadingIconData,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        );

        // ----- TRAILING WIDGET (dot / buttons) -----
        Widget? trailing;

        if (isFriendRequest && friendRequesterId != null && isUnread) {
          // ✅ Only show Accept / Decline while unread
          trailing = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Accept
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 0),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () async {
                  // 1) mark this notification as read
                  _optimisticMarkOneAsRead(n);
                  // 2) accept friend request from this user
                  await dbProvider.acceptFriendRequest(friendRequesterId!);
                },
                child: const Text(
                  'Accept',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              // Decline
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 0),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () async {
                  // 1) mark this notification as read
                  _optimisticMarkOneAsRead(n);
                  // 2) decline (delete pending row)
                  await dbProvider.declineFriendRequest(friendRequesterId!);
                },
                child: const Text(
                  'Decline',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        } else if (!n.isRead && !isFollow) {
          // 🔵 Generic unread dot (but not for follow, per your change)
          trailing =
              _UnreadDot(colorScheme: Theme.of(context).colorScheme);
        } else {
          trailing = null;
        }

        // ----- ROW CONTAINER (card-style) -----
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              if (!n.isRead) {
                _optimisticMarkOneAsRead(n);
              }

              // 🔗 NAVIGATION BEHAVIOR

              // 1) Friend request → go to sender profile
              if (isFriendRequest && friendRequesterId != null) {
                if (!mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      userId: friendRequesterId!,
                    ),
                  ),
                );

                if (!mounted) return;
                setState(() {});
              }

              // 2) "accepted your friend request" → go to accepter's profile
              else if (isFriendAccepted && friendAcceptedUserId != null) {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      userId: friendAcceptedUserId!,
                    ),
                  ),
                );
              }

              // 3) Like / Comment / Comment reply → go to post
              else if ((isLike || isComment || isCommentReply) &&
                  (likePostId != null ||
                      commentPostId != null ||
                      commentReplyPostId != null)) {
                final postId = isLike
                    ? likePostId
                    : (isComment ? commentPostId : commentReplyPostId);

                if (postId == null) return;

                final post = await dbProvider.getPostById(postId);
                if (post != null && mounted) {
                  await goPostPage(
                    context,
                    post,
                    scrollToComments: isComment || isCommentReply,
                    highlightPost: true,
                    highlightComments: isComment || isCommentReply,
                    // Later you can add: scrollToCommentId: commentReplyCommentId
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'This post is no longer available.',
                      ),
                    ),
                  );
                }
              }

              // 4) Follow → go to follower profile (only for new-style FOLLOW_USER:... bodies)
              else if (isFollow && followUserId != null) {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      userId: followUserId!,
                    ),
                  ),
                );
              }
            },
            child: Ink(
              decoration: BoxDecoration(
                color: isUnread
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    leading,
                    const SizedBox(width: 10),
                    // Texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  n.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isUnread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              TimeAgoText(
                                createdAt: n.createdAt,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                              ),
                            ],
                          ),
                          if (subtitleText != null &&
                              subtitleText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitleText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Trailing (buttons or dot)
                    trailing ?? const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _iconForNotificationType({
    required bool isFriendRequest,
    required bool isFriendAccepted,
    required bool isLike,
    required bool isComment,
    required bool isCommentReply, // 👈 NEW
    required bool isFollow,
  }) {
    if (isFriendRequest) return Icons.person_add_alt_1;
    if (isFriendAccepted) return Icons.handshake;
    if (isLike) return Icons.favorite;
    if (isComment || isCommentReply) return Icons.mode_comment_outlined;
    if (isFollow) return Icons.person;
    return Icons.notifications;
  }
}

class _UnreadDot extends StatelessWidget {
  final ColorScheme colorScheme;

  const _UnreadDot({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
