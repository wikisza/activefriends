import 'package:activefriends/src/models/forum_comment.dart';
import 'package:activefriends/src/models/forum_topic.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ForumRemoteDataSource {
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
  Future<void> voteComment(String commentId, int vote); // 1 like, -1 dislike
}

class ForumRemoteDataSourceImpl implements ForumRemoteDataSource {
  final SupabaseClient _client;

  ForumRemoteDataSourceImpl(this._client);

  @override
  Future<List<ForumTopic>> getTopics({
    String? filter,
    String? searchQuery,
    String? sortBy,
    String? category,
  }) async {
    var query = _client.from('forum_topics').select();

    if (filter == 'subscribed') {
      query = query.eq('is_subscribed', true);
    } else if (filter != null && filter != 'all') {
      // Assume filter is topic id
      query = query.eq('id', filter);
    }

    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
    }

    String orderColumn = 'created_at';
    bool ascending = false;
    if (sortBy == 'oldest') {
      ascending = true;
    } else if (sortBy == 'comments') {
      orderColumn = 'comment_count';
    }

    final response = await query.order(orderColumn, ascending: ascending);
    return (response as List).map((json) => ForumTopic.fromJson(json)).toList();
  }

  @override
  Future<ForumTopic> createTopic(String title, String? description, String? category) async {
    final userId = _client.auth.currentUser!.id;
    final response = await _client.from('forum_topics').insert({
      'title': title,
      'description': description,
      'category': category,
      'author_id': userId,
    }).select().single();

    return ForumTopic.fromJson(response);
  }

  @override
  Future<List<ForumComment>> getComments(String topicId) async {
    final response = await _client
        .from('forum_comments')
        .select('*, profiles(display_name)')
        .eq('topic_id', topicId)
        .order('created_at', ascending: true);

    return (response as List).map((json) => ForumComment.fromJson(json)).toList();
  }

  @override
  Future<ForumComment> addComment(String topicId, String content, {String? parentId}) async {
    final userId = _client.auth.currentUser!.id;
    final response = await _client.from('forum_comments').insert({
      'topic_id': topicId,
      'author_id': userId,
      'content': content,
      'parent_id': parentId,
    }).select().single();

    // Zwiększ licznik komentarzy dla tematu
    await _client.rpc('increment_comment_count', params: {'topic_id': topicId});

    return ForumComment.fromJson(response);
  }

  @override
  Future<void> subscribeToTopic(String topicId) async {
    await _client.from('forum_topics').update({'is_subscribed': true}).eq('id', topicId);
  }

  @override
  Future<void> unsubscribeFromTopic(String topicId) async {
    await _client.from('forum_topics').update({'is_subscribed': false}).eq('id', topicId);
  }

  @override
  Future<void> editComment(String commentId, String newContent) async {
    await _client.from('forum_comments').update({'content': newContent}).eq('id', commentId);
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _client.from('forum_comments').delete().eq('id', commentId);
  }

  @override
  Future<void> voteComment(String commentId, int vote) async {
    final userId = _client.auth.currentUser!.id;

    // Check if vote exists
    final existingVote = await _client
        .from('forum_comment_votes')
        .select()
        .eq('user_id', userId)
        .eq('comment_id', commentId)
        .maybeSingle();

    if (existingVote != null) {
      if ((existingVote['vote'] as int) == vote) {
        // Remove vote
        await _client.from('forum_comment_votes').delete().eq('id', existingVote['id']);
        // Update comment counts
        await _updateCommentVotes(commentId);
      } else {
        // Change vote
        await _client.from('forum_comment_votes').update({'vote': vote}).eq('id', existingVote['id']);
        await _updateCommentVotes(commentId);
      }
    } else {
      // Add new vote
      await _client.from('forum_comment_votes').insert({
        'user_id': userId,
        'comment_id': commentId,
        'vote': vote,
      });
      await _updateCommentVotes(commentId);
    }
  }

  Future<void> _updateCommentVotes(String commentId) async {
    final likes = await _client
        .from('forum_comment_votes')
        .select()
        .eq('comment_id', commentId)
        .eq('vote', 1)
        .count();

    final dislikes = await _client
        .from('forum_comment_votes')
        .select()
        .eq('comment_id', commentId)
        .eq('vote', -1)
        .count();

    await _client.from('forum_comments').update({
      'likes': likes.count,
      'dislikes': dislikes.count,
    }).eq('id', commentId);
  }
}