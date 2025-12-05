// lib/services/database/database_provider.dart

/*
DATABASE PROVIDER

This provider is to separate the firestore data handling and the UI of out app.

--------------------------------------------------------------------------------

- The database service class handles data to and from supabase
- The database provider class processes the data to display in our app.

This is to make out code more modular, cleaner, and easier to read and test.
Particularly as the number of pages grow, we need this provider to properly manage
the different states of the app.

- Also, if one day, we decide to change out backend (from supabase to something else)
the it's much easier to manage and switch out different databases.

*/

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/comment.dart';
import '../../models/dua.dart';
import '../../models/post.dart';
import '../../models/user_profile.dart';
import '../auth/auth_service.dart';
import 'database_service.dart';

class DatabaseProvider extends ChangeNotifier {
  // Get db & auth service
  final AuthService _auth = AuthService();
  final DatabaseService _db = DatabaseService();

  /* ==================== USER PROFILE ==================== */

  /// Get user profile given userId
  Future<UserProfile?> getUserProfile(String userId) =>
      _db.getUserFromDatabase(userId);

  Future<void> updateProfilePhoto(Uint8List bytes) async {
    final userId = _auth.getCurrentUserId();
    if (userId == null) return;

    final url = await _db.uploadProfilePhotoToDatabase(bytes, userId);
    if (url != null) {
      await _db.updateUserProfilePhotoInDatabase(url);
    }
  }


  /// Update user bio
  Future<void> updateBio(String bio) => _db.updateUserBioInDatabase(bio);

  /// Update profile song
  Future<void> updateProfileSong(String songId) =>
      _db.updateUserProfileSong(songId);

  /// Update about me (city + languages + interests)
  Future<void> updateAboutMe({
    required String? city,
    required List<String> languages,
    required List<String> interests,
  }) async {
    await _db.updateUserAboutMeInDatabase(
      city: city,
      languages: languages,
      interests: interests,
    );
  }

  /// 🆕 Update core profile (name + country + gender) from CompleteProfilePage
  Future<void> updateCoreProfile({
    required String name,
    required String country,
    required String gender,
  }) async {
    await _db.updateUserCoreProfileInDatabase(
      name: name,
      country: country,
      gender: gender,
    );
  }


  /* ==================== POSTS ==================== */

  // local list of posts
  List<Post> _allPosts = [];
  List<Post> _followingPosts = [];

  // get posts
  List<Post> get allPosts => _allPosts;
  List<Post> get followingPosts => _followingPosts;

  Post? _loadingPost;
  Post? get loadingPost => _loadingPost;

  void showLoadingPost({
    required String message,
    File? imageFile,
    File? videoFile,
  }) {
    _loadingPost = Post(
      id: 'loading',
      userId: currentUserId,
      name: 'Posting…',
      username: 'posting...',
      message: message,
      imageUrl: null,
      communityId: null,
      createdAt: DateTime.now(),
      likeCount: 0,
    );

    notifyListeners();
  }

  void clearLoadingPost() {
    _loadingPost = null;
    notifyListeners();
  }


  /// post message
  ///
  /// `communityId` is:
  /// - null  → normal global/home feed post
  /// - uuid → post that belongs to a specific community
  Future<void> postMessage(
      String message, {
        File? imageFile,
        File? videoFile,      // 👈 NEW
        String? communityId, // ✅ NEW
      }) async {
    // Forward message, optional image + optional community to database service
    await _db.postMessageInDatabase(
      message,
      imageFile: imageFile,
      videoFile: videoFile,        // 👈 NEW
      communityId: communityId,
    );

    // Reload all posts after posting
    await loadAllPosts();
  }

