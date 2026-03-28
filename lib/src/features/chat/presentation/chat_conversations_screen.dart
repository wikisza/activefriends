import 'dart:async';

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
  final SupabaseClient _client = Supabase.instance.client;

  List<ConversationSummary> _items = <ConversationSummary>[];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _convChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToNewConversations();
  }

  void _subscribeToNewConversations() {
    _convChannel = _repo.subscribeToNewConversations(() {
      if (mounted) {
        _load();
      }
    });
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

  @override
  void dispose() {
    final RealtimeChannel? ch = _convChannel;
    if (ch != null) {
      unawaited(_client.removeChannel(ch));
    }
    super.dispose();
  }

  String _subtitle(ConversationSummary s) {
    final String? preview = s.lastMessagePreview;
    if (preview != null && preview.isNotEmpty) {
      return preview.length > 80 ? '${preview.substring(0, 80)}…' : preview;
    }
    return 'Brak wiadomości — zacznij rozmowę';
  }

  Widget _avatar(ConversationSummary s, ColorScheme cs) {
    final String? url = s.peerAvatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(url),
        radius: 24,
      );
    }
    return CircleAvatar(
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
      radius: 24,
      child: Text(
        s.peerDisplayName.isNotEmpty
            ? s.peerDisplayName[0].toUpperCase()
            : '?',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: _avatar(s, cs),
                            title: Text(
                              s.peerDisplayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              _subtitle(s),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            trailing: s.lastMessageAt != null
                                ? Text(
                                    _formatTime(s.lastMessageAt!),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  )
                                : null,
                            onTap: () {
                              Navigator.of(context)
                                  .push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      ChatThreadScreen(
                                    peerUserId: s.peerUserId,
                                    peerDisplayName: s.peerDisplayName,
                                    peerAvatarUrl: s.peerAvatarUrl,
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

  String _formatTime(DateTime dt) {
    final DateTime now = DateTime.now();
    final DateTime local = dt.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}';
  }
}
