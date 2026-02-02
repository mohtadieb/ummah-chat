// lib/pages/notification_page.dart
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ummah_chat/models/notification.dart' as models;
import 'package:ummah_chat/pages/profile_page.dart';
import 'package:ummah_chat/pages/chat_page.dart';
import 'package:ummah_chat/pages/group_chat_page.dart'; // 👈 NEW
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

  // ✅ Cache names so titles show FULL NAME consistently
  final Map<String, String> _userNameCache =
      {}; // userId -> display name (full name preferred)
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

        // ✅ Prefetch names for body-based notifications
        for (final n in data) {
          final body = (n.body ?? '').trim();

          // FOLLOW_USER:<userId>
          if (body.startsWith('FOLLOW_USER:')) {
            final parts = body.split(':');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          // FRIEND_REQUEST:<userId>
          if (body.startsWith('FRIEND_REQUEST:')) {
            final parts = body.split(':');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          // FRIEND_ACCEPTED:<userId>
          if (body.startsWith('FRIEND_ACCEPTED:')) {
            final parts = body.split(':');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          // MAHRAM_REQUEST:<userId>
          if (body.startsWith('MAHRAM_REQUEST:')) {
            final parts = body.split(':');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          // MAHRAM_ACCEPTED:<userId>
          if (body.startsWith('MAHRAM_ACCEPTED:')) {
            final parts = body.split(':');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          // CHAT_MESSAGE:<senderId>::<senderName>
          if (body.startsWith('CHAT_MESSAGE:')) {
            final rest = body.substring('CHAT_MESSAGE:'.length);
            final parts = rest.split('::');
            if (parts.isNotEmpty) _cacheName(parts[0].trim());
          }

          // ✅ COMMUNITY_INVITE:<communityId>::<communityName>::<inviterId>
          if (body.startsWith('COMMUNITY_INVITE:')) {
            final rest = body.substring('COMMUNITY_INVITE:'.length);
            final parts = rest.split('::');
            if (parts.length > 2) _cacheName(parts[2].trim()); // ✅ inviterId
          }

          // MARRIAGE_INQUIRY_REQUEST:<inquiryId>::<manId>
          if (body.startsWith('MARRIAGE_INQUIRY_REQUEST:')) {
            final rest = body.substring('MARRIAGE_INQUIRY_REQUEST:'.length);
            final parts = rest.split('::');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          // MARRIAGE_INQUIRY_MAHRAM:<inquiryId>::<manId>::<womanId>
          if (body.startsWith('MARRIAGE_INQUIRY_MAHRAM:')) {
            final rest = body.substring('MARRIAGE_INQUIRY_MAHRAM:'.length);
            final parts = rest.split('::');
            if (parts.length > 2) _cacheName(parts[2].trim());
          }

          // MARRIAGE_INQUIRY_MAN_DECISION:<inquiryId>::<womanId>::<mahramId>
          if (body.startsWith('MARRIAGE_INQUIRY_MAN_DECISION:')) {
            final rest = body.substring(
              'MARRIAGE_INQUIRY_MAN_DECISION:'.length,
            );
            final parts = rest.split('::');
            if (parts.length > 1) _cacheName(parts[1].trim()); // ✅ womanId
          }

          // ✅ UPDATED: MARRIAGE_INQUIRY_ACCEPTED:<inquiryId>::<otherUserId>
          if (body.startsWith('MARRIAGE_INQUIRY_ACCEPTED:')) {
            final rest = body.substring('MARRIAGE_INQUIRY_ACCEPTED:'.length);
            final parts = rest.split('::');
            if (parts.length > 1) _cacheName(parts[1].trim()); // ✅ otherUserId
          }

          // MARRIAGE_INQUIRY_DECLINED:<inquiryId>::<manId>::...
          if (body.startsWith('MARRIAGE_INQUIRY_DECLINED:')) {
            final rest = body.substring('MARRIAGE_INQUIRY_DECLINED:'.length);
            final parts = rest.split('::');
            if (parts.length > 1) _cacheName(parts[1].trim());
          }

          // MARRIAGE_INQUIRY_MAHRAM_ACCEPTED:<inquiryId>::<manId>
          if (body.startsWith('MARRIAGE_INQUIRY_MAHRAM_ACCEPTED:')) {
            final rest = body.substring(
              'MARRIAGE_INQUIRY_MAHRAM_ACCEPTED:'.length,
            );
            final parts = rest.split('::');
            if (parts.length > 1) _cacheName(parts[1].trim()); // manId
          }

          // ✅ NEW: MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO:<inquiryId>::<manId>
          if (body.startsWith('MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO:')) {
            final rest = body.substring(
              'MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO:'.length,
            );
            final parts = rest.split('::');
            if (parts.length > 1) _cacheName(parts[1].trim()); // manId
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

  // ✅ Single small cache method: prefer FULL NAME, fallback to username
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

    // ✅ NEW: prevent "ghost rooms"
    final exists = await ChatService().groupRoomExistsInDatabase(chatRoomId.trim());
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

    // ✅ Fetch context payload for correct title ("Marriage inquiry for X")
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


  // --------- OPTIMISTIC HELPERS ---------

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

  /// Format a date like "13 Dec 2025"
  String _formatDate(DateTime d) {
    return DateFormat('dd MMM yyyy', context.locale.toString()).format(d);
  }

  /// Build a flattened list of header + notification items grouped by date
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
      if (d == yesterday) return 'Yesterday'.tr() + ' · ${_formatDate(d)}';
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

  // ✅ Updated: use FULL NAME from cache where possible (consistent style)
  String _localizedTitleFor(models.Notification n, String body) {
    final rawTitle = (n.title).trim();

    // Legacy fallback (only used if we truly can't derive an ID)
    String legacyName = 'Someone'.tr();
    if (rawTitle.isNotEmpty) {
      final firstWord = rawTitle.split(' ').first.trim();
      if (firstWord.isNotEmpty && firstWord.length < 30) legacyName = firstWord;
    }

    // LIKE/COMMENT/REPLY: your body does not include senderId, so we cannot fetch name reliably
    if (body.startsWith('LIKE_POST:')) {
      return 'notif_like_post'.tr(namedArgs: {'name': legacyName});
    }
    if (body.startsWith('COMMENT_POST:')) {
      return 'notif_comment_post'.tr(namedArgs: {'name': legacyName});
    }
    if (body.startsWith('COMMENT_REPLY:')) {
      return 'notif_comment_reply'.tr(namedArgs: {'name': legacyName});
    }

    // FOLLOW_USER:<userId>
    if (body.startsWith('FOLLOW_USER:')) {
      final parts = body.split(':');
      final userId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(userId, legacyName);
      return 'notif_follow_user'.tr(namedArgs: {'name': name});
    }

    // FRIEND_REQUEST:<userId>
    if (body.startsWith('FRIEND_REQUEST:')) {
      final parts = body.split(':');
      final userId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(userId, legacyName);
      return 'notif_friend_request'.tr(namedArgs: {'name': name});
    }

    // FRIEND_ACCEPTED:<userId>
    if (body.startsWith('FRIEND_ACCEPTED:')) {
      final parts = body.split(':');
      final userId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(userId, legacyName);
      return 'notif_friend_accepted'.tr(namedArgs: {'name': name});
    }

    // MAHRAM_REQUEST:<userId>
    if (body.startsWith('MAHRAM_REQUEST:')) {
      final parts = body.split(':');
      final userId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(userId, legacyName);
      return 'notif_mahram_request'.tr(namedArgs: {'name': name});
    }

    // MAHRAM_ACCEPTED:<userId>
    if (body.startsWith('MAHRAM_ACCEPTED:')) {
      final parts = body.split(':');
      final userId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(userId, legacyName);
      return 'notif_mahram_accepted'.tr(namedArgs: {'name': name});
    }

    // CHAT_MESSAGE:<senderId>::<senderName>
    if (body.startsWith('CHAT_MESSAGE:')) {
      final rest = body.substring('CHAT_MESSAGE:'.length);
      final parts = rest.split('::');
      final senderId = parts.isNotEmpty ? parts[0].trim() : '';
      final name = _nameFromIdOrFallback(senderId, legacyName);
      return 'notif_chat_message'.tr(namedArgs: {'name': name});
    }

    if (body.startsWith('GROUP_MESSAGE:')) return 'notif_group_message'.tr();

    // GROUP_ADDED:<chatRoomId>::<groupName>::<addedByName>
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

    // ✅ COMMUNITY_INVITE:<communityId>::<communityName>::<inviterId>
    if (body.startsWith('COMMUNITY_INVITE:')) {
      final rest = body.substring('COMMUNITY_INVITE:'.length);
      final parts = rest.split('::');

      final communityName = (parts.length > 1 ? parts[1] : '').trim();
      final inviterName = (parts.length > 2 ? parts[2] : '').trim();

      // ✅ If inviter exists, use the new key:
      if (inviterName.isNotEmpty && communityName.isNotEmpty) {
        return 'notif_community_invite_from'.tr(namedArgs: {
          'inviter': inviterName,
          'community': communityName,
        });
      }

      // ✅ fallback (old notifications without inviter)
      return 'notif_community_invite'.tr(namedArgs: {
        'name': communityName.isNotEmpty ? communityName : 'a community'.tr(),
      });
    }


    // Marriage inquiry: use manId (2nd part)
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

      // body = inquiryId :: manId :: womanId
      final womanId = parts.length > 2 ? parts[2].trim() : '';
      final name = _nameFromIdOrFallback(womanId, legacyName);

      return 'notif_mahram_chosen_for_marriage'.tr(namedArgs: {'name': name});
    }

    // ✅ UPDATE: when man initiates and woman selects mahram, show the simple title key
    if (body.startsWith('MARRIAGE_INQUIRY_MAHRAM_ACCEPTED:')) {
      return 'notif_marriage_inquiry_mahram_accepted_title'.tr();
    }

    // ✅ NEW: when woman initiates, show "sent to {man}"
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

      // ✅ body format: <inquiryId>::<womanId>::<mahramId>
      final womanId = parts.length > 1 ? parts[1].trim() : '';
      final name = _nameFromIdOrFallback(womanId, legacyName);

      return 'notif_marriage_inquiry_man_decision'.tr(
        namedArgs: {'name': name},
      );
    }

    if (body.startsWith('MARRIAGE_INQUIRY_GROUP_CREATED:')) {
      return 'notif_marriage_inquiry_group_created'.tr();
    }

    // ✅ UPDATED: accepted uses <otherUserId> (not "manId")
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
            onPressed: _notifications.isEmpty ? null : _optimisticMarkAllAsRead,
            icon: Icon(Icons.done_all, size: 18, color: colorScheme.primary),
            label: Text(
              'Mark all'.tr(),
              style: TextStyle(
                color: colorScheme.primary,
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
              Text(
                "When something happens — likes, comments, or new followers — you'll see it here."
                    .tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colorScheme.primary),
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
        final isCommunityInvite = body.startsWith('COMMUNITY_INVITE:');
        final isLike = body.startsWith('LIKE_POST:');
        final isComment = body.startsWith('COMMENT_POST:');
        final isCommentReply = body.startsWith('COMMENT_REPLY:');
        final isFollow = body.startsWith('FOLLOW_USER:');
        final isChatMessage = body.startsWith('CHAT_MESSAGE:'); // DM
        final isGroupMessage = body.startsWith('GROUP_MESSAGE:'); // group msg
        final isGroupAdded = body.startsWith('GROUP_ADDED:'); // ✅ NEW
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

        // ✅ NEW
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
        String? communityInviteCommunityName; // ✅ NEW
        String? communityInviteInviterId; // ✅ NEW

        String? inquiryId;
        String? inquiryRequesterId;
        String? inquiryManId;
        String? inquiryWomanId;
        String? inquiryChatRoomId;
        String? inquiryGroupName;

        String? inquiryMahramAcceptedManId;

        // ✅ NEW: accepted otherUserId holder
        String? inquiryAcceptedOtherUserId;

        // Parse IDs (and cache names when possible)
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

        // ✅ COMMUNITY_INVITE:<communityId>::<communityName>::<inviterId>
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
            _cacheName(communityInviteInviterId!); // ✅ cache inviter name
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

        // ✅ NEW: same parsing, different body prefix
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

          // ✅ body format: <inquiryId>::<womanId>::<mahramId>
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

        // ✅ UPDATED: accepted uses otherUserId
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

        // ----- LEADING ICON -----
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

        // ----- TRAILING -----
        Widget? trailing;
        if (!n.isRead && !isFollow) {
          trailing = _UnreadDot(colorScheme: Theme.of(context).colorScheme);
        } else {
          trailing = null;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              if (!n.isRead) _optimisticMarkOneAsRead(n);

              // 1) Friend request → sender profile
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

              // 2) Friend accepted → accepter profile
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

              // 2.1) Mahram request → requester profile
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

              // 2.2) Mahram accepted → accepter profile
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

              // 3) Likes / comments → post
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

              // 4) Follow → follower profile
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

              // 5) Chat message → open DM
              if (isChatMessage &&
                  chatFriendId != null &&
                  chatFriendId!.isNotEmpty) {
                if (!mounted) return;

                final profile = await DatabaseService().getUserFromDatabase(
                  chatFriendId!,
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
                      friendId: chatFriendId!,
                      friendName: displayName,
                    ),
                  ),
                );

                if (!mounted) return;

                final currentUserId = AuthService().getCurrentUserId();
                if (currentUserId.isNotEmpty) {
                  final chatProvider = Provider.of<ChatProvider>(
                    context,
                    listen: false,
                  );
                  final chatRoomId = await chatProvider.getOrCreateChatRoomId(
                    currentUserId,
                    chatFriendId!,
                  );
                  await chatProvider.markRoomMessagesAsRead(
                    chatRoomId,
                    currentUserId,
                  );
                }
                return;
              }

              // 6) Group message → open GroupChatPage (with context)
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

              // 7) Group added → open GroupChatPage (with context)
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

              // ✅ Community invite → open CommunityPostsPage (banner will show there)
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

              // 💍 Marriage inquiry request → open MAN profile
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

              // ✅ MAHRAM_ACCEPTED (both variants) → open MAN profile (same behavior)
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

              // 💍 Marriage inquiry mahram notif → go to MAN profile
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

              // ✅ UPDATED: accepted → open the OTHER user's profile
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

              // 💍 Man declined → open man's profile (kept as-is)
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

              // 💍 Man decision notification → go to WOMAN profile
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

              // 💍 Marriage inquiry group created → open group chat (with context)
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
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
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
                                  _localizedTitleFor(n, body),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isUnread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              TimeAgoText(
                                createdAt: n.createdAt,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.primary,
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
                                color: Theme.of(context).colorScheme.primary,
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
    if (isFriendRequest) return Icons.person_add_alt_1;
    if (isFriendAccepted) return Icons.handshake;
    if (isMahramRequest) return Icons.verified_user_outlined;
    if (isMahramAccepted) return Icons.verified_user;
    if (isGroupAdded) return Icons.group_add;
    if (isGroupMessage) return Icons.groups;
    if (isChatMessage) return Icons.chat_bubble_outline;
    if (isLike) return Icons.favorite;
    if (isComment || isCommentReply) return Icons.mode_comment_outlined;
    if (isFollow) return Icons.person;
    if (isCommunityInvite) return Icons.mail_outline;

    // ✅ icon for MARRIAGE_INQUIRY_MAHRAM_ACCEPTED (both types)
    if (isMarriageInquiryMahramAccepted ||
        isMarriageInquiryMahramAcceptedSentTo) {
      return Icons.verified_user;
    }

    if (isMarriageInquiryAccepted) return Icons.check_circle_outline;
    if (isMarriageInquiryDeclined) return Icons.cancel_outlined;
    if (isMarriageInquiryGroupCreated) return Icons.forum;
    if (isMarriageInquiryManDecision) return Icons.how_to_reg;
    if (isMarriageInquiryMahram) return Icons.admin_panel_settings;
    if (isMarriageInquiryRequest) return Icons.favorite_border;

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
