// lib/services/database/database_service.dart

/*

DATABASE SERVICE

This class handles all the data from and to supabase

--------------------------------------------------------------------------------

- User Profile
- Post message
- Likes
- Comments
- Account stuff (report / block / delete account)
- Follow / unfollow
- Search users

 */

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:ummah_chat/services/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/comment.dart';
import '../../models/dua.dart';
import '../../models/post.dart';
import '../../models/user_profile.dart';
import '../notifications/notification_service.dart';
import 'dart:typed_data';
import '../chat/chat_service.dart';


// 🆕 Notifications

class DatabaseService {
  // get instance of supabase
  final _db = Supabase.instance.client;
  final _auth = Supabase.instance.client.auth;
  late final _storage = _db.storage;

  // 🆕 Notification service (used to create in-app notifications)
  final NotificationService _notifications = NotificationService();

  /* ==================== USER PROFILE ==================== */

  /// 🆕 Update core profile info after CompleteProfilePage:
  /// name, country, gender – and CREATE row if it doesn't exist.
  Future<void> updateUserCoreProfileInDatabase({
    required String name,
    required String country,
    required String gender, // 'male' or 'female'
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No logged-in user');
    }

    final email = currentUser.email ?? '';
    String username = email.split('@').first.trim();
    if (username.isEmpty) {
      username = 'user_${currentUser.id.substring(0, 8)}';
    }

    try {
      await _db.from('profiles').upsert({
        'id': currentUser.id,
        'name': name,
        'email': email,
        'username': username,
        'country': country,
        'gender': gender,
        // if the row is new we set created_at now, if existing it can be ignored/overwritten
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e, st) {
      print("Error updating core profile info: $e\n$st");
      rethrow;
    }
  }

  /// Check if the current user's profile is completed
  Future<bool> isProfileCompleted() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final data = await _db
          .from('profiles')
          .select('country, gender')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        // No row yet = not completed
        return false;
      }

      final country = (data['country'] ?? '').toString().trim();
      final gender = (data['gender'] ?? '').toString().trim();

      // ✅ profile is "complete" if both are filled
      return country.isNotEmpty && gender.isNotEmpty;
    } catch (e) {
      print('Error checking profile completion: $e');
      // On error, be safe and treat as incomplete
      return false;
    }
  }

  /// Get user from database
  Future<UserProfile?> getUserFromDatabase(String userId) async {
    try {
      final userData = await _db
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (userData == null) return null;

      return UserProfile.fromMap(userData);
    } catch (e) {
      print("Error fetching user: $e");
      return null;
    }
  }

  Future<String?> uploadProfilePhotoToDatabase(
    Uint8List bytes,
    String userId,
  ) async {
    try {
      final filePath = '$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';

      final response = await _db.storage
          .from('profile_photos')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      if (response != null) {
        final url = _db.storage.from('profile_photos').getPublicUrl(filePath);
        print('✅ Profile photo URL: $url');
        return url;
      }
    } catch (e) {
      print("Error uploading profile picture: $e");
    }
    return null;
  }

  Future<void> updateUserProfilePhotoInDatabase(String url) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _db
          .from('profiles')
          .update({'profile_photo_url': url})
          .eq('id', userId);
    } catch (e) {
      print("Error updating profile picture in DB: $e");
    }
  }

  /// Update user bio
  Future<void> updateUserBioInDatabase(String bio) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await _db.from('profiles').update({'bio': bio}).eq('id', currentUserId);
    } catch (e) {
      print("Error updating bio: $e");
    }
  }

  /// Update the About Me section (city + languages + interests)
  Future<void> updateUserAboutMeInDatabase({
    required String? city,
    required List<String> languages,
    required List<String> interests,
  }) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      await _db
          .from('profiles')
          .update({
            'city': city,
            'languages': languages,
            'interests': interests,
          })
          .eq('id', currentUserId);
    } catch (e) {
      print("Error updating About Me: $e");
    }
  }

  /* ==================== POSTS ==================== */

  /// Get all posts
  ///
  /// This returns both:
  /// - global posts (`community_id IS NULL`)
  /// - community posts (`community_id IS NOT NULL`)
  /// and your UI decides how to filter them.
  Future<List<Post>> getAllPostsFromDatabase() async {
    try {
      final List data =
          await _db
                  // Go to collection "posts"
                  .from('posts')
                  // Select all fields
                  .select()
                  // Chronological order
                  .order('created_at', ascending: false)
              as List;

      // Return as list of posts
      return data.map((e) => Post.fromMap(e)).toList();
    } catch (e) {
      print("Error fetching all posts: $e");
      return [];
    }
  }

  Future<Post?> getPostByIdFromDatabase(String postId) async {
    try {
      final data = await _db
          .from('posts')
          .select()
          .eq('id', postId)
          .maybeSingle();

      if (data == null) return null;
      return Post.fromMap(data);
    } catch (e) {
      print("Error fetching post by id $postId: $e");
      return null;
    }
  }

  Future<void> postMultiMediaMessageInDatabase(
    String message, {
    required List<File> imageFiles,
    required List<File> videoFiles,
    String? communityId,
  }) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    // get profile for denormalized name/username (same as postMessageInDatabase)
    final user = await getUserFromDatabase(userId);
    if (user == null) {
      throw Exception('User profile not found');
    }

    // 1️⃣ Create main post row first (without cover URLs)
    final postInsert = await _db
        .from('posts')
        .insert({
          'user_id': userId,
          'name': user.name,
          'username': user.username,
          'message': message,
          'community_id': communityId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'like_count': 0,
        })
        .select()
        .single();

    final String postId = postInsert['id'].toString();

    // 2️⃣ Upload media files to 'post_media' bucket and prepare rows for post_media table
    final List<Map<String, dynamic>> mediaRows = [];

    String? firstImageUrl;
    String? firstVideoUrl;

    Future<void> uploadFile(File file, String type, int orderIndex) async {
      final ext = file.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${type}.$ext';

      final storagePath = '$postId/$fileName';

      // 👇 uses your new "post_media" bucket
      await _storage.from('post_media').upload(storagePath, file);

      final publicUrl = _storage.from('post_media').getPublicUrl(storagePath);

      mediaRows.add({
        'post_id': postId,
        'type': type, // 'image' or 'video'
        'url': publicUrl,
        'order_index': orderIndex,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (type == 'image' && firstImageUrl == null) {
        firstImageUrl = publicUrl;
      }
      if (type == 'video' && firstVideoUrl == null) {
        firstVideoUrl = publicUrl;
      }
    }

    int index = 0;
    for (final img in imageFiles) {
      await uploadFile(img, 'image', index++);
    }
    for (final vid in videoFiles) {
      await uploadFile(vid, 'video', index++);
    }

    // 3️⃣ Insert all media rows into post_media
    if (mediaRows.isNotEmpty) {
      await _db.from('post_media').insert(mediaRows);
    }

    // ✅ No more image_url / video_url updates on posts
    debugPrint(
      '✅ postMultiMediaMessageInDatabase done for $postId | '
      'images=${imageFiles.length}, videos=${videoFiles.length}',
    );
  }

  Future<List<Map<String, dynamic>>> getPostMediaFromDatabase(
    String postId,
  ) async {
    final res = await _db
        .from('post_media')
        .select()
        .eq('post_id', postId)
        .order('order_index', ascending: true)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Delete a post + all its media
  Future<void> deletePostFromDatabase(String postId) async {
    try {
      // 1️⃣ Fetch media urls for this post
      final mediaRows = await _db
          .from('post_media')
          .select('url')
          .eq('post_id', postId);

      // 2️⃣ Delete storage objects
      if (mediaRows is List && mediaRows.isNotEmpty) {
        final pathsToDelete = <String>[];

        for (final row in mediaRows) {
          final url = row['url']?.toString();
          if (url == null || url.isEmpty) continue;

          final path = _extractStoragePathFromPublicUrl(
            publicUrl: url,
            bucketName: 'post_media',
          );

          if (path != null && path.isNotEmpty) {
            pathsToDelete.add(path);
          }
        }

        if (pathsToDelete.isNotEmpty) {
          await _storage.from('post_media').remove(pathsToDelete);
          debugPrint(
            '🗑 Deleted ${pathsToDelete.length} media files from post_media',
          );
        }
      }

      // 3️⃣ Delete DB rows (order depends on your FK setup)
      // If you have ON DELETE CASCADE on post_media.post_id -> posts.id,
      // you can skip deleting post_media rows manually.
      await _db.from('post_media').delete().eq('post_id', postId);

      // 4️⃣ Delete the post itself
      final res = await _db.from('posts').delete().eq('id', postId);

      debugPrint('✅ Post deleted from database: $postId | res=$res');
    } catch (e, st) {
      debugPrint("❌ Error deleting post (or media): $e\n$st");
      rethrow; // ✅ IMPORTANT: let the UI/provider know it failed
    }
  }

  /// Extract storage path from a Supabase public URL.
  /// Returns something like: "userId/postId/file.jpg"
  String? _extractStoragePathFromPublicUrl({
    required String publicUrl,
    required String bucketName,
  }) {
    try {
      final uri = Uri.parse(publicUrl);

      // Typical public URL format:
      // .../storage/v1/object/public/<bucket>/<path>
      final segments = uri.pathSegments;

      final bucketIndex = segments.indexOf(bucketName);
      if (bucketIndex == -1) return null;

      if (bucketIndex + 1 >= segments.length) return null;

      return segments.sublist(bucketIndex + 1).join('/');
    } catch (_) {
      return null;
    }
  }

  //* ==================== LIKES ==================== */

  /// Toggle like for a post
  ///
  /// We now let the database trigger keep `like_count` in sync based
  /// on rows in `post_likes`. Here we only insert/delete the like row
  /// and (optionally) create notifications.
  Future<void> toggleLikeInDatabase(String postId) async {
    try {
      final currentUserId = _auth.currentUser!.id;

      // 1️⃣ Get the post owner + message (for notifications)
      final postData = await _db
          .from('posts')
          .select('id, user_id, message')
          .eq('id', postId)
          .maybeSingle();

      if (postData == null) {
        print("⚠️ Post not found for id: $postId");
        return;
      }

      final postOwnerId = postData['user_id']?.toString() ?? '';

      // 2️⃣ Check if the user already liked this post
      final existingLike = await _db
          .from('post_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', currentUserId)
          .maybeSingle();

      final isCurrentlyLiked = existingLike != null;
      final isLikingNow = !isCurrentlyLiked;

      // 3️⃣ Insert / delete from post_likes
      if (isLikingNow) {
        // Like
        await _db.from('post_likes').insert({
          'post_id': postId,
          'user_id': currentUserId,
        });
      } else {
        // Unlike
        await _db
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', currentUserId);
      }

      // ⚠️ IMPORTANT:
      // We do NOT manually update `posts.like_count` here anymore.
      // The database trigger `update_post_like_count()` will update
      // the `like_count` for us whenever post_likes changes.

      // 4️⃣ Only when it's a new like (not unlike) → create notification
      if (isLikingNow &&
          postOwnerId.isNotEmpty &&
          postOwnerId != currentUserId) {
        try {
          final likerProfile = await getUserFromDatabase(currentUserId);

          final displayName = (likerProfile?.username.isNotEmpty ?? false)
              ? likerProfile!.username
              : (likerProfile?.name ?? 'Someone');

          final postPreview = (postData['message']?.toString() ?? '').trim();
          final truncatedPreview = postPreview.length > 50
              ? '${postPreview.substring(0, 50)}...'
              : postPreview;

          final rawPreview = postPreview.isEmpty ? '' : truncatedPreview;

          // Machine-readable + human preview (NotificationPage parsing stays same)
          final body = 'LIKE_POST:$postId::$rawPreview';

          await _notifications.createNotificationForUser(
            targetUserId: postOwnerId,
            title: '$displayName liked your post', // fallback for in-app list
            body: body,
            data: {
              'type': 'LIKE_POST',
              'fromUserId': currentUserId,
              'senderName': displayName,
              'postId': postId,
            },
          );
        } catch (e) {
          print('⚠️ Error creating like notification: $e');
        }
      }
    } catch (e) {
      print("❌ Error toggling like: $e");
    }
  }

  /// EXTRA /// for when I use post_likes
  Future<List<String>> getLikedPostIdsFromDatabase(
    String userId,
    List<String> postIds,
  ) async {
    final likedPostIds = <String>[];
    if (postIds.isEmpty) return likedPostIds;

    try {
      final res = await _db
          .from('post_likes')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);

      if (res != null && res is List) {
        for (final row in res) {
          if (row['post_id'] != null) {
            likedPostIds.add(row['post_id'].toString());
          }
        }
      }
    } catch (e) {
      print("Error fetching liked posts: $e");
    }

    return likedPostIds;
  }

  /// ✅ Get likes for a set of posts, but only from specific users (friends/following).
  /// Returns: { postId: { userId1, userId2, ... } }
  Future<Map<String, Set<String>>> getLikesByPostIdsForUsersFromDatabase({
    required List<String> postIds,
    required List<String> userIds,
  }) async {
    final map = <String, Set<String>>{};
    if (postIds.isEmpty || userIds.isEmpty) return map;

    try {
      final res = await _db
          .from('post_likes')
          .select('post_id, user_id')
          .inFilter('post_id', postIds)
          .inFilter('user_id', userIds);

      if (res is! List) return map;

      for (final row in res) {
        final postId = row['post_id']?.toString();
        final userId = row['user_id']?.toString();
        if (postId == null || userId == null) continue;

        map.putIfAbsent(postId, () => <String>{}).add(userId);
      }

      return map;
    } catch (e, st) {
      debugPrint('❌ Error getLikesByPostIdsForUsersFromDatabase: $e\n$st');
      return map;
    }
  }

  //* ==================== COMMENTS ==================== */

  /// Add comment to a post
  ///
  /// 🆕 Also sends a notification to the post owner when someone comments.
  Future<void> addCommentInDatabase(String postId, message) async {
    try {
      // get current user
      final currentUserId = _auth.currentUser!.id;

      UserProfile? user = await getUserFromDatabase(currentUserId);
      if (user == null) throw Exception("User profile not found");

      // 🔍 Get post owner so we can notify them
      final postData = await _db
          .from('posts')
          .select('user_id, message')
          .eq('id', postId)
          .maybeSingle();

      final postOwnerId = postData?['user_id']?.toString() ?? '';

      // create a new comment
      Comment newComment = Comment(
        id: '',
        postId: postId,
        userId: currentUserId,
        name: user.name,
        username: user.username,
        message: message,
        createdAt: DateTime.now().toUtc(),
      );

      // convert comment to a map
      Map<String, dynamic> newCommentMap = newComment.toMap();

      // store in Database
      await _db.from('comments').insert(newCommentMap).select().single();

      // 🆕 Create notification for post owner (if not commenting on own post)
      if (postOwnerId.isNotEmpty && postOwnerId != currentUserId) {
        try {
          final displayName = user.username.isNotEmpty
              ? user.username
              : user.name;

          final postPreview = (postData?['message']?.toString() ?? '').trim();
          final truncatedPostPreview = postPreview.length > 50
              ? '${postPreview.substring(0, 50)}...'
              : postPreview;

          final body = 'COMMENT_POST:$postId::$truncatedPostPreview';

          await _notifications.createNotificationForUser(
            targetUserId: postOwnerId,
            title: '$displayName commented on your post', // fallback
            body: body,
            data: {
              'type': 'COMMENT_POST',
              'fromUserId': currentUserId,
              'senderName': displayName,
              'postId': postId,
            },
          );
        } catch (e) {
          print('⚠️ Error creating comment notification: $e');
        }
      }
    } catch (e) {
      print("Error adding comment: $e");
    }
  }

  /// Reply to a specific comment (stores as a normal comment on the post)
  /// and notifies the original commenter.
  ///
  /// ✅ Keeps notification logic inside DatabaseService (not UI).
  Future<void> replyToCommentInDatabase({
    required String postId,
    required String replyText,
    required String parentCommentId,
    required String parentCommentUserId,
    required String parentCommentUsername,
  }) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    final text = replyText.trim();
    if (text.isEmpty) return;

    try {
      // 1) Save reply as a normal comment (same as you currently do in UI)
      // This will ALSO trigger COMMENT_POST notification to the post owner
      // (because your addCommentInDatabase does that).
      await addCommentInDatabase(postId, text);

      // 2) Notify the user who wrote the original comment (not yourself)
      if (parentCommentUserId != currentUserId) {
        final me = await getUserFromDatabase(currentUserId);

        // Name for push/title consistency (username > name > Someone)
        final displayName = (me?.username.isNotEmpty ?? false)
            ? me!.username
            : (me?.name ?? 'Someone');

        final preview = text.length > 80 ? '${text.substring(0, 80)}…' : text;

        // BODY FORMAT (what your NotificationPage parses):
        // COMMENT_REPLY:<postId>::<commentId>::<preview>
        // (keep :: delimiter consistent)
        final body = 'COMMENT_REPLY:$postId::${parentCommentId}::$preview';

        await _notifications.createNotificationForUser(
          targetUserId: parentCommentUserId,
          title: '$displayName replied to your comment',
          body: body,
          data: {
            'type': 'COMMENT_REPLY',
            'postId': postId,
            'commentId': parentCommentId,
            'fromUserId': currentUserId,
            'senderName': displayName,
          },
        );
      }
    } catch (e, st) {
      debugPrint('❌ Error replying to comment: $e\n$st');
      rethrow;
    }
  }

  /// Delete comment for a post
  Future<void> deleteCommentFromDatabase(String commentId) async {
    try {
      await _db.from('comments').delete().eq('id', commentId);
    } catch (e) {
      print("Error deleting comment: $e");
    }
  }

  /// Fetch comments for a post
  Future<List<Comment>> getCommentsFromDatabase(String postId) async {
    try {
      final response = await _db
          .from('comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (response as List).map((row) => Comment.fromMap(row)).toList();
    } catch (e) {
      print("Error loading comments: $e");
      return [];
    }
  }

  /* ==================== REPORT / BLOCK ==================== */

  /// Report user in database
  Future<void> reportUserInDatabase(String postId, String userId) async {
    try {
      // Get current user ID from Supabase auth
      final currentUserId = _auth.currentUser!.id;

      // Prepare report data
      final report = {
        'reported_by': currentUserId,
        'message_id': postId,
        'message_owner_id': userId,
        'created_at': DateTime.now()
            .toUtc()
            .toIso8601String(), // Use current timestamp
      };

      // Insert into "reports" table
      await _db.from('reports').insert(report);
    } catch (e) {
      print('Error reporting post: $e');
    }
  }

  /// Block user in database
  Future<void> blockUserInDatabase(String userId) async {
    try {
      final currentUserId = _auth.currentUser!.id;

      // 1️⃣ Insert block row
      await _db.from('blocks').insert({
        'blocker_id': currentUserId,
        'blocked_id': userId,
      });

      // 2️⃣ Clean up mutual likes between the two users
      try {
        await removeLikesBetweenUsers(currentUserId, userId);
      } catch (e) {
        print('⚠️ Error removing mutual likes on block: $e');
      }

      // 3️⃣ Clean up relationship notifications between the two users
      try {
        await _notifications.deleteAllRelationshipNotificationsBetween(
          userAId: currentUserId,
          userBId: userId,
        );
      } catch (e) {
        print('⚠️ Error deleting relationship notifications on block: $e');
      }

      print(
        "✅ User $userId blocked by $currentUserId (likes + notifications cleaned)",
      );
    } catch (e) {
      print("Error blocking user: $e");
    }
  }

  /// Unblock user in database
  Future<void> unblockUserInDatabase(String userId) async {
    try {
      final currentUser = _auth.currentUser!.id;

      await _db
          .from('blocks')
          .delete()
          .eq('blocker_id', currentUser)
          .eq('blocked_id', userId);
    } catch (e) {
      print("Error unblocking user: $e");
    }
  }

  /// Get blocked user from database
  Future<List<String>> getBlockedUserIdsFromDatabase() async {
    try {
      final currentUser = _auth.currentUser!.id;

      final data = await _db
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', currentUser);

      if (data is! List) return [];

      return data
          .map((row) => row['blocked_id']?.toString())
          .whereType<String>()
          .toList();
    } catch (e) {
      print("Error getting blocked users: $e");
      return [];
    }
  }

  /// EXTRA: remove mutual likes when blocking
  Future<void> removeLikesBetweenUsers(
    String currentUserId,
    String blockedUserId,
  ) async {
    // 1️⃣ Get all post IDs by blocked user
    final blockedUserPosts = await _db
        .from('posts')
        .select('id')
        .eq('user_id', blockedUserId);

    final blockedPostIds = (blockedUserPosts as List)
        .map((p) => p['id'] as String)
        .toList();

    // 2️⃣ Get all post IDs by current user
    final currentUserPosts = await _db
        .from('posts')
        .select('id')
        .eq('user_id', currentUserId);

    final currentPostIds = (currentUserPosts as List)
        .map((p) => p['id'] as String)
        .toList();

    // 3️⃣ Remove likes that current user gave to blocked user’s posts
    if (blockedPostIds.isNotEmpty) {
      await _db
          .from('post_likes')
          .delete()
          .inFilter('post_id', blockedPostIds)
          .eq('user_id', currentUserId);
    }

    // 4️⃣ Remove likes that blocked user gave to current user’s posts
    if (currentPostIds.isNotEmpty) {
      await _db
          .from('post_likes')
          .delete()
          .inFilter('post_id', currentPostIds)
          .eq('user_id', blockedUserId);
    }

    // 5️⃣ like_count on posts will be updated automatically by triggers.
  }

  /* ==================== BOOKMARKS ==================== */

  /// Toggle bookmark for an item.
  ///
  /// itemType: 'post' or 'ayah'
  /// itemId:  postId OR ayahKey like "2:255"
  Future<void> toggleBookmarkInDatabase({
    required String itemType,
    required String itemId,
  }) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      final existing = await _db
          .from('bookmarks')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('item_type', itemType)
          .eq('item_id', itemId)
          .maybeSingle();

      if (existing != null) {
        // remove bookmark
        await _db.from('bookmarks').delete().eq('id', existing['id']);
      } else {
        // add bookmark
        await _db.from('bookmarks').insert({
          'user_id': currentUserId,
          'item_type': itemType,
          'item_id': itemId,
        });
      }
    } catch (e, st) {
      debugPrint('❌ Error toggling bookmark: $e\n$st');
      rethrow;
    }
  }

  /// Get all bookmarks for the current user.
  /// Returns rows with: item_type, item_id, created_at
  Future<List<Map<String, dynamic>>> getBookmarksFromDatabase() async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return [];

    try {
      final res = await _db
          .from('bookmarks')
          .select('item_type, item_id, created_at')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(res);
    } catch (e, st) {
      debugPrint('❌ Error loading bookmarks: $e\n$st');
      return [];
    }
  }

  /// Optional helper if you ever want it (not required if you cache in provider)
  Future<bool> isBookmarkedInDatabase({
    required String itemType,
    required String itemId,
  }) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return false;

    try {
      final res = await _db
          .from('bookmarks')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('item_type', itemType)
          .eq('item_id', itemId)
          .maybeSingle();

      return res != null;
    } catch (e) {
      debugPrint('❌ Error checking bookmark: $e');
      return false;
    }
  }

  /* ==================== FRIENDS ==================== */

  /// Get friendship status between current user and [otherUserId]
  ///
  /// Returns one of:
  /// - "none"             = no relation
  /// - "pending_sent"     = I sent a friend request
  /// - "pending_received" = I received a friend request
  /// - "accepted"         = we are friends
  /// - "blocked"          = relationship is blocked
  Future<String> getFriendshipStatusFromDatabase(String otherUserId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return 'none';
    if (currentUserId == otherUserId) return 'none';

    try {
      // ✅ Use list query (not maybeSingle) so it never crashes if multiple rows exist.
      final res = await _db
          .from('friendships')
          .select(
            'requester_id, addressee_id, status, relation_type, created_at',
          )
          .or(
            'and(requester_id.eq.$currentUserId,addressee_id.eq.$otherUserId),'
            'and(requester_id.eq.$otherUserId,addressee_id.eq.$currentUserId)',
          )
          .order('created_at', ascending: false)
          .limit(1);

      if (res is! List || res.isEmpty) return 'none';

      final row = Map<String, dynamic>.from(res.first);

      final status = (row['status'] ?? 'pending')
          .toString(); // pending/accepted/blocked
      final relationType = (row['relation_type'] ?? 'friends')
          .toString(); // friends/mahram
      final requesterId = (row['requester_id'] ?? '').toString();
      final addresseeId = (row['addressee_id'] ?? '').toString();

      // Accepted
      if (status == 'accepted') {
        if (relationType == 'mahram') return 'mahram';
        return 'accepted';
      }

      // Blocked
      if (status == 'blocked') {
        return 'blocked';
      }

      // Pending
      if (status == 'pending') {
        final isRequesterMe = requesterId == currentUserId;
        final isAddresseeMe = addresseeId == currentUserId;

        if (relationType == 'mahram') {
          if (isRequesterMe) return 'pending_mahram_sent';
          if (isAddresseeMe) return 'pending_mahram_received';
          return 'none';
        }

        // Normal friend pending
        if (isRequesterMe) return 'pending_sent';
        if (isAddresseeMe) return 'pending_received';
      }

      return 'none';
    } catch (e, st) {
      debugPrint('❌ Error fetching friendship status: $e\n$st');
      return 'none';
    }
  }

  /// Send a friend request from current user to [targetUserId]
  ///
  /// - Does nothing if any friendship row already exists between the two users.
  /// - Creates a notification for [targetUserId].
  Future<void> sendFriendRequestInDatabase(String targetUserId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;
    if (currentUserId == targetUserId) return;

    try {
      // Check if there's already a friendship row in any direction
      final existing = await _db
          .from('friendships')
          .select('status')
          .or(
            'and(requester_id.eq.$currentUserId,addressee_id.eq.$targetUserId),'
            'and(requester_id.eq.$targetUserId,addressee_id.eq.$currentUserId)',
          )
          .maybeSingle();

      if (existing != null) {
        print(
          'ℹ️ Friendship already exists with status: ${existing['status']}',
        );
        return;
      }

      // Insert pending friendship
      await _db.from('friendships').insert({
        'requester_id': currentUserId,
        'addressee_id': targetUserId,
        'status': 'pending',
      });

      // 🆕 Notification for receiver
      try {
        final requesterProfile = await getUserFromDatabase(currentUserId);
        final displayName = (requesterProfile?.username.isNotEmpty ?? false)
            ? requesterProfile!.username
            : (requesterProfile?.name ?? 'Someone');

        await _notifications.createNotificationForUser(
          targetUserId: targetUserId,
          title: '$displayName sent you a friend request',
          body: 'FRIEND_REQUEST:$currentUserId',

          // ✅ IMPORTANT:
          fromUserId: currentUserId,
          type: 'social',
          unreadCount: 1,
          isRead: false,

          data: {'type': 'FRIEND_REQUEST', 'senderName': displayName},
        );
      } catch (e) {
        print('⚠️ Error creating friend request notification: $e');
      }

      print('✅ Friend request sent');
    } catch (e) {
      print('❌ Error sending friend request: $e');
    }
  }

  /// Accept a pending friend request from [otherUserId] → current user
  ///
  /// - Current user must be the addressee in a 'pending' row.
  /// - Updates status to 'accepted' and updates timestamp.
  /// - Sends notification back to requester.
  Future<void> acceptFriendRequestInDatabase(String otherUserId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      // Find the pending request where otherUser is requester, I am addressee
      final row = await _db
          .from('friendships')
          .select('id, requester_id')
          .eq('requester_id', otherUserId)
          .eq('addressee_id', currentUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (row == null) {
        print('ℹ️ No pending friend request from $otherUserId to accept');
        return;
      }

      final requestId = row['id'];

      await _db
          .from('friendships')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId);

      // Notify requester
      try {
        final me = await getUserFromDatabase(currentUserId);
        final displayName = (me?.username.isNotEmpty ?? false)
            ? me!.username
            : (me?.name ?? 'Someone');

        await _notifications.createNotificationForUser(
          targetUserId: otherUserId,
          title: '$displayName accepted your friend request', // fallback
          body: 'FRIEND_ACCEPTED:$currentUserId',
          data: {
            'type': 'FRIEND_ACCEPTED',
            'fromUserId': currentUserId,
            'senderName': displayName,
          },
        );
      } catch (e) {
        print('⚠️ Error creating friend accepted notification: $e');
      }

      print('✅ Friend request accepted');
    } catch (e) {
      print('❌ Error accepting friend request: $e');
    }
  }

  /// Cancel a pending friend request that the current user previously sent
  /// to [otherUserId].
  Future<void> cancelFriendRequestInDatabase(String otherUserId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      // 1️⃣ Delete the pending friendship row
      await _db
          .from('friendships')
          .delete()
          .eq('requester_id', currentUserId)
          .eq('addressee_id', otherUserId)
          .eq('status', 'pending');

      // 2️⃣ Delete the friend-request notification if it still exists:
      //    user_id = otherUserId, body = FRIEND_REQUEST:<currentUserId>
      await _notifications.deleteFriendRequestNotification(
        targetUserId: otherUserId,
        requesterId: currentUserId,
      );

      print('✅ Friend request cancelled (and notification removed)');
    } catch (e) {
      print('❌ Error cancelling friend request: $e');
    }
  }

  Future<void> declineFriendRequestInDatabase(String otherUserId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      await _db
          .from('friendships')
          .delete()
          .eq('requester_id', otherUserId) // they sent it
          .eq('addressee_id', currentUserId) // I received it
          .eq('status', 'pending');

      print('✅ Friend request declined');
    } catch (e) {
      print('❌ Error declining friend request: $e');
    }
  }

  // 🔄 New: realtime friends stream
  Stream<List<UserProfile>> friendsStreamFromDatabase() {
    final userId = _auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const Stream.empty();
    }

    return _db
        .from('friendships')
        .stream(primaryKey: ['id'])
        .eq('status', 'accepted')
        .asyncMap((rows) async {
          // 🔍 see what comes in
          debugPrint('🔔 friendships stream rows: ${rows.length}');

          // ✅ Filter to only rows involving the current user
          final filtered = rows.where((row) {
            return row['requester_id'] == userId ||
                row['addressee_id'] == userId;
          }).toList();

          debugPrint('🔍 filtered friendships for $userId: ${filtered.length}');

          // ✅ Determine the "other" user in each friendship
          final friendIds = filtered
              .map<String>((row) {
                final requester = row['requester_id'] as String;
                final addressee = row['addressee_id'] as String;
                return requester == userId ? addressee : requester;
              })
              .toSet()
              .toList(); // ensure unique

          // ✅ Fetch UserProfile objects for each friend
          final profiles = <UserProfile>[];
          for (final fid in friendIds) {
            final profile = await getUserFromDatabase(fid);
            if (profile != null) profiles.add(profile);
          }

          debugPrint(
            '✅ friendsStreamFromDatabase returning ${profiles.length} profiles',
          );
          return profiles;
        });
  }

  // 🔄 New: realtime friends stream for ANY user (not just current user)
  Stream<List<UserProfile>> friendsStreamForUserFromDatabase(
    String profileUserId,
  ) {
    if (profileUserId.isEmpty) {
      return const Stream.empty();
    }

    return _db
        .from('friendships')
        .stream(primaryKey: ['id'])
        .eq('status', 'accepted')
        .asyncMap((rows) async {
          // Only friendships where this profile user is involved
          final filtered = rows.where((row) {
            final requester = row['requester_id']?.toString();
            final addressee = row['addressee_id']?.toString();
            return requester == profileUserId || addressee == profileUserId;
          }).toList();

          // Determine "the other person" in each friendship
          final friendIds = filtered
              .map<String>((row) {
                final requester = row['requester_id'] as String;
                final addressee = row['addressee_id'] as String;
                return requester == profileUserId ? addressee : requester;
              })
              .toSet()
              .toList(); // unique

          // Load profiles for each friend
          final profiles = <UserProfile>[];
          for (final fid in friendIds) {
            final profile = await getUserFromDatabase(fid);
            if (profile != null) profiles.add(profile);
          }

          return profiles;
        });
  }

  Future<void> unfriendUserInDatabase(String otherUserId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;
    if (currentUserId == otherUserId) return;

    try {
      // 1️⃣ Remove the accepted friendship in either direction
      await _db
          .from('friendships')
          .delete()
          .eq('status', 'accepted')
          .or(
            'and(requester_id.eq.$currentUserId,addressee_id.eq.$otherUserId),'
            'and(requester_id.eq.$otherUserId,addressee_id.eq.$currentUserId)',
          );

      print('✅ Unfriended $otherUserId');
    } catch (e) {
      print('❌ Error unfriending user $otherUserId: $e');
    }
  }

  /// ✅ Get accepted friend IDs for [userId]
  /// Returns the "other" user for each accepted friendship.
  Future<List<String>> getFriendIdsFromDatabase(String userId) async {
    if (userId.isEmpty) return [];

    try {
      final res = await _db
          .from('friendships')
          .select('requester_id, addressee_id')
          .eq('status', 'accepted')
          .or('requester_id.eq.$userId,addressee_id.eq.$userId');

      if (res is! List) return [];

      final ids = <String>{};

      for (final row in res) {
        final requester = row['requester_id']?.toString();
        final addressee = row['addressee_id']?.toString();

        if (requester == null || addressee == null) continue;

        final other = requester == userId ? addressee : requester;
        if (other.isNotEmpty) ids.add(other);
      }

      return ids.toList();
    } catch (e, st) {
      debugPrint('❌ Error getFriendIdsFromDatabase: $e\n$st');
      return [];
    }
  }

  /// ✅ Get friends-of-friends IDs for [userId]
  /// - Uses accepted friendships only
  /// - Excludes [userId] and excludes direct friends (so it stays true 2nd-degree)
  ///
  /// Your schema:
  /// friendships: requester_id, addressee_id, status
  Future<Set<String>> getFriendsOfFriendsIdsFromDatabase({
    required String userId,
    required Set<String> friendIds,
  }) async {
    if (userId.isEmpty) return <String>{};
    if (friendIds.isEmpty) return <String>{};

    try {
      // Supabase 'inFilter' needs a List
      final friendList = friendIds.toList();

      // ✅ We do two safe queries and merge results
      // (this avoids "or requester_id.in.(...)" string formatting issues with UUIDs)
      final resA = await _db
          .from('friendships')
          .select('requester_id, addressee_id')
          .eq('status', 'accepted')
          .inFilter('requester_id', friendList);

      final resB = await _db
          .from('friendships')
          .select('requester_id, addressee_id')
          .eq('status', 'accepted')
          .inFilter('addressee_id', friendList);

      final rows = <dynamic>[
        ...(resA is List ? resA : const []),
        ...(resB is List ? resB : const []),
      ];

      final foaf = <String>{};

      for (final row in rows) {
        final requester = row['requester_id']?.toString();
        final addressee = row['addressee_id']?.toString();
        if (requester == null || addressee == null) continue;

        // If requester is my friend -> addressee might be a FOAF (and vice versa)
        if (friendIds.contains(requester)) foaf.add(addressee);
        if (friendIds.contains(addressee)) foaf.add(requester);
      }

      // remove self and direct friends
      foaf.remove(userId);
      foaf.removeAll(friendIds);

      return foaf;
    } catch (e, st) {
      debugPrint('❌ Error getFriendsOfFriendsIdsFromDatabase: $e\n$st');
      return <String>{};
    }
  }

  /* ==================== MAHRAM ==================== */

  /// Send a MAHRAM request (mimics friend request 1:1, but relation_type='mahram')
  Future<void> sendMahramRequestInDatabase(String targetUserId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;
    if (currentUserId == targetUserId) return;

    try {
      final existing = await _db
          .from('friendships')
          .select('status, relation_type')
          .or(
            'and(requester_id.eq.$currentUserId,addressee_id.eq.$targetUserId),'
            'and(requester_id.eq.$targetUserId,addressee_id.eq.$currentUserId)',
          )
          .maybeSingle();

      if (existing != null) {
        debugPrint('ℹ️ Relationship already exists: $existing');
        return;
      }

      await _db.from('friendships').insert({
        'requester_id': currentUserId,
        'addressee_id': targetUserId,
        'status': 'pending',
        'relation_type': 'mahram',
      });

      // ✅ EXACTLY like friend request notification
      final me = await getUserFromDatabase(currentUserId);
      final displayName = (me?.username.isNotEmpty ?? false)
          ? me!.username
          : (me?.name ?? 'Someone');

      await _notifications.createNotificationForUser(
        targetUserId: targetUserId,
        title: '$displayName sent you a mahram request',
        body: 'MAHRAM_REQUEST:$currentUserId',

        // must be set so requester can delete via RLS
        fromUserId: currentUserId,
        type: 'social',
        unreadCount: 1,
        isRead: false,

        data: {
          'type': 'MAHRAM_REQUEST',
          'fromUserId': currentUserId,
          'senderName': displayName,
        },
      );

      debugPrint('✅ Mahram request sent');
    } catch (e, st) {
      debugPrint('❌ Error sending mahram request: $e\n$st');
      rethrow;
    }
  }

  /// Cancel a pending MAHRAM request that the current user previously sent
  Future<void> cancelMahramRequestInDatabase(String otherUserId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      await _db
          .from('friendships')
          .delete()
          .eq('requester_id', currentUserId)
          .eq('addressee_id', otherUserId)
          .eq('status', 'pending')
          .eq('relation_type', 'mahram');

      // ✅ EXACTLY like friend cancel: delete receiver notif by body
      await _notifications.deleteMahramRequestNotification(
        targetUserId: otherUserId,
        requesterId: currentUserId,
      );

      debugPrint('✅ Mahram request cancelled (and notification removed)');
    } catch (e, st) {
      debugPrint('❌ Error cancelling mahram request: $e\n$st');
      rethrow;
    }
  }

  /// Accept a pending MAHRAM request from [otherUserId] → current user
  Future<void> acceptMahramRequestInDatabase(String otherUserId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      final row = await _db
          .from('friendships')
          .select('id')
          .eq('requester_id', otherUserId)
          .eq('addressee_id', currentUserId)
          .eq('status', 'pending')
          .eq('relation_type', 'mahram')
          .maybeSingle();

      if (row == null) {
        print('ℹ️ No pending mahram request from $otherUserId to accept');
        return;
      }

      await _db
          .from('friendships')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', row['id']);

      // ✅ Nice UX: notify requester it was accepted
      try {
        final me = await getUserFromDatabase(currentUserId);
        final displayName = (me?.username.isNotEmpty ?? false)
            ? me!.username
            : (me?.name ?? 'Someone');

        await _notifications.createNotificationForUser(
          targetUserId: otherUserId,
          title: '$displayName accepted your mahram request',
          body: 'MAHRAM_ACCEPTED:$currentUserId',
          data: {
            'type': 'MAHRAM_ACCEPTED',
            'fromUserId': currentUserId,
            'senderName': displayName,
          },
        );
      } catch (e) {
        print('⚠️ Error creating mahram accepted notification: $e');
      }

      print('✅ Mahram request accepted');
    } catch (e) {
      print('❌ Error accepting mahram request: $e');
    }
  }

  /// Decline a pending MAHRAM request from [otherUserId] → current user
  Future<void> declineMahramRequestInDatabase(String otherUserId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      await _db
          .from('friendships')
          .delete()
          .eq('requester_id', otherUserId)
          .eq('addressee_id', currentUserId)
          .eq('status', 'pending')
          .eq('relation_type', 'mahram');

      print('✅ Mahram request declined');
    } catch (e) {
      print('❌ Error declining mahram request: $e');
    }
  }

  /// Delete an accepted MAHRAM relationship between current user and [otherUserId]
  Future<void> deleteMahramRelationshipInDatabase(String otherUserId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;
    if (currentUserId == otherUserId) return;

    try {
      await _db
          .from('friendships')
          .delete()
          .eq('status', 'accepted')
          .eq('relation_type', 'mahram')
          .or(
            'and(requester_id.eq.$currentUserId,addressee_id.eq.$otherUserId),'
            'and(requester_id.eq.$otherUserId,addressee_id.eq.$currentUserId)',
          );

      print('✅ Mahram relationship deleted with $otherUserId');
    } catch (e) {
      print('❌ Error deleting mahram relationship: $e');
    }
  }

  Future<List<UserProfile>> getMyMahramsInDatabase() async {
    final myId = _auth.currentUser?.id;
    if (myId == null || myId.isEmpty) return [];

    final rows = await _db
        .from('friendships')
        .select('requester_id, addressee_id')
        .eq('status', 'accepted')
        .eq('relation_type', 'mahram')
        .or('requester_id.eq.$myId,addressee_id.eq.$myId');

    final ids = <String>{};
    for (final r in (rows as List)) {
      final requester = (r['requester_id'] ?? '').toString();
      final addressee = (r['addressee_id'] ?? '').toString();
      final other = requester == myId ? addressee : requester;
      if (other.isNotEmpty) ids.add(other);
    }

    if (ids.isEmpty) return [];

    final profiles = await _db
        .from('profiles')
        .select('id, name, username, profile_photo_url, last_seen_at, gender, country, city')
        .inFilter('id', ids.toList());

    return (profiles as List)
        .map((p) => UserProfile.fromMap(Map<String, dynamic>.from(p as Map)))
        .toList();
  }




