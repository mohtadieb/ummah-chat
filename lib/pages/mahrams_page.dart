import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ummah_chat/models/user_profile.dart';
import 'package:ummah_chat/pages/profile_page.dart';
import 'package:ummah_chat/services/auth/auth_service.dart';

import '../components/my_friend_tile.dart';
import '../components/my_search_bar.dart';
import '../helper/navigate_pages.dart';
import '../helper/last_message_time_formatter.dart';
import '../services/chat/chat_provider.dart';
import '../services/chat/chat_service.dart';
import '../services/database/database_provider.dart';
import '../services/notifications/notification_service.dart';
import 'chat_page.dart';

class MahramsPage extends StatefulWidget {
  final String? userId;

  const MahramsPage({super.key, this.userId});

  @override
  State<MahramsPage> createState() => _MahramsPageState();
}

class _MahramsPageState extends State<MahramsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _isOtherUserView => widget.userId != null;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildMahramsList(context);
  }

  Widget _buildMahramsList(BuildContext context) {
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
          'You must be logged in to view mahrams'.tr(),
          style: TextStyle(color: colorScheme.primary),
        ),
      );
    }

    if (_isOtherUserView) {
      return StreamBuilder<List<UserProfile>>(
        stream: dbProvider.mahramsStreamForUser(targetUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildSimpleState(
              context,
              icon: Icons.error_outline_rounded,
              title: "Error loading mahrams".tr(),
              subtitle: '',
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allMahrams = snapshot.data ?? [];

          if (allMahrams.isEmpty) {
            return _buildSimpleState(
              context,
              icon: Icons.verified_user_outlined,
              title: "No mahrams yet".tr(),
              subtitle: "No mahrams to show yet.".tr(),
            );
          }

          List<UserProfile> filteredMahrams = allMahrams;
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            filteredMahrams = allMahrams.where((u) {
              final name = u.name.toLowerCase();
              final username = u.username.toLowerCase();
              return name.contains(q) || username.contains(q);
            }).toList();
          }

          filteredMahrams.sort((a, b) => a.username.compareTo(b.username));

          final noMatches =
              _searchQuery.trim().isNotEmpty && filteredMahrams.isEmpty;

          return Column(
            children: [
              _buildTopSection(
                context,
                title: "Mahrams".tr(),
                count: allMahrams.length,
                hintText: 'Search mahrams'.tr(),
              ),
              Expanded(
                child: noMatches
                    ? _buildSimpleState(
                  context,
                  icon: Icons.search_off_rounded,
                  title: 'No mahrams match your search'.tr(),
                  subtitle: '',
                  compact: true,
                )
                    : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(overscroll: false),
                  child: ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: 6,
                      bottom: MediaQuery.of(context).padding.bottom + 96,
                    ),
                    itemCount: filteredMahrams.length,
                    itemBuilder: (context, index) {
                      final u = filteredMahrams[index];

                      return MyFriendTile(
                        key: ValueKey(u.id),
                        user: u,
                        isMahram: true,
                        customTitle: u.name,
                        isOnline: u.isOnline,
                        unreadCount: 0,
                        lastMessagePreview: null,
                        lastMessageTimeLabel: null,
                        onTap: () {
                          final currentUserId =
                          AuthService().getCurrentUserId();

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
                          final currentUserId =
                          AuthService().getCurrentUserId();

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
                ),
              ),
            ],
          );
        },
      );
    }

    return StreamBuilder<Map<String, int>>(
      stream: chatProvider.unreadCountsPollingStream(currentUserId),
      builder: (context, unreadSnapshot) {
        final unreadByUser = unreadSnapshot.data ?? const <String, int>{};

        return StreamBuilder<Map<String, LastMessageInfo>>(
          stream: chatProvider.lastMessagesByFriendPollingStream(currentUserId),
          builder: (context, lastMsgSnapshot) {
            final lastMessageByUser =
                lastMsgSnapshot.data ?? const <String, LastMessageInfo>{};

            return StreamBuilder<List<UserProfile>>(
              stream: dbProvider.mahramsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildSimpleState(
                    context,
                    icon: Icons.error_outline_rounded,
                    title: "Error loading mahrams".tr(),
                    subtitle: '',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allMahrams = (snapshot.data ?? [])
                    .where((u) => u.id != currentUserId)
                    .toList();

                if (allMahrams.isEmpty) {
                  return _buildSimpleState(
                    context,
                    icon: Icons.verified_user_outlined,
                    title: "No mahrams yet".tr(),
                    subtitle: "Add mahrams to start chatting.".tr(),
                  );
                }

                List<UserProfile> filteredMahrams = allMahrams;
                if (_searchQuery.trim().isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filteredMahrams = allMahrams.where((u) {
                    final name = u.name.toLowerCase();
                    final username = u.username.toLowerCase();
                    return name.contains(q) || username.contains(q);
                  }).toList();
                }

                filteredMahrams.sort((a, b) {
                  final infoA = lastMessageByUser[a.id];
                  final infoB = lastMessageByUser[b.id];
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
                    _searchQuery.trim().isNotEmpty && filteredMahrams.isEmpty;

                final String? activeDmFriendId =
                    notificationService.activeDmFriendId;

                return Column(
                  children: [
                    _buildTopSection(
                      context,
                      title: "Your mahrams".tr(),
                      count: allMahrams.length,
                      hintText: 'Search mahrams'.tr(),
                    ),
                    Expanded(
                      child: noMatches
                          ? _buildSimpleState(
                        context,
                        icon: Icons.search_off_rounded,
                        title: 'No mahrams match your search'.tr(),
                        subtitle: '',
                        compact: true,
                      )
                          : ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context)
                            .copyWith(overscroll: false),
                        child: ListView.builder(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.only(
                            top: 6,
                            bottom:
                            MediaQuery.of(context).padding.bottom + 96,
                          ),
                          itemCount: filteredMahrams.length,
                          itemBuilder: (context, index) {
                            final user = filteredMahrams[index];
                            final rawUnread = unreadByUser[user.id] ?? 0;

                            final unreadCount =
                            (activeDmFriendId != null &&
                                activeDmFriendId == user.id)
                                ? 0
                                : rawUnread;

                            final lastInfo = lastMessageByUser[user.id];
                            final lastText = lastInfo?.text;
                            final lastTime = lastInfo?.createdAt;

                            final lastTimeLabel =
                            formatLastMessageTime(lastTime);

                            final preview = (lastText == null ||
                                lastText.trim().isEmpty)
                                ? null
                                : (lastInfo!.sentByCurrentUser
                                ? '${"You".tr()}: $lastText'
                                : lastText);

                            return MyFriendTile(
                              key: ValueKey(user.id),
                              user: user,
                              isMahram: true,
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
                                    builder: (_) =>
                                        ProfilePage(userId: user.id),
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
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTopSection(
      BuildContext context, {
        required String title,
        required int count,
        required String hintText,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
}