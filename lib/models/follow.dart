class Follow {
  final String followerId;
  final String followingId;
  final DateTime createdAt;

  Follow({
    required this.followerId,
    required this.followingId,
    required this.createdAt,
  });

  factory Follow.fromMap(Map<String, dynamic> map) {
    return Follow(
      followerId: map['follower_id']?.toString() ?? '',
      followingId: map['following_id']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ??
          DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'follower_id': followerId,
      'following_id': followingId,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  Follow copyWith({
    String? followerId,
    String? followingId,
    DateTime? createdAt,
  }) {
    return Follow(
      followerId: followerId ?? this.followerId,
      followingId: followingId ?? this.followingId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
