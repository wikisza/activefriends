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

    final List<ChatMessage> messages = rows
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.tryFromRow)
        .whereType<ChatMessage>()
        .toList(growable: false);

    // Pobierz profile nadawców dla wiadomości grupowych
    final Set<String> senderIds =
        messages.map((ChatMessage m) => m.senderId).toSet();
    if (senderIds.isEmpty) return messages;

    final Map<String, ({String name, String? avatarUrl})> profiles =
        await _fetchPeerInfo(senderIds);

    return messages.map((ChatMessage m) {
      final p = profiles[m.senderId];
      if (p == null) return m;
      return m.withSender(name: p.name, avatarUrl: p.avatarUrl);
    }).toList(growable: false);
  }

  /// Dołącz bieżącego użytkownika do czatu grupowego (wywołaj przy otwieraniu).
  Future<void> ensureGroupConversationMember(String conversationId) async {
    await _client.rpc(
      'ensure_group_conversation_member',
      params: <String, dynamic>{'p_conversation_id': conversationId},
    );
  }

  /// Pobiera profil nadawcy z bazy (dla wiadomości Realtime bez join).
  Future<({String name, String? avatarUrl})?> fetchSenderProfile(
      String userId) async {
    final Map<String, dynamic>? row = await _client
        .from('profiles')
        .select('display_name,avatar_url')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return (
      name: row['display_name']?.toString() ?? 'Użytkownik',
      avatarUrl: row['avatar_url']?.toString(),
    );
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
        final Map<String, dynamic> rec = payload.newRecord;
        final ChatMessage? m = ChatMessage.tryFromRow(rec);
        if (m != null) {
          onInsert(m);
        }
      },
    );
    channel.subscribe();
    return channel;
  }

  /// Tworzy lub zwraca istniejący czat grupowy dla eventu.
  Future<String> getOrCreateEventGroupConversation(String eventId) async {
    final dynamic res = await _client.rpc(
      'get_or_create_event_group_conversation',
      params: <String, dynamic>{'p_event_id': eventId},
    );
    final String id = res?.toString() ?? '';
    if (id.isEmpty) throw StateError('Brak id konwersacji grupowej.');
    return id;
  }

  Future<List<ConversationSummary>> fetchMyConversations() async {
    final String? myId = _myId;
    if (myId == null) return <ConversationSummary>[];

    // 1. Pobierz konwersacje użytkownika z meta-danymi (is_direct, title, event_id)
    final List<dynamic> mine = await _client
        .from('conversation_members')
        .select('conversation_id, conversations!inner(id, is_direct, title, event_id)')
        .eq('user_id', myId);

    if (mine.isEmpty) return <ConversationSummary>[];

    // Mapa cid → dane konwersacji
    final Map<String, Map<String, dynamic>> convMeta = <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> row in mine.whereType<Map<String, dynamic>>()) {
      final String cid = row['conversation_id']?.toString() ?? '';
      final Map<String, dynamic>? conv = row['conversations'] as Map<String, dynamic>?;
      if (cid.isNotEmpty && conv != null) convMeta[cid] = conv;
    }
    final Set<String> convIds = convMeta.keys.toSet();
    if (convIds.isEmpty) return <ConversationSummary>[];

    // 2. Wszyscy członkowie tych konwersacji
    final List<dynamic> allMembers = await _client
        .from('conversation_members')
        .select('conversation_id,user_id')
        .inFilter('conversation_id', convIds.toList(growable: false));

    // direct: peer per conv; group: member count
    final Map<String, String> peerByConv = <String, String>{};
    final Map<String, int> memberCount = <String, int>{};
    for (final Map<String, dynamic> row in allMembers.whereType<Map<String, dynamic>>()) {
      final String cid = row['conversation_id']?.toString() ?? '';
      final String uid = row['user_id']?.toString() ?? '';
      if (cid.isEmpty || uid.isEmpty) continue;
      memberCount[cid] = (memberCount[cid] ?? 0) + 1;
      if (uid != myId) peerByConv[cid] = uid;
    }

    // 3. Profile peerów (tylko direct)
    final Set<String> directConvIds = convMeta.entries
        .where((e) => e.value['is_direct'] == true)
        .map((e) => e.key)
        .toSet();
    final Set<String> peerIds =
        peerByConv.entries.where((e) => directConvIds.contains(e.key)).map((e) => e.value).toSet();
    final Map<String, ({String name, String? avatarUrl})> peerInfo =
        await _fetchPeerInfo(peerIds);

    // 4. Ostatnie wiadomości
    final List<dynamic> recentMsgs = await _client
        .from('messages')
        .select('conversation_id,body,created_at')
        .inFilter('conversation_id', convIds.toList(growable: false))
        .order('created_at', ascending: false)
        .limit(500);

    final Map<String, Map<String, dynamic>> lastByConv = <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> row in recentMsgs.whereType<Map<String, dynamic>>()) {
      final String cid = row['conversation_id']?.toString() ?? '';
      if (cid.isEmpty || lastByConv.containsKey(cid)) continue;
      lastByConv[cid] = row;
    }

    // 5. Złóż wynik
    final List<ConversationSummary> out = <ConversationSummary>[];
    for (final String cid in convIds) {
      final Map<String, dynamic> meta = convMeta[cid]!;
      final bool isGroup = meta['is_direct'] == false;
      final Map<String, dynamic>? last = lastByConv[cid];
      final String? atRaw = last?['created_at']?.toString();

      if (isGroup) {
        out.add(ConversationSummary(
          conversationId: cid,
          peerUserId: '',
          peerDisplayName: '',
          lastMessagePreview: last?['body']?.toString(),
          lastMessageAt: atRaw != null ? DateTime.tryParse(atRaw) : null,
          isGroup: true,
          groupTitle: meta['title']?.toString(),
          memberCount: memberCount[cid] ?? 0,
          eventId: meta['event_id']?.toString(),
        ));
      } else {
        final String? peerId = peerByConv[cid];
        if (peerId == null) continue;
        final ({String name, String? avatarUrl})? info = peerInfo[peerId];
        out.add(ConversationSummary(
          conversationId: cid,
          peerUserId: peerId,
          peerDisplayName: info?.name ?? 'Użytkownik',
          peerAvatarUrl: info?.avatarUrl,
          lastMessagePreview: last?['body']?.toString(),
          lastMessageAt: atRaw != null ? DateTime.tryParse(atRaw) : null,
        ));
      }
    }

    out.sort((ConversationSummary a, ConversationSummary b) {
      final DateTime? ta = a.lastMessageAt;
      final DateTime? tb = b.lastMessageAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
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
