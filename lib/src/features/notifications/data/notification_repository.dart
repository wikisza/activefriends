import 'package:activefriends/src/features/notifications/domain/app_notification.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationRepository {
  NotificationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _myId => _client.auth.currentUser?.id;

  Future<List<AppNotification>> fetchNotifications({int limit = 60}) async {
    final String? uid = _myId;
    if (uid == null) return <AppNotification>[];
    final List<dynamic> rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.tryFromRow)
        .whereType<AppNotification>()
        .toList(growable: false);
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final String? uid = _myId;
    if (uid == null) return;
    await _client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }

  /// Subskrypcja nowych powiadomień w czasie rzeczywistym.
  RealtimeChannel subscribeToNotifications(
    void Function(AppNotification) onInsert,
  ) {
    final String? uid = _myId;
    final RealtimeChannel channel = _client.channel('notifications:me');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: uid != null
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: uid,
            )
          : null,
      callback: (PostgresChangePayload payload) {
        final AppNotification? n =
            AppNotification.tryFromRow(payload.newRecord);
        if (n != null) onInsert(n);
      },
    );
    channel.subscribe();
    return channel;
  }

  /// Subskrypcja tylko do zliczania nowych (dla badge'a w tab barze).
  RealtimeChannel subscribeToUnreadCount(VoidCallback onNew) {
    final String? uid = _myId;
    final RealtimeChannel channel = _client.channel('notifications:badge');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
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
}
