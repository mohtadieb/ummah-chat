class MessageModel {
  final String id;
  final String? chatRoomId;
  final String senderId;
  final String? receiverId;
  final String message;
  final String? imageUrl;
  final String? videoUrl;

  /// 🆕 ID of the message this one is replying to (nullable)
  final String? replyToMessageId;

  final DateTime createdAt;
  final bool isRead;
  final bool isDelivered;
  final DateTime? deliveredAt;
  final List<String> likedBy;
  final bool isDeleted;

  // 🆕 NEW: whether this message is still uploading media
  final bool isUploading;

  // 🆕 Voice message fields
  final String? audioUrl;
  final int? audioDurationSeconds;

  MessageModel({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    this.receiverId,
    required this.message,
    this.imageUrl,
    this.videoUrl,
    this.replyToMessageId, // 🆕
    required this.createdAt,
    this.isRead = false,
    this.isDelivered = false,
    this.deliveredAt,
    this.likedBy = const [],
    this.isUploading = false, // NEW default
    this.isDeleted = false,
    this.audioUrl,
    this.audioDurationSeconds,
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

  // 🆕 helper: treat this message as a "pure" audio message
  bool get isAudio =>
      (audioUrl != null && audioUrl!.trim().isNotEmpty) &&
          (imageUrl == null || imageUrl!.trim().isEmpty) &&
          (videoUrl == null || videoUrl!.trim().isEmpty);

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    // Normalize the audio URL to null if it's an empty string
    final rawAudioUrl = map['audio_url'];
    final String? normalizedAudioUrl = (rawAudioUrl == null)
        ? null
        : rawAudioUrl.toString().trim().isEmpty
        ? null
        : rawAudioUrl.toString();

    return MessageModel(
      id: map['id'].toString(),
      chatRoomId: map['chat_room_id']?.toString(),
      senderId: map['sender_id'].toString(),
      receiverId: map['receiver_id']?.toString(),
      message: (map['message'] ?? '').toString(),
      imageUrl: map['image_url']?.toString(),
      videoUrl: map['video_url']?.toString(),
      replyToMessageId: map['reply_to_message_id']?.toString(), // 🆕
      createdAt: parseDate(map['created_at']),
      isRead: map['is_read'] == true,
      isDelivered: map['is_delivered'] == true,
      deliveredAt: parseNullableDate(map['delivered_at']),
      likedBy: parseLikedBy(map['liked_by']),
      isUploading: map['is_uploading'] == true,
      isDeleted: map['is_deleted'] == true,

      // 🆕 Voice fields
      audioUrl: normalizedAudioUrl,
      audioDurationSeconds:
      (map['audio_duration_seconds'] as num?)?.toInt(), // safe for double/int
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
      'reply_to_message_id': replyToMessageId, // 🆕
      'is_read': isRead,
      'is_delivered': isDelivered,
      'delivered_at': deliveredAt?.toUtc().toIso8601String(),
      'liked_by': likedBy,
      'is_uploading': isUploading,
      'is_deleted': isDeleted,

      // 🆕 Voice fields
      'audio_url': audioUrl,
      'audio_duration_seconds': audioDurationSeconds,
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
    String? replyToMessageId,
    bool? isRead,
    bool? isDelivered,
    DateTime? deliveredAt,
    List<String>? likedBy,
    bool? isUploading,
    bool? isDeleted,

    // 🆕 Voice fields in copyWith
    String? audioUrl,
    int? audioDurationSeconds,
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
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      likedBy: likedBy ?? this.likedBy,
      isUploading: isUploading ?? this.isUploading,
      isDeleted: isDeleted ?? this.isDeleted,

      // 🆕 carry over / override audio fields
      audioUrl: audioUrl ?? this.audioUrl,
      audioDurationSeconds:
      audioDurationSeconds ?? this.audioDurationSeconds,
    );
  }
}
