class ChatRoom {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime createdAt;

  ChatRoom({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.createdAt,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> map) {
    return ChatRoom(
      id: map['id']?.toString() ?? '',
      user1Id: map['user1_id']?.toString() ?? '',
      user2Id: map['user2_id']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ??
          DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'user1_id': user1Id,
      'user2_id': user2Id,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  ChatRoom copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    DateTime? createdAt,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
