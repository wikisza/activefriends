import 'package:activefriends/src/features/forum/data/datasources/forum_remote_datasource.dart';
import 'package:activefriends/src/models/forum_comment.dart';
import 'package:activefriends/src/models/forum_topic.dart';

abstract class ForumRepository {
  Future<List<ForumTopic>> getTopics({
    String? filter,
    String? searchQuery,
    String? sortBy,
    String? category,
  });
  Future<ForumTopic> createTopic(String title, String? description, String? category);
  Future<List<ForumComment>> getComments(String topicId);
  Future<ForumComment> addComment(String topicId, String content, {String? parentId});
  Future<void> subscribeToTopic(String topicId);
  Future<void> unsubscribeFromTopic(String topicId);
  Future<void> editComment(String commentId, String newContent);
  Future<void> deleteComment(String commentId);
  Future<void> voteComment(String commentId, int vote);
}

class ForumRepositoryImpl implements ForumRepository {
  final ForumRemoteDataSource remoteDataSource;

  ForumRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<ForumTopic>> getTopics({
    String? filter,
    String? searchQuery,
    String? sortBy,
    String? category,
  }) {
    return remoteDataSource.getTopics(
      filter: filter,
      searchQuery: searchQuery,
      sortBy: sortBy,
      category: category,
    );
  }

  @override
  Future<ForumTopic> createTopic(String title, String? description, String? category) {
    return remoteDataSource.createTopic(title, description, category);
  }

  @override
  Future<List<ForumComment>> getComments(String topicId) {
    return remoteDataSource.getComments(topicId);
  }

  @override
  Future<ForumComment> addComment(String topicId, String content, {String? parentId}) {
    return remoteDataSource.addComment(topicId, content, parentId: parentId);
  }

  @override
  Future<void> subscribeToTopic(String topicId) {
    return remoteDataSource.subscribeToTopic(topicId);
  }

  @override
  Future<void> unsubscribeFromTopic(String topicId) {
    return remoteDataSource.unsubscribeFromTopic(topicId);
  }

  @override
  Future<void> editComment(String commentId, String newContent) {
    return remoteDataSource.editComment(commentId, newContent);
  }

  @override
  Future<void> deleteComment(String commentId) {
    return remoteDataSource.deleteComment(commentId);
  }

  @override
  Future<void> voteComment(String commentId, int vote) {
    return remoteDataSource.voteComment(commentId, vote);
  }
}