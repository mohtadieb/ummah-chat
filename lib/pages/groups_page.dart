import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth/auth_service.dart';
import '../services/chat/chat_provider.dart';
import '../pages/group_chat_page.dart';
import '../models/message.dart';
import '../helper/last_message_time_formatter.dart';
import '../components/my_search_bar.dart';
import '../components/my_group_tile.dart';
import '../services/notifications/notification_service.dart';

class GroupsPage extends StatefulWidget {
  final bool embeddedMode;

  const GroupsPage({
    super.key,
    this.embeddedMode = false,
  });

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage>
    with AutomaticKeepAliveClientMixin<GroupsPage> {
  final AuthService _authService = AuthService();

  Map<String, MessageModel> _lastGroupMessages = {};
  Map<String, int> _groupUnreadCounts = {};

  StreamSubscription<Map<String, MessageModel>>? _lastMsgSub;
  StreamSubscription<Map<String, int>>? _unreadSub;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const double _embeddedHeaderHeight = 126;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId != null && currentUserId.isNotEmpty) {
      Provider.of<ChatProvider>(context, listen: false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startSubscriptionsIfNeeded();
  }

  void _startSubscriptionsIfNeeded() {
    if (_lastMsgSub != null || _unreadSub != null) return;

    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null || currentUserId.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    _lastMsgSub = chatProvider.lastGroupMessagesPollingStream().listen((map) {
      if (!mounted) return;
      setState(() {
        _lastGroupMessages = map;
      });
    });

    _unreadSub = chatProvider
        .groupUnreadCountsPollingStream(currentUserId)
        .listen((map) {
      if (!mounted) return;
      debugPrint('📥 GroupsPage: unread map from provider: $map');
      setState(() {
        _groupUnreadCounts = map;
      });
    });
  }

  @override
  void dispose() {
    _lastMsgSub?.cancel();
    _unreadSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _authService.getCurrentUserId();

    if (currentUserId == null || currentUserId.isEmpty) {
      return Center(
        child: Text(
          'You must be logged in to view your groups'.tr(),
          style: TextStyle(color: colorScheme.primary),
        ),
      );
    }

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final notificationService = NotificationService();
    final String? activeChatRoomId = notificationService.activeChatRoomId;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: chatProvider.groupRoomsForUserPollingStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildSimpleState(
            context,
            icon: Icons.error_outline_rounded,
            title: 'Error loading groups'.tr(),
            subtitle: '',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data ?? [];

        if (groups.isEmpty) {
          return _buildSimpleState(
            context,
            icon: Icons.group_outlined,
            title: 'No groups yet'.tr(),
            subtitle:
            'Create a group to start chatting with multiple friends at once.'
                .tr(),
          );
        }

        List<Map<String, dynamic>> filteredGroups = groups;
        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          filteredGroups = groups.where((g) {
            final name = (g['name'] as String? ?? '').toLowerCase();
            return name.contains(q);
          }).toList();
        }

        final noMatches =
            _searchQuery.trim().isNotEmpty && filteredGroups.isEmpty;

        if (!widget.embeddedMode) {
          return Column(
            children: [
              _buildTopSection(
                context,
                title: "Your groups".tr(),
                count: groups.length,
                hintText: 'Search groups'.tr(),
              ),
              Expanded(
                child: noMatches
                    ? _buildSimpleState(
                  context,
                  icon: Icons.search_off_rounded,
                  title: 'No groups match your search'.tr(),
                  subtitle: '',
                  compact: true,
                )
                    : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(overscroll: false),
                  child: ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: 4,
                      bottom: MediaQuery.of(context).padding.bottom + 96,
                    ),
                    itemCount: filteredGroups.length,
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      final groupId = group['id']?.toString() ?? '';
                      final rawGroupName =
                      (group['name'] as String?)?.trim().isNotEmpty ==
                          true
                          ? (group['name'] as String)
                          : 'Group'.tr();

                      final baseGroupName =
                      localizeGroupName(rawGroupName);

                      final contextType =
                      (group['context_type'] ?? '').toString().trim();
                      final isMarriageInquiryRoom =
                          contextType == 'marriage_inquiry';

                      String displayGroupName = baseGroupName;

                      if (isMarriageInquiryRoom) {
                        final manId =
                        (group['man_id'] ?? '').toString().trim();
                        final womanId =
                        (group['woman_id'] ?? '').toString().trim();

                        final manName =
                        (group['man_name'] ?? '').toString().trim();
                        final womanName =
                        (group['woman_name'] ?? '').toString().trim();

                        final targetName =
                        (currentUserId == manId) ? womanName : manName;

                        if (targetName.isNotEmpty) {
                          displayGroupName = 'marriage_inquiry_for'.tr(
                            namedArgs: {'name': targetName},
                          );
                        } else {
                          displayGroupName = baseGroupName;
                        }
                      }

                      final avatarUrl = group['avatar_url'] as String?;
                      final MessageModel? lastMsg =
                      _lastGroupMessages[groupId];

                      final int rawUnread =
                          _groupUnreadCounts[groupId] ?? 0;

                      final int unread =
                      (activeChatRoomId != null &&
                          activeChatRoomId == groupId)
                          ? 0
                          : rawUnread;

                      final String subtitle = lastMsg != null
                          ? _buildLastMessagePreview(
                        msg: lastMsg,
                        currentUserId: currentUserId,
                      )
                          : 'No messages yet'.tr();

                      final String? lastTimeLabel = lastMsg != null
                          ? formatLastMessageTime(lastMsg.createdAt)
                          : null;

                      return MyGroupTile(
                        groupName: displayGroupName,
                        avatarUrl: avatarUrl,
                        lastMessagePreview: subtitle,
                        lastMessageTimeLabel: lastTimeLabel,
                        unreadCount: unread,
                        onTap: groupId.isEmpty
                            ? null
                            : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupChatPage(
                                chatRoomId: groupId,
                                groupName: rawGroupName,
                                avatarUrl: avatarUrl,
                                contextType:
                                group['context_type']?.toString(),
                                manId: group['man_id']?.toString(),
                                womanId:
                                group['woman_id']?.toString(),
                                mahramId:
                                group['mahram_id']?.toString(),
                                manName:
                                group['man_name']?.toString(),
                                womanName:
                                group['woman_name']?.toString(),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          key: const PageStorageKey<String>('groups_embedded'),
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _GroupsTopHeaderDelegate(
                minExtentValue: _embeddedHeaderHeight,
                maxExtentValue: _embeddedHeaderHeight,
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: _buildTopSection(
                    context,
                    title: "Your groups".tr(),
                    count: groups.length,
                    hintText: 'Search groups'.tr(),
                    embedded: true,
                  ),
                ),
              ),
            ),
            if (noMatches)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildSimpleState(
                  context,
                  icon: Icons.search_off_rounded,
                  title: 'No groups match your search'.tr(),
                  subtitle: '',
                  compact: true,
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.only(
                  top: 2,
                  bottom: MediaQuery.of(context).padding.bottom + 96,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final group = filteredGroups[index];
                      final groupId = group['id']?.toString() ?? '';
                      final rawGroupName =
                      (group['name'] as String?)?.trim().isNotEmpty == true
                          ? (group['name'] as String)
                          : 'Group'.tr();

                      final baseGroupName = localizeGroupName(rawGroupName);

                      final contextType =
                      (group['context_type'] ?? '').toString().trim();
                      final isMarriageInquiryRoom =
                          contextType == 'marriage_inquiry';

                      String displayGroupName = baseGroupName;

                      if (isMarriageInquiryRoom) {
                        final manId =
                        (group['man_id'] ?? '').toString().trim();
                        final womanId =
                        (group['woman_id'] ?? '').toString().trim();

                        final manName =
                        (group['man_name'] ?? '').toString().trim();
                        final womanName =
                        (group['woman_name'] ?? '').toString().trim();

                        final targetName =
                        (currentUserId == manId) ? womanName : manName;

                        if (targetName.isNotEmpty) {
                          displayGroupName = 'marriage_inquiry_for'.tr(
                            namedArgs: {'name': targetName},
                          );
                        } else {
                          displayGroupName = baseGroupName;
                        }
                      }

                      final avatarUrl = group['avatar_url'] as String?;
                      final MessageModel? lastMsg = _lastGroupMessages[groupId];

                      final int rawUnread = _groupUnreadCounts[groupId] ?? 0;

                      final int unread =
                      (activeChatRoomId != null &&
                          activeChatRoomId == groupId)
                          ? 0
                          : rawUnread;

                      final String subtitle = lastMsg != null
                          ? _buildLastMessagePreview(
                        msg: lastMsg,
                        currentUserId: currentUserId,
                      )
                          : 'No messages yet'.tr();

                      final String? lastTimeLabel = lastMsg != null
                          ? formatLastMessageTime(lastMsg.createdAt)
                          : null;

                      return MyGroupTile(
                        groupName: displayGroupName,
                        avatarUrl: avatarUrl,
                        lastMessagePreview: subtitle,
                        lastMessageTimeLabel: lastTimeLabel,
                        unreadCount: unread,
                        onTap: groupId.isEmpty
                            ? null
                            : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupChatPage(
                                chatRoomId: groupId,
                                groupName: rawGroupName,
                                avatarUrl: avatarUrl,
                                contextType:
                                group['context_type']?.toString(),
                                manId: group['man_id']?.toString(),
                                womanId: group['woman_id']?.toString(),
                                mahramId: group['mahram_id']?.toString(),
                                manName: group['man_name']?.toString(),
                                womanName:
                                group['woman_name']?.toString(),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: filteredGroups.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTopSection(
      BuildContext context, {
        required String title,
        required int count,
        required String hintText,
        bool embedded = false,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: embedded
          ? const EdgeInsets.fromLTRB(16, 8, 16, 6)
          : const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surfaceContainerHigh,
              colorScheme.surfaceContainer,
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            MySearchBar(
              controller: _searchController,
              hintText: hintText,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              onClear: () {
                setState(() => _searchQuery = '');
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleState(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        bool compact = false,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 24 : 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: colorScheme.onSurface.withValues(alpha: 0.70),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String localizeGroupName(String raw) {
    final s = raw.trim();
    if (s.startsWith('L10N:')) {
      final key = s.substring('L10N:'.length).trim();
      return key.isEmpty ? raw : key.tr();
    }
    return raw;
  }

  String localizeLastMessagePreview(String raw) {
    final s = raw.trim();
    if (s.startsWith('SYSTEM:')) {
      final key = s.substring('SYSTEM:'.length).trim();
      return key.isEmpty ? '' : key.tr();
    }
    return raw;
  }

  String _buildLastMessagePreview({
    required MessageModel msg,
    required String currentUserId,
  }) {
    final raw = msg.message.trim();
    if (raw.isEmpty) return '';

    if (raw.startsWith('SYSTEM:')) {
      final key = raw.substring('SYSTEM:'.length).trim();
      return key.isNotEmpty ? key.tr() : raw;
    }

    final bool isMine = msg.senderId == currentUserId;
    final String base = isMine ? '${"You".tr()}: $raw' : raw;

    const maxLen = 40;
    if (base.length <= maxLen) return base;
    return '${base.substring(0, maxLen)}…';
  }
}

class _GroupsTopHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtentValue;
  final double maxExtentValue;
  final Widget child;

  _GroupsTopHeaderDelegate({
    required this.minExtentValue,
    required this.maxExtentValue,
    required this.child,
  });

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _GroupsTopHeaderDelegate oldDelegate) {
    return oldDelegate.minExtentValue != minExtentValue ||
        oldDelegate.maxExtentValue != maxExtentValue ||
        oldDelegate.child != child;
  }
}