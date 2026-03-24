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

const double kFriendsEmbeddedHeaderHeight = 126.0;

class FriendsPage extends StatefulWidget {
  final String? userId;
  final bool includeMahrams;
  final bool embeddedMode;

  const FriendsPage({
    super.key,
    this.userId,
    this.includeMahrams = false,
    this.embeddedMode = false,
  });

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with AutomaticKeepAliveClientMixin<FriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _isOtherUserView => widget.userId != null;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
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

          if (!widget.embeddedMode) {
            return Column(
              children: [
                _buildTopSection(
                  context,
                  title: "Friends".tr(),
                  count: allFriends.length,
                  hintText: 'Search friends'.tr(),
                ),
                Expanded(
                  child: noMatches
                      ? _buildSimpleState(
                    context,
                    icon: Icons.search_off_rounded,
                    title: 'No friends match your search'.tr(),
                    subtitle: '',
                    compact: true,
                  )
                      : ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: 2,
                      bottom: MediaQuery.of(context).padding.bottom + 96,
                    ),
                    itemCount: filteredFriends.length,
                    itemBuilder: (context, index) {
                      final u = filteredFriends[index];
                      return _buildOtherUserTile(context, u);
                    },
                  ),
                ),
              ],
            );
          }

          return Builder(
            builder: (innerContext) {
              return CustomScrollView(
                key: const PageStorageKey<String>('friends_other_embedded'),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  SliverOverlapInjector(
                    handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(
                      innerContext,
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _EmbeddedFriendsHeaderDelegate(
                      extent: kFriendsEmbeddedHeaderHeight,
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: SizedBox(
                          height: kFriendsEmbeddedHeaderHeight,
                          child: _buildTopSection(
                            context,
                            title: "Friends".tr(),
                            count: allFriends.length,
                            hintText: 'Search friends'.tr(),
                            embedded: true,
                          ),
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
                        title: 'No friends match your search'.tr(),
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
                            final u = filteredFriends[index];
                            return _buildOtherUserTile(context, u);
                          },
                          childCount: filteredFriends.length,
                        ),
                      ),
                    ),
                ],
              );
            },
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

                if (!widget.embeddedMode) {
                  return Column(
                    children: [
                      _buildTopSection(
                        context,
                        title: widget.includeMahrams
                            ? "Your chats".tr()
                            : "Your friends".tr(),
                        count: allFriends.length,
                        hintText: widget.includeMahrams
                            ? 'Search chats'.tr()
                            : 'Search friends'.tr(),
                      ),
                      Expanded(
                        child: noMatches
                            ? _buildSimpleState(
                          context,
                          icon: Icons.search_off_rounded,
                          title: widget.includeMahrams
                              ? 'No chats match your search'.tr()
                              : 'No friends match your search'.tr(),
                          subtitle: '',
                          compact: true,
                        )
                            : ListView.builder(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.only(
                            top: 2,
                            bottom:
                            MediaQuery.of(context).padding.bottom +
                                96,
                          ),
                          itemCount: filteredFriends.length,
                          itemBuilder: (context, index) {
                            final user = filteredFriends[index];
                            return _buildChatTile(
                              context: context,
                              user: user,
                              unreadByFriend: unreadByFriend,
                              lastMessageByFriend: lastMessageByFriend,
                              activeDmFriendId: activeDmFriendId,
                              dbProvider: dbProvider,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }

                return Builder(
                  builder: (innerContext) {
                    return CustomScrollView(
                      key: PageStorageKey<String>(
                        widget.includeMahrams
                            ? 'friends_chats_embedded'
                            : 'friends_friends_embedded',
                      ),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      slivers: [
                        SliverOverlapInjector(
                          handle:
                          NestedScrollView.sliverOverlapAbsorberHandleFor(
                            innerContext,
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _EmbeddedFriendsHeaderDelegate(
                            extent: kFriendsEmbeddedHeaderHeight,
                            child: ColoredBox(
                              color: Theme.of(context).colorScheme.surface,
                              child: SizedBox(
                                height: kFriendsEmbeddedHeaderHeight,
                                child: _buildTopSection(
                                  context,
                                  title: widget.includeMahrams
                                      ? "Your chats".tr()
                                      : "Your friends".tr(),
                                  count: allFriends.length,
                                  hintText: widget.includeMahrams
                                      ? 'Search chats'.tr()
                                      : 'Search friends'.tr(),
                                  embedded: true,
                                ),
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
                              title: widget.includeMahrams
                                  ? 'No chats match your search'.tr()
                                  : 'No friends match your search'.tr(),
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
                                  final user = filteredFriends[index];
                                  return _buildChatTile(
                                    context: context,
                                    user: user,
                                    unreadByFriend: unreadByFriend,
                                    lastMessageByFriend: lastMessageByFriend,
                                    activeDmFriendId: activeDmFriendId,
                                    dbProvider: dbProvider,
                                  );
                                },
                                childCount: filteredFriends.length,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOtherUserTile(BuildContext context, UserProfile u) {
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
  }

  Widget _buildChatTile({
    required BuildContext context,
    required UserProfile user,
    required Map<String, int> unreadByFriend,
    required Map<String, LastMessageInfo> lastMessageByFriend,
    required String? activeDmFriendId,
    required DatabaseProvider dbProvider,
  }) {
    final rawUnread = unreadByFriend[user.id] ?? 0;
    final unreadCount =
    (activeDmFriendId != null && activeDmFriendId == user.id)
        ? 0
        : rawUnread;

    final lastInfo = lastMessageByFriend[user.id];
    final lastText = lastInfo?.text;
    final lastTime = lastInfo?.createdAt;
    final lastTimeLabel = formatLastMessageTime(lastTime);

    final preview = (lastText == null || lastText.trim().isEmpty)
        ? null
        : (lastInfo!.sentByCurrentUser
        ? '${"You".tr()}: $lastText'
        : lastText);

    return MyFriendTile(
      key: ValueKey(user.id),
      user: user,
      isMahram: widget.includeMahrams
          ? dbProvider.isMahramUser(user.id)
          : false,
      customTitle: user.name,
      isOnline: user.isOnline,
      unreadCount: unreadCount,
      lastMessagePreview: preview,
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

class _EmbeddedFriendsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  _EmbeddedFriendsHeaderDelegate({
    required this.extent,
    required this.child,
  });

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _EmbeddedFriendsHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}