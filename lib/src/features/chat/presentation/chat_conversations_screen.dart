import 'package:activefriends/src/features/chat/data/chat_repository.dart';
import 'package:activefriends/src/features/chat/domain/conversation_summary.dart';
import 'package:activefriends/src/features/chat/presentation/chat_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatConversationsScreen extends StatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  State<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState extends State<ChatConversationsScreen> {
  final ChatRepository _repo = ChatRepository();

  List<ConversationSummary> _items = <ConversationSummary>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<ConversationSummary> list = await _repo.fetchMyConversations();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _subtitle(ConversationSummary s) {
    final String? preview = s.lastMessagePreview;
    if (preview != null && preview.isNotEmpty) {
      return preview.length > 80 ? '${preview.substring(0, 80)}…' : preview;
    }
    return 'Brak wiadomości — zacznij rozmowę';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Czat'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const <Widget>[
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: <Widget>[
                      const SizedBox(height: 48),
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 56,
                        color: cs.error.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton(
                          onPressed: _load,
                          child: const Text('Odśwież'),
                        ),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        children: <Widget>[
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.2,
                          ),
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 72,
                            color: cs.primary.withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Brak rozmów',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Otwórz zgłoszenie na mapie i użyj ikony czatu, '
                            'żeby napisać do organizatora.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final ConversationSummary s = _items[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              foregroundColor: cs.onPrimaryContainer,
                              child: Text(
                                s.peerDisplayName.isNotEmpty
                                    ? s.peerDisplayName[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(s.peerDisplayName),
                            subtitle: Text(_subtitle(s)),
                            onTap: () {
                              Navigator.of(context)
                                  .push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      ChatThreadScreen(
                                    peerUserId: s.peerUserId,
                                    peerDisplayName: s.peerDisplayName,
                                    conversationId: s.conversationId,
                                  ),
                                ),
                              )
                                  .then((_) => _load());
                            },
                          );
                        },
                      ),
      ),
    );
  }
}