  /// fetch all posts
  Future<void> loadAllPosts() async {
    try {
      // 1️⃣ Fetch all posts from database
      final allPosts = await _db.getAllPostsFromDatabase();

      // 2️⃣ Get blocked userId's from database
      final blockedUserIds = await _db.getBlockedUserIdsFromDatabase();

      // 3️⃣ Filter out blocked users
      _allPosts =
          allPosts.where((post) => !blockedUserIds.contains(post.userId)).toList();

      // 4️⃣ Initialize like counts
      initializeLikeMap();

      // 5️⃣ Load which posts are liked by the current user (from post_likes)
      final currentUserId = _auth.getCurrentUserId();
      if (currentUserId.isNotEmpty && _allPosts.isNotEmpty) {
        final postIds = _allPosts.map((p) => p.id).whereType<String>().toList();

        _likedPosts =
        await _db.getLikedPostIdsFromDatabase(currentUserId, postIds);
      } else {
        _likedPosts = [];
      }

      // 6️⃣ Load following posts (also filtered)
      await loadFollowingPosts();

      // 7️⃣ Update UI
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading posts: $e');
    }
  }

  /// filter and return posts for given UserId
  List<Post> getUserPosts(String userId) {
    return _allPosts.where((post) => post.userId == userId).toList();
  }

  /// EXTRA ///
  /// Returns a list of posts that the current user has liked
  List<Post> getPostsLikedByCurrentUser(List<Post> allPosts) {
    return allPosts.where((post) => _likedPosts.contains(post.id)).toList();
  }

  /// load following posts
  Future<void> loadFollowingPosts() async {
    // get current userId
    final currentUserId = _auth.getCurrentUserId();
    if (currentUserId.isEmpty) return;

    try {
      // get list of UserId's that the current logged in user follows
      final followingUserIds = await _db.getFollowingFromDatabase(currentUserId);

      // filter all the posts to be the ones for the following tab
      _followingPosts =
          _allPosts.where((post) => followingUserIds.contains(post.userId)).toList();

      // update UI
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading following posts: $e');
    }
  }

  /// delete post
  /// Deletes a post along with its image (if any).
  ///
  /// We pass the full `Post` object so that we can access both the post ID
  /// and the optional image URL for deletion in Supabase Storage.
  Future<void> deletePost(Post post) async {
    try {
      // 1️⃣ Call the service to delete from database and storage
      await _db.deletePostFromDatabase(
        post.id,
        imagePath: post.imageUrl, // optional, may be null
        videoPath: post.videoUrl,       // 👈 NEW
      );

      // 2️⃣ Update local state: remove the post from _allPosts list
      _allPosts.removeWhere((p) => p.id == post.id);

      // 3️⃣ Reload posts from database to notify listeners
      await loadAllPosts();
    } catch (e) {
      debugPrint('Error deleting post: $e');
    }
  }

  Future<Post?> getPostById(String postId) {
    return _db.getPostByIdFromDatabase(postId);
  }

  /* ==================== LIKES ==================== */

  // Local map to track like counts for each post
  Map<String, int> _likeCounts = {
    // for each postId: like count
  };

  // local list to track posts liked by current user
  List<String> _likedPosts = [];

  // does current user like this post?
  bool isPostLikedByCurrentUser(String postId) => _likedPosts.contains(postId);

  // get like count of a post
  int getLikeCount(String postId) => _likeCounts[postId] ?? 0;

  /// initialize like map locally
  void initializeLikeMap() {
    // clear previous state
    _likeCounts.clear();
    _likedPosts.clear();

    // initialize like counts from posts
    for (var post in _allPosts) {
      if (post.id.isNotEmpty) {
        _likeCounts[post.id] = post.likeCount;
      }
    }
  }

