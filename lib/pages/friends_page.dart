import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ummah_chat/models/user_profile.dart';
import 'package:ummah_chat/pages/profile_page.dart';
import 'package:ummah_chat/services/auth/auth_service.dart';

import '../components/my_friend_tile.dart';
import '../components/my_search_bar.dart';
import '../helper/last_message_time_formatter.dart';
import '../helper/navigate_pages.dart';
import '../services/chat/chat_provider.dart';
import '../services/chat/chat_service.dart';
import '../services/database/database_provider.dart';
import '../services/notifications/notification_service.dart';
import 'chat_page.dart';

const double kChatsHeaderOuterHeight = 148.0;

class FriendsPage extends StatefulWidget {
  final String? userId;
  final bool includeMahrams;
  final bool embeddedMode;
  final ValueChanged<double>? onEmbeddedScrollOffsetChanged;
  final double embeddedListTopCompensation;
  final bool isActiveTab;
  final int tabActivationTick;
  final ScrollController? externalScrollController;

  const FriendsPage({
    super.key,
    this.userId,
    this.includeMahrams = false,
    this.embeddedMode = false,
    this.onEmbeddedScrollOffsetChanged,
    this.embeddedListTopCompensation = 0,
    this.isActiveTab = false,
    this.tabActivationTick = 0,
    this.externalScrollController,
  });

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with AutomaticKeepAliveClientMixin<FriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _fallbackScrollController = ScrollController();

  String _searchQuery = '';

  ScrollController get _scrollController =>
      widget.externalScrollController ?? _fallbackScrollController;

  bool get _isOtherUserView => widget.userId != null;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant FriendsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final becameActive =
        widget.embeddedMode &&
            widget.isActiveTab &&
            (!oldWidget.isActiveTab ||
                oldWidget.tabActivationTick != widget.tabActivationTick);

