class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final String? chatRoomId;
  final DateTime createdAt;

  /// Optional image URL for image messages (from image_url in DB)
  final String? imageUrl;

  /// Whether the receiver has read this message (from `is_read` in DB)
  final bool isRead;

  /// Whether the message has been delivered to the receiver (from `is_delivered` in DB)
  final bool isDelivered;

  /// When the message was delivered (if stored in `delivered_at`)
  final DateTime? deliveredAt;

  /// Users who liked this message (from `liked_by` text[] in DB)
  final List<String> likedBy;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.createdAt,
    this.chatRoomId,
    this.imageUrl,
    this.isRead = false,
    this.isDelivered = false,
    this.deliveredAt,
    this.likedBy = const [],
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      return DateTime.tryParse(value.toString())?.toLocal() ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString())?.toLocal();
    }

    // liked_by can be null, List<dynamic>, etc.
    List<String> parseLikedBy(dynamic value) {
      if (value == null) return const [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return MessageModel(
      id: map['id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      receiverId: map['receiver_id']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      chatRoomId: map['chat_room_id']?.toString(),
      createdAt: parseDate(map['created_at']),

      // 🆕 image_url is optional
      imageUrl: map['image_url']?.toString(),

      // Safely read booleans; anything "truthy" becomes true
      isRead: map['is_read'] == true,
      isDelivered: map['is_delivered'] == true,

      deliveredAt: parseNullableDate(map['delivered_at']),
      likedBy: parseLikedBy(map['liked_by']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'created_at': createdAt.toUtc().toIso8601String(),
      'chat_room_id': chatRoomId,
      'image_url': imageUrl, // 🆕 include optional imageUrl
      'is_read': isRead,
      'is_delivered': isDelivered,
      'delivered_at': deliveredAt?.toUtc().toIso8601String(),
      'liked_by': likedBy,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? message,
    String? chatRoomId,
    DateTime? createdAt,
    String? imageUrl,
    bool? isRead,
    bool? isDelivered,
    DateTime? deliveredAt,
    List<String>? likedBy,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      likedBy: likedBy ?? this.likedBy,
    );
  }
}
