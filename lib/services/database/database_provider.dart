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
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../helper/user_search_ranker.dart';
import '../../models/comment.dart';
import '../../models/dua.dart';
import '../../models/post.dart';
import '../../models/post_media.dart';
import '../../models/private_reflection.dart';
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
    if (userId.isEmpty) return;

    final url = await _db.uploadProfilePhotoToDatabase(bytes, userId);
    if (url != null) {
      await _db.updateUserProfilePhotoInDatabase(url);
    }
  }

  /// Update user bio
  Future<void> updateBio(String bio) => _db.updateUserBioInDatabase(bio);

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
      commentCount: 0,
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

      // ✅ Load following posts (filtered) WITHOUT notifying mid-load
      await loadFollowingPosts(notify: false);

      // ✅ Load friend IDs (needed for For You) WITHOUT notifying mid-load
      await loadFriendIds(notify: false);

      // ✅ Load likes map for For You (friends + following likes)
      final postIds = _posts
          .take(200)
          .map((p) => p.id)
          .whereType<String>()
          .toList();

      await loadLikesForForYou(postIds, notify: false);

      // ✅ Init like + comment count maps from posts (single source for UI)
      initializeCountMaps();

      // ✅ Load bookmarks after posts so bookmarkedPosts can be derived from _posts
      await loadBookmarks(notify: false);

      // 5️⃣ Load which posts are liked by the current user (from post_likes)
      final currentUserId = _auth.getCurrentUserId();
      if (currentUserId.isNotEmpty && _posts.isNotEmpty) {
        final postIds = _posts.map((p) => p.id).whereType<String>().toList();

        _likedPosts = await _db.getLikedPostIdsFromDatabase(
          currentUserId,
          postIds,
        );
      } else {
        _likedPosts = [];
      }

      // 7️⃣ Update UI once at the end
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
      clearPostMediaCache();
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
  Future<void> loadFollowingPosts({bool notify = true}) async {
    final currentUserId = _auth.getCurrentUserId();
    if (currentUserId.isEmpty) return;

    try {
      final followingUserIds = await _db.getFollowingFromDatabase(
        currentUserId,
      );

      // ✅ Cache for ForYou algorithm
      _following[currentUserId] = followingUserIds;
      _followingCount[currentUserId] = followingUserIds.length;

      _followingPosts = _posts
          .where((post) => followingUserIds.contains(post.userId))
          .toList();

      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('Error loading following posts: $e');
    }
  }

  /// ✅ Delete post with optimistic UI removal + rollback
  Future<void> deletePost(Post post) async {
    // snapshots for rollback
    final oldPosts = List<Post>.from(_posts);
    final oldFollowingPosts = List<Post>.from(_followingPosts);
    final oldLikeCounts = Map<String, int>.from(_likeCounts);
    final oldCommentCounts = Map<String, int>.from(_commentCounts);
    final oldLikedPosts = List<String>.from(_likedPosts);
    final oldBookmarkedPostIds = Set<String>.from(_bookmarkedPostIds);
    final oldComments = Map<String, List<Comment>>.from(_comments);

    try {
      // ✅ 1) optimistic local remove
      _posts.removeWhere((p) => p.id == post.id);
      _followingPosts.removeWhere((p) => p.id == post.id);

      // remove local caches tied to this post
      _likeCounts.remove(post.id);
      _commentCounts.remove(post.id);
      _likedPosts.remove(post.id);
      _bookmarkedPostIds.remove(post.id);
      _comments.remove(post.id);

      notifyListeners();

      // ✅ 2) delete from DB
      await _db.deletePostFromDatabase(post.id);

      // ✅ 3) refresh server truth (filters/likes/bookmarks/following)
      await loadAllPosts();
    } catch (e) {
      debugPrint('Error deleting post: $e');

      // rollback
      _posts = oldPosts;
      _followingPosts = oldFollowingPosts;
      _likeCounts = oldLikeCounts;
      _commentCounts = oldCommentCounts;
      _likedPosts = oldLikedPosts;

      _bookmarkedPostIds
        ..clear()
        ..addAll(oldBookmarkedPostIds);

      _comments
        ..clear()
        ..addAll(oldComments);

      notifyListeners();

      rethrow; // let UI show error if it wants
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

  // ✅ Media cache to prevent refetch + stutter
  final Map<String, List<PostMedia>> _postMediaCache = {};

  // ✅ Dedupe concurrent requests per post (prevents "loading forever" feeling)
  final Map<String, Future<List<PostMedia>>> _postMediaInFlight = {};

  // Optional: if you want to clear cache on refresh / logout
  void clearPostMediaCache() {
    _postMediaCache.clear();
    _postMediaInFlight.clear();
  }

  Future<List<PostMedia>> getPostMediaCached(String postId) {
    // cache hit
    final cached = _postMediaCache[postId];
    if (cached != null) return Future.value(cached);

    // in-flight hit (dedupe)
    final inFlight = _postMediaInFlight[postId];
    if (inFlight != null) return inFlight;

    // create in-flight
    final future = getPostMedia(postId)
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            // ✅ Avoid "forever loading"
            return <PostMedia>[];
          },
        )
        .then((items) {
          _postMediaCache[postId] = items;
          return items;
        })
        .catchError((_) {
          // ✅ Avoid "forever loading"
          return <PostMedia>[];
        })
        .whenComplete(() {
          _postMediaInFlight.remove(postId);
        });

    _postMediaInFlight[postId] = future;
    return future;
  }

  /* ==================== BOOKMARKS ==================== */

  final Set<String> _bookmarkedPostIds = {};
  final Set<String> _bookmarkedAyahKeys = {};

  /// ✅ IDs only (fast lookup for icons)
  Set<String> get bookmarkedPostIds => _bookmarkedPostIds;

  /// ✅ Ayah keys only (fast lookup for icons)
  Set<String> get bookmarkedAyahKeys => _bookmarkedAyahKeys;

  bool isPostBookmarkedByCurrentUser(String postId) =>
      _bookmarkedPostIds.contains(postId);

  bool isAyahBookmarkedByCurrentUser(String ayahKey) =>
      _bookmarkedAyahKeys.contains(ayahKey);

  List<Post> get bookmarkedPosts {
    final idSet = _bookmarkedPostIds;
    return _posts.where((p) => idSet.contains(p.id)).toList();
  }

  Future<void> loadBookmarks({bool notify = true}) async {
    try {
      final rows = await _db.getBookmarksFromDatabase();

      _bookmarkedPostIds.clear();
      _bookmarkedAyahKeys.clear();

      for (final row in rows) {
        final type = row['item_type']?.toString();
        final id = row['item_id']?.toString();
        if (type == null || id == null) continue;

        if (type == 'post') _bookmarkedPostIds.add(id);
        if (type == 'ayah') _bookmarkedAyahKeys.add(id);
      }

      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    }
  }

  Future<void> toggleBookmark({
    required String itemType, // 'post' or 'ayah'
    required String itemId,
  }) async {
    // snapshot for rollback
    final oldPosts = Set<String>.from(_bookmarkedPostIds);
    final oldAyahs = Set<String>.from(_bookmarkedAyahKeys);

    // optimistic update
    if (itemType == 'post') {
      if (_bookmarkedPostIds.contains(itemId)) {
        _bookmarkedPostIds.remove(itemId);
      } else {
        _bookmarkedPostIds.add(itemId);
      }
    } else if (itemType == 'ayah') {
      if (_bookmarkedAyahKeys.contains(itemId)) {
        _bookmarkedAyahKeys.remove(itemId);
      } else {
        _bookmarkedAyahKeys.add(itemId);
      }
    }

    notifyListeners();

    try {
      await _db.toggleBookmarkInDatabase(itemType: itemType, itemId: itemId);
    } catch (e) {
      // rollback
      _bookmarkedPostIds
        ..clear()
        ..addAll(oldPosts);
      _bookmarkedAyahKeys
        ..clear()
        ..addAll(oldAyahs);

      notifyListeners();
    }
  }

  /* ==================== LIKES + COMMENTS COUNTS (SAME PATTERN) ==================== */

  Map<String, int> _likeCounts = {};
  Map<String, int> _commentCounts = {};
  List<String> _likedPosts = [];

  bool isPostLikedByCurrentUser(String postId) => _likedPosts.contains(postId);

  int getLikeCount(String postId) => _likeCounts[postId] ?? 0;

  int getCommentCount(String postId) => _commentCounts[postId] ?? 0;

  /// Initialize count maps locally from `_posts`
  void initializeCountMaps() {
    _likeCounts.clear();
    _commentCounts.clear();

    for (final post in _posts) {
      if (post.id.isNotEmpty) {
        _likeCounts[post.id] = post.likeCount;
        _commentCounts[post.id] = post.commentCount;
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

  /* ==================== FOR YOU LIKES MAP ==================== */

  Map<String, Set<String>> _likesByPostId = {};

  Map<String, Set<String>> get likesByPostId => _likesByPostId;

  Future<void> loadLikesForForYou(
    List<String> postIds, {
    bool notify = true,
  }) async {
    if (postIds.isEmpty) {
      _likesByPostId = {};
      if (notify) notifyListeners();
      return;
    }

    try {
      final relevantUserIds = <String>{...followingUserIds, ...friendUserIds};

      if (relevantUserIds.isEmpty) {
        _likesByPostId = {};
        if (notify) notifyListeners();
        return;
      }

      _likesByPostId = await _db.getLikesByPostIdsForUsersFromDatabase(
        postIds: postIds,
        userIds: relevantUserIds.toList(),
      );

      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('Error loading likes map for For You: $e');
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
    final text = message.trim();
    if (text.isEmpty) return;

    // ✅ instant UI update (same as likes pattern)
    _bumpPostCommentCount(postId, 1);

    try {
      await _db.addCommentInDatabase(postId, text);
      await loadComments(postId); // for post page
    } catch (e) {
      debugPrint('Error adding comment: $e');

      // rollback
      _bumpPostCommentCount(postId, -1);
      rethrow;
    }
  }

  Future<void> replyToComment({
    required String postId,
    required String replyText,
    required String parentCommentId,
    required String parentCommentUserId,
    required String parentCommentUsername,
  }) async {
    final text = replyText.trim();
    if (text.isEmpty) return;

    _bumpPostCommentCount(postId, 1);

    try {
      await _db.replyToCommentInDatabase(
        postId: postId,
        replyText: text,
        parentCommentId: parentCommentId,
        parentCommentUserId: parentCommentUserId,
        parentCommentUsername: parentCommentUsername,
      );

      await loadComments(postId);
    } catch (e) {
      debugPrint('Error replying to comment: $e');
      _bumpPostCommentCount(postId, -1);
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId, String postId) async {
    _bumpPostCommentCount(postId, -1);

    try {
      await _db.deleteCommentFromDatabase(commentId);
      await loadComments(postId);
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      _bumpPostCommentCount(postId, 1); // rollback
      rethrow;
    }
  }

  void _bumpPostCommentCount(String postId, int delta) {
    // provider map (same pattern as likes)
    final current = _commentCounts[postId] ?? 0;
    _commentCounts[postId] = (current + delta).clamp(0, 1 << 30);

    // also keep Post objects in sync (optional but nice for deep-linked PostPage)
    bool changed = false;

    final i = _posts.indexWhere((p) => p.id == postId);
    if (i != -1) {
      final currentPost = _posts[i];
      _posts[i] = currentPost.copyWith(
        commentCount: (_commentCounts[postId] ?? currentPost.commentCount),
      );
      changed = true;
    }

    final j = _followingPosts.indexWhere((p) => p.id == postId);
    if (j != -1) {
      final currentPost = _followingPosts[j];
      _followingPosts[j] = currentPost.copyWith(
        commentCount: (_commentCounts[postId] ?? currentPost.commentCount),
      );
      changed = true;
    }

    // Always notify (count changed even if post list didn't contain it)
    notifyListeners();
  }

  /* ==================== BLOCKED USERS ==================== */

  List<UserProfile> _blockedUsers = [];

  List<UserProfile> get blockedUsers => _blockedUsers;

  Future<void> loadBlockedUsers() async {
    final blockedIds = await _db.getBlockedUserIdsFromDatabase();

    final profiles = await Future.wait(
      blockedIds.map((id) => _db.getUserFromDatabase(id)),
    );

    _blockedUsers = profiles.whereType<UserProfile>().toList();

    notifyListeners();
  }

  Future<void> blockUser(String userId) async {
    final currentUserId = _auth.getCurrentUserId();
    if (currentUserId.isEmpty) return;

    try {
      await _db.blockUserInDatabase(userId);

      // ✅ also remove from friends
      await _db.unfriendUserInDatabase(userId);

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

  Future<bool> isViewerBlockedByUser({
    required String profileOwnerId,
    required String viewerId,
  }) async {
    return _db.isViewerBlockedByUserInDatabase(
      profileOwnerId: profileOwnerId,
      viewerId: viewerId,
    );
  }



  Future<void> reportUser(String postId, String userId) async {
    await _db.reportUserInDatabase(postId, userId);
  }

  Future<void> reportUserFromChat(String reportedUserId) async {
    await _db.reportUserFromChatInDatabase(reportedUserId);
  }


  /* ==================== FRIENDS ==================== */

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

  // You referenced this in the code snippet above; you already have the service method.
  Future<String> getFriendshipStatus(String otherUserId) =>
      _db.getFriendshipStatusFromDatabase(otherUserId);

  /// True if we are "connected" (friends OR mahram).
  /// Used by ChatPage to decide if chat actions are allowed.
  Future<bool> areWeConnected(String otherUserId) async {
    return _db.areWeConnectedInDatabase(otherUserId);
  }


  /* ==================== FRIEND IDS (For You ranking) ==================== */

  Set<String> _friendIds = {};

  Set<String> get friendUserIds => _friendIds;

  Future<void> loadFriendIds({bool notify = true}) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    try {
      final ids = await _db.getFriendIdsFromDatabase(uid);
      _friendIds = ids.toSet();

      // ✅ IMPORTANT: friends changed -> FOAF cache must be recomputed later
      _friendsOfFriendsIds = {};

      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('Error loading friend ids: $e');
    }
  }

  Future<Set<String>> getCommunityMemberIds(String communityId) {
    return _db.getCommunityMemberIdsFromDatabase(communityId);
  }

  Future<Set<String>> getPendingCommunityInviteIds(String communityId) {
    return _db.getPendingCommunityInviteIdsFromDatabase(communityId);
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
      _followerCount[targetUserId] = ((_followerCount[targetUserId] ?? 0) + 1);

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
      _followerCount[targetUserId] = (_followerCount[targetUserId] ?? 0) - 1;

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
      _followerCount[targetUserId] = (_followerCount[targetUserId] ?? 1) - 1;

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
      _followerCount[targetUserId] = ((_followerCount[targetUserId] ?? 0) + 1);

      _following[currentUserId]?.add(targetUserId);
      _followingCount[currentUserId] =
          ((_followingCount[currentUserId] ?? 0) + 1);

      notifyListeners();
    }
  }

  bool isFollowing(String userId) {
    final currentUserId = _auth.getCurrentUserId();
    if (currentUserId.isEmpty) return false;

    // ✅ FIX: following means "I follow them"
    return (_following[currentUserId] ?? const <String>[]).contains(userId);
  }

  /// ✅ Current user's following IDs (cached)
  Set<String> get followingUserIds {
    final uid = currentUserId;
    return (_following[uid] ?? const <String>[]).toSet();
  }

  /* ==================== MAHRAM ==================== */

  // ✅ MAHRAM FLOW (Provider wrappers)

  Future<void> sendMahramRequest(String targetUserId) async {
    await _db.sendMahramRequestInDatabase(targetUserId);
  }

  Future<void> cancelMahramRequest(String otherUserId) async {
    await _db.cancelMahramRequestInDatabase(otherUserId);
  }

  Future<void> acceptMahramRequest(String otherUserId) async {
    await _db.acceptMahramRequestInDatabase(otherUserId);
  }

  Future<void> declineMahramRequest(String otherUserId) async {
    await _db.declineMahramRequestInDatabase(otherUserId);
  }

  Future<void> deleteMahramRelationship(String otherUserId) async {
    await _db.deleteMahramRelationshipInDatabase(otherUserId);
  }

  Future<List<UserProfile>> getMyMahrams() => _db.getMyMahramsInDatabase();

  // =========================================================
  // MARRIAGE INQUIRIES (DatabaseProvider)
  // =========================================================

  Future<String> createMarriageInquiry({
    required String manId,
    required String womanId,
    String? mahramId,
    String initiatedBy = 'man', // 'man' or 'woman'
  }) async {
    return _db.createMarriageInquiryInDatabase(
      manId: manId,
      womanId: womanId,
      mahramId: mahramId,
      initiatedBy: initiatedBy,
    );
  }

  /// FLOW 1 ONLY (initiated_by=man):
  /// Woman declines the inquiry.
  Future<void> womanDeclineInquiry({required String inquiryId}) async {
    await _db.womanDeclineInquiryInDatabase(inquiryId: inquiryId);
  }

  /// FLOW 1 ONLY (initiated_by=man):
  /// Woman accepts AND selects mahram (single step).
  Future<void> womanAcceptAndSelectMahramForInquiry({
    required String inquiryId,
    required String mahramId,
  }) async {
    await _db.womanAcceptAndSelectMahramForInquiryInDatabase(
      inquiryId: inquiryId,
      mahramId: mahramId,
    );
  }

  /// BOTH FLOWS:
  /// Mahram approves/declines.
  Future<void> mahramRespondToInquiry({
    required String inquiryId,
    required bool approve,
  }) async {
    await _db.mahramRespondToInquiryInDatabase(
      inquiryId: inquiryId,
      approve: approve,
    );
  }

  /// FLOW 2 ONLY (initiated_by=woman):
  /// Man accepts/declines after mahram approval.
  Future<void> manRespondToInquiry({
    required String inquiryId,
    required bool accept,
  }) async {
    await _db.manRespondToInquiryInDatabase(
      inquiryId: inquiryId,
      accept: accept,
    );
  }

  /// Used by ProfilePage combined relationship status (button state override)
  Future<Map<String, dynamic>?> getLatestActiveInquiryBetweenMeAnd(
    String otherUserId,
  ) async {
    return _db.getLatestActiveInquiryBetweenMeAnd(otherUserId);
  }

  /// Used by ProfilePage combined relationship status (button state override)
  String? computeInquiryUiStatus({
    required Map<String, dynamic> inquiry,
    required String viewerId,
    required String otherUserId,
  }) {
    return _db.computeInquiryUiStatus(
      inquiry: inquiry,
      viewerId: viewerId,
      otherUserId: otherUserId,
    );
  }

  Future<String> getCombinedRelationshipStatus(String otherUserId) async {
    return _db.getCombinedRelationshipStatus(otherUserId);
  }

  Future<void> cancelOrEndMarriageInquiry({required String inquiryId}) async {
    await _db.cancelOrEndMarriageInquiryInDatabase(inquiryId: inquiryId);
  }

  Future<Map<String, dynamic>?> getInquiryById(String inquiryId) =>
      _db.getInquiryByIdInDatabase(inquiryId);

  /* ==================== SEARCH USERS ==================== */

  List<UserProfile> _searchResults = [];

  List<UserProfile> get searchResults => _searchResults;

  /// ✅ Cache friends-of-friends (2nd degree) so we can rank them higher
  Set<String> _friendsOfFriendsIds = {};

  Set<String> get friendsOfFriendsIds => _friendsOfFriendsIds;

  Future<void> _ensureFriendsOfFriendsLoaded() async {
    try {
      final currentUserId = _auth.getCurrentUserId();
      if (currentUserId.isEmpty) return;

      if (friendUserIds.isEmpty) {
        _friendsOfFriendsIds = {};
        return;
      }

      _friendsOfFriendsIds = await _db.getFriendsOfFriendsIdsFromDatabase(
        userId: currentUserId,
        friendIds: friendUserIds,
      );
    } catch (e) {
      debugPrint('Error loading friends-of-friends: $e');
      _friendsOfFriendsIds = {};
    }
  }

  Future<void> _ensureSearchGraphLoaded() async {
    final uid = _auth.getCurrentUserId();
    if (uid.isEmpty) return;

    try {
      if (friendUserIds.isEmpty) {
        await loadFriendIds();
      }

      if (followingUserIds.isEmpty) {
        await loadUserFollowing(uid);
      }

      if (_friendsOfFriendsIds.isEmpty && friendUserIds.isNotEmpty) {
        await _ensureFriendsOfFriendsLoaded();
      }
    } catch (e) {
      debugPrint('Error ensuring search graph: $e');
    }
  }

  Future<void> searchUsers(String searchTerm) async {
    final query = searchTerm.trim();

    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    try {
      await _ensureSearchGraphLoaded();

      final results = await _db.searchUsersInDatabase(query);
      final currentUserId = _auth.getCurrentUserId();

      final candidates = results.where((u) => u.id != currentUserId).toList();

      _searchResults = UserSearchRanker.rank(
        candidates: candidates,
        currentUserId: currentUserId,
        query: query,
        friendIds: friendUserIds,
        friendsOfFriendsIds: _friendsOfFriendsIds,
        followingIds: followingUserIds,
        limit: 60,
      );

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
      if (userId.isNotEmpty) {
        // 1 query to get ONLY my memberships
        final myMemberships = await _db.getMyCommunityMembershipsFromDatabase();

        final joinedIds = myMemberships
            .map((r) => r['community_id']?.toString())
            .whereType<String>()
            .toSet();

        for (final community in _allCommunities) {
          final id = community['id']?.toString();
          community['is_joined'] = id != null && joinedIds.contains(id);
        }
      }
    }

    notifyListeners();
  }

  void addCommunityLocally(Map<String, dynamic> community) {
    _allCommunities.add(community);
    notifyListeners();
  }

  Future<void> createCommunity(
    String name,
    String desc,
    String country, {
    bool isPrivate = false,
  }) async {
    final created = await _db.createCommunityInDatabase(
      name,
      desc,
      country,
      isPrivate: isPrivate,
    );

    if (created != null) {
      // Optimistic: show instantly as joined
      created['is_joined'] = true;
      _allCommunities.insert(0, created);
      notifyListeners();
    }

    // Single refresh for server truth
    await getAllCommunities();
  }

  Future<bool> isMember(String communityId) async {
    return await _db.isMemberInDatabase(communityId);
  }


  Future<void> joinCommunity(String communityId) async {
    final id = communityId.trim();
    if (id.isEmpty) return;

    Map<String, dynamic>? community;
    try {
      community = _allCommunities.firstWhere((c) => c['id'] == id);
    } catch (_) {
      community = null;
    }

    // Optimistic UI
    if (community != null) {
      community['is_joined'] = true;
      notifyListeners();
    }

    try {
      await _db.joinCommunityInDatabase(
        communityId: communityId,
        isPrivate: (community?['is_private'] == true),
      );
      await getAllCommunities();
    } catch (e) {
      // Revert optimistic
      if (community != null) {
        community['is_joined'] = false;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> leaveCommunity(String communityId) async {
    await _db.leaveCommunityInDatabase(communityId);

    // refresh community lists / membership flags
    await getAllCommunities();
    notifyListeners();
  }


  Future<void> searchCommunities(String query) async {
    final q = query.trim();

    if (q.isEmpty) {
      _communitySearchResults = [];
      notifyListeners();
      return;
    }

    // Supabase ILIKE is already case-insensitive
    _communitySearchResults = await _db.searchCommunitiesInDatabase(q);

    notifyListeners();
  }

  void clearCommunitySearchResults() {
    _communitySearchResults.clear();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getCommunityMemberProfiles(
    String communityId,
  ) async {
    return await _db.getCommunityMemberProfilesFromDatabase(communityId);
  }

  Future<void> inviteUserToCommunity(
    String communityId,
    String invitedUserId,
    String communityName,
    String inviterName, // ✅ NEW
  ) async {
    await _db.inviteUserToCommunityInDatabase(
      communityId,
      invitedUserId,
      communityName,
      inviterName,
    );
    await getAllCommunities();
  }

  Future<void> acceptCommunityInvite(String communityId) async {
    final id = communityId.trim();
    if (id.isEmpty) return;

    await _db.acceptCommunityInviteInDatabase(id);
    await getAllCommunities();
  }

  Future<void> declineCommunityInvite(String communityId) async {
    final id = communityId.trim();
    if (id.isEmpty) return;

    await _db.declineCommunityInviteInDatabase(id);
    await getAllCommunities();
  }

  Future<bool> hasPendingCommunityInvite(String communityId) async {
    return await _db.hasPendingCommunityInviteInDatabase(communityId);
  }

  Future<Map<String, dynamic>?> getCommunityById(String communityId) async {
    return await _db.getCommunityByIdFromDatabase(communityId);
  }


  Future<void> deleteCommunity(String communityId) async {
    await _db.deleteCommunityInDatabase(communityId);

    // instant local update
    _allCommunities.removeWhere((c) => c['id']?.toString() == communityId);
    notifyListeners();
  }

  Future<String> updateCommunityAvatar({
    required String communityId,
    required String filePath,
  }) async {
    final url = await _db.updateCommunityAvatarInDatabase(
      communityId: communityId,
      filePath: filePath,
    );

    // ✅ refresh so CommunitiesPage shows it too
    await getAllCommunities();

    return url;
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
    String storyId,
    List<int?> selectedIndices,
  ) async {
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

  /* ==================== PRIVATE REFLECTIONS ==================== */

  List<PrivateReflection> _privateReflections = [];

  List<PrivateReflection> get privateReflections => _privateReflections;

  Future<void> loadPrivateReflections() async {
    try {
      final rows = await _db.getMyPrivateReflectionsFromDatabase();
      _privateReflections = rows
          .map((r) => PrivateReflection.fromMap(r))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading private reflections (provider): $e');
    }
  }

  Future<void> addPrivateReflection({
    required String text,
    String? postId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      await _db.addPrivateReflectionInDatabase(text: trimmed, postId: postId);

      await loadPrivateReflections();
    } catch (e) {
      debugPrint('Error adding private reflection (provider): $e');
    }
  }

  Future<void> deletePrivateReflection(String reflectionId) async {
    try {
      await _db.deletePrivateReflectionFromDatabase(reflectionId);

      _privateReflections.removeWhere((r) => r.id == reflectionId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting private reflection (provider): $e');
    }
  }

  /* ==================== LOG OUT ==================== */

  void clearAllCachedData() {
    // Posts
    _posts.clear();
    _followingPosts.clear();
    _loadingPost = null;

    // Likes + comment counts
    _likeCounts.clear();
    _commentCounts.clear();
    _likedPosts.clear();

    // ✅ Bookmarks (important so Saved tab doesn't show old user's saved posts)
    _bookmarkedPostIds.clear();
    _bookmarkedAyahKeys.clear();

    // Comments
    _comments.clear();

    // Followers / Following
    _followers.clear();
    _following.clear();
    _followerCount.clear();
    _followingCount.clear();
    _followerProfiles.clear();
    _followingProfiles.clear();

    // Friends / FOAF cache
    _friendIds.clear();
    _friendsOfFriendsIds.clear();

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

  // =====================
// Feedback
// =====================
  Future<void> submitFeedback({
    required String userId,
    required String message,
    String category = 'general',
    String? appVersion,
    String? device,
  }) async {
    await _db.submitFeedbackInDatabase(
      userId: userId,
      message: message,
      category: category,
      appVersion: appVersion,
      device: device,
    );
  }

  // DatabaseProvider
  String _profileVisibility = 'everyone';
  String get profileVisibility => _profileVisibility;

  Future<void> hydrateMyProfileVisibility() async {
    final uid = AuthService().getCurrentUserId();
    final me = await getUserProfile(uid);

    // default to everyone if missing
    _profileVisibility = (me?.profileVisibility ?? 'everyone')
        .trim()
        .toLowerCase();

    if (_profileVisibility.isEmpty) _profileVisibility = 'everyone';

    notifyListeners();
  }

  Future<void> setProfileVisibility({required String visibility}) async {
    final prev = _profileVisibility;

    final v = visibility.trim().toLowerCase();
    if (v != 'everyone' && v != 'friends' && v != 'nobody') {
      throw Exception('Invalid profile_visibility: $visibility');
    }

    _profileVisibility = v; // optimistic
    notifyListeners();

    try {
      await _db.setProfileVisibilityInDatabase(visibility: v);

      // refresh my cached profile if you cache it
      final uid = AuthService().getCurrentUserId();
      await getUserProfile(uid);
      notifyListeners();
    } catch (_) {
      _profileVisibility = prev; // rollback
      notifyListeners();
      rethrow;
    }
  }

}
