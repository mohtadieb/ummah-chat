// lib/pages/notification_page.dart
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ummah_chat/models/notification.dart' as models;
import 'package:ummah_chat/pages/profile_page.dart';
import 'package:ummah_chat/pages/chat_page.dart';
import 'package:ummah_chat/pages/group_chat_page.dart';
import 'community_posts_page.dart';

import '../helper/navigate_pages.dart';
import '../helper/time_ago_text.dart';
import '../services/chat/chat_service.dart';
import '../services/database/database_service.dart';
import '../services/notifications/notification_service.dart';
import 'package:intl/intl.dart';

// Providers
import 'package:provider/provider.dart';
import '../services/database/database_provider.dart';
import '../services/auth/auth_service.dart';
import '../services/chat/chat_provider.dart';

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
  final NotificationService notificationService = NotificationService();

  late StreamSubscription<List<models.Notification>> _sub;
  List<models.Notification> _notifications = [];
  bool _isLoading = true;

  final Map<String, String> _userNameCache = {};
  final Set<String> _nameFetchInFlight = {};

  @override
  void initState() {
    super.initState();

    _sub = notificationService.notificationsStream().listen(
          (data) {
        setState(() {
          _notifications = data;
          _isLoading = false;
        });

        for (final n in data) {
          final body = (n.body ?? '').trim();

          if (body.startsWith('FOLLOW_USER:')) {
            final parts = body.split(':');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          if (body.startsWith('FRIEND_REQUEST:')) {
            final parts = body.split(':');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          if (body.startsWith('FRIEND_ACCEPTED:')) {
            final parts = body.split(':');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          if (body.startsWith('MAHRAM_REQUEST:')) {
            final parts = body.split(':');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          if (body.startsWith('MAHRAM_ACCEPTED:')) {
            final parts = body.split(':');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          if (body.startsWith('CHAT_MESSAGE:')) {
            final rest = body.substring('CHAT_MESSAGE:'.length);
            final parts = rest.split('::');
            if (parts.isNotEmpty) _cacheName(parts[0].trim());
          }

          if (body.startsWith('COMMUNITY_INVITE:')) {
            final rest = body.substring('COMMUNITY_INVITE:'.length);
            final parts = rest.split('::');
            if (parts.length > 2) _cacheName(parts[2].trim());
          }

          if (body.startsWith('MARRIAGE_INQUIRY_REQUEST:')) {
            final rest = body.substring('MARRIAGE_INQUIRY_REQUEST:'.length);
            final parts = rest.split('::');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          if (body.startsWith('MARRIAGE_INQUIRY_MAHRAM:')) {
            final rest = body.substring('MARRIAGE_INQUIRY_MAHRAM:'.length);
            final parts = rest.split('::');
            if (parts.length > 2) _cacheName(parts[2].trim());
          }

          if (body.startsWith('MARRIAGE_INQUIRY_MAN_DECISION:')) {
            final rest = body.substring(
              'MARRIAGE_INQUIRY_MAN_DECISION:'.length,
            );
            final parts = rest.split('::');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          if (body.startsWith('MARRIAGE_INQUIRY_ACCEPTED:')) {
            final rest = body.substring('MARRIAGE_INQUIRY_ACCEPTED:'.length);
            final parts = rest.split('::');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          if (body.startsWith('MARRIAGE_INQUIRY_DECLINED:')) {
            final rest = body.substring('MARRIAGE_INQUIRY_DECLINED:'.length);
            final parts = rest.split('::');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          if (body.startsWith('MARRIAGE_INQUIRY_MAHRAM_ACCEPTED:')) {
            final rest = body.substring(
              'MARRIAGE_INQUIRY_MAHRAM_ACCEPTED:'.length,
            );
            final parts = rest.split('::');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          if (body.startsWith('MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO:')) {
            final rest = body.substring(
              'MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO:'.length,
            );
            final parts = rest.split('::');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }
        }
      },
      onError: (_) {
        setState(() => _isLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _cacheName(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    if (_userNameCache.containsKey(id)) return;
    if (_nameFetchInFlight.contains(id)) return;

    _nameFetchInFlight.add(id);
    try {
      final profile = await DatabaseService().getUserFromDatabase(id);

      final fullName = (profile?.name ?? '').trim();
      final username = (profile?.username ?? '').trim();

      final display = fullName.isNotEmpty
          ? fullName
          : (username.isNotEmpty ? username : '');

      if (!mounted) return;
      if (display.isNotEmpty) {
        setState(() => _userNameCache[id] = display);
      }
    } catch (_) {
      // ignore
    } finally {
      _nameFetchInFlight.remove(id);
    }
  }

  String _nameFromIdOrFallback(String? userId, String fallback) {
    final id = (userId ?? '').trim();
    final cached = (id.isNotEmpty) ? (_userNameCache[id] ?? '').trim() : '';
    return cached.isNotEmpty ? cached : fallback;
  }

  Future<void> _openGroupChatWithContext({
    required BuildContext context,
    required String chatRoomId,
    required String fallbackGroupName,
  }) async {
    if (chatRoomId.trim().isEmpty) return;

    final exists = await ChatService().groupRoomExistsInDatabase(
      chatRoomId.trim(),
    );
    if (!exists) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This group is no longer available.'.tr()),
        ),
      );
      return;
    }

    final currentUserId = AuthService().getCurrentUserId();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    Map<String, dynamic>? ctx;
    try {
      ctx = await chatProvider.fetchChatRoomContext(chatRoomId);
    } catch (_) {
      ctx = null;
    }

    final String passedGroupName = (fallbackGroupName.trim().isNotEmpty)
        ? fallbackGroupName.trim()
        : ((ctx?['name']?.toString().trim().isNotEmpty == true)
        ? ctx!['name'].toString().trim()
        : 'Group'.tr());

    if (currentUserId.isNotEmpty) {
      await chatProvider.setActiveChatRoom(
        userId: currentUserId,
        chatRoomId: chatRoomId,
      );
    }

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatPage(
            chatRoomId: chatRoomId,
            groupName: passedGroupName,
            contextType: ctx?['context_type']?.toString(),
            manId: ctx?['man_id']?.toString(),
            womanId: ctx?['woman_id']?.toString(),
            mahramId: ctx?['mahram_id']?.toString(),
            manName: ctx?['man_name']?.toString(),
            womanName: ctx?['woman_name']?.toString(),
          ),
        ),
      );
    } finally {
      if (currentUserId.isNotEmpty) {
        await chatProvider.setActiveChatRoom(
          userId: currentUserId,
          chatRoomId: null,
        );
      }
    }
  }

  void _optimisticMarkOneAsRead(models.Notification n) async {
    setState(() {
      final idx = _notifications.indexWhere((x) => x.id == n.id);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      }
    });

    try {
      await notificationService.markAsRead(n.id);
    } catch (_) {}
  }

  void _optimisticMarkAllAsRead() async {
    setState(() {
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
    });

    try {
      await notificationService.markAllAsRead();
    } catch (_) {}
  }

  String _formatDate(DateTime d) {
    return DateFormat('dd MMM yyyy', context.locale.toString()).format(d);
  }

  List<_NotificationListItem> _buildGroupedItems() {
    final sorted = [..._notifications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final List<_NotificationListItem> items = [];
    String? lastHeader;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String headerForDate(DateTime dt) {
      final d = DateTime(dt.year, dt.month, dt.day);
      if (d == today) return 'Today'.tr();
      if (d == yesterday) return '${'Yesterday'.tr()} · ${_formatDate(d)}';
      return _formatDate(d);
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

  String _localizedTitleFor(models.Notification n, String body) {
    final rawTitle = (n.title).trim();

    String legacyName = 'Someone'.tr();
    if (rawTitle.isNotEmpty) {
      final firstWord = rawTitle.split(' ').first.trim();
      if (firstWord.isNotEmpty && firstWord.length < 30) legacyName = firstWord;
    }

    if (body.startsWith('LIKE_POST:')) {
      return 'notif_like_post'.tr(namedArgs: {'name': legacyName});
    }
    if (body.startsWith('COMMENT_POST:')) {
      return 'notif_comment_post'.tr(namedArgs: {'name': legacyName});
    }
    if (body.startsWith('COMMENT_REPLY:')) {
      return 'notif_comment_reply'.tr(namedArgs: {'name': legacyName});
    }

    if (body.startsWith('FOLLOW_USER:')) {
      final parts = body.split(':');
      final userId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(userId, legacyName);
      return 'notif_follow_user'.tr(namedArgs: {'name': name});
    }

    if (body.startsWith('FRIEND_REQUEST:')) {
      final parts = body.split(':');
      final userId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(userId, legacyName);
      return 'notif_friend_request'.tr(namedArgs: {'name': name});
    }

    if (body.startsWith('FRIEND_ACCEPTED:')) {
      final parts = body.split(':');
      final userId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(userId, legacyName);
      return 'notif_friend_accepted'.tr(namedArgs: {'name': name});
    }

    if (body.startsWith('MAHRAM_REQUEST:')) {
      final parts = body.split(':');
      final userId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(userId, legacyName);
      return 'notif_mahram_request'.tr(namedArgs: {'name': name});
    }

    if (body.startsWith('MAHRAM_ACCEPTED:')) {
      final parts = body.split(':');
      final userId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(userId, legacyName);
      return 'notif_mahram_accepted'.tr(namedArgs: {'name': name});
    }

    if (body.startsWith('CHAT_MESSAGE:')) {
      final rest = body.substring('CHAT_MESSAGE:'.length);
      final parts = rest.split('::');
      final senderId = parts.isNotEmpty ? parts[0].trim() : '';
      final name = _nameFromIdOrFallback(senderId, legacyName);
      return 'notif_chat_message'.tr(namedArgs: {'name': name});
    }

    if (body.startsWith('GROUP_MESSAGE:')) return 'notif_group_message'.tr();

    if (body.startsWith('GROUP_ADDED:')) {
      final rest = body.substring('GROUP_ADDED:'.length);
      final parts = rest.split('::');

      final gName = (parts.length > 1 && parts[1].trim().isNotEmpty)
          ? parts[1].trim()
          : 'Group'.tr();
      final adder = (parts.length > 2 && parts[2].trim().isNotEmpty)
          ? parts[2].trim()
          : 'Someone'.tr();

      return 'notif_group_added'.tr(namedArgs: {'name': adder, 'group': gName});
    }

    if (body.startsWith('COMMUNITY_INVITE:')) {
      final rest = body.substring('COMMUNITY_INVITE:'.length);
      final parts = rest.split('::');

      final communityName = (parts.length > 1 ? parts[1] : '').trim();
      final inviterName = (parts.length > 2 ? parts[2] : '').trim();

      if (inviterName.isNotEmpty && communityName.isNotEmpty) {
        return 'notif_community_invite_from'.tr(namedArgs: {
          'inviter': inviterName,
          'community': communityName,
        });
      }

      return 'notif_community_invite'.tr(namedArgs: {
        'name': communityName.isNotEmpty ? communityName : 'a community'.tr(),
      });
    }

    if (body.startsWith('MARRIAGE_INQUIRY_REQUEST:')) {
      final rest = body.substring('MARRIAGE_INQUIRY_REQUEST:'.length);
      final parts = rest.split('::');
      final manId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(manId, legacyName);
      return 'notif_marriage_inquiry_request'.tr(namedArgs: {'name': name});
    }

    if (body.startsWith('MARRIAGE_INQUIRY_MAHRAM:')) {
      final rest = body.substring('MARRIAGE_INQUIRY_MAHRAM:'.length);
      final parts = rest.split('::');

      final womanId = parts.length > 2 ? parts[2].trim() : '';
      final name = _nameFromIdOrFallback(womanId, legacyName);

      return 'notif_mahram_chosen_for_marriage'.tr(namedArgs: {'name': name});
    }

    if (body.startsWith('MARRIAGE_INQUIRY_MAHRAM_ACCEPTED:')) {
      return 'notif_marriage_inquiry_mahram_accepted_title'.tr();
    }

    if (body.startsWith('MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO:')) {
      final rest = body.substring(
        'MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO:'.length,
      );
      final parts = rest.split('::');
      final manId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(manId, legacyName);
      return 'notif_marriage_inquiry_mahram_accepted_sent_to'.tr(
        namedArgs: {'name': name},
      );
    }

    if (body.startsWith('MARRIAGE_INQUIRY_MAN_DECISION:')) {
      final rest = body.substring('MARRIAGE_INQUIRY_MAN_DECISION:'.length);
      final parts = rest.split('::');

      final womanId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(womanId, legacyName);

      return 'notif_marriage_inquiry_man_decision'.tr(
        namedArgs: {'name': name},
      );
    }

    if (body.startsWith('MARRIAGE_INQUIRY_GROUP_CREATED:')) {
      return 'notif_marriage_inquiry_group_created'.tr();
    }

    if (body.startsWith('MARRIAGE_INQUIRY_ACCEPTED:')) {
      final rest = body.substring('MARRIAGE_INQUIRY_ACCEPTED:'.length);
      final parts = rest.split('::');
      final otherUserId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(otherUserId, legacyName);
      return 'notif_marriage_inquiry_accepted'.tr(namedArgs: {'name': name});
    }

    if (body.startsWith('MARRIAGE_INQUIRY_DECLINED:')) {
      final rest = body.substring('MARRIAGE_INQUIRY_DECLINED:'.length);
      final parts = rest.split('::');
      final manId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(manId, legacyName);
      return 'notif_marriage_inquiry_declined'.tr(namedArgs: {'name': name});
    }

    return rawTitle.isNotEmpty ? rawTitle : 'Notifications'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Notifications'.tr(),
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton(
              onPressed: _notifications.isEmpty ? null : _optimisticMarkAllAsRead,
              style: TextButton.styleFrom(
                foregroundColor: _notifications.isEmpty
                    ? colorScheme.primary.withValues(alpha: 0.35)
                    : colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.done_all_rounded,
                    size: 18,
                    color: _notifications.isEmpty
                        ? colorScheme.primary.withValues(alpha: 0.35)
                        : colorScheme.primary.withValues(alpha: 0.82),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Mark all'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      letterSpacing: -0.1,
                      color: _notifications.isEmpty
                          ? colorScheme.primary.withValues(alpha: 0.35)
                          : colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface.withValues(alpha: 0.98),
              colorScheme.secondary.withValues(alpha: 0.18),
            ],
          ),
        ),
        child: _buildBody(context, colorScheme, dbProvider),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      ColorScheme colorScheme,
      DatabaseProvider dbProvider,
      ) {
    if (_isLoading) {
      return Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: colorScheme.primary,
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.secondary.withValues(alpha: 0.55),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 40,
                  color: colorScheme.primary.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No notifications yet'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "When something happens — likes, comments, or new followers — you'll see it here."
                    .tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: colorScheme.primary.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final groupedItems = _buildGroupedItems();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
      itemCount: groupedItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = groupedItems[index];

        if (item.isHeader) {
          return _PremiumDateHeader(
            label: item.headerLabel!,
            colorScheme: colorScheme,
          );
        }

        final n = item.notification!;

        final rawBody = n.body ?? '';
        final body = rawBody.trim();
        final isUnread = !n.isRead;

        final isFriendRequest = body.startsWith('FRIEND_REQUEST:');
        final isFriendAccepted = body.startsWith('FRIEND_ACCEPTED:');
        final isCommunityInvite = body.startsWith('COMMUNITY_INVITE:');
        final isLike = body.startsWith('LIKE_POST:');
        final isComment = body.startsWith('COMMENT_POST:');
        final isCommentReply = body.startsWith('COMMENT_REPLY:');
        final isFollow = body.startsWith('FOLLOW_USER:');
        final isChatMessage = body.startsWith('CHAT_MESSAGE:');
        final isGroupMessage = body.startsWith('GROUP_MESSAGE:');
        final isGroupAdded = body.startsWith('GROUP_ADDED:');
        final isMahramRequest = body.startsWith('MAHRAM_REQUEST:');
        final isMahramAccepted = body.startsWith('MAHRAM_ACCEPTED:');

        final isMarriageInquiryRequest = body.startsWith(
          'MARRIAGE_INQUIRY_REQUEST:',
        );
        final isMarriageInquiryMahram = body.startsWith(
          'MARRIAGE_INQUIRY_MAHRAM:',
        );
        final isMarriageInquiryManDecision = body.startsWith(
          'MARRIAGE_INQUIRY_MAN_DECISION:',
        );
        final isMarriageInquiryGroupCreated = body.startsWith(
          'MARRIAGE_INQUIRY_GROUP_CREATED:',
        );
        final isMarriageInquiryAccepted = body.startsWith(
          'MARRIAGE_INQUIRY_ACCEPTED:',
        );
        final isMarriageInquiryDeclined = body.startsWith(
          'MARRIAGE_INQUIRY_DECLINED:',
        );

        final isMarriageInquiryMahramAccepted = body.startsWith(
          'MARRIAGE_INQUIRY_MAHRAM_ACCEPTED:',
        );

        final isMarriageInquiryMahramAcceptedSentTo = body.startsWith(
          'MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO:',
        );

        String? friendRequesterId;
        String? friendAcceptedUserId;
        String? followUserId;
        String? mahramRequesterId;
        String? mahramAcceptedUserId;

        String? likePostId;
        String? likePreview;
        String? commentPostId;
        String? commentPreview;
        String? commentReplyPostId;
        String? commentReplyPreview;

        String? chatFriendId;
        String? chatFriendName;

        String? groupChatRoomId;
        String? groupName;

        String? groupAddedRoomId;
        String? groupAddedName;

        String? communityInviteCommunityId;
        String? communityInviteCommunityName;
        String? communityInviteInviterId;

        String? inquiryId;
        String? inquiryRequesterId;
        String? inquiryManId;
        String? inquiryWomanId;
        String? inquiryChatRoomId;
        String? inquiryGroupName;

        String? inquiryMahramAcceptedManId;
        String? inquiryAcceptedOtherUserId;

        if (isFriendRequest) {
          final parts = body.split(':');
          if (parts.length > 1) {
            friendRequesterId = parts[1].trim();
            _cacheName(friendRequesterId!);
          }
        }

        if (isFriendAccepted) {
          final parts = body.split(':');
          if (parts.length > 1) {
            friendAcceptedUserId = parts[1].trim();
            _cacheName(friendAcceptedUserId!);
          }
        }

        if (isFollow) {
          final parts = body.split(':');
          if (parts.length > 1) {
            followUserId = parts[1].trim();
            _cacheName(followUserId!);
          }
        }

        if (isMahramRequest) {
          final parts = body.split(':');
          if (parts.length > 1) {
            mahramRequesterId = parts[1].trim();
            _cacheName(mahramRequesterId!);
          }
        }

        if (isMahramAccepted) {
          final parts = body.split(':');
          if (parts.length > 1) {
            mahramAcceptedUserId = parts[1].trim();
            _cacheName(mahramAcceptedUserId!);
          }
        }

        if (isLike) {
          final rest = body.substring('LIKE_POST:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) likePostId = parts[0];
          if (parts.length > 1) likePreview = parts[1];
        }

        if (isComment) {
          final rest = body.substring('COMMENT_POST:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) commentPostId = parts[0];
          if (parts.length > 1) commentPreview = parts[1];
        }

        if (isCommentReply) {
          final rest = body.substring('COMMENT_REPLY:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) commentReplyPostId = parts[0];
          if (parts.length > 2) commentReplyPreview = parts[2];
        }

        if (isChatMessage) {
          final rest = body.substring('CHAT_MESSAGE:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) {
            chatFriendId = parts[0].trim();
            _cacheName(chatFriendId!);
          }
          if (parts.length > 1) chatFriendName = parts[1].trim();
        }

        if (isGroupMessage) {
          final rest = body.substring('GROUP_MESSAGE:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) groupChatRoomId = parts[0].trim();
          if (parts.length > 1) groupName = parts[1].trim();
        }

        if (isGroupAdded) {
          final rest = body.substring('GROUP_ADDED:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) groupAddedRoomId = parts[0].trim();
          if (parts.length > 1) groupAddedName = parts[1].trim();
        }

        if (isCommunityInvite) {
          final rest = body.substring('COMMUNITY_INVITE:'.length);
          final parts = rest.split('::');

          if (parts.isNotEmpty) {
            communityInviteCommunityId = parts[0].trim();
          }
          if (parts.length > 1) {
            communityInviteCommunityName = parts[1].trim();
          }
          if (parts.length > 2) {
            communityInviteInviterId = parts[2].trim();
            _cacheName(communityInviteInviterId!);
          }
        }

        if (isMarriageInquiryRequest) {
          final rest = body.substring('MARRIAGE_INQUIRY_REQUEST:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) inquiryId = parts[0].trim();
          if (parts.length > 1) {
            inquiryRequesterId = parts[1].trim();
            _cacheName(inquiryRequesterId!);
          }
        }

        if (isMarriageInquiryMahram) {
          final rest = body.substring('MARRIAGE_INQUIRY_MAHRAM:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) inquiryId = parts[0].trim();
          if (parts.length > 1) {
            inquiryManId = parts[1].trim();
            _cacheName(inquiryManId!);
          }
          if (parts.length > 2) inquiryWomanId = parts[2].trim();
        }

        if (isMarriageInquiryMahramAccepted) {
          final rest = body.substring(
            'MARRIAGE_INQUIRY_MAHRAM_ACCEPTED:'.length,
          );
          final parts = rest.split('::');
          if (parts.isNotEmpty) inquiryId = parts[0].trim();
          if (parts.length > 1) {
            inquiryMahramAcceptedManId = parts[1].trim();
            _cacheName(inquiryMahramAcceptedManId!);
          }
        }

        if (isMarriageInquiryMahramAcceptedSentTo) {
          final rest = body.substring(
            'MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO:'.length,
          );
          final parts = rest.split('::');
          if (parts.isNotEmpty) inquiryId = parts[0].trim();
          if (parts.length > 1) {
            inquiryMahramAcceptedManId = parts[1].trim();
            _cacheName(inquiryMahramAcceptedManId!);
          }
        }

        if (isMarriageInquiryManDecision) {
          final rest = body.substring('MARRIAGE_INQUIRY_MAN_DECISION:'.length);
          final parts = rest.split('::');

          if (parts.isNotEmpty) inquiryId = parts[0].trim();

          if (parts.length > 1) {
            inquiryWomanId = parts[1].trim();
            _cacheName(inquiryWomanId!);
          }
        }

        if (isMarriageInquiryGroupCreated) {
          final rest = body.substring('MARRIAGE_INQUIRY_GROUP_CREATED:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) inquiryId = parts[0].trim();
          if (parts.length > 1) inquiryChatRoomId = parts[1].trim();
          if (parts.length > 2) inquiryGroupName = parts[2].trim();
        }

        if (isMarriageInquiryAccepted) {
          final rest = body.substring('MARRIAGE_INQUIRY_ACCEPTED:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) inquiryId = parts[0].trim();
          if (parts.length > 1) {
            inquiryAcceptedOtherUserId = parts[1].trim();
            _cacheName(inquiryAcceptedOtherUserId!);
          }
        }

        if (isMarriageInquiryDeclined) {
          final rest = body.substring('MARRIAGE_INQUIRY_DECLINED:'.length);
          final parts = rest.split('::');
          if (parts.isNotEmpty) inquiryId = parts[0].trim();
          if (parts.length > 1) {
            inquiryManId = parts[1].trim();
            _cacheName(inquiryManId!);
          }
        }

        String? subtitleText;
        if (isLike) {
          subtitleText = likePreview;
        } else if (isComment) {
          subtitleText = commentPreview;
        } else if (isCommentReply) {
          subtitleText = commentReplyPreview;
        } else if (!isFriendRequest &&
            !isFriendAccepted &&
            !isMahramRequest &&
            !isMahramAccepted &&
            !isFollow &&
            !isChatMessage &&
            !isGroupMessage &&
            !isGroupAdded &&
            !isCommunityInvite &&
            !isMarriageInquiryRequest &&
            !isMarriageInquiryMahram &&
            !isMarriageInquiryManDecision &&
            !isMarriageInquiryGroupCreated &&
            !isMarriageInquiryAccepted &&
            !isMarriageInquiryDeclined &&
            !isMarriageInquiryMahramAccepted &&
            !isMarriageInquiryMahramAcceptedSentTo &&
            rawBody.isNotEmpty &&
            !rawBody.contains(':')) {
          subtitleText = rawBody;
        }

        final leadingIconData = _iconForNotificationType(
          isFriendRequest: isFriendRequest,
          isFriendAccepted: isFriendAccepted,
          isMahramRequest: isMahramRequest,
          isMahramAccepted: isMahramAccepted,
          isChatMessage: isChatMessage,
          isGroupMessage: isGroupMessage,
          isGroupAdded: isGroupAdded,
          isCommunityInvite: isCommunityInvite,
          isLike: isLike,
          isComment: isComment,
          isCommentReply: isCommentReply,
          isFollow: isFollow,
          isMarriageInquiryRequest: isMarriageInquiryRequest,
          isMarriageInquiryMahram: isMarriageInquiryMahram,
          isMarriageInquiryManDecision: isMarriageInquiryManDecision,
          isMarriageInquiryGroupCreated: isMarriageInquiryGroupCreated,
          isMarriageInquiryAccepted: isMarriageInquiryAccepted,
          isMarriageInquiryDeclined: isMarriageInquiryDeclined,
          isMarriageInquiryMahramAccepted: isMarriageInquiryMahramAccepted,
          isMarriageInquiryMahramAcceptedSentTo:
          isMarriageInquiryMahramAcceptedSentTo,
        );

        final leading = _PremiumLeadingIcon(
          icon: leadingIconData,
          isUnread: isUnread,
          colorScheme: colorScheme,
        );

        Widget? trailing;
        if (!n.isRead && !isFollow) {
          trailing = _UnreadDot(colorScheme: colorScheme);
        } else {
          trailing = null;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () async {
              if (!n.isRead) _optimisticMarkOneAsRead(n);

              if (isFriendRequest && friendRequesterId != null) {
                if (!mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: friendRequesterId!),
                  ),
                );
                if (!mounted) return;
                setState(() {});
                return;
              }

              if (isFriendAccepted && friendAcceptedUserId != null) {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: friendAcceptedUserId!),
                  ),
                );
                return;
              }

              if (isMahramRequest && mahramRequesterId != null) {
                if (!mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: mahramRequesterId!),
                  ),
                );
                if (!mounted) return;
                setState(() {});
                return;
              }

              if (isMahramAccepted && mahramAcceptedUserId != null) {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: mahramAcceptedUserId!),
                  ),
                );
                return;
              }

              if ((isLike || isComment || isCommentReply) &&
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
                      content: Text('This post is no longer available.'.tr()),
                    ),
                  );
                }
                return;
              }

              if (isFollow && followUserId != null) {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: followUserId!),
                  ),
                );
                return;
              }

              if (isChatMessage &&
                  chatFriendId != null &&
                  chatFriendId!.isNotEmpty) {
                if (!mounted) return;

                final friendId = chatFriendId!.trim();
                if (friendId.isEmpty) return;

                final isConnected = await dbProvider.areWeConnected(friendId);
                if (!mounted) return;

                if (!isConnected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('You are no longer connected.'.tr())),
                  );
                  return;
                }

                final profile = await DatabaseService().getUserFromDatabase(
                  friendId,
                );

                final displayName = (profile?.name ?? '').trim().isNotEmpty
                    ? profile!.name
                    : ((profile?.username ?? '').trim().isNotEmpty
                    ? profile!.username
                    : ((chatFriendName ?? '').trim().isNotEmpty
                    ? chatFriendName!
                    : 'Chat'.tr()));

                if (!mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      friendId: friendId,
                      friendName: displayName,
                      allowCreateRoom: false,
                    ),
                  ),
                );
                return;
              }

              if (isGroupMessage &&
                  groupChatRoomId != null &&
                  groupChatRoomId!.isNotEmpty) {
                if (!mounted) return;

                await _openGroupChatWithContext(
                  context: context,
                  chatRoomId: groupChatRoomId!,
                  fallbackGroupName: (groupName ?? '').trim().isNotEmpty
                      ? groupName!.trim()
                      : 'Group'.tr(),
                );

                if (!mounted) return;
                setState(() {});
                return;
              }

              if (isGroupAdded &&
                  groupAddedRoomId != null &&
                  groupAddedRoomId!.isNotEmpty) {
                if (!mounted) return;

                await _openGroupChatWithContext(
                  context: context,
                  chatRoomId: groupAddedRoomId!,
                  fallbackGroupName: (groupAddedName ?? '').trim().isNotEmpty
                      ? groupAddedName!.trim()
                      : 'Group'.tr(),
                );

                if (!mounted) return;
                setState(() {});
                return;
              }

              if (isCommunityInvite &&
                  communityInviteCommunityId != null &&
                  communityInviteCommunityId!.isNotEmpty) {
                if (!mounted) return;

                final community = await dbProvider.getCommunityById(
                  communityInviteCommunityId!,
                );

                if (!mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityPostsPage(
                      communityId: communityInviteCommunityId!,
                      communityName:
                      (community?['name'] ??
                          (communityInviteCommunityName
                              ?.trim()
                              .isNotEmpty ==
                              true
                              ? communityInviteCommunityName!.trim()
                              : 'Community'.tr()))
                          .toString(),
                      communityDescription: community?['description']
                          ?.toString(),
                      openedFromInvite: true,
                    ),
                  ),
                );

                if (!mounted) return;
                setState(() {});
                return;
              }

              if (isMarriageInquiryRequest &&
                  inquiryRequesterId != null &&
                  inquiryRequesterId!.isNotEmpty &&
                  inquiryId != null &&
                  inquiryId!.isNotEmpty) {
                if (!mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      userId: inquiryRequesterId!,
                      inquiryId: inquiryId!,
                    ),
                  ),
                );

                if (!mounted) return;
                setState(() {});
                return;
              }

              if ((isMarriageInquiryMahramAccepted ||
                  isMarriageInquiryMahramAcceptedSentTo) &&
                  inquiryMahramAcceptedManId != null &&
                  inquiryMahramAcceptedManId!.isNotEmpty) {
                if (!mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      userId: inquiryMahramAcceptedManId!,
                      inquiryId: inquiryId ?? '',
                    ),
                  ),
                );
                if (!mounted) return;
                setState(() {});
                return;
              }

              if (isMarriageInquiryMahram &&
                  inquiryId != null &&
                  inquiryId!.isNotEmpty &&
                  inquiryManId != null &&
                  inquiryManId!.isNotEmpty) {
                if (!mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      userId: inquiryManId!,
                      inquiryId: inquiryId!,
                    ),
                  ),
                );

                if (!mounted) return;
                setState(() {});
                return;
              }

              if (isMarriageInquiryAccepted &&
                  inquiryAcceptedOtherUserId != null &&
                  inquiryAcceptedOtherUserId!.isNotEmpty &&
                  inquiryId != null &&
                  inquiryId!.isNotEmpty) {
                if (!mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      userId: inquiryAcceptedOtherUserId!,
                      inquiryId: inquiryId!,
                    ),
                  ),
                );

                if (!mounted) return;
                setState(() {});
                return;
              }

              if (isMarriageInquiryDeclined &&
                  inquiryManId != null &&
                  inquiryManId!.isNotEmpty &&
                  inquiryId != null &&
                  inquiryId!.isNotEmpty) {
                if (!mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      userId: inquiryManId!,
                      inquiryId: inquiryId!,
                    ),
                  ),
                );

                if (!mounted) return;
                setState(() {});
                return;
              }

              if (isMarriageInquiryManDecision &&
                  inquiryId != null &&
                  inquiryId!.isNotEmpty &&
                  inquiryWomanId != null &&
                  inquiryWomanId!.isNotEmpty) {
                if (!mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      userId: inquiryWomanId!,
                      inquiryId: inquiryId!,
                    ),
                  ),
                );

                if (!mounted) return;
                setState(() {});
                return;
              }

              if (isMarriageInquiryGroupCreated &&
                  inquiryChatRoomId != null &&
                  inquiryChatRoomId!.isNotEmpty) {
                if (!mounted) return;

                final exists = await ChatService().groupRoomExistsInDatabase(
                  inquiryChatRoomId!,
                );

                if (!exists) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('This group is no longer available.'.tr()),
                    ),
                  );
                  return;
                }

                await _openGroupChatWithContext(
                  context: context,
                  chatRoomId: inquiryChatRoomId!,
                  fallbackGroupName: (inquiryGroupName ?? '').trim().isNotEmpty
                      ? inquiryGroupName!.trim()
                      : 'Group'.tr(),
                );

                if (!mounted) return;
                setState(() {});
                return;
              }
            },
            child: Ink(
              decoration: BoxDecoration(
                color: isUnread
                    ? colorScheme.surface.withValues(alpha: 0.96)
                    : colorScheme.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isUnread
                      ? colorScheme.primary.withValues(alpha: 0.10)
                      : colorScheme.primary.withValues(alpha: 0.05),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isUnread ? 0.07 : 0.045),
                    blurRadius: isUnread ? 22 : 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _localizedTitleFor(n, body),
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.35,
                                    fontWeight: isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    letterSpacing: -0.15,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: TimeAgoText(
                                  createdAt: n.createdAt,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.50,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (subtitleText != null &&
                              subtitleText.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitleText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.25,
                                height: 1.45,
                                color: colorScheme.primary.withValues(
                                  alpha: 0.68,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: trailing,
                      ),
                    ],
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
    required bool isMahramRequest,
    required bool isMahramAccepted,
    required bool isChatMessage,
    required bool isGroupMessage,
    required bool isGroupAdded,
    required bool isLike,
    required bool isComment,
    required bool isCommentReply,
    required bool isFollow,
    required bool isMarriageInquiryRequest,
    required bool isMarriageInquiryMahram,
    required bool isMarriageInquiryManDecision,
    required bool isMarriageInquiryGroupCreated,
    required bool isMarriageInquiryAccepted,
    required bool isMarriageInquiryDeclined,
    required bool isMarriageInquiryMahramAccepted,
    required bool isMarriageInquiryMahramAcceptedSentTo,
    required bool isCommunityInvite,
  }) {
    if (isFriendRequest) return Icons.person_add_alt_1_rounded;
    if (isFriendAccepted) return Icons.handshake_rounded;
    if (isMahramRequest) return Icons.verified_user_outlined;
    if (isMahramAccepted) return Icons.verified_user_rounded;
    if (isGroupAdded) return Icons.group_add_rounded;
    if (isGroupMessage) return Icons.groups_rounded;
    if (isChatMessage) return Icons.chat_bubble_outline_rounded;
    if (isLike) return Icons.favorite_rounded;
    if (isComment || isCommentReply) return Icons.mode_comment_outlined;
    if (isFollow) return Icons.person_rounded;
    if (isCommunityInvite) return Icons.mail_outline_rounded;

    if (isMarriageInquiryMahramAccepted ||
        isMarriageInquiryMahramAcceptedSentTo) {
      return Icons.verified_user_rounded;
    }

    if (isMarriageInquiryAccepted) return Icons.check_circle_outline_rounded;
    if (isMarriageInquiryDeclined) return Icons.cancel_outlined;
    if (isMarriageInquiryGroupCreated) return Icons.forum_rounded;
    if (isMarriageInquiryManDecision) return Icons.how_to_reg_rounded;
    if (isMarriageInquiryMahram) return Icons.admin_panel_settings_rounded;
    if (isMarriageInquiryRequest) return Icons.favorite_border_rounded;

    return Icons.notifications_rounded;
  }
}

class _PremiumDateHeader extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;

  const _PremiumDateHeader({
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.15,
              color: colorScheme.primary.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumLeadingIcon extends StatelessWidget {
  final IconData icon;
  final bool isUnread;
  final ColorScheme colorScheme;

  const _PremiumLeadingIcon({
    required this.icon,
    required this.isUnread,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isUnread
              ? [
            colorScheme.primary.withValues(alpha: 0.16),
            colorScheme.primary.withValues(alpha: 0.08),
          ]
              : [
            colorScheme.secondary.withValues(alpha: 0.75),
            colorScheme.secondary.withValues(alpha: 0.42),
          ],
        ),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isUnread ? 0.10 : 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: isUnread ? 0.08 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 20,
        color: colorScheme.primary.withValues(alpha: isUnread ? 0.95 : 0.78),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  final ColorScheme colorScheme;

  const _UnreadDot({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}