  /// Toggle like for a post
  Future<void> toggleLike(String postId) async {
    /*
    The first part will update local values first so that the UI feels
    immediate and responsive. We will update the UI optimistically, and revert
    back if anything goes wrong while writing to the database.
     */

    // store original values
    final likedPostsOriginal = List<String>.from(_likedPosts);
    final likeCountsOriginal = Map<String, int>.from(_likeCounts);

    // perform like / unlike
    if (_likedPosts.contains(postId)) {
      _likedPosts.remove(postId);
      _likeCounts[postId] = (_likeCounts[postId] ?? 0) - 1;
    } else {
      _likedPosts.add(postId);
      _likeCounts[postId] = (_likeCounts[postId] ?? 0) + 1;
    }

    // update UI locally
    notifyListeners();

    // Attempt like in database
    try {
      await _db.toggleLikeInDatabase(postId);
    }
    // revert back to initial state if update fails
    catch (e) {
      _likedPosts = likedPostsOriginal;
      _likeCounts = likeCountsOriginal;
    }

    // update UI again
    notifyListeners();
  }

  /* ==================== COMMENTS ==================== */

  // Local list of comments
  final Map<String, List<Comment>> _comments = {};

  // get comments locally
  List<Comment> getComments(String postId) => _comments[postId] ?? [];

  // fetch comments from database
  Future<void> loadComments(String postId) async {
    try {
      // get all comments for this post, update locally
      _comments[postId] = await _db.getCommentsFromDatabase(postId);

      // update UI
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading comments: $e');
    }
  }

  // add a comment
  Future<void> addComment(String postId, String message) async {
    if (message.trim().isEmpty) return;

    try {
      // add comment in Database
      await _db.addCommentInDatabase(postId, message);

      // reload comments
      await loadComments(postId);
    } catch (e) {
      debugPrint('Error adding comment: $e');
    }
  }

  // delete a comment
  Future<void> deleteComment(String commentId, String postId) async {
    try {
      // delete comment in Database
      await _db.deleteCommentFromDatabase(commentId);

      // reload comments
      await loadComments(postId);
    } catch (e) {
      debugPrint('Error deleting comment: $e');
    }
  }

  /* ==================== BLOCKED USERS ==================== */

  // local list of blocked users
  List<UserProfile> _blockedUsers = [];

  // get list of blocked users
  List<UserProfile> get blockedUsers => _blockedUsers;

  Future<void> loadBlockedUsers() async {
    // get list of blocked userId's
    final blockedIds = await _db.getBlockedUserIdsFromDatabase();

    // get full user details using userId
    final profiles =
    await Future.wait(blockedIds.map((id) => _db.getUserFromDatabase(id)));

    // return as a list
    _blockedUsers = profiles.whereType<UserProfile>().toList();

    // update UI
    notifyListeners();
  }

  Future<void> blockUser(String userId) async {
    final currentUserId = _auth.getCurrentUserId();
    if (currentUserId.isEmpty) return;

    try {
      // ✅ 1. Block the user in the database
      await _db.blockUserInDatabase(userId);

      // reload blocked users
      await loadBlockedUsers();

      // reload data
      await loadAllPosts();

      // update UI
      notifyListeners();
    } catch (e) {
      debugPrint('Error blocking user: $e');
    }
  }

  Future<void> unblockUser(String userId) async {
    // perform unblock in database
    await _db.unblockUserInDatabase(userId);

    // reload blocked users
    await loadBlockedUsers();

    // reload data
    await loadAllPosts();

    // update UI
    notifyListeners();
  }

  Future<void> reportUser(String postId, String userId) async {
    // report user in Database
    await _db.reportUserInDatabase(postId, userId);
  }

  /* ==================== FRIENDS ==================== */

  /// Get friendship status between current user and [otherUserId]
  ///
  /// Just forwards to DatabaseService for now.
  Future<String> getFriendStatus(String otherUserId) {
    return _db.getFriendshipStatusFromDatabase(otherUserId);
  }

  /// Send friend request
  Future<void> sendFriendRequest(String otherUserId) {
    return _db.sendFriendRequestInDatabase(otherUserId);
  }

  /// Accept friend request (when the other user sent it to me)
  Future<void> acceptFriendRequest(String otherUserId) async {
    await _db.acceptFriendRequestInDatabase(otherUserId);
  }

