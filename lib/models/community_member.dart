class CommunityMember {
  final String id;
  final String communityId;
  final String userId;
  final DateTime joinedAt;

  CommunityMember({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.joinedAt,
  });

  factory CommunityMember.fromMap(Map<String, dynamic> map) {
    return CommunityMember(
      id: map['id']?.toString() ?? '',
      communityId: map['community_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      joinedAt: map['joined_at'] != null
          ? DateTime.tryParse(map['joined_at'].toString())?.toLocal() ??
          DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'community_id': communityId,
      'user_id': userId,
      'joined_at': joinedAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  CommunityMember copyWith({
    String? id,
    String? communityId,
    String? userId,
    DateTime? joinedAt,
  }) {
    return CommunityMember(
      id: id ?? this.id,
      communityId: communityId ?? this.communityId,
      userId: userId ?? this.userId,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
