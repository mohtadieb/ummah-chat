class Community {
  final String id; // matches Supabase 'communities.id'
  final String name;
  final String description;
  final String country;
  final String createdBy; // userId of the creator
  final DateTime createdAt;
  final int memberCount; // optional, useful if you join/leave
  final bool isJoined; // optional, for UI state

  Community({
    required this.id,
    required this.name,
    required this.description,
    required this.country,
    required this.createdBy,
    required this.createdAt,
    this.memberCount = 0,
    this.isJoined = false,
  });

  /// ✅ Supabase -> App
  factory Community.fromMap(Map<String, dynamic> map) {
    return Community(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      country: map['country'] ?? '',
      createdBy: map['created_by'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      memberCount: map['member_count'] ?? 0,
      isJoined: map['is_joined'] ?? false,
    );
  }

  /// ✅ App -> Supabase
  Map<String, dynamic> toMap() {
    final map = {
      'name': name,
      'description': description,
      'country': country,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };

    if (id.isNotEmpty) map['id'] = id;

    return map;
  }

  /// ✅ Copy with updated fields
  Community copyWith({
    String? id,
    String? name,
    String? description,
    String? country,
    String? createdBy,
    DateTime? createdAt,
    int? memberCount,
    bool? isJoined,
  }) {
    return Community(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      country: country ?? this.country,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
      isJoined: isJoined ?? this.isJoined,
    );
  }
}