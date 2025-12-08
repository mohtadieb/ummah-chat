import 'package:flutter/material.dart';
import 'package:ummah_chat/models/user_profile.dart';
import 'package:ummah_chat/services/auth/auth_service.dart';
import 'package:provider/provider.dart';

import '../components/my_friend_tile.dart';
import '../components/my_search_bar.dart';
import '../services/chat/chat_service.dart';
import '../services/database/database_provider.dart';
import '../helper/last_message_time_formatter.dart';
import 'chat_page.dart';
// removed: import 'profile_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final ChatService _chatService = ChatService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildFriendsList(context);
  }

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

    return StreamBuilder<Map<String, int>>(
      stream: _chatService.unreadCountsPollingStream(currentUserId),
      builder: (context, unreadSnapshot) {
        final unreadByFriend = unreadSnapshot.data ?? const <String, int>{};

        return StreamBuilder<Map<String, LastMessageInfo>>(
          stream: _chatService.lastMessagesByFriendPollingStream(
            currentUserId,
          ),
          builder: (context, lastMsgSnapshot) {
            final lastMessageByFriend =
                lastMsgSnapshot.data ?? const <String, LastMessageInfo>{};

            return StreamBuilder<List<UserProfile>>(
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

                final allFriends = (snapshot.data ?? [])
                    .where((u) => u.id != currentUserId)
                    .toList();

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
                    _searchQuery.trim().isNotEmpty &&
                        filteredFriends.isEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                      const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
                      child: MySearchBar(
                        controller: _searchController,
                        hintText: 'Search friends',
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        onClear: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
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
                              color: colorScheme.secondary,
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
                          : ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context)
                            .copyWith(overscroll: false),
                        child: ListView.builder(
                          physics:
                          const ClampingScrollPhysics(),
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context)
                                .padding
                                .bottom +
                                96,
                          ),
                          itemCount: filteredFriends.length,
                          itemBuilder: (context, index) {
                            final user = filteredFriends[index];

                            final isOnline = user.isOnline;
                            final unreadCount =
                                unreadByFriend[user.id] ?? 0;

                            final lastInfo =
                            lastMessageByFriend[user.id];
                            final lastText = lastInfo?.text;
                            final lastTime = lastInfo?.createdAt;

                            final lastTimeLabel =
                            formatLastMessageTime(lastTime);

                            final preview =
                            (lastText == null ||
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

                              // 👇 Whole tile opens chat
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

                                if (mounted) {
                                  setState(() {}); // refresh unread
                                }
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
}
