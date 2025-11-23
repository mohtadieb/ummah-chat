class Block {
  final String blockerId;
  final String blockedId;
  final DateTime createdAt;

  Block({
    required this.blockerId,
    required this.blockedId,
    required this.createdAt,
  });

  factory Block.fromMap(Map<String, dynamic> map) {
    return Block(
      blockerId: map['blocker_id']?.toString() ?? '',
      blockedId: map['blocked_id']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ??
          DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'blocker_id': blockerId,
      'blocked_id': blockedId,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  Block copyWith({
    String? blockerId,
    String? blockedId,
    DateTime? createdAt,
  }) {
    return Block(
      blockerId: blockerId ?? this.blockerId,
      blockedId: blockedId ?? this.blockedId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
