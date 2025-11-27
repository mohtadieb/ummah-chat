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

import 'package:flutter/cupertino.dart';
import 'package:ummah_chat/services/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../../models/user.dart';
import '../notification_service.dart';

// 🆕 Notifications

class DatabaseService {
  // get instance of supabase
  final _db = Supabase.instance.client;
  final _auth = Supabase.instance.client.auth;
  late final _storage = _db.storage;

  // 🆕 Notification service (used to create in-app notifications)
  final NotificationService _notifications = NotificationService();

  /* ==================== USER PROFILE ==================== */

  /// Save user in database
  Future<void> saveUserInDatabase({
    required String name,
    required String email,
  }) async {
    try {
      // get current userId
      String currentUserId = _auth.currentUser!.id;

      // Generate a safe username
      String username = email.split('@').first.trim();
      if (username.isEmpty) {
        username = 'user_$currentUserId';
      }

      // Create user profile
      UserProfile user = UserProfile(
        id: currentUserId,
        name: name,
        email: email,
        username: username,
        bio: '',
        createdAt: DateTime.now().toUtc(),
      );

      // convert user into map so that we can store in in supabase
      final userMap = user.toMap();

      print('Inserting user: $userMap');

      // save user in database
      await _db.from('profiles').insert(userMap);
    } catch (e, st) {
      print("Error saving user info: $e\n$st");
    }
  }

  /// Get user from database
  Future<UserProfile?> getUserFromDatabase(String userId) async {
    // Retrieve user info from database
    try {
      final userData =
      await _db.from('profiles').select().eq('id', userId).maybeSingle();
      if (userData == null) return null;

      // Convert userData to user profile
      return UserProfile.fromMap(userData);
    } catch (e) {
      print("Error fetching user: $e");
      return null;
    }
  }

  /// Update user bio
  Future<void> updateUserBioInDatabase(String bio) async {
    // Get current user Id
    final currentUserId = _auth.currentUser!.id;

    try {
      await _db.from('profiles').update({'bio': bio}).eq('id', currentUserId);
    } catch (e) {
      print("Error updating bio: $e");
    }
  }

  /* ==================== POSTS ==================== */

  /// Create a new post (global or community) and insert into database
  ///
  /// - `communityId == null` → normal homepage / global post
  /// - `communityId != null` → post belongs to that community
  Future<void> postMessageInDatabase(
      String message, {
        File? imageFile,
        String? communityId, // ✅ NEW
      }) async {
    try {
      final currentUserId = _auth.currentUser!.id;

      final user = await getUserFromDatabase(currentUserId);
      if (user == null) throw Exception("User profile not found");

      String? imageUrl;

      // If an image was picked, upload it to Supabase Storage
      if (imageFile != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${currentUserId}.jpg';
        final storagePath = 'posts/$fileName';

        // Convert file to bytes
        final bytes = await imageFile.readAsBytes();

        // Upload to Supabase Storage
        await _db.storage.from('post_images').uploadBinary(storagePath, bytes);

        // Get public URL
        imageUrl = _db.storage.from('post_images').getPublicUrl(storagePath);
      }

      // Create new post object
      Post newPost = Post(
        id: '',
        userId: currentUserId,
        name: user.name,
        username: user.username,
        message: message,
        imageUrl: imageUrl,
        communityId: communityId, // ✅ store the community link (can be null)
        createdAt: DateTime.now().toUtc(),
        likeCount:
        0, // initial value; DB trigger will keep this in sync with post_likes
      );

      // Insert post into database
      await _db.from('posts').insert(newPost.toMap()).select().single();
    } catch (e) {
      print("Error posting message: $e");
    }
  }

