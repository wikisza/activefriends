class Topic {
  final String id;
  final String code;
  final String label;
  final String iconName;
  final DateTime createdAt;

  const Topic({
    required this.id,
    required this.code,
    required this.label,
    required this.iconName,
    required this.createdAt,
  });

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as String,
        code: json['code'] as String,
        label: json['label'] as String,
        iconName: json['icon_name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'label': label,
        'icon_name': iconName,
        'created_at': createdAt.toIso8601String(),
      };
}
