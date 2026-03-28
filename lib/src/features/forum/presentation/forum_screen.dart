import 'package:activefriends/src/app/ui/app_transitions.dart';
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
                const SnackBar(
                  content: Text('Nowy komentarz w subskrybowanym temacie!'),
                ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd ładowania tematów: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Forum'), elevation: 0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Szukaj tematów...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerLowest,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (value) {
                    setState(
                      () => _selectedCategory = value == 'all' ? null : value,
                    );
                    _loadTopics();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'all',
                      child: Text('Wszystkie kategorie'),
                    ),
                    ..._categories.map(
                      (cat) => PopupMenuItem(value: cat, child: Text(cat)),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value.startsWith('sort_')) {
                      setState(() => _sortBy = value.replaceFirst('sort_', ''));
                    } else {
                      setState(() => _filter = value);
                    }
                    _loadTopics();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuDivider(height: 8),
                    const PopupMenuItem(
                      value: 'all',
                      child: Row(
                        children: [
                          Icon(Icons.public, size: 18),
                          SizedBox(width: 8),
                          Text('Wszystkie tematy'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 12),
                    const PopupMenuItem(
                      value: 'sort_newest',
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 18),
                          SizedBox(width: 8),
                          Text('Najnowsze'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'sort_oldest',
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 18),
                          SizedBox(width: 8),
                          Text('Najstarsze'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'sort_comments',
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble, size: 18),
                          SizedBox(width: 8),
                          Text('Popularne'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const ShimmerLoading(itemCount: 6)
                : _topics.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 64,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Brak tematów',
                          style: TextStyle(
                            fontSize: 16,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _topics.length,
                    itemBuilder: (context, index) {
                      final topic = _topics[index];
                      return AnimatedListItem(
                        index: index,
                        child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(
                            topic.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (topic.description != null &&
                                  topic.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    topic.description!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    if (topic.category != null)
                                      Chip(
                                        label: Text(topic.category!),
                                        backgroundColor:
                                            cs.surfaceContainerHighest,
                                        labelStyle: const TextStyle(
                                          fontSize: 11,
                                        ),
                                      ),
                                    const Spacer(),
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 16,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${topic.commentCount}',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              AppRoute<void>(
                                builder: (context) => TopicDiscussionScreen(
                                  topic: topic,
                                  repository: _repository,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      );
                    },
                  ),
          ),
        ],
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Tytuł tematu',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'Np. Gdzie najlepiej jeździć na rowerze?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Opis (szczegóły)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    hintText:
                        'Opisz swoje pytanie, problem lub temat dyskusji...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Kategoria',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  hint: const Text('Wybierz kategorię'),
                  items: _categories
                      .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedCategory = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wpisz tytuł tematu')),
                  );
                  return;
                }
                try {
                  await _repository.createTopic(
                    titleController.text,
                    descriptionController.text.isEmpty
                        ? null
                        : descriptionController.text,
                    selectedCategory,
                  );
                  Navigator.pop(context);
                  _loadTopics();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Błąd tworzenia tematu: $e')),
                  );
                }
              },
              child: const Text('Dodaj temat'),
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
  List<ForumComment> _allComments = [];
  bool _isLoading = true;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  List<ForumComment> _getTopLevelComments() {
    return _allComments.where((c) => c.parentId == null).toList();
  }

  List<ForumComment> _getReplies(String parentId) {
    return _allComments.where((c) => c.parentId == parentId).toList();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await widget.repository.getComments(widget.topic.id);
      setState(() {
        _allComments = comments;
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

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.topic.title)),
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
                    itemCount: _getTopLevelComments().length,
                    itemBuilder: (context, index) {
                      final topLevelComment = _getTopLevelComments()[index];
                      final replies = _getReplies(topLevelComment.id);
                      return CommentThread(
                        comment: topLevelComment,
                        replies: replies,
                        repository: widget.repository,
                        onCommentUpdated: _loadComments,
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
                    decoration: InputDecoration(
                      hintText: 'Dodaj komentarz...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerLowest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
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
                          SnackBar(
                            content: Text('Błąd dodawania komentarza: $e'),
                          ),
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
  int _userVote = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _vote(int vote) async {
    try {
      await widget.repository.voteComment(widget.comment.id, vote);
      setState(() => _userVote = vote);
      widget.onCommentUpdated();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd głosowania: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId == widget.comment.authorId;
    final ColorScheme cs = Theme.of(context).colorScheme;

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
                        widget.comment.authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: widget.level > 0 ? 12 : 14,
                        ),
                      ),
                      const Spacer(),
                      if (isOwner)
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              _showEditDialog();
                            } else if (value == 'delete') {
                              await widget.repository.deleteComment(
                                widget.comment.id,
                              );
                              widget.onCommentUpdated();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edytuj'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Usuń'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.comment.content,
                    style: TextStyle(fontSize: widget.level > 0 ? 12 : 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.thumb_up,
                          color: _userVote == 1 ? cs.secondary : null,
                          size: widget.level > 0 ? 16 : 20,
                        ),
                        onPressed: () => _vote(_userVote == 1 ? 0 : 1),
                      ),
                      Text(
                        '${widget.comment.likes}',
                        style: TextStyle(fontSize: widget.level > 0 ? 10 : 12),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.thumb_down,
                          color: _userVote == -1 ? cs.error : null,
                          size: widget.level > 0 ? 16 : 20,
                        ),
                        onPressed: () => _vote(_userVote == -1 ? 0 : -1),
                      ),
                      Text(
                        '${widget.comment.dislikes}',
                        style: TextStyle(fontSize: widget.level > 0 ? 10 : 12),
                      ),
                      const Spacer(),
                      if (widget.level == 0)
                        TextButton(
                          onPressed: () =>
                              setState(() => _showReply = !_showReply),
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
                      decoration: InputDecoration(
                        hintText: 'Odpowiedz...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
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
                            SnackBar(
                              content: Text('Błąd dodawania odpowiedzi: $e'),
                            ),
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
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await widget.repository.editComment(
                  widget.comment.id,
                  controller.text,
                );
                Navigator.pop(context);
                widget.onCommentUpdated();
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Błąd edycji: $e')));
              }
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }
}

class CommentThread extends StatefulWidget {
  const CommentThread({
    super.key,
    required this.comment,
    required this.replies,
    required this.repository,
    required this.onCommentUpdated,
  });

  final ForumComment comment;
  final List<ForumComment> replies;
  final ForumRepository repository;
  final VoidCallback onCommentUpdated;

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  bool _showAllReplies = false;
  static const int _replyPreviewLimit = 3;

  @override
  Widget build(BuildContext context) {
    final visibleReplies = _showAllReplies
        ? widget.replies
        : widget.replies.take(_replyPreviewLimit).toList();

    final hasMoreReplies =
        widget.replies.length > _replyPreviewLimit && !_showAllReplies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommentWidget(
          comment: widget.comment,
          repository: widget.repository,
          onCommentUpdated: widget.onCommentUpdated,
          level: 0,
        ),
        if (widget.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 20.0, top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...visibleReplies.map(
                  (reply) => CommentWidget(
                    comment: reply,
                    repository: widget.repository,
                    onCommentUpdated: widget.onCommentUpdated,
                    level: 1,
                  ),
                ),
                if (hasMoreReplies)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                    child: TextButton(
                      onPressed: () => setState(() => _showAllReplies = true),
                      child: Text(
                        'Pokaż wszystkie odpowiedzi (${widget.replies.length})',
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