  /// Cancel friend request I previously sent
  Future<void> cancelFriendRequest(String otherUserId) {
    return _db.cancelFriendRequestInDatabase(otherUserId);
  }

  /// Decline friend request by other user
  Future<void> declineFriendRequest(String otherUserId) {
    return _db.declineFriendRequestInDatabase(otherUserId);
  }

  /// Get friend stream for current user (for FriendsPage)
  Stream<List<UserProfile>> friendsStream() {
    return _db.friendsStreamFromDatabase();
  }

  /// Friends stream for ANY user profile (used to show friends on their profile)
  Stream<List<UserProfile>> friendsStreamForUser(String userId) {
    return _db.friendsStreamForUserFromDatabase(userId);
  }

  /* ==================== FOLLOWERS / FOLLOWING ==================== */

  /// Local map of followers and following
  final Map<String, List<String>> _followers = {};
  final Map<String, List<String>> _following = {};
  final Map<String, int> _followerCount = {};
  final Map<String, int> _followingCount = {};
  final Map<String, List<UserProfile>> _followerProfiles = {};
  final Map<String, List<UserProfile>> _followingProfiles = {};

  int getFollowerCount(String userId) => _followerCount[userId] ?? 0;
  int getFollowingCount(String userId) => _followingCount[userId] ?? 0;

  // load followers
  Future<void> loadUserFollowers(String userId) async {
    // get list of follower userId's from database
    final followerIds = await _db.getFollowersFromDatabase(userId);

    // update local data
    _followers[userId] = followerIds;
    _followerCount[userId] = followerIds.length;

    // update UI
    notifyListeners();
  }

  // load following
  Future<void> loadUserFollowing(String userId) async {
    // get list of following userId's from database
    final followingIds = await _db.getFollowingFromDatabase(userId);

    // update local data
    _following[userId] = followingIds;
    _followingCount[userId] = followingIds.length;

    // update UI
    notifyListeners();
  }

  // get list of follower profiles for a given user
  List<UserProfile> getListOfFollowerProfiles(String userId) =>
      _followerProfiles[userId] ?? [];

  // get a list of following profiles for a given user
  List<UserProfile> getListOfFollowingProfiles(String userId) =>
      _followingProfiles[userId] ?? [];

  // load follower profiles for a given userId
  Future<void> loadUserFollowerProfiles(String userId) async {
    try {
      final followerIds = await _db.getFollowersFromDatabase(userId);

      // create a list of user profiles
      List<UserProfile> followerProfiles = [];

      // go through each follower id
      for (String followerId in followerIds) {
        // get user profile from database with this userId
        UserProfile? followerProfile =
        await _db.getUserFromDatabase(followerId);

        // add to follower profile
        if (followerProfile != null) {
          followerProfiles.add(followerProfile);
        }
      }

      // update local data
      _followerProfiles[userId] = followerProfiles;

      // update UI
      notifyListeners();
    }
    // if there are any errors
    catch (e) {
      print(e);
    }
  }

  // load following profiles for a given userId
  Future<void> loadUserFollowingProfiles(String userId) async {
    try {
      final followingIds = await _db.getFollowingFromDatabase(userId);

      // create a list of user profiles
      List<UserProfile> followingProfiles = [];

      // go through each following id
      for (String followingId in followingIds) {
        // get user profile from database with this userId
        UserProfile? followingProfile =
        await _db.getUserFromDatabase(followingId);

        // add to following profile
        if (followingProfile != null) {
          followingProfiles.add(followingProfile);
        }
      }
      // update local data
      _followingProfiles[userId] = followingProfiles;

      // update UI
      notifyListeners();
    }
    // if there are any errors
    catch (e) {
      print(e);
    }
  }

