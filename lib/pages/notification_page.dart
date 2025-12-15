// lib/pages/notification_page.dart
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ummah_chat/models/notification.dart' as models;
import 'package:ummah_chat/pages/profile_page.dart';
import 'package:ummah_chat/pages/chat_page.dart';
import 'package:ummah_chat/pages/group_chat_page.dart'; // 👈 NEW

import '../helper/navigate_pages.dart';
import '../helper/time_ago_text.dart';
import '../services/notifications/notification_service.dart';
import 'package:intl/intl.dart';

// Providers
import 'package:provider/provider.dart';
import '../services/database/database_provider.dart';
import '../services/auth/auth_service.dart'; // DM / group helpers
import '../services/chat/chat_provider.dart'; // DM / group helpers

/// Helper model so we can mix "header rows" (Today, Yesterday, etc.) and real notifications in one list.
class _NotificationListItem {
  final models.Notification? notification;
  final String? headerLabel;

  _NotificationListItem.header(this.headerLabel) : notification = null;
  _NotificationListItem.notification(this.notification) : headerLabel = null;

  bool get isHeader => headerLabel != null;
}

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

  /// Format a date like "13 Dec 2025"
  String _formatDate(DateTime d) {
    return DateFormat('dd MMM yyyy', context.locale.toString()).format(d);
  }

  /// Build a flattened list of header + notification items grouped by date
  List<_NotificationListItem> _buildGroupedItems() {
    // Clone and sort newest → oldest
    final sorted = [..._notifications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final List<_NotificationListItem> items = [];

    String? lastHeader;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String headerForDate(DateTime dt) {
      final d = DateTime(dt.year, dt.month, dt.day);

      if (d == today) {
        return 'Today'.tr();
      } else if (d == yesterday) {
        // Yesterday + formatted date
        return 'Yesterday'.tr() + ' · ${_formatDate(d)}';
      } else {
        // Just the date for older notifications
        return _formatDate(d);
      }
    }

    for (final n in sorted) {
      final h = headerForDate(n.createdAt);

      if (h != lastHeader) {
        items.add(_NotificationListItem.header(h));
        lastHeader = h;
      }

      items.add(_NotificationListItem.notification(n));
    }

    return items;
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
          'Notifications'.tr(),
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
              'Mark all'.tr(),
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
                'No notifications yet'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text("When something happens — likes, comments, or new followers — you'll see it here.".tr(),
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

    final groupedItems = _buildGroupedItems();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: groupedItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = groupedItems[index];

        // ---- DATE HEADER ROW ----
        if (item.isHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text(
              item.headerLabel!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary.withValues(alpha: 0.8),
              ),
            ),
          );
        }

        // ---- NORMAL NOTIFICATION TILE ----
        final n = item.notification!;

        final rawBody = n.body ?? '';
        final body = rawBody.trim();
        final isUnread = !n.isRead;

        // ----- TYPE DETECTION -----
        final isFriendRequest = body.startsWith('FRIEND_REQUEST:');
        final isFriendAccepted = body.startsWith('FRIEND_ACCEPTED:');
        final isLike = body.startsWith('LIKE_POST:');
        final isComment = body.startsWith('COMMENT_POST:');
        final isCommentReply = body.startsWith('COMMENT_REPLY:');
        final isFollow = body.startsWith('FOLLOW_USER:');
        final isChatMessage = body.startsWith('CHAT_MESSAGE:'); // DM
        final isGroupMessage = body.startsWith('GROUP_MESSAGE:'); // 👈 NEW

        String? friendRequesterId;
        String? friendAcceptedUserId;
        String? likePostId;
        String? likePreview;
        String? commentPostId;
        String? commentPreview;
        String? commentReplyPostId;
        String? commentReplyCommentId;
        String? commentReplyPreview;
        String? followUserId;

        // DM chat fields
        String? chatFriendId;
        String? chatFriendName;

        // GROUP chat fields 👇
        String? groupChatRoomId;
        String? groupName;

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

        // 👤 Follow
        if (isFollow) {
          final parts = body.split(':');
          if (parts.length > 1) {
            followUserId = parts[1].trim();
          }
        }

        // 💬 Chat message (DM) – parse `CHAT_MESSAGE:<senderId>::<senderName>`
        if (isChatMessage) {
          final rest = body.substring('CHAT_MESSAGE:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) chatFriendId = parts[0].trim();
          if (parts.length > 1) chatFriendName = parts[1].trim();
        }

        // 👥 Group message – `GROUP_MESSAGE:<chatRoomId>::<groupName>`
        // Make sure NotificationService writes body in exactly this format.
        if (isGroupMessage) {
          final rest = body.substring('GROUP_MESSAGE:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) groupChatRoomId = parts[0].trim();
          if (parts.length > 1) groupName = parts[1].trim();
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
            !isChatMessage &&
            !isGroupMessage && // 👈 exclude group bodies here too
            rawBody.isNotEmpty &&
            !rawBody.contains(':')) {
          // legacy / generic
          subtitleText = rawBody;
        }

        // ----- LEADING ICON -----
        final leadingIconData = _iconForNotificationType(
          isFriendRequest: isFriendRequest,
          isFriendAccepted: isFriendAccepted,
          isChatMessage: isChatMessage,
          isGroupMessage: isGroupMessage, // 👈 NEW
          isLike: isLike,
          isComment: isComment,
          isCommentReply: isCommentReply,
          isFollow: isFollow,
        );

        final leading = Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isUnread
                ? Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.15)
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

        // ----- TRAILING -----
        Widget? trailing;

        if (isFriendRequest && friendRequesterId != null && isUnread) {
          // Accept / Decline
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
                  _optimisticMarkOneAsRead(n);
                  await dbProvider.acceptFriendRequest(friendRequesterId!);
                },
                child: Text(
                  'Accept'.tr(),
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
                  _optimisticMarkOneAsRead(n);
                  await dbProvider.declineFriendRequest(friendRequesterId!);
                },
                child: Text(
                  'Decline'.tr(),
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        } else if (!n.isRead && !isFollow) {
          trailing = _UnreadDot(
            colorScheme: Theme.of(context).colorScheme,
          );
        } else {
          trailing = null;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              if (!n.isRead) {
                _optimisticMarkOneAsRead(n);
              }

              // 🔗 NAVIGATION BEHAVIOR

              // 1) Friend request → sender profile
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

              // 2) Friend accepted → accepter profile
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

              // 3) Likes / comments → post
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
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'This post is no longer available.'.tr(),
                      ),
                    ),
                  );
                }
              }

              // 4) Follow → follower profile
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

              // 5) Chat message → open DM ChatPage + FORCE mark read
              else if (isChatMessage &&
                  chatFriendId != null &&
                  chatFriendId!.isNotEmpty) {
                if (!mounted) return;

                // Open chat
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      friendId: chatFriendId!,
                      friendName:
                      (chatFriendName != null && chatFriendName!.isNotEmpty)
                          ? chatFriendName!
                          : 'Chat'.tr(),
                    ),
                  ),
                );

                if (!mounted) return;

                // 🔁 After returning, force mark room messages as read
                final currentUserId = AuthService().getCurrentUserId();
                if (currentUserId.isNotEmpty) {
                  final chatProvider =
                  Provider.of<ChatProvider>(context, listen: false);

                  final chatRoomId = await chatProvider.getOrCreateChatRoomId(
                    currentUserId,
                    chatFriendId!,
                  );

                  await chatProvider.markRoomMessagesAsRead(
                    chatRoomId,
                    currentUserId,
                  );
                }
              }

              // 6) Group message → open GroupChatPage + mark group as read
              else if (isGroupMessage &&
                  groupChatRoomId != null &&
                  groupChatRoomId!.isNotEmpty) {
                if (!mounted) return;

                final currentUserId = AuthService().getCurrentUserId();
                final chatProvider =
                Provider.of<ChatProvider>(context, listen: false);

                if (currentUserId.isNotEmpty) {
                  // ✅ Mark messages as read so group badge clears even when opened via notifications
                  await chatProvider.markGroupMessagesAsRead(
                    groupChatRoomId!,
                    currentUserId,
                  );

                  // Optional: mark presence so you don't get duplicate group pushes while inside
                  await chatProvider.setActiveChatRoom(
                    userId: currentUserId,
                    chatRoomId: groupChatRoomId!,
                  );
                }

                // Navigate to the group chat page
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupChatPage(
                      chatRoomId: groupChatRoomId!,
                      groupName: groupName ?? 'Group'.tr(),
                    ),
                  ),
                );

                if (!mounted) return;

                // Optional: clear active chat room when you come back
                if (currentUserId.isNotEmpty) {
                  await chatProvider.setActiveChatRoom(
                    userId: currentUserId,
                    chatRoomId: null,
                  );
                }
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
    required bool isChatMessage,
    required bool isGroupMessage, // 👈 NEW
    required bool isLike,
    required bool isComment,
    required bool isCommentReply,
    required bool isFollow,
  }) {
    if (isFriendRequest) return Icons.person_add_alt_1;
    if (isFriendAccepted) return Icons.handshake;
    if (isGroupMessage) return Icons.groups; // 👈 NEW
    if (isChatMessage) return Icons.chat_bubble_outline;
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
