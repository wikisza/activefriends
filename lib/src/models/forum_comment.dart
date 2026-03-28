import 'package:equatable/equatable.dart';

class ForumComment extends Equatable {
  const ForumComment({
    required this.id,
    required this.topicId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.parentId,
    required this.likes,
    required this.dislikes,
    required this.createdAt,
  });

  final String id;
  final String topicId;
  final String authorId;
  final String authorName;
  final String content;
  final String? parentId;
  final int likes;
  final int dislikes;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, topicId, authorId, authorName, content, parentId, likes, dislikes, createdAt];

  factory ForumComment.fromJson(Map<String, dynamic> json) {
    return ForumComment(
      id: json['id'] as String,
      topicId: json['topic_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['profiles'] != null ? json['profiles']['display_name'] as String : 'Anonimowy',
      content: json['content'] as String,
      parentId: json['parent_id'] as String?,
      likes: json['likes'] as int,
      dislikes: json['dislikes'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic_id': topicId,
      'author_id': authorId,
      'content': content,
      'parent_id': parentId,
      'likes': likes,
      'dislikes': dislikes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}