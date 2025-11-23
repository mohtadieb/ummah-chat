import 'package:flutter/material.dart';
import 'package:ummah_chat/models/user.dart';
import 'package:ummah_chat/services/auth/auth_service.dart';
import 'package:provider/provider.dart';

import '../components/my_friend_tile.dart';
import '../components/my_search_bar.dart';
import '../services/chat/chat_service.dart';
import '../services/database/database_provider.dart';
import 'chat_page.dart';
import 'profile_page.dart';

class FriendsPage extends StatefulWidget {
  /// Callback provided by MainLayout to switch to the Search tab
  final VoidCallback onGoToSearch;

  const FriendsPage({
    super.key,
    required this.onGoToSearch,
  });

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  // Local search within friends list
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Chat service for unread counts (and later: presence)
  final ChatService _chatService = ChatService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Friends",
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Main content: list of friends (with local search)
      body: _buildFriendsList(context),

      // FAB → switch to Search tab in MainLayout (via callback)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onGoToSearch,
        icon: const Icon(Icons.person_search),
        label: const Text('Find people'),
        backgroundColor: const Color(0xFF0D6746),
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }

  /// Live-updating list of friends for the current logged-in user
  Widget _buildFriendsList(BuildContext context) {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final auth = AuthService();
    final currentUserId = auth.getCurrentUserId();
    final colorScheme = Theme.of(context).colorScheme;

    if (currentUserId.isEmpty) {
      return Center(
        child: Text(
          'You must be logged in to view friends',
          style: TextStyle(color: colorScheme.primary),
        ),
      );
    }

    // 1️⃣ Live-ish unread message counts per friend (polling stream)
    return StreamBuilder<Map<String, int>>(
      stream: _chatService.unreadCountsPollingStream(currentUserId),
      builder: (context, unreadSnapshot) {
        final unreadByFriend = unreadSnapshot.data ?? const <String, int>{};

        // 2️⃣ Live-ish "last message info" per friend (polling stream)
        return StreamBuilder<Map<String, LastMessageInfo>>(
          stream: _chatService.lastMessagesByFriendPollingStream(
            currentUserId,
          ),
          builder: (context, lastMsgSnapshot) {
            final lastMessageByFriend =
                lastMsgSnapshot.data ?? const <String, LastMessageInfo>{};

            // 3️⃣ Realtime friends stream
            return StreamBuilder<List<UserProfile>>(
              // 🔄 Realtime stream of accepted friendships
              stream: dbProvider.friendsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error loading friends",
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // All friends returned by the stream (filter out current user just in case)
                final allFriends = (snapshot.data ?? [])
                    .where((u) => u.id != currentUserId)
                    .toList();

                // No friends at all yet
                if (allFriends.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 52,
                            color:
                            colorScheme.primary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "No friends yet",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Add people as friends or accept friend requests to start chatting.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.primary
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 🎯 Apply local search filter
                List<UserProfile> filteredFriends = allFriends;
                if (_searchQuery.trim().isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filteredFriends = allFriends.where((u) {
                    final name = u.name.toLowerCase();
                    final username = u.username.toLowerCase();
                    return name.contains(q) || username.contains(q);
                  }).toList();
                }

                // 🕒 SORT by most recent chat first
                filteredFriends.sort((a, b) {
                  final infoA = lastMessageByFriend[a.id];
                  final infoB = lastMessageByFriend[b.id];
                  final timeA = infoA?.createdAt;
                  final timeB = infoB?.createdAt;

                  // If both have no chats → fallback alphabetical
                  if (timeA == null && timeB == null) {
                    return a.username.compareTo(b.username);
                  }

                  // Friends with chats come before friends with no chats
                  if (timeA == null) return 1;
                  if (timeB == null) return -1;

                  // More recent first (descending)
                  return timeB.compareTo(timeA);
                });

                final noMatches =
                    _searchQuery.trim().isNotEmpty &&
                        filteredFriends.isEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔍 Local search bar for friends (shared MySearchBar component)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16.0, 8.0, 16.0, 4.0),
                      child: MySearchBar(
                        controller: _searchController,
                        hintText: 'Search friends',
                        onChanged: (value) {
                          // Local, instant filtering of the in-memory friends list
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        onClear: () {
                          // Clear query + reset filter when user taps the clear icon
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Header with total friends count
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Your friends",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondary
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${allFriends.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Friends list or "no matches" message
                    Expanded(
                      child: noMatches
                          ? Center(
                        child: Text(
                          'No friends match your search',
                          style: TextStyle(
                            color: colorScheme.primary
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      )
                          : ListView.builder(
                        padding: EdgeInsets.only(
                          bottom:
                          MediaQuery.of(context).padding.bottom +
                              96, // avoid FAB overlap
                        ),
                        itemCount: filteredFriends.length,
                        itemBuilder: (context, index) {
                          final user = filteredFriends[index];

                          // 🟢 Online based on last_seen_at from UserProfile
                          final isOnline = user.isOnline;

                          // 🔴 Unread messages from this friend
                          final unreadCount =
                              unreadByFriend[user.id] ?? 0;

                          // 🕒 Last message meta
                          final lastInfo =
                          lastMessageByFriend[user.id];
                          final lastText = lastInfo?.text;
                          final lastTime = lastInfo?.createdAt;

                          final lastTimeLabel =
                          _formatLastMessageTime(lastTime);

                          // Optional: prefix "You: " when last sender is current user
                          final preview = (lastText == null ||
                              lastText.trim().isEmpty)
                              ? null
                              : (lastInfo!.sentByCurrentUser
                              ? 'You: $lastText'
                              : lastText);

                          return MyFriendTile(
                            key: ValueKey(user.id),
                            user: user,
                            customTitle: user.name,
                            isOnline: isOnline,
                            unreadCount: unreadCount,
                            lastMessagePreview: preview,
                            lastMessageTimeLabel: lastTimeLabel,

                            // 👤 tap avatar/name/row → profile page
                            onProfileTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfilePage(
                                    userId: user.id,
                                  ),
                                ),
                              );
                            },

                            // 💬 tap "Chat" pill → open chat
                            onChatTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    friendId: user.id,
                                    friendName: user.name,
                                  ),
                                ),
                              );

                              // 🔄 when returning from ChatPage, rebuild to refresh unread counts
                              if (mounted) {
                                setState(() {});
                              }
                            },
                          );
                        },
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

  /// 💬 Format last message time similar-ish to WhatsApp/IG
  String? _formatLastMessageTime(DateTime? time) {
    if (time == null) return null;

    final now = DateTime.now();
    final local = time.toLocal();
    final difference = now.difference(local);

    // Same day → show HH:mm
    if (difference.inDays == 0 && local.day == now.day) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    // Within last 7 days → show weekday (Mon, Tue...)
    if (difference.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[local.weekday - 1];
    }

    // Else → show dd/MM
    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$d/$mo';
  }
}
