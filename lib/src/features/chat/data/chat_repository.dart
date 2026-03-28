import 'dart:async';

import 'package:activefriends/src/features/chat/domain/chat_message.dart';
import 'package:activefriends/src/features/chat/domain/conversation_summary.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pobieranie historii, wysyłka i Realtime dla tabel `conversations` / `messages`.
///
/// Wymaga migracji SQL: [supabase/migrations/20250328140000_direct_chat.sql].
class ChatRepository {
  ChatRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isUuid(String value) => _uuid.hasMatch(value.trim());

  String? get _myId => _client.auth.currentUser?.id;

  Future<String> getOrCreateDirectConversation(String otherUserId) async {
    final String trimmed = otherUserId.trim();
    if (!isUuid(trimmed)) {
      throw ArgumentError('Nieprawidłowy identyfikator użytkownika.');
    }
    final dynamic res = await _client.rpc(
      'get_or_create_direct_conversation',
      params: <String, dynamic>{'p_other_user': trimmed},
    );
    final String id = res?.toString() ?? '';
    if (id.isEmpty) {
      throw StateError('Brak id konwersacji z serwera.');
    }
    return id;
  }

  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    int limit = 200,
  }) async {
    final List<dynamic> rows = await _client
        .from('messages')
        .select('id,conversation_id,sender_id,body,created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(limit);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.tryFromRow)
        .whereType<ChatMessage>()
        .toList(growable: false);
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final String? uid = _myId;
    if (uid == null) {
      throw StateError('Zaloguj się, aby wysłać wiadomość.');
    }
    final String text = body.trim();
    if (text.isEmpty) {
      return;
    }
    await _client.from('messages').insert(<String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': uid,
      'body': text,
    });
  }

  /// Subskrypcja nowych wiadomości. Anuluj kanał przez [_client.removeChannel].
  RealtimeChannel subscribeToNewMessages(
    String conversationId,
    void Function(ChatMessage message) onInsert,
  ) {
    final RealtimeChannel channel = _client.channel('messages:$conversationId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (PostgresChangePayload payload) {
        final Map<String, dynamic>? rec = payload.newRecord;
        if (rec == null) {
          return;
        }
        final ChatMessage? m = ChatMessage.tryFromRow(rec);
        if (m != null) {
          onInsert(m);
        }
      },
    );
    channel.subscribe();
    return channel;
  }

  Future<List<ConversationSummary>> fetchMyConversations() async {
    final String? myId = _myId;
    if (myId == null) {
      return <ConversationSummary>[];
    }

    final List<dynamic> mine = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', myId);

    final Set<String> convIds = mine
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> r) => r['conversation_id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    if (convIds.isEmpty) {
      return <ConversationSummary>[];
    }

    final List<dynamic> allMembers = await _client
        .from('conversation_members')
        .select('conversation_id,user_id')
        .inFilter('conversation_id', convIds.toList(growable: false));

    final Map<String, String> peerByConv = <String, String>{};
    for (final Map<String, dynamic> row
        in allMembers.whereType<Map<String, dynamic>>()) {
      final String cid = row['conversation_id']?.toString() ?? '';
      final String uid = row['user_id']?.toString() ?? '';
      if (cid.isEmpty || uid.isEmpty || uid == myId) {
        continue;
      }
      peerByConv[cid] = uid;
    }

    final Set<String> peerIds = peerByConv.values.toSet();
    final Map<String, ({String name, String? avatarUrl})> peerInfo =
        await _fetchPeerInfo(peerIds);

    final List<dynamic> recentMsgs = await _client
        .from('messages')
        .select('conversation_id,body,created_at')
        .inFilter('conversation_id', convIds.toList(growable: false))
        .order('created_at', ascending: false)
        .limit(500);

    final Map<String, Map<String, dynamic>> lastByConv =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> row
        in recentMsgs.whereType<Map<String, dynamic>>()) {
      final String cid = row['conversation_id']?.toString() ?? '';
      if (cid.isEmpty || lastByConv.containsKey(cid)) {
        continue;
      }
      lastByConv[cid] = row;
    }

    final List<ConversationSummary> out = <ConversationSummary>[];
    for (final String cid in convIds) {
      final String? peerId = peerByConv[cid];
      if (peerId == null) {
        continue;
      }
      final Map<String, dynamic>? last = lastByConv[cid];
      final String? atRaw = last?['created_at']?.toString();
      final ({String name, String? avatarUrl})? info = peerInfo[peerId];
      out.add(
        ConversationSummary(
          conversationId: cid,
          peerUserId: peerId,
          peerDisplayName: info?.name ?? 'Użytkownik',
          peerAvatarUrl: info?.avatarUrl,
          lastMessagePreview: last?['body']?.toString(),
          lastMessageAt:
              atRaw != null ? DateTime.tryParse(atRaw) : null,
        ),
      );
    }

    out.sort((ConversationSummary a, ConversationSummary b) {
      final DateTime? ta = a.lastMessageAt;
      final DateTime? tb = b.lastMessageAt;
      if (ta == null && tb == null) {
        return 0;
      }
      if (ta == null) {
        return 1;
      }
      if (tb == null) {
        return -1;
      }
      return tb.compareTo(ta);
    });
    return out;
  }

  /// Subskrypcja nowych konwersacji (nowy wpis w conversation_members dla bieżącego użytkownika).
  RealtimeChannel subscribeToNewConversations(VoidCallback onNew) {
    final String? uid = _myId;
    final RealtimeChannel channel =
        _client.channel('conversation_members:me');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'conversation_members',
      filter: uid != null
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: uid,
            )
          : null,
      callback: (_) => onNew(),
    );
    channel.subscribe();
    return channel;
  }

  /// Subskrypcja nowych wiadomości globalnie (dla badge powiadomień).
  RealtimeChannel subscribeToAllNewMessages(
    void Function(String senderId) onInsert,
  ) {
    final RealtimeChannel channel = _client.channel('messages:global');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (PostgresChangePayload payload) {
        final String? sender =
            payload.newRecord['sender_id']?.toString();
        if (sender != null) {
          onInsert(sender);
        }
      },
    );
    channel.subscribe();
    return channel;
  }

  Future<Map<String, ({String name, String? avatarUrl})>> _fetchPeerInfo(
    Set<String> userIds,
  ) async {
    if (userIds.isEmpty) {
      return <String, ({String name, String? avatarUrl})>{};
    }
    final List<dynamic> rows = await _client
        .from('profiles')
        .select('id,display_name,avatar_url')
        .inFilter('id', userIds.toList(growable: false));

    final Map<String, ({String name, String? avatarUrl})> map =
        <String, ({String name, String? avatarUrl})>{};
    for (final Map<String, dynamic> row
        in rows.whereType<Map<String, dynamic>>()) {
      final String id = row['id']?.toString() ?? '';
      if (id.isEmpty) {
        continue;
      }
      map[id] = (
        name: row['display_name']?.toString() ?? 'Użytkownik',
        avatarUrl: row['avatar_url']?.toString(),
      );
    }
    return map;
  }
}
