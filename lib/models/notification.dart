class Notification {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    required this.isRead,
    required this.createdAt,
  });

  // ✅ Supabase -> App
  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'].toString(), // ✅ key line
      userId: map['user_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString(),
      isRead: map['is_read'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ??
          DateTime.now()
          : DateTime.now(),
    );
  }

  // ✅ App -> Supabase (for inserts/updates)
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'title': title,
      'body': body,
      'is_read': isRead,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  // ✅ Copy with updated fields
  Notification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