  // follow user
  Future<void> followUser(String targetUserId) async {
    // get current user Id
    final currentUserId = _auth.getCurrentUserId();

    // initialize with empty list
    _following.putIfAbsent(currentUserId, () => []);
    _followers.putIfAbsent(targetUserId, () => []);

    // Optimistically update UI
    // follow if current user is not one of the target user's followers
    if (!_followers[targetUserId]!.contains(currentUserId)) {
      // add current user to target user's follower list
      _followers[targetUserId]?.add(currentUserId);

      // update follower count
      _followerCount[targetUserId] =
      ((_followerCount[targetUserId] ?? 0) + 1);

      // then add target user to current user following
      _following[currentUserId]?.add(targetUserId);

      // update following count
      _followingCount[currentUserId] =
      ((_followingCount[currentUserId] ?? 0) + 1);
    }

    // Update UI
    notifyListeners();

    try {
      // follow user in firebase
      await _db.followUserInDatabase(targetUserId);

      // reload current user's followers
      await loadUserFollowers(currentUserId);

      // reload current user's following
      await loadUserFollowing(currentUserId);
    }
    // if there is an error ... revert back to original
    catch (e) {
      // remove current user from target user's followers
      _followers[targetUserId]?.remove(currentUserId);

      // update follower count
      _followerCount[targetUserId] =
          (_followerCount[targetUserId] ?? 0) - 1;

      // remove from current user's following
      _following[currentUserId]?.remove(targetUserId);

      // update following count
      _followingCount[currentUserId] =
          (_followingCount[currentUserId] ?? 0) - 1;

      // update UI
      notifyListeners();
    }
  }

  Future<void> unfollowUser(String targetUserId) async {
    // get current userId
    final currentUserId = _auth.getCurrentUserId();

    // initialize lists if they don't exist
    _following.putIfAbsent(currentUserId, () => []);
    _followers.putIfAbsent(targetUserId, () => []);

    // unfollow if current user is one of the target user's following
    if (_followers[targetUserId]!.contains(currentUserId)) {
      // remove current user from target user's following
      _followers[targetUserId]?.remove(currentUserId);

      // update follower count
      _followerCount[targetUserId] =
          (_followerCount[targetUserId] ?? 1) - 1;

      // remove target user from current user's following list
      _following[currentUserId]?.remove(targetUserId);

      // update following count
      _followingCount[currentUserId] =
          (_followingCount[currentUserId] ?? 1) - 1;
    }

    // update UI
    notifyListeners();

    try {
      // unfollow target user in firebase
      await _db.unfollowUserInDatabase(targetUserId);

      // reload user followers
      await loadUserFollowers(currentUserId);

      // reload user following
      await loadUserFollowing(currentUserId);
    }

    // if there is an error.. revert back to original
    catch (e) {
      // add current user back into target user's followers
      _followers[targetUserId]?.add(currentUserId);

      // update follower count
      _followerCount[targetUserId] =
          (_followerCount[targetUserId] ?? 0) + 1;

      // add target user back into current user's following list
      _following[currentUserId]?.add(targetUserId);

      // update following count
      _followingCount[currentUserId] =
          (_followingCount[currentUserId] ?? 0) + 1;

      // update UI
      notifyListeners();
    }
  }

  // is current user following target user?
  bool isFollowing(String userId) {
    final currentUserId = _auth.getCurrentUserId();
    if (currentUserId.isEmpty) {
      // no logged-in user -> definitely not following
      return false;
    }
    return _followers[userId]?.contains(currentUserId) ?? false;
  }

  /* ==================== SEARCH USERS ==================== */

  List<UserProfile> _searchResults = [];
  List<UserProfile> get searchResults => _searchResults;

