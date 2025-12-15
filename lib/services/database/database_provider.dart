// lib/services/database/database_provider.dart

/*
DATABASE PROVIDER

This provider is to separate the firestore data handling and the UI of our app.

--------------------------------------------------------------------------------

- The database service class handles data to and from supabase
- The database provider class processes the data to display in our app.

This is to make our code more modular, cleaner, and easier to read and test.
*/

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/comment.dart';
import '../../models/dua.dart';
import '../../models/post.dart';
import '../../models/post_media.dart';
import '../../models/user_profile.dart';
import '../auth/auth_service.dart';
import 'database_service.dart';

class DatabaseProvider extends ChangeNotifier {
  // Get db & auth service
  final AuthService _auth = AuthService();
  final DatabaseService _db = DatabaseService();

  String get currentUserId => _auth.getCurrentUserId();

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

  /// Update core profile (name + country + gender)
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

  // single source of truth for all posts in feed
  List<Post> _posts = [];
  List<Post> _followingPosts = [];

  List<Post> get posts => _posts;
  List<Post> get followingPosts => _followingPosts;

  Post? _loadingPost;
  Post? get loadingPost => _loadingPost;

  bool _isLoadingPosts = false;
  bool get isLoadingPosts => _isLoadingPosts;

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

  /// Fetch all posts, filter blocked users, init likes, derive following posts.
  Future<void> loadAllPosts() async {
    try {
      // 1️⃣ Fetch all posts from database
      final fetchedPosts = await _db.getAllPostsFromDatabase();

      // 2️⃣ Get blocked user IDs
      final blockedUserIds = await _db.getBlockedUserIdsFromDatabase();

      // 3️⃣ Filter out blocked users
      _posts = fetchedPosts
          .where((post) => !blockedUserIds.contains(post.userId))
          .toList();

      // 4️⃣ Initialize like counts
      initializeLikeMap();

      // 5️⃣ Load which posts are liked by the current user (from post_likes)
      final currentUserId = _auth.getCurrentUserId();
      if (currentUserId.isNotEmpty && _posts.isNotEmpty) {
        final postIds = _posts.map((p) => p.id).whereType<String>().toList();

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

  /// Call this to reload the home feed (used on first load,
  /// pull-to-refresh, after create/delete post).
  Future<void> reloadPosts() async {
    _isLoadingPosts = true;
    notifyListeners();

    try {
      await loadAllPosts();
    } catch (e, s) {
      debugPrint('Error reloading posts: $e\n$s');
    } finally {
      _isLoadingPosts = false;
      notifyListeners();
    }
  }

  /// Filter and return posts for given userId
  List<Post> getUserPosts(String userId) {
    return _posts.where((post) => post.userId == userId).toList();
  }

  /// Returns a list of posts that the current user has liked
  List<Post> getPostsLikedByCurrentUser(List<Post> sourcePosts) {
    return sourcePosts.where((post) => _likedPosts.contains(post.id)).toList();
  }

  /// Load following posts
  Future<void> loadFollowingPosts() async {
    final currentUserId = _auth.getCurrentUserId();
    if (currentUserId.isEmpty) return;

    try {
      // get list of user IDs that the current logged in user follows
      final followingUserIds = await _db.getFollowingFromDatabase(currentUserId);

      // filter posts to be the ones for the following tab
      _followingPosts = _posts
          .where((post) => followingUserIds.contains(post.userId))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading following posts: $e');
    }
  }

  /// Delete post + refresh list
  Future<void> deletePost(Post post) async {
    try {
      await _db.deletePostFromDatabase(post.id);

      // After deletion, refresh everything (filters, likes, following tab)
      await loadAllPosts();
    } catch (e) {
      debugPrint('Error deleting post: $e');
    }
  }

  Future<Post?> getPostById(String postId) {
    return _db.getPostByIdFromDatabase(postId);
  }

  /// Create new post with media + caption
  Future<void> postMultiMediaMessage(
      String message, {
        required List<File> imageFiles,
        required List<File> videoFiles,
        String? communityId,
      }) async {
    await _db.postMultiMediaMessageInDatabase(
      message,
      imageFiles: imageFiles,
      videoFiles: videoFiles,
      communityId: communityId,
    );

    // Refresh posts list so new post shows up in feed
    await loadAllPosts();
  }

  /// Fetch all media items (images + videos) for a given post.
  Future<List<PostMedia>> getPostMedia(String postId) async {
    if (postId.isEmpty) return [];

    try {
      final raw = await _db.getPostMediaFromDatabase(postId);

      final media = raw
          .map((row) => PostMedia.fromMap(Map<String, dynamic>.from(row)))
          .toList();

      media.sort((a, b) {
        final byOrder = a.orderIndex.compareTo(b.orderIndex);
        if (byOrder != 0) return byOrder;
        return a.createdAt.compareTo(b.createdAt);
      });

      return media;
    } catch (e) {
      debugPrint('Error fetching post media for $postId: $e');
      return [];
    }
  }

  /* ==================== LIKES ==================== */

  Map<String, int> _likeCounts = {};
  List<String> _likedPosts = [];

  bool isPostLikedByCurrentUser(String postId) => _likedPosts.contains(postId);

  int getLikeCount(String postId) => _likeCounts[postId] ?? 0;

  /// Initialize like map locally from `_posts`
  void initializeLikeMap() {
    _likeCounts.clear();
    _likedPosts.clear();

    for (var post in _posts) {
      if (post.id.isNotEmpty) {
        _likeCounts[post.id] = post.likeCount;
      }
    }
  }

  /// Toggle like for a post
  Future<void> toggleLike(String postId) async {
    final likedPostsOriginal = List<String>.from(_likedPosts);
    final likeCountsOriginal = Map<String, int>.from(_likeCounts);

    if (_likedPosts.contains(postId)) {
      _likedPosts.remove(postId);
      _likeCounts[postId] = (_likeCounts[postId] ?? 0) - 1;
    } else {
      _likedPosts.add(postId);
      _likeCounts[postId] = (_likeCounts[postId] ?? 0) + 1;
    }

    notifyListeners();

    try {
      await _db.toggleLikeInDatabase(postId);
    } catch (e) {
      _likedPosts = likedPostsOriginal;
      _likeCounts = likeCountsOriginal;
      notifyListeners();
    }
  }

  /* ==================== COMMENTS ==================== */

  final Map<String, List<Comment>> _comments = {};

  List<Comment> getComments(String postId) => _comments[postId] ?? [];

  Future<void> loadComments(String postId) async {
    try {
      _comments[postId] = await _db.getCommentsFromDatabase(postId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading comments: $e');
    }
  }

  Future<void> addComment(String postId, String message) async {
    if (message.trim().isEmpty) return;

    try {
      await _db.addCommentInDatabase(postId, message);
      await loadComments(postId);
    } catch (e) {
      debugPrint('Error adding comment: $e');
    }
  }

  Future<void> deleteComment(String commentId, String postId) async {
    try {
      await _db.deleteCommentFromDatabase(commentId);
      await loadComments(postId);
    } catch (e) {
      debugPrint('Error deleting comment: $e');
    }
  }

  /* ==================== BLOCKED USERS ==================== */

  List<UserProfile> _blockedUsers = [];
  List<UserProfile> get blockedUsers => _blockedUsers;

  Future<void> loadBlockedUsers() async {
    final blockedIds = await _db.getBlockedUserIdsFromDatabase();

    final profiles =
    await Future.wait(blockedIds.map((id) => _db.getUserFromDatabase(id)));

    _blockedUsers = profiles.whereType<UserProfile>().toList();

    notifyListeners();
  }

  Future<void> blockUser(String userId) async {
    final currentUserId = _auth.getCurrentUserId();
    if (currentUserId.isEmpty) return;

    try {
      await _db.blockUserInDatabase(userId);

      await loadBlockedUsers();
      await loadAllPosts();
    } catch (e) {
      debugPrint('Error blocking user: $e');
    }
  }

  Future<void> unblockUser(String userId) async {
    await _db.unblockUserInDatabase(userId);

    await loadBlockedUsers();
    await loadAllPosts();
  }

  Future<void> reportUser(String postId, String userId) async {
    await _db.reportUserInDatabase(postId, userId);
  }

  /* ==================== FRIENDS ==================== */

  Future<String> getFriendStatus(String otherUserId) {
    return _db.getFriendshipStatusFromDatabase(otherUserId);
  }

  Future<void> sendFriendRequest(String otherUserId) {
    return _db.sendFriendRequestInDatabase(otherUserId);
  }

  Future<void> acceptFriendRequest(String otherUserId) async {
    await _db.acceptFriendRequestInDatabase(otherUserId);
  }

  Future<void> cancelFriendRequest(String otherUserId) {
    return _db.cancelFriendRequestInDatabase(otherUserId);
  }

  Future<void> declineFriendRequest(String otherUserId) {
    return _db.declineFriendRequestInDatabase(otherUserId);
  }

  Stream<List<UserProfile>> friendsStream() {
    return _db.friendsStreamFromDatabase();
  }

  Stream<List<UserProfile>> friendsStreamForUser(String userId) {
    return _db.friendsStreamForUserFromDatabase(userId);
  }

  Future<void> unfriendUser(String otherUserId) async {
    await _db.unfriendUserInDatabase(otherUserId);
  }

  /* ==================== FOLLOWERS / FOLLOWING ==================== */

  final Map<String, List<String>> _followers = {};
  final Map<String, List<String>> _following = {};
  final Map<String, int> _followerCount = {};
  final Map<String, int> _followingCount = {};
  final Map<String, List<UserProfile>> _followerProfiles = {};
  final Map<String, List<UserProfile>> _followingProfiles = {};

  int getFollowerCount(String userId) => _followerCount[userId] ?? 0;
  int getFollowingCount(String userId) => _followingCount[userId] ?? 0;

  Future<void> loadUserFollowers(String userId) async {
    final followerIds = await _db.getFollowersFromDatabase(userId);

    _followers[userId] = followerIds;
    _followerCount[userId] = followerIds.length;

    notifyListeners();
  }

  Future<void> loadUserFollowing(String userId) async {
    final followingIds = await _db.getFollowingFromDatabase(userId);

    _following[userId] = followingIds;
    _followingCount[userId] = followingIds.length;

    notifyListeners();
  }

  List<UserProfile> getListOfFollowerProfiles(String userId) =>
      _followerProfiles[userId] ?? [];

  List<UserProfile> getListOfFollowingProfiles(String userId) =>
      _followingProfiles[userId] ?? [];

  Future<void> loadUserFollowerProfiles(String userId) async {
    try {
      final followerIds = await _db.getFollowersFromDatabase(userId);

      final List<UserProfile> followerProfiles = [];

      for (String followerId in followerIds) {
        final followerProfile = await _db.getUserFromDatabase(followerId);
        if (followerProfile != null) {
          followerProfiles.add(followerProfile);
        }
      }

      _followerProfiles[userId] = followerProfiles;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading follower profiles: $e');
    }
  }

  Future<void> loadUserFollowingProfiles(String userId) async {
    try {
      final followingIds = await _db.getFollowingFromDatabase(userId);

      final List<UserProfile> followingProfiles = [];

      for (String followingId in followingIds) {
        final followingProfile = await _db.getUserFromDatabase(followingId);
        if (followingProfile != null) {
          followingProfiles.add(followingProfile);
        }
      }

      _followingProfiles[userId] = followingProfiles;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading following profiles: $e');
    }
  }

  Future<void> followUser(String targetUserId) async {
    final currentUserId = _auth.getCurrentUserId();

    _following.putIfAbsent(currentUserId, () => []);
    _followers.putIfAbsent(targetUserId, () => []);

    if (!_followers[targetUserId]!.contains(currentUserId)) {
      _followers[targetUserId]?.add(currentUserId);
      _followerCount[targetUserId] =
      ((_followerCount[targetUserId] ?? 0) + 1);

      _following[currentUserId]?.add(targetUserId);
      _followingCount[currentUserId] =
      ((_followingCount[currentUserId] ?? 0) + 1);
    }

    notifyListeners();

    try {
      await _db.followUserInDatabase(targetUserId);
      await loadUserFollowers(currentUserId);
      await loadUserFollowing(currentUserId);
    } catch (e) {
      _followers[targetUserId]?.remove(currentUserId);
      _followerCount[targetUserId] =
          (_followerCount[targetUserId] ?? 0) - 1;

      _following[currentUserId]?.remove(targetUserId);
      _followingCount[currentUserId] =
          (_followingCount[currentUserId] ?? 0) - 1;

      notifyListeners();
    }
  }

  Future<void> unfollowUser(String targetUserId) async {
    final currentUserId = _auth.getCurrentUserId();

    _following.putIfAbsent(currentUserId, () => []);
    _followers.putIfAbsent(targetUserId, () => []);

    if (_followers[targetUserId]!.contains(currentUserId)) {
      _followers[targetUserId]?.remove(currentUserId);
      _followerCount[targetUserId] =
          (_followerCount[targetUserId] ?? 1) - 1;

      _following[currentUserId]?.remove(targetUserId);
      _followingCount[currentUserId] =
          (_followingCount[currentUserId] ?? 1) - 1;
    }

    notifyListeners();

    try {
      await _db.unfollowUserInDatabase(targetUserId);
      await loadUserFollowers(currentUserId);
      await loadUserFollowing(currentUserId);
    } catch (e) {
      _followers[targetUserId]?.add(currentUserId);
      _followerCount[targetUserId] =
          (_followerCount[targetUserId] ?? 0) + 1;

      _following[currentUserId]?.add(targetUserId);
      _followingCount[currentUserId] =
          (_followingCount[currentUserId] ?? 0) + 1;

      notifyListeners();
    }
  }

  bool isFollowing(String userId) {
    final currentUserId = _auth.getCurrentUserId();
    if (currentUserId.isEmpty) return false;
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
      final results = await _db.searchUsersInDatabase(searchTerm);
      final currentUserId = _auth.getCurrentUserId();

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
    final community =
    _allCommunities.firstWhere((c) => c['id'] == communityId);
    community['is_joined'] = true;
    notifyListeners();

    try {
      await _db.joinCommunityInDatabase(communityId);
      await getAllCommunities();
    } catch (e) {
      community['is_joined'] = false;
      notifyListeners();
    }
  }

  Future<void> leaveCommunity(String communityId) async {
    await _db.leaveCommunityInDatabase(communityId);
    await getAllCommunities();
  }

  Future<void> searchCommunities(String query) async {
    final all = await _db.searchCommunitiesInDatabase(query);
    final queryLower = query.toLowerCase();

    _communitySearchResults = all
        .where((c) => c['name'].toLowerCase().startsWith(queryLower))
        .toList();

    notifyListeners();
  }

  void clearCommunitySearchResults() {
    _communitySearchResults.clear();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getCommunityMemberProfiles(
      String communityId) async {
    return await _db.getCommunityMemberProfilesFromDatabase(communityId);
  }

  /* ==================== STORY PROGRESS ==================== */

  final Set<String> _completedStoryIds = {};
  Set<String> get completedStoryIds => _completedStoryIds;

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

  Future<void> saveStoryAnswers(
      String storyId, List<int?> selectedIndices) async {
    final currentUserId = _auth.getCurrentUserId();
    if (currentUserId.isEmpty) return;

    try {
      final Map<int, int> answers = {};
      for (int i = 0; i < selectedIndices.length; i++) {
        final selected = selectedIndices[i];
        if (selected != null) {
          answers[i] = selected;
        }
      }

      await _db.saveStoryAnswersInDatabase(storyId, answers);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving story answers: $e');
    }
  }

  Future<List<String>> getCompletedStoriesForUser(String userId) async {
    try {
      return await _db.getCompletedStoryIdsFromDatabase(userId);
    } catch (e) {
      debugPrint('Error fetching completed stories for user $userId: $e');
      return [];
    }
  }

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

  Future<void> loadDuaWall() async {
    try {
      final allDuas = await _db.getDuaWallFromDatabase();
      final blockedUserIds = await _db.getBlockedUserIdsFromDatabase();

      _duaWall = allDuas
          .where((d) => !blockedUserIds.contains(d.userId))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading dua wall: $e');
    }
  }

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
      await loadDuaWall();
    } catch (e) {
      debugPrint('Error creating dua: $e');
      rethrow;
    }
  }

  Future<void> toggleAmeenForDua(String duaId) async {
    try {
      await _db.toggleAmeenForDuaInDatabase(duaId);
      await loadDuaWall();
    } catch (e) {
      debugPrint('Error toggling Ameen for dua $duaId: $e');
    }
  }

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
    _posts.clear();
    _followingPosts.clear();
    _loadingPost = null;

    // Likes
    _likeCounts.clear();
    _likedPosts.clear();

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
