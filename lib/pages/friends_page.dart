import 'package:easy_localization/easy_localization.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ummah_chat/models/user_profile.dart';
import 'package:ummah_chat/pages/profile_page.dart';
import 'package:ummah_chat/services/auth/auth_service.dart';

import '../components/my_friend_tile.dart';
import '../helper/last_message_time_formatter.dart';
import '../helper/navigate_pages.dart';
import '../services/chat/chat_provider.dart';
import '../services/chat/chat_service.dart';
import '../services/database/database_provider.dart';
import '../services/notifications/notification_service.dart';
import 'chat_page.dart';

class FriendsPage extends StatefulWidget {
  final String? userId;
  final bool includeMahrams;
  final bool embeddedMode;
  final String embeddedSearchQuery;
  final ValueChanged<int>? onEmbeddedCountChanged;

  const FriendsPage({
    super.key,
    this.userId,
    this.includeMahrams = false,
    this.embeddedMode = false,
    this.embeddedSearchQuery = '',
    this.onEmbeddedCountChanged,
  });

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with AutomaticKeepAliveClientMixin<FriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _standaloneScrollController = ScrollController();

  String _searchQuery = '';
  int? _lastReportedCount;

  Stream<List<UserProfile>>? _otherUserFriendsBroadcastStream;

  bool get _isOtherUserView => widget.userId != null;