  Future<void> searchUsers(String searchTerm) async {
    if (searchTerm.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    try {
      final results =
      await _db.searchUsersInDatabase(searchTerm); // call service
      final currentUserId = _auth.getCurrentUserId();

      // Filter out current user
      _searchResults = results.where((u) => u.id != currentUserId).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  /* ==================== COMMUNITIES ==================== */

  List<Map<String, dynamic>> _allCommunities = [];
  List<Map<String, dynamic>> get allCommunities => _allCommunities;

  List<Map<String, dynamic>> _communitySearchResults = [];
  List<Map<String, dynamic>> get communitySearchResults =>
      _communitySearchResults;

  String get currentUserId => _auth.getCurrentUserId();

  /// Fetch all communities
  Future<void> getAllCommunities({bool includeMembership = true}) async {
    _allCommunities = await _db.getAllCommunitiesFromDatabase();

    if (includeMembership) {
      final userId = _auth.getCurrentUserId();
      for (var community in _allCommunities) {
        final members =
        await _db.getCommunityMembersFromDatabase(community['id']);
        community['is_joined'] =
            members.any((m) => m['user_id'] == userId);
      }
    }

    notifyListeners();
  }

  /// Optimistically add community locally
  void addCommunityLocally(Map<String, dynamic> community) {
    _allCommunities.add(community);
    notifyListeners();
  }

  Future<void> createCommunity(String name, String desc, String country) async {
    await _db.createCommunityInDatabase(name, desc, country);
    await getAllCommunities();
  }

  Future<bool> isMember(String communityId) async {
    return await _db.isMemberInDatabase(communityId);
  }

  Future<void> joinCommunity(String communityId) async {
    // Optimistic update
    final community =
    _allCommunities.firstWhere((c) => c['id'] == communityId);
    community['is_joined'] = true;
    notifyListeners();

    try {
      await _db.joinCommunityInDatabase(communityId);
      await getAllCommunities(); // sync with DB
    } catch (e) {
      community['is_joined'] = false; // revert on error
      notifyListeners();
    }
  }

  Future<void> leaveCommunity(String communityId) async {
    await _db.leaveCommunityInDatabase(communityId);
    await getAllCommunities(); // refresh memberships
  }

  Future<void> searchCommunities(String query) async {
    final allCommunities = await _db.searchCommunitiesInDatabase(query);
    final queryLower = query.toLowerCase();

    _communitySearchResults = allCommunities
        .where((c) => c['name'].toLowerCase().startsWith(queryLower))
        .toList();

    notifyListeners();
  }

  void clearCommunitySearchResults() {
    _communitySearchResults.clear();
    notifyListeners();
  }

  /// get community member's profiles
  Future<List<Map<String, dynamic>>> getCommunityMemberProfiles(
      String communityId) async {
    return await _db.getCommunityMemberProfilesFromDatabase(communityId);
  }

  /* ==================== STORY PROGRESS ==================== */

  // Local cache of completed story IDs for the *current* user
  final Set<String> _completedStoryIds = {};
  Set<String> get completedStoryIds => _completedStoryIds;

  /// Load completed stories for a specific user from the database
  Future<void> loadCompletedStories(String userId) async {
    try {
      final ids = await _db.getCompletedStoryIdsFromDatabase(userId);
      _completedStoryIds
        ..clear()
        ..addAll(ids);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading completed stories: $e');
    }
  }

  /// Mark a story as completed for the *current* user
  Future<void> markStoryCompleted(String storyId) async {
    final currentUserId = _auth.getCurrentUserId();
    if (currentUserId.isEmpty) return;

    try {
      await _db.markStoryCompletedInDatabase(storyId);
      _completedStoryIds.add(storyId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking story completed: $e');
    }
  }

  /// Save answers for a story (per current user).
  ///
  /// [selectedIndices] is a list where index = questionIndex,
  /// value = selectedOptionIndex or null if unanswered.
  Future<void> saveStoryAnswers(String storyId, List<int?> selectedIndices) async {
    final currentUserId = _auth.getCurrentUserId();
    if (currentUserId.isEmpty) return;

    try {
      // Build compact map of answered questions only
      final Map<int, int> answers = {};
      for (int i = 0; i < selectedIndices.length; i++) {
        final selected = selectedIndices[i];
        if (selected != null) {
          answers[i] = selected;
        }
      }

      await _db.saveStoryAnswersInDatabase(
        storyId,
        answers,
      );

      // ❌ still do NOT touch _completedStoryIds here
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving story answers: $e');
    }
  }

  /// Fetch completed story IDs for any user (used for profile pages)
  Future<List<String>> getCompletedStoriesForUser(String userId) async {
    try {
      return await _db.getCompletedStoryIdsFromDatabase(userId);
    } catch (e) {
      debugPrint('Error fetching completed stories for user $userId: $e');
      return [];
    }
  }

  /// Load saved answers for the *current* user and a given story
  Future<Map<int, int>> getStoryAnswers(String storyId) async {
    try {
      return await _db.getStoryAnswersFromDatabase(storyId);
    } catch (e) {
      debugPrint('Error getting story answers for $storyId: $e');
      return {};
    }
  }

  /* ==================== DUA WALL ==================== */

  List<Dua> _duaWall = [];
  List<Dua> get duaWall => _duaWall;

  /// Load all visible duas into local state.
  ///
  /// - Filters out duas from blocked users.
  Future<void> loadDuaWall() async {
    try {
      // 1️⃣ Fetch all duas
      final allDuas = await _db.getDuaWallFromDatabase();

      // 2️⃣ Filter out blocked users from the Dua Wall (same logic as posts)
      final blockedUserIds = await _db.getBlockedUserIdsFromDatabase();

      _duaWall = allDuas
          .where((d) => !blockedUserIds.contains(d.userId))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading dua wall: $e');
    }
  }

  /// Create a new dua and refresh wall.
  Future<void> createDua({
    required String text,
    required bool isAnonymous,
    required bool isPrivate,
  }) async {
    try {
      await _db.createDuaInDatabase(
        text: text,
        isAnonymous: isAnonymous,
        isPrivate: isPrivate,
      );

      // Refresh after posting
      await loadDuaWall();
    } catch (e) {
      debugPrint('Error creating dua: $e');
      rethrow;
    }
  }

  /// Toggle Ameen for a specific dua and refresh.
  ///
  /// (You can later make this optimistic if you want smoother UX.)
  Future<void> toggleAmeenForDua(String duaId) async {
    try {
      await _db.toggleAmeenForDuaInDatabase(duaId);
      await loadDuaWall();
    } catch (e) {
      debugPrint('Error toggling Ameen for dua $duaId: $e');
    }
  }

  /// Delete a dua and refresh the wall.
  Future<void> deleteDua(String duaId) async {
    try {
      await _db.deleteDuaFromDatabase(duaId);
      await loadDuaWall();
    } catch (e) {
      debugPrint('Error deleting dua: $e');
      rethrow;
    }
  }


  /* ==================== LOG OUT ==================== */

  void clearAllCachedData() {
    // Posts
    _allPosts.clear();
    _followingPosts.clear();

    // Likes
    _likeCounts.clear();
    _likedPosts.clear(); // added, tracks posts liked by current user

    // Comments
    _comments.clear();

    // Followers / Following
    _followers.clear();
    _following.clear();
    _followerCount.clear();
    _followingCount.clear();
    _followerProfiles.clear();
    _followingProfiles.clear();

    // Search results
    _searchResults.clear();

    // Blocked users
    _blockedUsers.clear();

    // Story progress
    _completedStoryIds.clear();

    // Time
    _serverNow = null;

    // Notify UI
    notifyListeners();
  }

  /* ==================== TIME ==================== */

  DateTime? _serverNow;
  DateTime get serverNow => _serverNow ?? DateTime.now().toUtc();

  Future<void> syncServerTime() async {
    final fetchedTime = await _db.getServerTime();
    if (fetchedTime != null) {
      _serverNow = fetchedTime;
      notifyListeners();
    }
  }
}
