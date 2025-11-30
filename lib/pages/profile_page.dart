// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/my_bio_box.dart';
import '../components/my_follow_button.dart';
import '../components/my_friend_button.dart';
import '../components/my_input_alert_box.dart';
import '../components/my_post_tile.dart';
import '../components/my_profile_stats.dart';
import '../helper/navigate_pages.dart';
import '../models/user.dart';
import '../services/auth/auth_service.dart';
import '../services/database/database_provider.dart';
import 'follow_list_page.dart';

// 🆕 Story registry (id -> StoryData with chipLabel/title/icon)
import '../models/story_registry.dart';

/*
PROFILE PAGE (Supabase Ready)
Displays user profile, bio, follow button, posts, followers/following counts
*/

class ProfilePage extends StatefulWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Providers
  late final databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);
  late final listeningProvider = Provider.of<DatabaseProvider>(context);

  // user info
  UserProfile? user;
  String currentUserId = AuthService().getCurrentUserId();

  // Text controller for bio
  final bioTextController = TextEditingController();

  // loading..
  bool _isLoading = true;

  // isFollowing state
  bool _isFollowing = false;

  // 🆕 FRIENDS state
  // "none", "pending_sent", "pending_received", "accepted", "blocked"
  String _friendStatus = 'none';

  // 🆕 Completed stories (for this profile – from DB for *other* users)
  List<String> _completedStoryIds = [];

  // 🆕 Posts dropdown state
  bool _showPosts = false;

  // Scroll controller for the profile list
  final ScrollController _scrollController = ScrollController();

  bool get _isOwnProfile => widget.userId == currentUserId;

  /// For own profile → always use provider’s live set
  /// For other users → use the list loaded from DB in loadUser()
  List<String> get _effectiveCompletedStoryIds {
    if (_isOwnProfile) {
      return listeningProvider.completedStoryIds.toList();
    }
    return _completedStoryIds;
  }

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  @override
  void dispose() {
    bioTextController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadUser() async {
    setState(() {
      _isLoading = true;
    });

    const int maxAttempts = 8;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      user = await databaseProvider.getUserProfile(widget.userId);

      if (user != null) {
        break;
      }

      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    await databaseProvider.loadUserFollowers(widget.userId);
    await databaseProvider.loadUserFollowing(widget.userId);

    _isFollowing = databaseProvider.isFollowing(widget.userId);

    _friendStatus = await databaseProvider.getFriendStatus(widget.userId);

    _completedStoryIds =
    await databaseProvider.getCompletedStoriesForUser(widget.userId);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showEditBioBox() {
    bioTextController.text = user?.bio ?? '';
    showDialog(
      context: context,
      builder: (context) => MyInputAlertBox(
        textController: bioTextController,
        hintText: "Edit bio...",
        onPressed: _saveBio,
        onPressedText: "Save",
      ),
    );
  }

  Future<void> _saveBio() async {
    setState(() => _isLoading = true);
    await databaseProvider.updateBio(bioTextController.text);
    await loadUser();
    setState(() => _isLoading = false);
  }

  Future<void> _toggleFollow() async {
    if (_isFollowing) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Unfollow"),
          content: const Text("Are you sure you want to unfollow?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Yes"),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await databaseProvider.unfollowUser(widget.userId);
        databaseProvider.loadFollowingPosts();
        setState(() => _isFollowing = false);
      }
    } else {
      await databaseProvider.followUser(widget.userId);
      databaseProvider.loadFollowingPosts();
      setState(() => _isFollowing = true);
    }
  }

  Future<void> _acceptFriendFromProfile() async {
    await databaseProvider.acceptFriendRequest(widget.userId);
    final updated = await databaseProvider.getFriendStatus(widget.userId);
    setState(() {
      _friendStatus = updated;
    });
  }

  Future<void> _declineFriendFromProfile() async {
    await databaseProvider.declineFriendRequest(widget.userId);
    final updated = await databaseProvider.getFriendStatus(widget.userId);
    setState(() {
      _friendStatus = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allUserPosts = listeningProvider.getUserPosts(widget.userId);
    final postCount = allUserPosts.length;

    final followerCount = listeningProvider.getFollowerCount(widget.userId);
    final followingCount = listeningProvider.getFollowingCount(widget.userId);

    _isFollowing = listeningProvider.isFollowing(widget.userId);

    // ✅ Stories progress values
    final totalStories = allStoriesById.length;
    final effectiveCompletedIds = _effectiveCompletedStoryIds;

    Widget bodyChild;
    if (_isLoading) {
      bodyChild = const Center(child: CircularProgressIndicator());
    } else if (user == null) {
      bodyChild = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Profile not found yet.\nPlease try again in a moment.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    } else {
      bodyChild = ListView(
        controller: _scrollController,
        children: [
          const SizedBox(height: 18),

          // NAME + USERNAME
          Center(
            child: Column(
              children: [
                Text(
                  user!.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user!.username}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Profile picture
          Center(
            child: user!.profilePhotoUrl.isNotEmpty
                ? CircleAvatar(
              radius: 56,
              backgroundImage: NetworkImage(user!.profilePhotoUrl),
            )
                : Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(56),
              ),
              padding: const EdgeInsets.all(28),
              child: Icon(
                Icons.person,
                size: 70,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Stats
          MyProfileStats(
            postCount: allUserPosts.length,
            followerCount: followerCount,
            followingCount: followingCount,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FollowListPage(userId: widget.userId),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Follow / Friend buttons
          if (user!.id != currentUserId)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: MyFollowButton(
                      onPressed: _toggleFollow,
                      isFollowing: _isFollowing,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MyFriendButton(
                      friendStatus: _friendStatus,
                      onAddFriend: () async {
                        await databaseProvider.sendFriendRequest(widget.userId);
                        setState(() => _friendStatus = 'pending_sent');
                      },
                      onCancelRequest: () async {
                        await databaseProvider
                            .cancelFriendRequest(widget.userId);
                        setState(() => _friendStatus = 'none');
                      },
                      onAcceptRequest: () async {
                        await databaseProvider
                            .acceptFriendRequest(widget.userId);
                        final updated = await databaseProvider
                            .getFriendStatus(widget.userId);
                        setState(() => _friendStatus = updated);
                      },
                      onDeclineRequest: () async {
                        await databaseProvider
                            .declineFriendRequest(widget.userId);
                        final updated = await databaseProvider
                            .getFriendStatus(widget.userId);
                        setState(() => _friendStatus = updated);
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Bio header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Bio",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (user!.id == currentUserId)
                  GestureDetector(
                    onTap: _showEditBioBox,
                    child: Icon(
                      Icons.edit,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 7),

          MyBioBox(text: user!.bio),

          // 🆕 Stories progress + medals with names
          if (totalStories > 0) ...[
            const SizedBox(height: 24),

            // Progress text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Text(
                "Stories completed: ${effectiveCompletedIds.length} / $totalStories",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

            if (effectiveCompletedIds.isNotEmpty) ...[
              const SizedBox(height: 12),

              // Medals + prophet names under them in a 4-column grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: effectiveCompletedIds.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, // 4 per row
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.75, // space for circle + text
                  ),
                  itemBuilder: (context, index) {
                    final id = effectiveCompletedIds[index];
                    final story = allStoriesById[id];
                    if (story == null) {
                      return const SizedBox.shrink();
                    }

                    // chipLabel e.g. "Prophet Musa (AS)" → we want "Musa (AS)"
                    final rawLabel = story.chipLabel;
                    final lower = rawLabel.toLowerCase();
                    final displayName = lower.startsWith('prophet ')
                        ? rawLabel.substring('Prophet '.length)
                        : rawLabel;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF0F8254),
                                  Color(0xFF0B6841),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26.withOpacity(0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              story.icon,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          displayName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Overall badge if all are done
              if (effectiveCompletedIds.length == totalStories) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F8254).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF0F8254).withOpacity(0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 18,
                          color: Color(0xFF0F8254),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Prophets Stories Level 1 completed",
                          style: TextStyle(
                            color: Color(0xFF0F8254),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],

          const SizedBox(height: 12),

          // 🆕 Posts section header (more prominent, card-like)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final willShow = !_showPosts;

                setState(() {
                  _showPosts = willShow;
                });

                // When opening posts → scroll a bit so they come into view
                if (willShow) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_scrollController.hasClients) return;
                    final current = _scrollController.offset;
                    _scrollController.animateTo(
                      current + 140, // tweak this value if needed
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                    );
                  });
                }
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    // Icon to suggest expandability
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.article_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Posts",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            postCount == 0
                                ? "Tap to view posts"
                                : "$postCount post${postCount == 1 ? '' : 's'} • tap to view",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Arrow in a pill to make it look like a control
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showPosts ? "Hide" : "Show",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showPosts
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 🆕 Posts dropdown content
          if (_showPosts)
            (allUserPosts.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Text(
                  "No posts yet..",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            )
                : ListView.builder(
              itemCount: allUserPosts.length,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final post = allUserPosts[index];
                return MyPostTile(
                  post: post,
                  onPostTap: () => goPostPage(context, post),
                  scaffoldContext: context,
                );
              },
            )),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: widget.userId != currentUserId
          ? AppBar(
        foregroundColor: Theme.of(context).colorScheme.primary,
      )
          : null,
      body: bodyChild,
    );
  }
}