  String get _effectiveQuery =>
      widget.embeddedMode ? widget.embeddedSearchQuery : _searchQuery;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isOtherUserView && _otherUserFriendsBroadcastStream == null) {
      _bindOtherUserFriendsStream();
    }
  }

  @override
  void didUpdateWidget(covariant FriendsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _bindOtherUserFriendsStream();
    }
  }

  void _bindOtherUserFriendsStream() {
    final otherUserId = widget.userId?.trim();
    if (otherUserId == null || otherUserId.isEmpty) {
      _otherUserFriendsBroadcastStream = null;
      return;
    }

    _otherUserFriendsBroadcastStream = Provider.of<DatabaseProvider>(
      context,
      listen: false,
    ).friendsStreamForUser(otherUserId).asBroadcastStream();
  }

  void _reportCount(int count) {
    if (!widget.embeddedMode) return;
    if (_lastReportedCount == count) return;
    _lastReportedCount = count;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onEmbeddedCountChanged?.call(count);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _standaloneScrollController.dispose();
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
        stream: _otherUserFriendsBroadcastStream,
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
          _reportCount(allFriends.length);

          if (allFriends.isEmpty) {
            return widget.embeddedMode
                ? _buildEmbeddedScrollableEmptyState(
              context,
              icon: Icons.group_outlined,
              title: "No friends yet".tr(),
              subtitle: "No friends to show yet.".tr(),
              storageKey: const PageStorageKey<String>(
                'friends_other_embedded_empty',
              ),
            )
                : _buildSimpleState(
              context,
              icon: Icons.group_outlined,
              title: "No friends yet".tr(),
              subtitle: "No friends to show yet.".tr(),
            );
          }

          List<UserProfile> filteredFriends = allFriends;
          if (_effectiveQuery.trim().isNotEmpty) {
            final q = _effectiveQuery.toLowerCase();
            filteredFriends = allFriends.where((u) {
              final name = u.name.toLowerCase();
              final username = u.username.toLowerCase();
              return name.contains(q) || username.contains(q);
            }).toList();
          }

          filteredFriends.sort((a, b) => a.username.compareTo(b.username));

          final noMatches =
              _effectiveQuery.trim().isNotEmpty && filteredFriends.isEmpty;

          if (!widget.embeddedMode) {
            return Column(
              children: [
                Expanded(
                  child: noMatches
                      ? _buildSimpleState(
                    context,
                    icon: Icons.search_off_rounded,
                    title: 'No friends match your search'.tr(),
                    subtitle: '',
                    compact: true,
                  )
                      : _buildOtherUserList(filteredFriends),
                ),
              ],
            );
          }

          if (noMatches) {
            return _buildEmbeddedScrollableEmptyState(
              context,
              icon: Icons.search_off_rounded,
              title: 'No friends match your search'.tr(),
              subtitle: '',
              compact: true,
              storageKey: const PageStorageKey<String>(
                'friends_other_embedded_no_matches',
              ),
            );
          }

          return Builder(
            builder: (innerContext) {
              return ExtendedVisibilityDetector(
                uniqueKey: const Key('friends_other_embedded_visible'),
                child: CustomScrollView(
                  key: const PageStorageKey<String>('friends_other_embedded'),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  slivers: [
                    SliverOverlapInjector(
                      handle:
                      ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
                        innerContext,
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.only(
                        top: 2,
                        bottom: MediaQuery.of(context).padding.bottom + 84,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                              _buildOtherUserTile(context, filteredFriends[index]),
                          childCount: filteredFriends.length,
                        ),
                      ),
                    ),
                  ],
                ),
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

                _reportCount(allFriends.length);

                if (allFriends.isEmpty) {
                  final title = widget.includeMahrams
                      ? "No chats yet".tr()
                      : "No friends yet".tr();
                  final subtitle = widget.includeMahrams
                      ? "Add friends or mahrams to start chatting.".tr()
                      : "Add people as friends or accept friend requests to start chatting."
                      .tr();

                  return widget.embeddedMode
                      ? _buildEmbeddedScrollableEmptyState(
                    context,
                    icon: widget.includeMahrams
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.group_outlined,
                    title: title,
                    subtitle: subtitle,
                    storageKey: PageStorageKey<String>(
                      widget.includeMahrams
                          ? 'friends_chats_embedded_empty'
                          : 'friends_friends_embedded_empty',
                    ),
                  )
                      : _buildSimpleState(
                    context,
                    icon: widget.includeMahrams
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.group_outlined,
                    title: title,
                    subtitle: subtitle,
                  );
                }

                List<UserProfile> filteredFriends = allFriends;
                if (_effectiveQuery.trim().isNotEmpty) {
                  final q = _effectiveQuery.toLowerCase();
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
                    _effectiveQuery.trim().isNotEmpty && filteredFriends.isEmpty;

                final String? activeDmFriendId =
                    notificationService.activeDmFriendId;

                if (!widget.embeddedMode) {
                  return Column(
                    children: [
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
                            : _buildChatsList(
                          filteredFriends: filteredFriends,
                          unreadByFriend: unreadByFriend,
                          lastMessageByFriend: lastMessageByFriend,
                          activeDmFriendId: activeDmFriendId,
                          dbProvider: dbProvider,
                        ),
                      ),
                    ],
                  );
                }

                if (noMatches) {
                  return _buildEmbeddedScrollableEmptyState(
                    context,
                    icon: Icons.search_off_rounded,
                    title: widget.includeMahrams
                        ? 'No chats match your search'.tr()
                        : 'No friends match your search'.tr(),
                    subtitle: '',
                    compact: true,
                    storageKey: PageStorageKey<String>(
                      widget.includeMahrams
                          ? 'friends_chats_embedded_no_matches'
                          : 'friends_friends_embedded_no_matches',
                    ),
                  );
                }

                return Builder(
                  builder: (innerContext) {
                    return ExtendedVisibilityDetector(
                      uniqueKey: Key(
                        widget.includeMahrams
                            ? 'friends_chats_embedded_visible'
                            : 'friends_friends_embedded_visible',
                      ),
                      child: CustomScrollView(
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
                            handle: ExtendedNestedScrollView
                                .sliverOverlapAbsorberHandleFor(innerContext),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.only(
                              top: 2,
                              bottom: MediaQuery.of(context).padding.bottom + 84,
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
                      ),
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

  Widget _buildOtherUserList(List<UserProfile> filteredFriends) {
    return ListView.builder(
      controller: _standaloneScrollController,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(
        top: 2,
        bottom: MediaQuery.of(context).padding.bottom + 96,
      ),
      itemCount: filteredFriends.length,
      itemBuilder: (context, index) {
        return _buildOtherUserTile(context, filteredFriends[index]);
      },
    );
  }

  Widget _buildChatsList({
    required List<UserProfile> filteredFriends,
    required Map<String, int> unreadByFriend,
    required Map<String, LastMessageInfo> lastMessageByFriend,
    required String? activeDmFriendId,
    required DatabaseProvider dbProvider,
  }) {
    return ListView.builder(
      controller: _standaloneScrollController,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(
        top: 2,
        bottom: MediaQuery.of(context).padding.bottom + 96,
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
    (activeDmFriendId != null && activeDmFriendId == user.id) ? 0 : rawUnread;

    final lastInfo = lastMessageByFriend[user.id];
    final lastText = lastInfo?.text;
    final lastTime = lastInfo?.createdAt;
    final lastTimeLabel = formatLastMessageTime(lastTime);

    final preview = (lastText == null || lastText.trim().isEmpty)
        ? null
        : (lastInfo!.sentByCurrentUser ? '${"You".tr()}: $lastText' : lastText);

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

  Widget _buildEmbeddedScrollableEmptyState(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Key storageKey,
        bool compact = false,
      }) {
    return Builder(
      builder: (innerContext) {
        return ExtendedVisibilityDetector(
          uniqueKey: ValueKey(storageKey.toString()),
          child: CustomScrollView(
            key: storageKey,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              SliverOverlapInjector(
                handle: ExtendedNestedScrollView
                    .sliverOverlapAbsorberHandleFor(innerContext),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                fillOverscroll: true,
                child: _buildSimpleState(
                  context,
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  compact: compact,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 84,
                ),
              ),
            ],
          ),
        );
      },
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