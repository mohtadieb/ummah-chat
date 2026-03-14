class Post {
  final String id;
  final String userId;
  final String name;
  final String username;
  final String message;
  final String? communityId;
  final String? profilePhotoUrl; // NEW
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  Post({
    required this.id,
    required this.userId,
    required this.name,
    required this.username,
    required this.message,
    this.communityId,
    this.profilePhotoUrl,
    required this.createdAt,
    required this.likeCount,
    this.commentCount = 0,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'].toString(),
      userId: map['user_id'] ?? '',
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      message: map['message'] ?? '',
      communityId: map['community_id']?.toString(),
      profilePhotoUrl: map['profile_photo_url']?.toString(),
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      likeCount: map['like_count'] ?? 0,
      commentCount: (map['comment_count'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'user_id': userId,
      'name': name,
      'username': username,
      'message': message,
      'community_id': communityId,
      'profile_photo_url': profilePhotoUrl,
      'created_at': createdAt.toIso8601String(),
      'like_count': likeCount,
      'comment_count': commentCount,
    };

    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  Post copyWith({
    String? id,
    String? message,
    String? communityId,
    String? profilePhotoUrl,
    int? likeCount,
    int? commentCount,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId,
      name: name,
      username: username,
      message: message ?? this.message,
      communityId: communityId ?? this.communityId,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
    );
  }
}