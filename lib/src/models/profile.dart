class Profile {
  final String id;
  final String displayName;
  final int verificationLevel;
  final String? avatarUrl;
  final List<String> subscribedTopics;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.displayName,
    required this.verificationLevel,
    this.avatarUrl,
    this.subscribedTopics = const <String>[],
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    verificationLevel: json['verification_level'] as int,
    avatarUrl: json['avatar_url'] as String?,
    subscribedTopics:
        ((json['subscribed_topics'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<String>()
            .map((String item) => item.trim())
            .where((String item) => item.isNotEmpty)
            .toList(growable: false),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Profile copyWith({
    String? id,
    String? displayName,
    int? verificationLevel,
    String? avatarUrl,
    List<String>? subscribedTopics,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      subscribedTopics: subscribedTopics ?? this.subscribedTopics,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'verification_level': verificationLevel,
    'avatar_url': avatarUrl,
    'subscribed_topics': subscribedTopics,
    'created_at': createdAt.toIso8601String(),
  };
}
