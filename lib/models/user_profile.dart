class UserProfile {
  final String id; // matches Supabase 'profiles.id'
  final String name;
  final String email;
  final String username;
  final String bio;
  final String profilePhotoUrl;
  final DateTime createdAt;
  final String profileSongId;

  /// 🆕 Country (set on CompleteProfilePage)
  final String country;

  /// 🆕 City (editable in "About me")
  final String? city;

  /// 🆕 Gender: "male" or "female"
  final String gender;

  final List<String> languages;
  final List<String> interests;

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
    this.profileSongId = '',
    this.country = '',
    this.city,
    this.gender = '',
    this.languages = const [],
    this.interests = const [],
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
    final createdAtRaw = map['created_at'];
    final lastSeenRaw = map['last_seen_at'];

    DateTime parseDate(dynamic value) {
      if (value == null) {
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
      profileSongId: map['profile_song_id'] as String? ?? '',
      country: (map['country'] ?? '') as String,
      city: map['city'] as String?,
      gender: (map['gender'] ?? '') as String,
      languages: List<String>.from(map['languages'] ?? []),
      interests: List<String>.from(map['interests'] ?? []),
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
      'profile_song_id': profileSongId,
      'country': country,
      'city': city,
      'gender': gender,
      'languages': languages,
      'interests': interests,
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
    String? profileSongId,
    String? country,
    String? city,
    String? gender,
    List<String>? languages,
    List<String>? interests,
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
      profileSongId: profileSongId ?? this.profileSongId,
      country: country ?? this.country,
      city: city ?? this.city,
      gender: gender ?? this.gender,
      languages: languages ?? this.languages,
      interests: interests ?? this.interests,
    );
  }
}
