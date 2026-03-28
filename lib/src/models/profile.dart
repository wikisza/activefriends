class Profile {
  final String id;
  final String displayName;
  final int verificationLevel;
  final String? avatarUrl;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.displayName,
    required this.verificationLevel,
    this.avatarUrl,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        verificationLevel: json['verification_level'] as int,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'verification_level': verificationLevel,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
      };
}