// =========================================================
// MARRIAGE INQUIRIES (DatabaseService)
// =========================================================
//
// ✅ FINAL, CONSISTENT VERSION (copy/paste over your whole marriage section)
//
// Statuses used (consistent everywhere):
// - pending_woman_response        (Flow 1: man initiated, waiting for woman to accept + pick mahram)
// - pending_mahram_response       (Waiting for mahram approval/decline)
// - pending_man_decision          (Flow 2: woman initiated, waiting for man accept/decline AFTER mahram approved)
// - approved_by_mahram            (optional milestone before group creation in flow 1)
// - accepted_by_man               (optional milestone before group creation in flow 2)
// - group_created
// - cancelled
// - ended
// - closed_woman_declined
// - closed_mahram_declined
// - closed_man_declined
//
// mahram_status values used:
// - pending
// - approved
// - declined
//
// man_status values used:
// - pending
// - accepted
// - declined
//
// Notifications bodies used (keep stable for NotificationPage parsing):
// - MARRIAGE_INQUIRY_REQUEST:$inquiryId::$manId
// - MARRIAGE_INQUIRY_MAHRAM:$inquiryId::$manId::$womanId
// - MARRIAGE_INQUIRY_MAN_DECISION:$inquiryId::$womanId::$mahramId
// - MARRIAGE_INQUIRY_GROUP_CREATED:$inquiryId::$chatRoomId::$groupName
// - MARRIAGE_INQUIRY_DECLINED:$inquiryId::$manId

  Future<String> createMarriageInquiryInDatabase({
    required String manId,
    required String womanId,
    String? mahramId, // nullable for initiatedBy='man'
    String initiatedBy = 'man', // 'man' or 'woman'
  }) async {
    final currentUserId = _auth.currentUser!.id;

    // ✅ Enforce caller matches initiatedBy
    if (initiatedBy == 'man' && currentUserId != manId) {
      throw Exception('Only the man can create this inquiry (initiated_by=man).');
    }
    if (initiatedBy == 'woman' && currentUserId != womanId) {
      throw Exception('Only the woman can create this inquiry (initiated_by=woman).');
    }

    // ✅ woman-initiated must include mahram upfront
    if (initiatedBy == 'woman' && (mahramId == null || mahramId.isEmpty)) {
      throw Exception('Woman-initiated inquiries require mahramId.');
    }

    final bool hasMahram = mahramId != null && mahramId!.isNotEmpty;

    // ✅ Consistent statuses
    final String initialStatus =
    hasMahram ? 'pending_mahram_response' : 'pending_woman_response';

    final String initialMahramStatus = hasMahram ? 'pending' : 'not_assigned';

    // ✅ In Flow 2 (woman initiated), man will later decide, so set man_status=pending
    final String initialManStatus =
    (initiatedBy == 'woman') ? 'pending' : 'not_required';

    final created = await _db
        .from('marriage_inquiries')
        .insert({
      'man_id': manId,
      'woman_id': womanId,
      'mahram_id': hasMahram ? mahramId : null,
      'status': initialStatus,
      'initiated_by': initiatedBy,
      'mahram_status': initialMahramStatus,
      'man_status': initialManStatus,
    })
        .select('id')
        .maybeSingle();

    if (created == null || created['id'] == null) {
      throw Exception('Failed to create marriage inquiry');
    }

    final inquiryId = created['id'].toString();

    // 2) Notifications
    if (hasMahram) {
      // ✅ Mahram gets notified first (works for initiated_by=woman)
      await NotificationService().createNotificationForUser(
        targetUserId: mahramId!,
        title: 'mahram_confirmation_title'.tr(),
        body: 'MARRIAGE_INQUIRY_MAHRAM:$inquiryId::$manId::$womanId',
        sendPush: true,
        data: {
          'type': 'MARRIAGE_INQUIRY_MAHRAM',
          'inquiryId': inquiryId,
          'manId': manId,
          'womanId': womanId,
        },
        fromUserId: manId, // keep as man for your NotificationPage parsing
        type: 'social',
        unreadCount: 1,
        isRead: false,
      );
    } else {
      // ✅ No mahram yet -> notify woman to accept + pick a mahram
      await NotificationService().createNotificationForUser(
        targetUserId: womanId,
        title: 'marriage_inquiry'.tr(),
        body: 'MARRIAGE_INQUIRY_REQUEST:$inquiryId::$manId',
        sendPush: true,
        data: {
          'type': 'MARRIAGE_INQUIRY_REQUEST',
          'inquiryId': inquiryId,
          'manId': manId,
          'womanId': womanId,
        },
        fromUserId: manId,
        type: 'social',
        unreadCount: 1,
        isRead: false,
      );
    }

    return inquiryId;
  }

  /// FLOW 1 (initiated_by=man):
  /// Woman accepts AND selects a mahram in one step.
  /// - must be status=pending_woman_response
  /// - sets mahram_id, mahram_status=pending
  /// - moves to status=pending_mahram_response
  /// - notifies mahram
  Future<void> womanAcceptAndSelectMahramForInquiryInDatabase({
    required String inquiryId,
    required String mahramId,
  }) async {
    final currentUserId = _auth.currentUser!.id;

    final inquiry = await _db
        .from('marriage_inquiries')
        .select('id, man_id, woman_id, initiated_by, status')
        .eq('id', inquiryId)
        .maybeSingle();

    if (inquiry == null) throw Exception('Inquiry not found');

    final manId = inquiry['man_id'].toString();
    final womanId = inquiry['woman_id'].toString();
    final initiatedBy = (inquiry['initiated_by'] ?? 'man').toString();
    final status = (inquiry['status'] ?? '').toString();

    if (initiatedBy != 'man') {
      throw Exception('This accept+pick flow is only for initiated_by=man.');
    }
    if (womanId != currentUserId) {
      throw Exception('Only the woman can accept this inquiry.');
    }
    if (status != 'pending_woman_response') {
      throw Exception('Inquiry is not awaiting the woman’s response.');
    }
    if (mahramId.isEmpty) {
      throw Exception('Mahram is required.');
    }

    await _db.from('marriage_inquiries').update({
      'mahram_id': mahramId,
      'mahram_status': 'pending',
      'status': 'pending_mahram_response',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', inquiryId);

    await NotificationService().createNotificationForUser(
      targetUserId: mahramId,
      title: 'mahram_confirmation_title'.tr(),
      body: 'MARRIAGE_INQUIRY_MAHRAM:$inquiryId::$manId::$womanId',
      sendPush: true,
      data: {
        'type': 'MARRIAGE_INQUIRY_MAHRAM',
        'inquiryId': inquiryId,
        'manId': manId,
        'womanId': womanId,
      },
      fromUserId: manId,
      type: 'social',
      unreadCount: 1,
      isRead: false,
    );
  }

  Future<void> womanDeclineInquiryInDatabase({
    required String inquiryId,
  }) async {
    final currentUserId = _auth.currentUser!.id;

    final inquiry = await _db
        .from('marriage_inquiries')
        .select('id, man_id, woman_id, initiated_by, status')
        .eq('id', inquiryId)
        .maybeSingle();

    if (inquiry == null) throw Exception('Inquiry not found');

    final womanId = inquiry['woman_id'].toString();
    final initiatedBy = (inquiry['initiated_by'] ?? 'man').toString();
    final status = (inquiry['status'] ?? '').toString();

    if (initiatedBy != 'man') throw Exception('Only for initiated_by=man.');
    if (currentUserId != womanId) throw Exception('Only woman can decline.');
    if (status != 'pending_woman_response') {
      throw Exception('Inquiry is not awaiting the woman’s response.');
    }

    await _db.from('marriage_inquiries').update({
      'status': 'closed_woman_declined',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', inquiryId);
  }

  /// BOTH FLOWS:
  /// Mahram approves/declines.
  /// - Requires status=pending_mahram_response and mahram_status=pending.
  /// - If declined -> ends inquiry (closed_mahram_declined) + notify man & woman.
  /// - If approved:
  ///    - initiated_by=woman -> status=pending_man_decision + notify man (opens WOMAN profile)
  ///    - initiated_by=man   -> create group immediately + notify all 3
  Future<void> mahramRespondToInquiryInDatabase({
    required String inquiryId,
    required bool approve,
  }) async {
    final currentUserId = _auth.currentUser!.id;

    final inquiry = await _db
        .from('marriage_inquiries')
        .select('id, man_id, woman_id, mahram_id, status, initiated_by, mahram_status')
        .eq('id', inquiryId)
        .maybeSingle();

    if (inquiry == null) throw Exception('Inquiry not found');

    final manId = inquiry['man_id'].toString();
    final womanId = inquiry['woman_id'].toString();
    final mahramId = (inquiry['mahram_id'] ?? '').toString();
    final status = (inquiry['status'] ?? '').toString();
    final initiatedBy = (inquiry['initiated_by'] ?? 'man').toString();
    final mahramStatus = (inquiry['mahram_status'] ?? '').toString();

    if (mahramId.isEmpty) throw Exception('No mahram set yet.');
    if (currentUserId != mahramId) throw Exception('Only the mahram can respond.');
    if (status != 'pending_mahram_response') {
      throw Exception('Inquiry is not awaiting mahram response.');
    }
    if (mahramStatus != 'pending') {
      throw Exception('Mahram has already responded.');
    }

    // -----------------------------
    // DECLINE
    // -----------------------------
    if (!approve) {
      await _db.from('marriage_inquiries').update({
        'status': 'closed_mahram_declined',
        'mahram_status': 'declined',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', inquiryId);

      // ✅ notify woman
      await NotificationService().createNotificationForUser(
        targetUserId: womanId,
        title: 'notif_marriage_inquiry_declined'.tr(),
        body: 'MARRIAGE_INQUIRY_DECLINED:$inquiryId::$manId',
        sendPush: true,
        data: {
          'type': 'MARRIAGE_INQUIRY_DECLINED',
          'inquiryId': inquiryId,
          'manId': manId,
        },
        fromUserId: mahramId,
        type: 'social',
        unreadCount: 1,
        isRead: false,
      );

      // ✅ notify man
      await NotificationService().createNotificationForUser(
        targetUserId: manId,
        title: 'notif_marriage_inquiry_declined'.tr(),
        body: 'MARRIAGE_INQUIRY_DECLINED:$inquiryId::$manId',
        sendPush: true,
        data: {
          'type': 'MARRIAGE_INQUIRY_DECLINED',
          'inquiryId': inquiryId,
          'manId': manId,
        },
        fromUserId: mahramId,
        type: 'social',
        unreadCount: 1,
        isRead: false,
      );

      return;
    }

    // -----------------------------
    // APPROVE
    // -----------------------------

    // ✅ Flow 2 (woman initiated): move to man decision
    if (initiatedBy == 'woman') {
      await _db.from('marriage_inquiries').update({
        'status': 'pending_man_decision',
        'mahram_status': 'approved',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', inquiryId);

      // ✅ IMPORTANT:
      // - the notification must open the WOMAN profile for the man
      // - so set fromUserId = womanId
      // - keep body format consistent with NotificationPage parser
      await NotificationService().createNotificationForUser(
        targetUserId: manId,
        title: 'notif_marriage_inquiry_man_decision_title'.tr(),
        body: 'MARRIAGE_INQUIRY_MAN_DECISION:$inquiryId::$womanId::$mahramId',
        sendPush: true,
        data: {
          'type': 'MARRIAGE_INQUIRY_MAN_DECISION',
          'inquiryId': inquiryId,
          'womanId': womanId,
          'mahramId': mahramId,
        },
        fromUserId: womanId, // ✅ CHANGED (was mahramId)
        type: 'social',
        unreadCount: 1,
        isRead: false,
      );

      return;
    }

    // ✅ Flow 1 (man initiated): create group immediately
    await _db.from('marriage_inquiries').update({
      'status': 'approved_by_mahram',
      'mahram_status': 'approved',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', inquiryId);

    final String groupName = 'Marriage inquiry'.tr();

    final chatRoomId = await ChatService().createGroupRoomInDatabase(
      name: groupName,
      creatorId: mahramId,
      initialMemberIds: [manId, womanId],
    );

    await _db.from('marriage_inquiries').update({
      'status': 'group_created',
      'chat_room_id': chatRoomId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', inquiryId);

    final bodyCode =
        'MARRIAGE_INQUIRY_GROUP_CREATED:$inquiryId::$chatRoomId::$groupName';

    for (final target in [manId, womanId, mahramId]) {
      await NotificationService().createNotificationForUser(
        targetUserId: target,
        title: 'notif_marriage_inquiry_group_created'.tr(),
        body: bodyCode,
        sendPush: true,
        data: {
          'type': 'MARRIAGE_INQUIRY_GROUP_CREATED',
          'inquiryId': inquiryId,
          'chatId': chatRoomId,
          'groupName': groupName,
        },
        fromUserId: manId,
        type: 'social',
        unreadCount: 1,
        isRead: false,
      );
    }
  }


  /// FLOW 2 ONLY (initiated_by=woman):
  Future<void> manRespondToInquiryInDatabase({
    required String inquiryId,
    required bool accept,
  }) async {
    final currentUserId = _auth.currentUser!.id;

    final inquiry = await _db
        .from('marriage_inquiries')
        .select('id, man_id, woman_id, mahram_id, status, mahram_status, initiated_by')
        .eq('id', inquiryId)
        .maybeSingle();

    if (inquiry == null) throw Exception('Inquiry not found');

    final manId = inquiry['man_id'].toString();
    final womanId = inquiry['woman_id'].toString();
    final mahramId = (inquiry['mahram_id'] ?? '').toString();
    final status = (inquiry['status'] ?? '').toString();
    final mahramStatus = (inquiry['mahram_status'] ?? '').toString();
    final initiatedBy = (inquiry['initiated_by'] ?? 'man').toString();

    if (currentUserId != manId) throw Exception('Only the man can decide.');
    if (initiatedBy != 'woman') {
      throw Exception('Man decision is only required when initiated_by=woman.');
    }
    if (status != 'pending_man_decision') {
      throw Exception('This inquiry is not awaiting the man’s decision.');
    }
    if (mahramStatus != 'approved') {
      throw Exception('Mahram has not approved yet.');
    }
    if (mahramId.isEmpty) {
      throw Exception('No mahram set for this inquiry.');
    }

    if (!accept) {
      await _db.from('marriage_inquiries').update({
        'status': 'closed_man_declined',
        'man_status': 'declined',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', inquiryId);

      await NotificationService().createNotificationForUser(
        targetUserId: womanId,
        title: 'notif_marriage_inquiry_declined'.tr(),
        body: 'MARRIAGE_INQUIRY_DECLINED:$inquiryId::$manId',
        sendPush: true,
        data: {
          'type': 'MARRIAGE_INQUIRY_DECLINED',
          'inquiryId': inquiryId,
          'manId': manId,
        },
        fromUserId: manId,
        type: 'social',
        unreadCount: 1,
        isRead: false,
      );

      await NotificationService().createNotificationForUser(
        targetUserId: mahramId,
        title: 'notif_marriage_inquiry_declined'.tr(),
        body: 'MARRIAGE_INQUIRY_DECLINED:$inquiryId::$manId',
        sendPush: true,
        data: {
          'type': 'MARRIAGE_INQUIRY_DECLINED',
          'inquiryId': inquiryId,
          'manId': manId,
        },
        fromUserId: manId,
        type: 'social',
        unreadCount: 1,
        isRead: false,
      );

      return;
    }

    await _db.from('marriage_inquiries').update({
      'status': 'accepted_by_man',
      'man_status': 'accepted',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', inquiryId);

    final String groupName = 'Marriage inquiry'.tr();

    final chatRoomId = await ChatService().createGroupRoomInDatabase(
      name: groupName,
      creatorId: manId,
      initialMemberIds: [womanId, mahramId],
    );

    await _db.from('marriage_inquiries').update({
      'status': 'group_created',
      'chat_room_id': chatRoomId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', inquiryId);

    final bodyCode =
        'MARRIAGE_INQUIRY_GROUP_CREATED:$inquiryId::$chatRoomId::$groupName';

    for (final target in [manId, womanId, mahramId]) {
      await NotificationService().createNotificationForUser(
        targetUserId: target,
        title: 'notif_marriage_inquiry_group_created'.tr(),
        body: bodyCode,
        sendPush: true,
        data: {
          'type': 'MARRIAGE_INQUIRY_GROUP_CREATED',
          'inquiryId': inquiryId,
          'chatId': chatRoomId,
          'groupName': groupName,
        },
        fromUserId: manId,
        type: 'social',
        unreadCount: 1,
        isRead: false,
      );
    }
  }

  Future<Map<String, dynamic>?> getLatestActiveInquiryBetweenMeAnd(String otherUserId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return null;

    final res = await _db
        .from('marriage_inquiries')
        .select(
      'id, man_id, woman_id, mahram_id, status, mahram_status, man_status, chat_room_id, updated_at, initiated_by',
    )
        .or(
      'and(man_id.eq.$currentUserId,woman_id.eq.$otherUserId),'
          'and(man_id.eq.$otherUserId,woman_id.eq.$currentUserId),'
          'and(mahram_id.eq.$currentUserId,man_id.eq.$otherUserId),'
          'and(mahram_id.eq.$currentUserId,woman_id.eq.$otherUserId)',
    )
        .order('updated_at', ascending: false)
        .limit(1);

    if (res is! List || res.isEmpty) return null;

    final row = Map<String, dynamic>.from(res.first);

    final s = (row['status'] ?? '').toString();
    const terminal = {
      'cancelled',
      'ended',
      'completed',
      'closed_woman_declined',
      'closed_mahram_declined',
      'closed_man_declined',
    };
    if (terminal.contains(s)) return null;

    return row;
  }

  String? computeInquiryUiStatus({
    required Map<String, dynamic> inquiry,
    required String viewerId,
    required String otherUserId,
  }) {
    final manId = (inquiry['man_id'] ?? '').toString();
    final womanId = (inquiry['woman_id'] ?? '').toString();
    final mahramId = (inquiry['mahram_id'] ?? '').toString();

    final status = (inquiry['status'] ?? '').toString().trim();
    final mahramStatusRaw = (inquiry['mahram_status'] ?? '').toString().trim();
    final mahramStatus = mahramStatusRaw.isEmpty ? 'not_assigned' : mahramStatusRaw;

    final chatRoomId = (inquiry['chat_room_id'] ?? '').toString();

    final isViewerMan = viewerId == manId;
    final isViewerWoman = viewerId == womanId;
    final isViewerMahram = mahramId.isNotEmpty && viewerId == mahramId;

    if (!isViewerMan && !isViewerWoman && !isViewerMahram) return null;

    // Once group exists -> show "End inquiry" for man/woman (mahram doesn't need controls)
    final bool inquiryActive = chatRoomId.isNotEmpty || status == 'group_created';
    if (inquiryActive) {
      if (isViewerMan || isViewerWoman) return 'inquiry_cancel_inquiry';
      return null;
    }

    // Flow 1: man initiated -> waiting for woman (woman must accept + pick mahram)
    if (status == 'pending_woman_response') {
      if (isViewerWoman) return 'inquiry_pending_received_woman';
      if (isViewerMan) return 'inquiry_pending_sent';
      return null;
    }

    // Waiting for mahram response (mahram has been selected)
    if (status == 'pending_mahram_response') {
      // Only mahram gets approve/decline buttons while it's pending
      if (isViewerMahram && mahramStatus == 'pending') {
        return 'inquiry_pending_received_mahram';
      }

      // Man + woman see "sent" while mahram decides (or if mahram already decided but status hasn't moved yet)
      if (isViewerMan || isViewerWoman) return 'inquiry_pending_sent';
      return null;
    }

    // Flow 2: after mahram approved -> waiting for man decision
    if (status == 'pending_man_decision') {
      if (isViewerMan) return 'inquiry_pending_received_man';
      if (isViewerWoman) return 'inquiry_pending_sent';
      return null;
    }

    return null;
  }


  Future<String> getCombinedRelationshipStatus(String otherUserId) async {
    final inquiry = await getLatestActiveInquiryBetweenMeAnd(otherUserId);
    if (inquiry != null) {
      final viewerId = _auth.currentUser!.id;
      final ui = computeInquiryUiStatus(
        inquiry: inquiry,
        viewerId: viewerId,
        otherUserId: otherUserId,
      );
      if (ui != null) return ui;
    }

    return getFriendshipStatusFromDatabase(otherUserId);
  }

  Future<void> cancelOrEndMarriageInquiryInDatabase({
    required String inquiryId,
  }) async {
    final currentUserId = _auth.currentUser!.id;

    final inquiry = await _db
        .from('marriage_inquiries')
        .select('id, man_id, woman_id, chat_room_id, status')
        .eq('id', inquiryId)
        .maybeSingle();

    if (inquiry == null) return;

    final manId = (inquiry['man_id'] ?? '').toString();
    final womanId = (inquiry['woman_id'] ?? '').toString();
    final chatRoomId = (inquiry['chat_room_id'] ?? '').toString();

    final isParty = currentUserId == manId || currentUserId == womanId;
    if (!isParty) {
      throw Exception('Only man or woman can cancel/end the inquiry.');
    }

    // ✅ If group exists -> delete group + end inquiry via secure RPC (works even if mahram created the room)
    if (chatRoomId.isNotEmpty) {
      await _db.rpc(
        'end_marriage_inquiry_and_delete_group',
        params: {'p_inquiry_id': inquiryId},
      );

      // ✅ remove any pending notifications for this inquiry
      await NotificationService().deleteMarriageInquiryNotifications(inquiryId);
      return;
    }

    // ✅ No group yet -> just cancel inquiry
    await _db.from('marriage_inquiries').update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', inquiryId);

    // ✅ remove pending notifications for this inquiry
    await NotificationService().deleteMarriageInquiryNotifications(inquiryId);
  }



  Future<Map<String, dynamic>?> getInquiryByIdInDatabase(String inquiryId) async {
    final res = await _db
        .from('marriage_inquiries')
        .select(
      'id, man_id, woman_id, mahram_id, status, mahram_status, man_status, chat_room_id, updated_at, initiated_by',
    )
        .eq('id', inquiryId)
        .maybeSingle();

    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }






  /* ==================== FOLLOW / UNFOLLOW ==================== */

  /// Follow user in database
  ///
  /// 🆕 After a successful follow, the target user gets a notification.
  Future<void> followUserInDatabase(String targetUserId) async {
    final currentUserId = _auth.currentUser!.id;

    try {
      // 1️⃣ Insert into follows (unique constraint prevents duplicates)
      await _db.from('follows').insert({
        'follower_id': currentUserId,
        'following_id': targetUserId,
      });

      // 3️⃣ Follow notification (in-app + push)
      try {
        final followerProfile = await getUserFromDatabase(currentUserId);

        final displayName = (followerProfile?.username.isNotEmpty ?? false)
            ? followerProfile!.username
            : ((followerProfile?.name ?? '').trim().isNotEmpty
                  ? followerProfile!.name
                  : 'Someone');

        await _notifications.createNotificationForUser(
          targetUserId: targetUserId,
          title: '$displayName started following you',
          body: 'FOLLOW_USER:$currentUserId',

          // ✅ match friend-request style
          fromUserId: currentUserId,
          type: 'social',
          unreadCount: 1,
          isRead: false,

          pushBody: '$displayName started following you',
          data: {
            'type': 'FOLLOW_USER',
            'fromUserId': currentUserId,
            'senderName': displayName,
          },
        );
      } catch (e) {
        print('⚠️ Error creating follow notification: $e');
      }
      print("✅ Follow successful");
    } catch (e) {
      print("❌ Follow error: $e");
    }
  }

  /// Unfollow user in database
  Future<void> unfollowUserInDatabase(String targetUserId) async {
    final currentUserId = _auth.currentUser!.id;

    try {
      // 1️⃣ Remove follow relation
      await _db
          .from('follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId);

      // 2️⃣ Remove follow notification:
      //    user_id = targetUserId, body = FOLLOW_USER:<currentUserId>
      await _notifications.deleteFollowNotification(
        targetUserId: targetUserId,
        followerId: currentUserId,
      );

      print("✅ Unfollow successful (follow notification cleanup requested)");
    } catch (e) {
      print("❌ Unfollow error: $e");
    }
  }

  /// Get followers UserId's from database
  Future<List<String>> getFollowersFromDatabase(String userId) async {
    try {
      final res = await _db
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId);

      if (res is! List) return [];

      final followers = res
          .map((row) => row['follower_id']?.toString())
          .whereType<String>()
          .toList();

      print("✅ Followers for $userId: $followers");
      return followers;
    } catch (e) {
      print("❌ Error fetching followers: $e");
      return [];
    }
  }

  /// Get following UserId's from database
  Future<List<String>> getFollowingFromDatabase(String userId) async {
    try {
      final res = await _db
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      if (res is! List) return [];

      final following = res
          .map((row) => row['following_id']?.toString())
          .whereType<String>()
          .toList();

      print("✅ Following for $userId: $following");
      return following;
    } catch (e) {
      print("❌ Error fetching following: $e");
      return [];
    }
  }

  /* ==================== DELETE USER ==================== */

  /// Invokes supabase function to delete user data as a batch
  Future<void> deleteUserDataFromDatabase(String userId) async {
    try {
      final result = await _db.rpc(
        'delete_user_data',
        params: {'target_user_id': userId},
      );

      print('✅ User data deleted successfully! Result: $result');
    } catch (e) {
      print('❌ Error calling delete_user_data function: $e');
      rethrow; // 🔥 this is important
    }
  }

  /* ==================== SEARCH USERS ==================== */

  Future<List<UserProfile>> searchUsersInDatabase(String searchTerm) async {
    final raw = searchTerm.trim();
    if (raw.isEmpty) return [];

    // Prevent wildcard / abuse (e.g. *** or %%% returning everything)
    if (RegExp(r'^[*%_]+$').hasMatch(raw)) return [];

    // Allow "@username"
    final qNoAt = raw.startsWith('@') ? raw.substring(1) : raw;

    try {
      // ✅ Typo-tolerant search (pg_trgm) via RPC
      //
      // Requires in Supabase:
      // - create extension if not exists pg_trgm;
      // - function search_profiles_fuzzy(q text, lim int default 60) returns setof profiles ...
      //
      // NOTE:
      // Supabase Dart returns List<dynamic> for set-returning SQL functions.
      final res = await _db.rpc(
        'search_profiles_fuzzy',
        params: {'q': qNoAt, 'lim': 60},
      );

      if (res is! List) return [];

      return res
          .map((e) => UserProfile.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, st) {
      debugPrint('❌ Error searching users (fuzzy rpc): $e\n$st');

      // ✅ Fallback (optional): if RPC fails, still do a basic ilike search so search isn't dead
      try {
        final List data = await _db
            .from('profiles')
            .select()
            .or(
              [
                'username.ilike.%$qNoAt%',
                'name.ilike.%$raw%',
                'city.ilike.%$raw%',
                'country.ilike.%$raw%',
              ].join(','),
            )
            .limit(60);

        return data
            .map((e) => UserProfile.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e2) {
        debugPrint('❌ Fallback ilike search also failed: $e2');
        return [];
      }
    }
  }

  /* ==================== COMMUNITY ==================== */

  // Fetch all communities
  Future<List<Map<String, dynamic>>> getAllCommunitiesFromDatabase() async {
    try {
      final res = await _db.from('communities').select();
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print("❌ Error fetching communities: $e");
      return [];
    }
  }

  // Create new community + auto-join creator
  Future<Map<String, dynamic>?> createCommunityInDatabase(
    String name,
    String desc,
    String country,
  ) async {
    try {
      final userId = _auth.currentUser!.id;

      // 1) Create community and get the created row back (so we have the id)
      final created = await _db
          .from('communities')
          .insert({
            'name': name,
            'description': desc,
            'country': country,
            'created_by': userId,
          })
          .select()
          .single();

      final communityId = created['id'];

      // 2) Auto-join the creator
      await _db.from('community_members').insert({
        'community_id': communityId,
        'user_id': userId,
      });

      return Map<String, dynamic>.from(created);
    } catch (e, st) {
      debugPrint("❌ Error creating community (auto-join): $e\n$st");
      return null;
    }
  }

  Future<bool> isMemberInDatabase(String communityId) async {
    try {
      final userId = _auth.currentUser!.id;
      final res = await _db
          .from('community_members')
          .select()
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .maybeSingle();
      return res != null;
    } catch (e) {
      print("❌ Error checking membership: $e");
      return false;
    }
  }

  Future<void> joinCommunityInDatabase(String communityId) async {
    try {
      final userId = _auth.currentUser!.id;
      await _db.from('community_members').insert({
        'community_id': communityId,
        'user_id': userId,
      });
    } catch (e) {
      print("❌ Error joining community: $e");
    }
  }

  Future<void> leaveCommunityInDatabase(String communityId) async {
    try {
      final userId = _auth.currentUser!.id;
      await _db
          .from('community_members')
          .delete()
          .eq('community_id', communityId)
          .eq('user_id', userId);
    } catch (e) {
      print("❌ Error leaving community: $e");
    }
  }

  Future<List<Map<String, dynamic>>> searchCommunitiesInDatabase(
    String query,
  ) async {
    try {
      final userId = _auth.currentUser!.id;
      final q = query.trim();

      if (q.isEmpty) return [];

      // OR search across name, description, and country (case-insensitive via ILIKE)
      final response = await _db
          .from('communities')
          .select(
            'id, name, description, country, members:community_members(user_id)',
          )
          .or(
            'name.ilike.%$q%,'
            'description.ilike.%$q%,'
            'country.ilike.%$q%',
          )
          .limit(30);

      return (response as List)
          .map<Map<String, dynamic>>(
            (c) => {
              'id': c['id'],
              'name': c['name'],
              'description': c['description'],
              'country': c['country'],
              'is_joined': (c['members'] as List).any(
                (m) => m['user_id'] == userId,
              ),
            },
          )
          .toList();
    } catch (e, st) {
      print("❌ Error searching communities: $e\n$st");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCommunityMembersFromDatabase(
    String communityId,
  ) async {
    try {
      final res = await _db
          .from('community_members')
          .select('user_id')
          .eq('community_id', communityId);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print("❌ Error fetching community members: $e");
      return [];
    }
  }

  // Fetch full profiles of all community members
  Future<List<Map<String, dynamic>>> getCommunityMemberProfilesFromDatabase(
    String communityId,
  ) async {
    try {
      // Step 1: Get all user_ids from community_members
      final memberLinks = await _db
          .from('community_members')
          .select('user_id')
          .eq('community_id', communityId);

      if (memberLinks.isEmpty) return [];

      // Extract user_ids
      final userIds = (memberLinks as List)
          .map((m) => m['user_id'].toString())
          .toList();

      // Step 2: Fetch full profiles from profiles table
      // Using filter 'id' in array
      final profiles = await _db
          .from('profiles')
          .select()
          .filter(
            'id',
            'in',
            '(${userIds.join(',')})',
          ); // Supabase requires string like "(id1,id2)"

      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) {
      print("❌ Error fetching community member profiles: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>>
  getMyCommunityMembershipsFromDatabase() async {
    try {
      final userId = _auth.currentUser!.id;

      final res = await _db
          .from('community_members')
          .select('community_id')
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("❌ Error fetching my community memberships: $e");
      return [];
    }
  }

  /* ==================== STORY PROGRESS ==================== */

  /// Save answers for a story (per user).
  ///
  /// [answers] is a map: questionIndex -> selectedOptionIndex
  Future<void> saveStoryAnswersInDatabase(
    String storyId,
    Map<int, int> answers,
  ) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      // Convert int keys to strings for JSONB
      final Map<String, dynamic> answersJson = {};
      answers.forEach((key, value) {
        answersJson[key.toString()] = value;
      });

      final data = <String, dynamic>{
        'user_id': currentUserId,
        'story_id': storyId,
        'answers': answersJson,
        // ❌ DO NOT set completed_at here
      };

      await _db
          .from('story_progress')
          .upsert(data, onConflict: 'user_id,story_id');
    } catch (e) {
      print('❌ Error saving story answers: $e');
    }
  }

  /// Mark a story as completed for the current user.
  ///
  /// ✅ Only place where `completed_at` is written.
  Future<void> markStoryCompletedInDatabase(String storyId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      await _db.from('story_progress').upsert({
        'user_id': currentUserId,
        'story_id': storyId,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        // answers will stay as-is if row already exists
      }, onConflict: 'user_id,story_id');
    } catch (e) {
      print('❌ Error marking story completed: $e');
    }
  }

  /// Get all completed story_ids for a given user
  ///
  /// ✅ Only rows with completed_at NOT NULL are considered "completed".
  Future<List<String>> getCompletedStoryIdsFromDatabase(String userId) async {
    try {
      final res = await _db
          .from('public_story_completions') // 👈 use the view
          .select('story_id')
          .eq('user_id', userId);

      if (res is! List) return [];

      return res
          .map((row) => row['story_id']?.toString())
          .whereType<String>()
          .toList();
    } catch (e) {
      print('❌ Error fetching completed stories for $userId: $e');
      return [];
    }
  }

  /// Load saved answers for the current user & story.
  ///
  /// Returns a map: questionIndex -> selectedOptionIndex
  Future<Map<int, int>> getStoryAnswersFromDatabase(String storyId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return {};

    try {
      final row = await _db
          .from('story_progress')
          .select('answers')
          .eq('user_id', currentUserId)
          .eq('story_id', storyId)
          .maybeSingle();

      if (row == null || row['answers'] == null) return {};

      final answersJson = row['answers'] as Map<String, dynamic>;
      final Map<int, int> result = {};

      answersJson.forEach((key, value) {
        final index = int.tryParse(key);
        final selected = (value as num?)?.toInt();
        if (index != null && selected != null) {
          result[index] = selected;
        }
      });

      return result;
    } catch (e) {
      print('❌ Error loading story answers for $storyId: $e');
      return {};
    }
  }

  /* ==================== DUA WALL ==================== */

  /// Get all duas for the Dua Wall.
  ///
  /// - Includes public duas from everyone.
  /// - Includes *private* duas only for the current user (RLS will also help later).
  Future<List<Dua>> getDuaWallFromDatabase() async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return [];

    try {
      // 1️⃣ Fetch all duas (we’ll add RLS later to enforce privacy)
      final raw = await _db
          .from('duas')
          .select('''
            id,
            user_id,
            user_name,
            text,
            is_anonymous,
            is_private,
            created_at,
            ameen_count,
            ameens:dua_ameens(user_id)
            ''')
          .order('created_at', ascending: false);

      if (raw is! List) return [];

      // 2️⃣ Map to Dua model, with userHasAmeened detection
      return raw
          .map(
            (row) => Dua.fromMap(Map<String, dynamic>.from(row), currentUserId),
          )
          .toList();
    } catch (e, st) {
      print('❌ Error loading Dua Wall: $e\n$st');
      return [];
    }
  }

  /// Create a new dua.
  ///
  /// - `isAnonymous` → others see "Anonymous" instead of your name
  /// - `isPrivate`   → only you can see this dua (RLS will be added later)
  Future<void> createDuaInDatabase({
    required String text,
    required bool isAnonymous,
    required bool isPrivate,
  }) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      final user = await getUserFromDatabase(currentUserId);
      if (user == null) {
        throw Exception('User profile not found for dua creation');
      }

      // Use username if available, fallback to name
      final displayName = user.username.isNotEmpty ? user.username : user.name;

      final payload = {
        'user_id': currentUserId,
        'user_name': displayName,
        'text': text,
        'is_anonymous': isAnonymous,
        'is_private': isPrivate,
        // `created_at` & `ameen_count` can be defaulted in DB
      };

      await _db.from('duas').insert(payload);
    } catch (e, st) {
      print('❌ Error creating dua: $e\n$st');
      rethrow;
    }
  }

  /// Toggle "Ameen" for the current user on a given dua.
  ///
  /// - Inserts into `dua_ameens` if not yet ameen'd
  /// - Deletes from `dua_ameens` if already ameen'd
  /// - `ameen_count` will later be kept in sync via DB trigger.
  Future<void> toggleAmeenForDuaInDatabase(String duaId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      // Check if an Ameen already exists
      final existing = await _db
          .from('dua_ameens')
          .select('id')
          .eq('dua_id', duaId)
          .eq('user_id', currentUserId)
          .maybeSingle();

      final bool isCurrentlyAmeened = existing != null;

      if (isCurrentlyAmeened) {
        // 🔁 Remove Ameen
        await _db
            .from('dua_ameens')
            .delete()
            .eq('dua_id', duaId)
            .eq('user_id', currentUserId);
      } else {
        // ✅ Add Ameen
        await _db.from('dua_ameens').insert({
          'dua_id': duaId,
          'user_id': currentUserId,
        });
      }

      // We’ll add a trigger to keep `ameen_count` in sync in the DB,
      // so we don’t manually update the count here.
    } catch (e, st) {
      print('❌ Error toggling Ameen for dua $duaId: $e\n$st');
      rethrow;
    }
  }

  /// Delete a dua (only if it belongs to the current user).
  Future<void> deleteDuaFromDatabase(String duaId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      await _db
          .from('duas')
          .delete()
          .eq('id', duaId)
          .eq('user_id', currentUserId); // safety: only delete own dua
    } catch (e, st) {
      print('❌ Error deleting dua $duaId: $e\n$st');
      rethrow;
    }
  }

  /* ==================== PRIVATE REFLECTIONS ==================== */

  /// Add a private reflection (optionally linked to a post)
  Future<void> addPrivateReflectionInDatabase({
    required String text,
    String? postId,
  }) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      await _db.from('private_reflections').insert({
        'user_id': currentUserId,
        'post_id': postId,
        'text': text,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e, st) {
      debugPrint('❌ Error adding private reflection: $e\n$st');
      rethrow;
    }
  }

  /// Get all private reflections for current user
  Future<List<Map<String, dynamic>>>
  getMyPrivateReflectionsFromDatabase() async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return [];

    try {
      final res = await _db
          .from('private_reflections')
          .select()
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(res);
    } catch (e, st) {
      debugPrint('❌ Error loading private reflections: $e\n$st');
      return [];
    }
  }

  /// Delete a reflection (RLS ensures only owner can delete)
  Future<void> deletePrivateReflectionFromDatabase(String reflectionId) async {
    final currentUserId = _auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      await _db
          .from('private_reflections')
          .delete()
          .eq('id', reflectionId)
          .eq('user_id', currentUserId); // extra safety
    } catch (e, st) {
      debugPrint('❌ Error deleting private reflection: $e\n$st');
      rethrow;
    }
  }

  /* ==================== TIME ==================== */

  Future<DateTime?> getServerTime() async {
    try {
      final response = await _db
          .from('posts')
          .select('now()')
          .limit(1)
          .maybeSingle();

      if (response == null || response['now'] == null) return null;

      // Supabase returns UTC time, so keep it consistent
      return DateTime.parse(response['now']).toUtc();
    } catch (e) {
      print('Error fetching server time: $e');
      return null;
    }
  }
}
