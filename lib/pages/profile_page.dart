import 'package:flutter/material.dart';
import 'package:ummah_chat/pages/settings_page.dart';
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
import 'package:flutter/cupertino.dart';

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

  bool get _isOwnProfile => widget.userId == currentUserId;

  /// For own profile → always use provider’s live set
  /// For other users → use the list loaded from DB in loadUser()
  List<String> get _effectiveCompletedStoryIds {
    if (_isOwnProfile) {
      return listeningProvider.completedStoryIds.toList();
    }
    return _completedStoryIds;
  }

  // on startup,
  @override
  void initState() {
    super.initState();

    // let's load user info
    loadUser();
  }

  Future<void> loadUser() async {
    setState(() {
      _isLoading = true;
    });

    // Try up to 8 times (≈1.5 seconds)
    const int maxAttempts = 8;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      user = await databaseProvider.getUserProfile(widget.userId);

      if (user != null) {
        break;
      }

      // Wait 200 ms then retry
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Still null after retries → show user-friendly message
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Now fetch followers / following
    await databaseProvider.loadUserFollowers(widget.userId);
    await databaseProvider.loadUserFollowing(widget.userId);

    // Follow status
    _isFollowing = databaseProvider.isFollowing(widget.userId);

    // Friends status
    _friendStatus = await databaseProvider.getFriendStatus(widget.userId);

    // 🆕 Completed stories for this profile (from Supabase)
    // For *other* profiles this is what we show.
    // For own profile the live provider set will override this in the UI.
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

  // Save updated bio
  Future<void> _saveBio() async {
    // start loading...
    setState(() => _isLoading = true);

    // update bio
    await databaseProvider.updateBio(bioTextController.text);

    // reload user
    await loadUser();

    // finished loading
    setState(() => _isLoading = false);
  }

  Future<void> _toggleFollow() async {
    // unfollow
    if (_isFollowing) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Unfollow"),
          content: const Text("Are you sure you want to unfollow?"),
          actions: [
            // cancel button
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel")),
            // yes button
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Yes")),
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

  /// 🆕 Get friend button label based on current friend status
  String _friendButtonText() {
    switch (_friendStatus) {
      case 'pending_sent':
        return 'Cancel request';
      case 'pending_received':
        return 'Accept request';
      case 'accepted':
        return 'Friends';
      case 'blocked':
        return 'Blocked';
      case 'none':
      default:
        return 'Add friend';
    }
  }

  /// 🆕 Should the friend button be enabled (clickable)?
  bool _isFriendButtonEnabled() {
    // Disable if already friends or blocked
    if (_friendStatus == 'accepted' || _friendStatus == 'blocked') {
      return false;
    }
    // You can keep 'pending_sent' enabled if you later want to allow "cancel"
    return true;
  }

  /// 🆕 Handle friend button tap
  Future<void> _onFriendButtonPressed() async {
    // If I'm receiving a request, accept it
    if (_friendStatus == 'pending_received') {
      await databaseProvider.acceptFriendRequest(widget.userId);
    }
    // If there's no relation, send a new request
    else if (_friendStatus == 'none') {
      await databaseProvider.sendFriendRequest(widget.userId);
    }
    // Optional: allow cancel when 'pending_sent'
    else if (_friendStatus == 'pending_sent') {
      await databaseProvider.cancelFriendRequest(widget.userId);
    }

    // Reload status from database
    final updated = await databaseProvider.getFriendStatus(widget.userId);
    setState(() {
      _friendStatus = updated;
    });
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

  // BUILD UI
  @override
  Widget build(BuildContext context) {
    // get user posts
    final allUserPosts = listeningProvider.getUserPosts(widget.userId);

    // listen to followers & following count
    final followerCount = listeningProvider.getFollowerCount(widget.userId);
    final followingCount = listeningProvider.getFollowingCount(widget.userId);

    // listen to is following
    _isFollowing = listeningProvider.isFollowing(widget.userId);

    // ✅ Stories progress values
    final totalStories = allStoriesById.length;
    final effectiveCompletedIds = _effectiveCompletedStoryIds;

    // Decide what the body should show (3 states: loading / no user / normal)
    Widget bodyChild;
    if (_isLoading) {
      // still fetching profile
      bodyChild = const Center(child: CircularProgressIndicator());
    } else if (user == null) {
      // profile row not found (e.g. just registered & profile not yet created)
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
      // ✅ Safe to use user! here because we've checked user != null above
      bodyChild = ListView(
        children: [
          const SizedBox(height: 18),

          // NAME + USERNAME at top (instead of AppBar)
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

          // Profile stats
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

          // Follow / Unfollow + Friend button
          // only show if the user is viewing someone else's profile
          if (user!.id != currentUserId)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🧍 FOLLOW BUTTON (let MyFollowButton handle color & height)
                  Expanded(
                    child: MyFollowButton(
                      onPressed: _toggleFollow,
                      isFollowing: _isFollowing,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 🧑‍🤝‍🧑 FRIEND BUTTON AREA
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

          // BIO Text
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

                // EDIT BIO BUTTON
                // only show edit button when you're looking at your own profile
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

          // Bio Box
          MyBioBox(text: user!.bio),

          // 🆕 Stories progress + medals + completed list (just above Posts)
          if (totalStories > 0) ...[
            const SizedBox(height: 24),

            // Progress text → always show, even if 0 completed
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

            // Only show medals / chips if there is at least 1 completed
            if (effectiveCompletedIds.isNotEmpty) ...[
              const SizedBox(height: 12),

              // Medals row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: effectiveCompletedIds.map((id) {
                    final story = allStoriesById[id];
                    if (story == null) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0F8254),
                            Color(0xFF0B6841),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          story.icon,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Optional overall badge if all are done
              if (effectiveCompletedIds.length == totalStories) ...[
                const SizedBox(height: 12),
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F8254).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                        const Color(0xFF0F8254).withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 18,
                          color: Color(0xFF0F8254),
                        ),
                        const SizedBox(width: 8),
                        const Text(
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

              const SizedBox(height: 18),

              // Completed stories list (chips)
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 28.0),
                child: Text(
                  "Completed stories",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: effectiveCompletedIds.map((id) {
                    final story = allStoriesById[id];
                    if (story == null) {
                      // Just in case a story_id exists in DB but not in app anymore
                      return const SizedBox.shrink();
                    }
                    return Chip(
                      avatar: const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.green,
                      ),
                      label: Text(story.chipLabel),
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceVariant,
                    );
                  }).toList(),
                ),
              ),
            ],
          ],

          Padding(
            padding: const EdgeInsets.only(left: 28.0, top: 28.0),
            child: Text(
              "Posts",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

          // list of posts from user
          allUserPosts.isEmpty
              ?
          // user posts is empty
          Center(
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
              :
          // user posts is NOT empty
          ListView.builder(
            itemCount: allUserPosts.length,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemBuilder: (context, index) {
              // get individual post
              final post = allUserPosts[index];
              return MyPostTile(
                post: post,
                onPostTap: () => goPostPage(context, post),
                scaffoldContext: context,
              );
            },
          ),
        ],
      );
    }

    //SCAFFOLD
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,

      // ✅ Show AppBar ONLY when viewing another user's profile
      appBar: widget.userId != currentUserId
          ? AppBar(
        foregroundColor:
        Theme.of(context).colorScheme.primary,
      )
          : null,

      // Body (one of: loading / not-found / full profile)
      body: bodyChild,
    );
  }
}
