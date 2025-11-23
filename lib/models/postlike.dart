class PostLike {
  final String id;
  final String postId;
  final String userId;
  final DateTime createdAt;

  PostLike({
    required this.id,
    required this.postId,
    required this.userId,
    required this.createdAt,
  });

  factory PostLike.fromMap(Map<String, dynamic> map) {
    return PostLike(
      id: map['id']?.toString() ?? '',
      postId: map['post_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ??
          DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'post_id': postId,
      'user_id': userId,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  PostLike copyWith({
    String? id,
    String? postId,
    String? userId,
    DateTime? createdAt,
  }) {
    return PostLike(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