  /// Delete a post
  Future<void> deletePostFromDatabase(String postId,
      {String? imagePath}) async {
    try {
      // 1️⃣ Delete image from Supabase Storage if provided
      if (imagePath != null && imagePath.isNotEmpty) {
        try {
          // Extract the relative path inside the bucket
          // Example: https://xyz.supabase.co/storage/v1/object/public/post_images/my_image.jpg
          // => we only want: "my_image.jpg" (everything after 'post_images/')
          final uri = Uri.parse(imagePath);
          final segments = uri.pathSegments;
          final bucketIndex = segments.indexOf('post_images');
          String? pathToDelete;
          if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
            pathToDelete = segments.sublist(bucketIndex + 1).join('/');
          }

          if (pathToDelete != null && pathToDelete.isNotEmpty) {
            await _storage.from('post_images').remove([pathToDelete]);
            print('Image deleted from storage: $pathToDelete');
          }
        } catch (e) {
          print('Error deleting image from storage: $e');
        }
      }

      // 2️⃣ Delete post from database
      await _db.from('posts').delete().eq('id', postId);
      print('Post deleted from database: $postId');
    } catch (e) {
      print("Error deleting post (or image): $e");
    }
  }

  /// Get all posts
  ///
  /// This returns both:
  /// - global posts (`community_id IS NULL`)
  /// - community posts (`community_id IS NOT NULL`)
  /// and your UI decides how to filter them.
  Future<List<Post>> getAllPostsFromDatabase() async {
    try {
      final List data = await _db
      // Go to collection "posts"
          .from('posts')
      // Select all fields
          .select()
      // Chronological order
          .order('created_at', ascending: false) as List;

      // Return as list of posts
      return data.map((e) => Post.fromMap(e)).toList();
    } catch (e) {
      print("Error fetching all posts: $e");
      return [];
    }
  }

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

          // Machine-readable + human preview
          final body = 'LIKE_POST:$postId::$rawPreview';

          await _notifications.createNotificationForUser(
            targetUserId: postOwnerId,
            title: '$displayName liked your post',
            body: body,
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

  Future<Post?> getPostByIdFromDatabase(String postId) async {
    try {
      final data =
      await _db.from('posts').select().eq('id', postId).maybeSingle();

      if (data == null) return null;
      return Post.fromMap(data);
    } catch (e) {
      print("Error fetching post by id $postId: $e");
      return null;
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
          final displayName =
          user.username.isNotEmpty ? user.username : user.name;

          final postPreview = (postData?['message']?.toString() ?? '').trim();
          final truncatedPostPreview = postPreview.length > 50
              ? '${postPreview.substring(0, 50)}...'
              : postPreview;

          final body = 'COMMENT_POST:$postId::$truncatedPostPreview';

          await _notifications.createNotificationForUser(
            targetUserId: postOwnerId,
            title: '$displayName commented on your post',
            body: body,
          );
        } catch (e) {
          print('⚠️ Error creating comment notification: $e');
        }
      }
    } catch (e) {
      print("Error adding comment: $e");
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
        'created_at':
        DateTime.now().toUtc().toIso8601String(), // Use current timestamp
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
      final currentUser = _auth.currentUser!.id;

      await _db.from('blocks').insert({
        'blocker_id': currentUser,
        'blocked_id': userId,
      });
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
    final blockedUserPosts =
    await _db.from('posts').select('id').eq('user_id', blockedUserId);

    final blockedPostIds =
    (blockedUserPosts as List).map((p) => p['id'] as String).toList();

    // 2️⃣ Get all post IDs by current user
    final currentUserPosts =
    await _db.from('posts').select('id').eq('user_id', currentUserId);

    final currentPostIds =
    (currentUserPosts as List).map((p) => p['id'] as String).toList();

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
      final row = await _db
          .from('friendships')
          .select('requester_id, addressee_id, status')
          .or(
        'and(requester_id.eq.$currentUserId,addressee_id.eq.$otherUserId),'
            'and(requester_id.eq.$otherUserId,addressee_id.eq.$currentUserId)',
      )
          .maybeSingle();

      if (row == null) return 'none';

      final status = (row['status'] as String?) ?? 'pending';
      final requesterId = row['requester_id']?.toString();
      final addresseeId = row['addressee_id']?.toString();

      if (status == 'accepted' || status == 'blocked') {
        return status; // 'accepted' or 'blocked'
      }

      // status == 'pending'
      if (requesterId == currentUserId) {
        return 'pending_sent';
      } else if (addresseeId == currentUserId) {
        return 'pending_received';
      }

      return 'none';
    } catch (e) {
      print('❌ Error fetching friendship status: $e');
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
        print('ℹ️ Friendship already exists with status: ${existing['status']}');
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
          // 🔴 IMPORTANT: special body format so UI knows this is a friend request
          body: 'FRIEND_REQUEST:$currentUserId',
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
          title: '$displayName accepted your friend request',
          // 👇 encode who accepted it
          body: 'FRIEND_ACCEPTED:$currentUserId',
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
      await _db
          .from('friendships')
          .delete()
          .eq('requester_id', currentUserId)
          .eq('addressee_id', otherUserId)
          .eq('status', 'pending');

      print('✅ Friend request cancelled');
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
      final friendIds = filtered.map<String>((row) {
        final requester = row['requester_id'] as String;
        final addressee = row['addressee_id'] as String;
        return requester == userId ? addressee : requester;
      }).toSet().toList(); // ensure unique

      // ✅ Fetch UserProfile objects for each friend
      final profiles = <UserProfile>[];
      for (final fid in friendIds) {
        final profile = await getUserFromDatabase(fid);
        if (profile != null) profiles.add(profile);
      }

      debugPrint(
          '✅ friendsStreamFromDatabase returning ${profiles.length} profiles');
      return profiles;
    });
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

      // 2️⃣ Follow notification
      try {
        final followerProfile = await getUserFromDatabase(currentUserId);
        final displayName = (followerProfile?.username.isNotEmpty ?? false)
            ? followerProfile!.username
            : (followerProfile?.name ?? 'Someone');

        await _notifications.createNotificationForUser(
          targetUserId: targetUserId,
          title: '$displayName started following you',
          body: 'FOLLOW_USER:$currentUserId',
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
      await _db
          .from('follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId);

      print("✅ Unfollow successful");
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
    if (searchTerm.isEmpty) return [];

    // Prevent wildcard abuse (e.g. * * * returning all users)
    if (RegExp(r'^[*]+$').hasMatch(searchTerm)) return [];

    try {
      final List data = await _db
          .from('profiles')
          .select()
          .or('username.ilike.${searchTerm}%,name.ilike.${searchTerm}%');

      // Sort results so exact or prefix matches appear first
      data.sort((a, b) {
        final nameA = (a['username'] as String).toLowerCase();
        final nameB = (b['username'] as String).toLowerCase();
        final term = searchTerm.toLowerCase();
        final startsA = nameA.startsWith(term) ? 0 : 1;
        final startsB = nameB.startsWith(term) ? 0 : 1;
        return startsA.compareTo(startsB);
      });

      return data.map((e) => UserProfile.fromMap(e)).toList();
    } catch (e) {
      print("Error searching users: $e");
      return [];
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

  // Create new community
  Future<void> createCommunityInDatabase(
      String name, String desc, String country) async {
    try {
      final userId = _auth.currentUser!.id;
      await _db.from('communities').insert({
        'name': name,
        'description': desc,
        'country': country,
        'created_by': userId,
      });
    } catch (e) {
      print("❌ Error creating community: $e");
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
      String query) async {
    try {
      final userId = _auth.currentUser!.id;
      final response = await _db
          .from('communities')
          .select('id, name, description, members:community_members(user_id)')
          .ilike('name', '%$query%');
      return (response as List)
          .map((c) => {
        'id': c['id'],
        'name': c['name'],
        'description': c['description'],
        'is_joined': (c['members'] as List)
            .any((m) => m['user_id'] == userId),
      })
          .toList();
    } catch (e) {
      print("❌ Error searching communities: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCommunityMembersFromDatabase(
      String communityId) async {
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
      String communityId) async {
    try {
      // Step 1: Get all user_ids from community_members
      final memberLinks = await _db
          .from('community_members')
          .select('user_id')
          .eq('community_id', communityId);

      if (memberLinks.isEmpty) return [];

      // Extract user_ids
      final userIds =
      (memberLinks as List).map((m) => m['user_id'].toString()).toList();

      // Step 2: Fetch full profiles from profiles table
      // Using filter 'id' in array
      final profiles = await _db
          .from('profiles')
          .select()
          .filter('id', 'in',
          '(${userIds.join(',')})'); // Supabase requires string like "(id1,id2)"

      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) {
      print("❌ Error fetching community member profiles: $e");
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

      await _db.from('story_progress').upsert(
        data,
        onConflict: 'user_id,story_id',
      );
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
      await _db.from('story_progress').upsert(
        {
          'user_id': currentUserId,
          'story_id': storyId,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
          // answers will stay as-is if row already exists
        },
        onConflict: 'user_id,story_id',
      );
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

  /* ==================== TIME ==================== */

  Future<DateTime?> getServerTime() async {
    try {
      final response =
      await _db.from('posts').select('now()').limit(1).maybeSingle();

      if (response == null || response['now'] == null) return null;

      // Supabase returns UTC time, so keep it consistent
      return DateTime.parse(response['now']).toUtc();
    } catch (e) {
      print('Error fetching server time: $e');
      return null;
    }
  }
}
