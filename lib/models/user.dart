class UserProfile {
  final String id; // matches Supabase 'profiles.id'
  final String name;
  final String email;
  final String username;
  final String bio;
  final String profilePhotoUrl;
  final DateTime createdAt;

  /// 🆕 When the user was last active in the app (UTC in Supabase)
  final DateTime? lastSeenAt;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.bio,
    this.profilePhotoUrl = '',
    required this.createdAt,
    this.lastSeenAt,
  });

  /// 🟢 Derived convenience: "online" if active in the last 5 minutes
  bool get isOnline {
    if (lastSeenAt == null) return false;
    final nowUtc = DateTime.now().toUtc();
    final lastUtc = lastSeenAt!.toUtc();
    final diff = nowUtc.difference(lastUtc);
    return diff.inMinutes < 5;
  }

  /// Create a UserProfile from a Supabase row (Map)
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    // Supabase usually returns timestamps as ISO 8601 strings
    final createdAtRaw = map['created_at'];
    final lastSeenRaw = map['last_seen_at'];

    DateTime parseDate(dynamic value) {
      if (value == null) {
        // fallback to now if created_at is unexpectedly null
        return DateTime.now().toUtc();
      }
      if (value is DateTime) return value.toUtc();
      return DateTime.parse(value.toString()).toUtc();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toUtc();
      return DateTime.parse(value.toString()).toUtc();
    }

    return UserProfile(
      id: map['id'] as String,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      username: (map['username'] ?? '') as String,
      bio: (map['bio'] ?? '') as String,
      profilePhotoUrl: (map['profile_photo_url'] ?? '') as String,
      createdAt: parseDate(createdAtRaw),
      lastSeenAt: parseNullableDate(lastSeenRaw),
    );
  }

  /// Convert to Map (e.g. if you ever want to upsert/update)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'username': username,
      'bio': bio,
      'profile_photo_url': profilePhotoUrl,
      'created_at': createdAt.toIso8601String(),
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toIso8601String(),
    };
  }

  /// Create a modified copy
  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? username,
    String? bio,
    String? profilePhotoUrl,
    DateTime? createdAt,
    DateTime? lastSeenAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}
