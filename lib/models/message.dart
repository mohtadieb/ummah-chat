class MessageModel {
  final String id;
  final String? chatRoomId;
  final String senderId;
  final String? receiverId;
  final String message;
  final String? imageUrl;
  final String? videoUrl;
  final DateTime createdAt;
  final bool isRead;
  final bool isDelivered;
  final DateTime? deliveredAt;
  final List<String> likedBy;
  final bool isDeleted;


  // 🆕 NEW: whether this message is still uploading media
  final bool isUploading;

  MessageModel({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    this.receiverId,
    required this.message,
    this.imageUrl,
    this.videoUrl,
    required this.createdAt,
    this.isRead = false,
    this.isDelivered = false,
    this.deliveredAt,
    this.likedBy = const [],
    this.isUploading = false, // NEW default
    this.isDeleted = false,
  });

  /// Safely parse DateTime from various possible types.
  static DateTime parseDate(dynamic value) {
    if (value is DateTime) {
      return value.toUtc();
    } else if (value is String) {
      return DateTime.parse(value).toUtc();
    } else {
      return DateTime.now().toUtc();
    }
  }

  /// Safely parse an optional DateTime.
  static DateTime? parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.parse(value).toUtc();
    }
    return null;
  }

  /// Safely parse liked_by array (from Postgres text[] or json list)
  static List<String> parseLikedBy(dynamic value) {
    if (value == null) return <String>[];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'].toString(),
      chatRoomId: map['chat_room_id']?.toString(),
      senderId: map['sender_id'].toString(),
      receiverId: map['receiver_id']?.toString(),
      message: (map['message'] ?? '').toString(),
      imageUrl: map['image_url']?.toString(),
      videoUrl: map['video_url']?.toString(),
      createdAt: parseDate(map['created_at']),
      isRead: map['is_read'] == true,
      isDelivered: map['is_delivered'] == true,
      deliveredAt: parseNullableDate(map['delivered_at']),
      likedBy: parseLikedBy(map['liked_by']),
      // 🆕 map DB column → field
      isUploading: map['is_uploading'] == true,
      isDeleted: map['is_deleted'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'created_at': createdAt.toUtc().toIso8601String(),
      'chat_room_id': chatRoomId,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'is_read': isRead,
      'is_delivered': isDelivered,
      'delivered_at': deliveredAt?.toUtc().toIso8601String(),
      'liked_by': likedBy,
      'is_uploading': isUploading,
      'is_deleted': isDeleted,
    };

    if (id.isNotEmpty) {
      map['id'] = id;
    }

    return map;
  }

  MessageModel copyWith({
    String? id,
    String? chatRoomId,
    String? senderId,
    String? receiverId,
    String? message,
    DateTime? createdAt,
    String? imageUrl,
    String? videoUrl,
    bool? isRead,
    bool? isDelivered,
    DateTime? deliveredAt,
    List<String>? likedBy,
    bool? isUploading,
    bool? isDeleted,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      likedBy: likedBy ?? this.likedBy,
      isUploading: isUploading ?? this.isUploading,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
