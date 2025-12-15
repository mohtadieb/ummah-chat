class Post {
  final String id;
  final String userId;
  final String name;
  final String username;
  final String message;
  final String? communityId;   // optional community
  final DateTime createdAt;
  final int likeCount;

  Post({
    required this.id,
    required this.userId,
    required this.name,
    required this.username,
    required this.message,
    this.communityId,
    required this.createdAt,
    required this.likeCount,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'].toString(),
      userId: map['user_id'] ?? '',
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      message: map['message'] ?? '',
      communityId: map['community_id']?.toString(),
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      likeCount: map['like_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'user_id': userId,
      'name': name,
      'username': username,
      'message': message,
      'community_id': communityId,
      'created_at': createdAt.toIso8601String(),
      'like_count': likeCount,
    };

    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  Post copyWith({
    String? id,
    String? message,
    String? communityId,
    int? likeCount,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId,
      name: name,
      username: username,
      message: message ?? this.message,
      communityId: communityId ?? this.communityId,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
    );
  }
}