    if (becameActive) {
      _syncToHeaderIfNeeded();
    }
  }

  void _syncToHeaderIfNeeded() {
    if (!widget.embeddedMode || !widget.isActiveTab) return;
    if (!_scrollController.hasClients) return;

    final max = _scrollController.position.maxScrollExtent;
    final target = widget.embeddedListTopCompensation.clamp(0.0, max);

    if ((_scrollController.offset - target).abs() >= 0.5) {
      _scrollController.jumpTo(target);
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.embeddedMode || !widget.isActiveTab) return false;
    if (notification.depth != 0) return false;
    widget.onEmbeddedScrollOffsetChanged?.call(notification.metrics.pixels);
    return false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fallbackScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildFriendsList(context);
  }

  Widget _buildFriendsList(BuildContext context) {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final auth = AuthService();
    final currentUserId = auth.getCurrentUserId();
    final colorScheme = Theme.of(context).colorScheme;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final notificationService = NotificationService();

    final targetUserId = widget.userId ?? currentUserId;

    if (targetUserId.isEmpty) {
      return Center(
        child: Text(
          'You must be logged in to view friends'.tr(),
          style: TextStyle(color: colorScheme.primary),
        ),
      );
    }

    if (_isOtherUserView) {
      return StreamBuilder<List<UserProfile>>(
        stream: dbProvider.friendsStreamForUser(targetUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildSimpleState(
              context,
              icon: Icons.error_outline_rounded,
              title: "Error loading friends".tr(),
              subtitle: '',
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allFriends = snapshot.data ?? [];

          if (allFriends.isEmpty) {
            return _buildSimpleState(
              context,
              icon: Icons.group_outlined,
              title: "No friends yet".tr(),
              subtitle: "No friends to show yet.".tr(),
            );
          }

          List<UserProfile> filteredFriends = allFriends;
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            filteredFriends = allFriends.where((u) {
              final name = u.name.toLowerCase();
              final username = u.username.toLowerCase();
              return name.contains(q) || username.contains(q);
            }).toList();
          }

          filteredFriends.sort((a, b) => a.username.compareTo(b.username));

          final noMatches =
              _searchQuery.trim().isNotEmpty && filteredFriends.isEmpty;

          return _buildEmbeddedOrNormalLayout(
            title: "Friends".tr(),
            count: allFriends.length,
            hintText: 'Search friends'.tr(),
            noMatches: noMatches,
            noMatchesTitle: 'No friends match your search'.tr(),
            listChild: _buildOtherUserList(
              filteredFriends,
              storageKey: widget.embeddedMode
                  ? 'friends_other_user_embedded_list'
                  : null,
            ),
          );
        },
      );
    }

    return StreamBuilder<Map<String, int>>(
      stream: chatProvider.unreadCountsPollingStream(currentUserId),
      builder: (context, unreadSnapshot) {
        final unreadByFriend = unreadSnapshot.data ?? const <String, int>{};

        return StreamBuilder<Map<String, LastMessageInfo>>(
          stream: chatProvider.lastMessagesByFriendPollingStream(currentUserId),
          builder: (context, lastMsgSnapshot) {
            final lastMessageByFriend =
                lastMsgSnapshot.data ?? const <String, LastMessageInfo>{};

            return StreamBuilder<List<UserProfile>>(
              stream: widget.includeMahrams
                  ? dbProvider.connectionsStream()
                  : dbProvider.friendsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildSimpleState(
                    context,
                    icon: Icons.error_outline_rounded,
                    title: "Error loading friends".tr(),
                    subtitle: '',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allFriends = (snapshot.data ?? [])
                    .where((u) => u.id != currentUserId)
                    .toList();

                if (allFriends.isEmpty) {
                  return _buildSimpleState(
                    context,
                    icon: widget.includeMahrams
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.group_outlined,
                    title: widget.includeMahrams
                        ? "No chats yet".tr()
                        : "No friends yet".tr(),
                    subtitle: widget.includeMahrams
                        ? "Add friends or mahrams to start chatting.".tr()
                        : "Add people as friends or accept friend requests to start chatting."
                        .tr(),
                  );
                }

                List<UserProfile> filteredFriends = allFriends;
                if (_searchQuery.trim().isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filteredFriends = allFriends.where((u) {
                    final name = u.name.toLowerCase();
                    final username = u.username.toLowerCase();
                    return name.contains(q) || username.contains(q);
                  }).toList();
                }

                filteredFriends.sort((a, b) {
                  final infoA = lastMessageByFriend[a.id];
                  final infoB = lastMessageByFriend[b.id];
                  final timeA = infoA?.createdAt;
                  final timeB = infoB?.createdAt;

                  if (timeA == null && timeB == null) {
                    return a.username.compareTo(b.username);
                  }
                  if (timeA == null) return 1;
                  if (timeB == null) return -1;
                  return timeB.compareTo(timeA);
                });

                final noMatches =
                    _searchQuery.trim().isNotEmpty && filteredFriends.isEmpty;

                final String? activeDmFriendId =
                    notificationService.activeDmFriendId;

                return _buildEmbeddedOrNormalLayout(
                  title: widget.includeMahrams
                      ? "Your chats".tr()
                      : "Your friends".tr(),
                  count: allFriends.length,
                  hintText: widget.includeMahrams
                      ? 'Search chats'.tr()
                      : 'Search friends'.tr(),
                  noMatches: noMatches,
                  noMatchesTitle: widget.includeMahrams
                      ? 'No chats match your search'.tr()
                      : 'No friends match your search'.tr(),
                  listChild: _buildChatsList(
                    filteredFriends: filteredFriends,
                    unreadByFriend: unreadByFriend,
                    lastMessageByFriend: lastMessageByFriend,
                    activeDmFriendId: activeDmFriendId,
                    dbProvider: dbProvider,
                    storageKey: widget.embeddedMode
                        ? (widget.includeMahrams
                        ? 'friends_embedded_chats_list'
                        : 'friends_embedded_friends_list')
                        : null,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmbeddedOrNormalLayout({
    required String title,
    required int count,
    required String hintText,
    required bool noMatches,
    required String noMatchesTitle,
    required Widget listChild,
  }) {
    return Column(
      children: [
        _buildTopSection(
          context,
          title: title,
          count: count,
          hintText: hintText,
          embedded: widget.embeddedMode,
        ),
        Expanded(
          child: noMatches
              ? _buildSimpleState(
            context,
            icon: Icons.search_off_rounded,
            title: noMatchesTitle,
            subtitle: '',
            compact: true,
          )
              : NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: listChild,
          ),
        ),
      ],
    );
  }

  Widget _buildOtherUserList(
      List<UserProfile> filteredFriends, {
        String? storageKey,
      }) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 72;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: ListView.builder(
        controller: _scrollController,
        key: storageKey == null ? null : PageStorageKey<String>(storageKey),
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: EdgeInsets.only(
          top: widget.embeddedMode ? widget.embeddedListTopCompensation : 0,
          bottom: widget.embeddedMode
              ? bottomPad + kChatsHeaderOuterHeight
              : MediaQuery.of(context).padding.bottom + 96,
        ),
        itemCount: filteredFriends.length,
        itemBuilder: (context, index) {
          final u = filteredFriends[index];

          return MyFriendTile(
            key: ValueKey(u.id),
            user: u,
            isMahram: false,
            customTitle: u.name,
            isOnline: u.isOnline,
            unreadCount: 0,
            lastMessagePreview: null,
            lastMessageTimeLabel: null,
            onTap: () {
              final currentUserId = AuthService().getCurrentUserId();

              if (u.id == currentUserId) {
                goToOwnProfileTab(context);
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(userId: u.id),
                ),
              );
            },
            onAvatarTap: () {
              final currentUserId = AuthService().getCurrentUserId();

              if (u.id == currentUserId) {
                goToOwnProfileTab(context);
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(userId: u.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChatsList({
    required List<UserProfile> filteredFriends,
    required Map<String, int> unreadByFriend,
    required Map<String, LastMessageInfo> lastMessageByFriend,
    required String? activeDmFriendId,
    required DatabaseProvider dbProvider,
    String? storageKey,
  }) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 72;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: ListView.builder(
        controller: _scrollController,
        key: storageKey == null ? null : PageStorageKey<String>(storageKey),
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: EdgeInsets.only(
          top: widget.embeddedMode ? widget.embeddedListTopCompensation : 0,
          bottom: widget.embeddedMode
              ? bottomPad + kChatsHeaderOuterHeight
              : MediaQuery.of(context).padding.bottom + 96,
        ),
        itemCount: filteredFriends.length,
        itemBuilder: (context, index) {
          final user = filteredFriends[index];

          final rawUnread = unreadByFriend[user.id] ?? 0;
          final unreadCount =
          (activeDmFriendId != null && activeDmFriendId == user.id)
              ? 0
              : rawUnread;

          final lastInfo = lastMessageByFriend[user.id];
          final lastText = lastInfo?.text;
          final lastTime = lastInfo?.createdAt;
          final lastTimeLabel = formatLastMessageTime(lastTime);

          final preview = (lastText == null || lastText.trim().isNotEmpty == false)
              ? null
              : (lastInfo!.sentByCurrentUser
              ? '${"You".tr()}: $lastText'
              : lastText);

          final effectivePreview = (lastText == null || lastText.trim().isEmpty)
              ? null
              : (lastInfo!.sentByCurrentUser
              ? '${"You".tr()}: $lastText'
              : lastText);

          return MyFriendTile(
            key: ValueKey(user.id),
            user: user,
            isMahram:
            widget.includeMahrams ? dbProvider.isMahramUser(user.id) : false,
            customTitle: user.name,
            isOnline: user.isOnline,
            unreadCount: unreadCount,
            lastMessagePreview: effectivePreview,
            lastMessageTimeLabel: lastTimeLabel,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                    friendId: user.id,
                    friendName: user.name,
                  ),
                ),
              );

              if (mounted) setState(() {});
            },
            onAvatarTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(userId: user.id),
                ),
              );
            },
          );
        },
      ),
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
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
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
}