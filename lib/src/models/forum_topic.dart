import 'package:equatable/equatable.dart';

class ForumTopic extends Equatable {
  const ForumTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.authorId,
    required this.category,
    required this.isSubscribed,
    required this.commentCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String authorId;
  final String? category;
  final bool isSubscribed;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, title, description, authorId, category, isSubscribed, commentCount, createdAt, updatedAt];

  factory ForumTopic.fromJson(Map<String, dynamic> json) {
    return ForumTopic(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      authorId: json['author_id'] as String,
      category: json['category'] as String?,
      isSubscribed: json['is_subscribed'] as bool,
      commentCount: json['comment_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'author_id': authorId,
      'category': category,
      'is_subscribed': isSubscribed,
      'comment_count': commentCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}