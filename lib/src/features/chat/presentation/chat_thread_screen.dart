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
    this.peerAvatarUrl,
    this.contextEventTitle,
    this.conversationId,
  });

  final String peerUserId;
  final String peerDisplayName;
  final String? peerAvatarUrl;
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

  // Popularne emoji pogrupowane
  static const List<String> _commonEmojis = <String>[
    '😀', '😂', '😊', '😍', '🥰', '😎', '😢', '😡',
    '👍', '👎', '👋', '🙏', '❤️', '🔥', '✅', '⚠️',
    '🚴', '🏃', '⛺', '🗺️', '📍', '🎉', '💪', '🤝',
  ];

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
      if (!mounted) return;
      _conversationId = cid;
      final List<ChatMessage> initial = await _repo.fetchMessages(cid);
      if (!mounted) return;
      setState(() {
        _messages = initial;
        _loading = false;
      });
      _channel = _repo.subscribeToNewMessages(cid, _onRealtimeInsert);
      _scrollToEnd();
    } on PostgrestException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _onRealtimeInsert(ChatMessage message) {
    if (!mounted) return;
    if (_messages.any((ChatMessage m) => m.id == message.id)) return;
    setState(() => _messages = <ChatMessage>[..._messages, message]);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final String? cid = _conversationId;
    if (cid == null || _sending) return;
    final String text = _textController.text;
    if (text.trim().isEmpty) return;
    setState(() => _sending = true);
    _textController.clear();
    try {
      await _repo.sendMessage(cid, text);
      if (mounted) _scrollToEnd();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        _textController.text = text;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
        _textController.text = text;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showEmojiPicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: _commonEmojis.length,
                  itemBuilder: (BuildContext context, int i) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _textController.text =
                            _textController.text + _commonEmojis[i];
                        _textController.selection =
                            TextSelection.fromPosition(
                          TextPosition(
                              offset: _textController.text.length),
                        );
                      },
                      child: Center(
                        child: Text(
                          _commonEmojis[i],
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    final RealtimeChannel? ch = _channel;
    if (ch != null) unawaited(_client.removeChannel(ch));
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Widget _peerAvatar({double radius = 18}) {
    final String? url = widget.peerAvatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE4F2E7),
      foregroundColor: const Color(0xFF1E8E3E),
      child: Text(
        widget.peerDisplayName.isNotEmpty
            ? widget.peerDisplayName[0].toUpperCase()
            : '?',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final DateTime l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      restorationId:
          'chat_thread_${widget.peerUserId}_${_conversationId ?? 'new'}',
      appBar: AppBar(
        leadingWidth: 56,
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            _peerAvatar(radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    widget.peerDisplayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.contextEventTitle != null &&
                      widget.contextEventTitle!.isNotEmpty)
                    Text(
                      widget.contextEventTitle!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
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
                                vertical: 12,
                              ),
                              itemCount: _messages.length,
                              itemBuilder: (BuildContext context, int i) {
                                final ChatMessage m = _messages[i];
                                final bool mine = m.senderId == _myId;
                                final bool showAvatar = !mine &&
                                    (i == _messages.length - 1 ||
                                        _messages[i + 1].senderId != m.senderId);
                                return _MessageBubble(
                                  message: m,
                                  mine: mine,
                                  showAvatar: showAvatar,
                                  peerAvatar: _peerAvatar(radius: 14),
                                  time: _formatTime(m.createdAt),
                                  cs: cs,
                                  theme: theme,
                                );
                              },
                            ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          border: Border(
                            top: BorderSide(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            IconButton(
                              onPressed: _showEmojiPicker,
                              icon: const Icon(Icons.emoji_emotions_outlined),
                              tooltip: 'Emoji',
                            ),
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
                                  fillColor: cs.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(22),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(22),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(22),
                                    borderSide: BorderSide(
                                      color: cs.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _sending
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : IconButton.filled(
                                    onPressed: _send,
                                    icon: const Icon(Icons.send_rounded),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.showAvatar,
    required this.peerAvatar,
    required this.time,
    required this.cs,
    required this.theme,
  });

  final ChatMessage message;
  final bool mine;
  final bool showAvatar;
  final Widget peerAvatar;
  final String time;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    const Radius big = Radius.circular(18);
    const Radius small = Radius.circular(4);

    final BorderRadius radius = mine
        ? const BorderRadius.only(
            topLeft: big,
            topRight: big,
            bottomLeft: big,
            bottomRight: small,
          )
        : BorderRadius.only(
            topLeft: big,
            topRight: big,
            bottomRight: big,
            bottomLeft: showAvatar ? small : big,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!mine) ...<Widget>[
            SizedBox(
              width: 32,
              child: showAvatar ? peerAvatar : const SizedBox(),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              decoration: BoxDecoration(
                color: mine ? cs.primary : cs.surfaceContainerHighest,
                borderRadius: radius,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Column(
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    message.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mine ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: (mine ? cs.onPrimary : cs.onSurfaceVariant)
                          .withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (mine) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
