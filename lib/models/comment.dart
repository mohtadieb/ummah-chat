class Comment {
  final String id;
  final String postId;
  final String userId;
  final String name;
  final String username;
  final String message;
  final DateTime createdAt;
  final String? profilePhotoUrl; // 👈 NEW

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.name,
    required this.username,
    required this.message,
    required this.createdAt,
    this.profilePhotoUrl, // 👈 NEW
  });

  /// Supabase -> App
  factory Comment.fromMap(Map<String, dynamic> data) {
    return Comment(
      id: data['id']?.toString() ?? '',
      postId: data['post_id'] ?? '',
      userId: data['user_id'] ?? '',
      name: data['name'] ?? '',
      username: data['username'] ?? '',
      message: data['message'] ?? '',
      profilePhotoUrl: data['profile_photo_url'], // 👈 NEW
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString())?.toLocal() ??
          DateTime.now()
          : DateTime.now(),
    );
  }

  /// App -> Supabase
  Map<String, dynamic> toMap() {
    final map = {
      'post_id': postId,
      'user_id': userId,
      'name': name,
      'username': username,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'profile_photo_url': profilePhotoUrl, // 👈 NEW
    };

    if (id.isNotEmpty) map['id'] = id;

    return map;
  }

  /// Copy with updated fields
  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? name,
    String? username,
    String? message,
    DateTime? createdAt,
    String? profilePhotoUrl, // 👈 NEW
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      username: username ?? this.username,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
    );
  }
}