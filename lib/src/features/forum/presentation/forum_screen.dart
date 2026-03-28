import 'package:activefriends/src/features/forum/data/datasources/forum_remote_datasource.dart';
import 'package:activefriends/src/features/forum/data/repositories/forum_repository.dart';
import 'package:activefriends/src/models/forum_comment.dart';
import 'package:activefriends/src/models/forum_topic.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  late final ForumRepository _repository;
  List<ForumTopic> _topics = [];
  String _filter = 'all';
  String _searchQuery = '';
  String _sortBy = 'newest';
  String? _selectedCategory;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['Rower', 'Ceramika', 'Pomoc'];

  @override
  void initState() {
    super.initState();
    _repository = ForumRepositoryImpl(
      ForumRemoteDataSourceImpl(Supabase.instance.client),
    );
    _loadTopics();
    _searchController.addListener(_onSearchChanged);
    _setupRealtimeNotifications();
  }

  void _setupRealtimeNotifications() {
    Supabase.instance.client
        .channel('forum_comments')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'forum_comments',
          callback: (payload) {
            // Show notification for new comments in subscribed topics
            final newComment = payload.newRecord;
            final topicId = newComment['topic_id'] as String;
            // Check if user is subscribed to this topic
            if (_topics.any((t) => t.id == topicId && t.isSubscribed)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nowy komentarz w subskrybowanym temacie!')),
              );
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text);
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);
    try {
      final topics = await _repository.getTopics(
        filter: _filter,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
        category: _selectedCategory,
      );
      setState(() {
        _topics = topics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania tematów: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Szukaj tematów...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _sortBy = value);
              _loadTopics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'newest', child: Text('Najnowsze')),
              const PopupMenuItem(value: 'oldest', child: Text('Najstarsze')),
              const PopupMenuItem(value: 'comments', child: Text('Najwięcej komentarzy')),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filter = value);
              _loadTopics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Wszystkie')),
              const PopupMenuItem(value: 'subscribed', child: Text('Subskrybowane')),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _selectedCategory = value == 'all' ? null : value);
              _loadTopics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Wszystkie kategorie')),
              ..._categories.map((cat) => PopupMenuItem(value: cat, child: Text(cat))),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _topics.length,
              itemBuilder: (context, index) {
                final topic = _topics[index];
                return ListTile(
                  title: Text(topic.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (topic.description != null) Text(topic.description!),
                      Text('${topic.commentCount} komentarzy • ${topic.category ?? 'Brak kategorii'}'),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TopicDiscussionScreen(topic: topic, repository: _repository),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'forum_add_topic_fab',
        onPressed: _showAddTopicDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTopicDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedCategory;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Dodaj nowy temat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Tytuł'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Opis (opcjonalny)'),
                maxLines: 3,
              ),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Kategoria'),
                items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (value) => setState(() => selectedCategory = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            TextButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  try {
                    await _repository.createTopic(
                      titleController.text,
                      descriptionController.text.isEmpty ? null : descriptionController.text,
                      selectedCategory,
                    );
                    Navigator.pop(context);
                    _loadTopics();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Błąd tworzenia tematu: $e')),
                    );
                  }
                }
              },
              child: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );
  }
}

class TopicDiscussionScreen extends StatefulWidget {
  const TopicDiscussionScreen({
    super.key,
    required this.topic,
    required this.repository,
  });

  final ForumTopic topic;
  final ForumRepository repository;

  @override
  State<TopicDiscussionScreen> createState() => _TopicDiscussionScreenState();
}

class _TopicDiscussionScreenState extends State<TopicDiscussionScreen> {
  List<ForumComment> _comments = [];
  bool _isLoading = true;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _isSubscribed = widget.topic.isSubscribed;
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await widget.repository.getComments(widget.topic.id);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania komentarzy: $e')),
        );
      }
    }
  }

  Future<void> _toggleSubscription() async {
    try {
      if (_isSubscribed) {
        await widget.repository.unsubscribeFromTopic(widget.topic.id);
      } else {
        await widget.repository.subscribeToTopic(widget.topic.id);
      }
      setState(() => _isSubscribed = !_isSubscribed);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd subskrypcji: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.title),
        actions: [
          IconButton(
            icon: Icon(_isSubscribed ? Icons.notifications : Icons.notifications_none),
            onPressed: _toggleSubscription,
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.topic.description != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(widget.topic.description!),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return CommentWidget(
                        comment: comment,
                        repository: widget.repository,
                        onCommentUpdated: _loadComments,
                        level: 0,
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Dodaj komentarz...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    if (_commentController.text.isNotEmpty) {
                      try {
                        await widget.repository.addComment(
                          widget.topic.id,
                          _commentController.text,
                        );
                        _commentController.clear();
                        _loadComments();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Błąd dodawania komentarza: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommentWidget extends StatefulWidget {
  const CommentWidget({
    super.key,
    required this.comment,
    required this.repository,
    required this.onCommentUpdated,
    required this.level,
  });

  final ForumComment comment;
  final ForumRepository repository;
  final VoidCallback onCommentUpdated;
  final int level;

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget> {
  bool _showReply = false;
  final TextEditingController _replyController = TextEditingController();
  int _userVote = 0; // 0: no vote, 1: like, -1: dislike

  @override
  void initState() {
    super.initState();
    // TODO: Load user's vote for this comment
  }

  Future<void> _vote(int vote) async {
    try {
      await widget.repository.voteComment(widget.comment.id, vote);
      setState(() => _userVote = vote);
      widget.onCommentUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd głosowania: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId == widget.comment.authorId;

    return Padding(
      padding: EdgeInsets.only(left: widget.level * 20.0, top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Użytkownik ${widget.comment.authorId.substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (isOwner)
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              _showEditDialog();
                            } else if (value == 'delete') {
                              await widget.repository.deleteComment(widget.comment.id);
                              widget.onCommentUpdated();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edytuj')),
                            const PopupMenuItem(value: 'delete', child: Text('Usuń')),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(widget.comment.content),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.thumb_up,
                          color: _userVote == 1 ? Colors.green : null,
                        ),
                        onPressed: () => _vote(_userVote == 1 ? 0 : 1),
                      ),
                      Text('${widget.comment.likes}'),
                      IconButton(
                        icon: Icon(
                          Icons.thumb_down,
                          color: _userVote == -1 ? Colors.red : null,
                        ),
                        onPressed: () => _vote(_userVote == -1 ? 0 : -1),
                      ),
                      Text('${widget.comment.dislikes}'),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _showReply = !_showReply),
                        child: const Text('Odpowiedz'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_showReply)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      decoration: const InputDecoration(
                        hintText: 'Odpowiedz...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      if (_replyController.text.isNotEmpty) {
                        try {
                          await widget.repository.addComment(
                            widget.comment.topicId,
                            _replyController.text,
                            parentId: widget.comment.id,
                          );
                          _replyController.clear();
                          setState(() => _showReply = false);
                          widget.onCommentUpdated();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Błąd dodawania odpowiedzi: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: widget.comment.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edytuj komentarz'),
        content: TextField(
          controller: controller,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await widget.repository.editComment(widget.comment.id, controller.text);
                Navigator.pop(context);
                widget.onCommentUpdated();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Błąd edycji: $e')),
                );
              }
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }
}