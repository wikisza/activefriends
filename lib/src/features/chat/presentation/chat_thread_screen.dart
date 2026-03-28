import 'dart:async';

import 'package:activefriends/src/features/chat/data/chat_repository.dart';
import 'package:activefriends/src/features/chat/domain/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.peerUserId,
    required this.peerDisplayName,
    this.contextEventTitle,
    this.conversationId,
  });

  final String peerUserId;
  final String peerDisplayName;
  final String? contextEventTitle;

  /// Gdy znane (np. z listy rozmów), pomija RPC.
  final String? conversationId;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final ChatRepository _repo = ChatRepository();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  final SupabaseClient _client = Supabase.instance.client;

  List<ChatMessage> _messages = <ChatMessage>[];
  String? _conversationId;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  String? get _myId => _client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final RealtimeChannel? previous = _channel;
    _channel = null;
    if (previous != null) {
      unawaited(_client.removeChannel(previous));
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final String cid = widget.conversationId ??
          await _repo.getOrCreateDirectConversation(widget.peerUserId);
      if (!mounted) {
        return;
      }
      _conversationId = cid;
      final List<ChatMessage> initial =
          await _repo.fetchMessages(cid);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = initial;
        _loading = false;
      });
      _channel = _repo.subscribeToNewMessages(cid, _onRealtimeInsert);
      _scrollToEnd();
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

  void _onRealtimeInsert(ChatMessage message) {
    if (!mounted) {
      return;
    }
    if (_messages.any((ChatMessage m) => m.id == message.id)) {
      return;
    }
    setState(() => _messages = <ChatMessage>[..._messages, message]);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final String? cid = _conversationId;
    if (cid == null || _sending) {
      return;
    }
    final String text = _textController.text;
    if (text.trim().isEmpty) {
      return;
    }
    setState(() => _sending = true);
    _textController.clear();
    try {
      await _repo.sendMessage(cid, text);
      if (mounted) {
        _scrollToEnd();
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        _textController.text = text;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
        _textController.text = text;
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  void dispose() {
    final RealtimeChannel? ch = _channel;
    if (ch != null) {
      unawaited(_client.removeChannel(ch));
    }
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      restorationId: 'chat_thread_${widget.peerUserId}_${_conversationId ?? 'new'}',
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(widget.peerDisplayName),
            if (widget.contextEventTitle != null &&
                widget.contextEventTitle!.isNotEmpty)
              Text(
                widget.contextEventTitle!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _bootstrap,
                          child: const Text('Spróbuj ponownie'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: <Widget>[
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Text(
                                'Napisz pierwszą wiadomość.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              itemCount: _messages.length,
                              itemBuilder: (BuildContext context, int i) {
                                final ChatMessage m = _messages[i];
                                final bool mine = m.senderId == _myId;
                                return Align(
                                  alignment: mine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.sizeOf(context).width * 0.78,
                                    ),
                                    decoration: BoxDecoration(
                                      color: mine
                                          ? cs.primaryContainer
                                          : cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      m.body,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: mine
                                            ? cs.onPrimaryContainer
                                            : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                minLines: 1,
                                maxLines: 5,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: 'Wiadomość…',
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
