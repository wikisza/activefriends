import 'dart:async';

import 'package:activefriends/src/app/ui/app_transitions.dart';
import 'package:activefriends/src/features/notifications/data/notification_repository.dart';
import 'package:activefriends/src/features/notifications/domain/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _Filter { all, messages, events, forum }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _repo = NotificationRepository();
  final SupabaseClient _client = Supabase.instance.client;

  List<AppNotification> _all = <AppNotification>[];
  bool _loading = true;
  String? _error;
  _Filter _filter = _Filter.all;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  void _subscribe() {
    _channel = _repo.subscribeToNotifications((AppNotification n) {
      if (!mounted) return;
      setState(() => _all = <AppNotification>[n, ..._all]);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<AppNotification> list = await _repo.fetchNotifications();
      if (mounted) setState(() { _all = list; _loading = false; });
    } on PostgrestException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    final RealtimeChannel? ch = _channel;
    if (ch != null) unawaited(_client.removeChannel(ch));
    super.dispose();
  }

  List<AppNotification> get _filtered {
    return switch (_filter) {
      _Filter.all => _all,
      _Filter.messages =>
        _all.where((n) => n.type == NotificationType.newMessage).toList(),
      _Filter.events =>
        _all.where((n) => n.type == NotificationType.eventJoin).toList(),
      _Filter.forum => _all
          .where((n) =>
              n.type == NotificationType.forumLike ||
              n.type == NotificationType.forumReply)
          .toList(),
    };
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    await _repo.markAsRead(n.id);
    if (mounted) {
      setState(() {
        _all = _all
            .map((x) => x.id == n.id ? x.copyWith(isRead: true) : x)
            .toList();
      });
    }
  }

  Future<void> _markAllRead() async {
    await _repo.markAllAsRead();
    if (mounted) {
      setState(() {
        _all = _all.map((n) => n.copyWith(isRead: true)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool hasUnread = _all.any((n) => !n.isRead);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Powiadomienia'),
        actions: <Widget>[
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Odczytaj wszystko'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: <Widget>[
            _FilterBar(
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: _loading
                  ? const ShimmerLoading(itemCount: 6)
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : _filtered.isEmpty
                          ? _EmptyView(filter: _filter, cs: cs, theme: theme)
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (BuildContext context, int i) {
                                final AppNotification n = _filtered[i];
                                return AnimatedListItem(
                                  index: i,
                                  child: _NotificationTile(
                                    notification: n,
                                    onTap: () => _markRead(n),
                                    cs: cs,
                                    theme: theme,
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter bar ──────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final _Filter selected;
  final void Function(_Filter) onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: <Widget>[
          _Chip(
            label: 'Wszystkie',
            active: selected == _Filter.all,
            onTap: () => onSelected(_Filter.all),
          ),
          _Chip(
            label: 'Wiadomości',
            active: selected == _Filter.messages,
            onTap: () => onSelected(_Filter.messages),
          ),
          _Chip(
            label: 'Zdarzenia',
            active: selected == _Filter.events,
            onTap: () => onSelected(_Filter.events),
          ),
          _Chip(
            label: 'Forum',
            active: selected == _Filter.forum,
            onTap: () => onSelected(_Filter.forum),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: active ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? cs.onPrimary : cs.onSurfaceVariant,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Notification tile ────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.cs,
    required this.theme,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final ColorScheme cs;
  final ThemeData theme;

  static const Map<NotificationType, IconData> _icons = <NotificationType, IconData>{
    NotificationType.newMessage: Icons.chat_bubble_rounded,
    NotificationType.eventJoin: Icons.directions_run_rounded,
    NotificationType.forumLike: Icons.thumb_up_rounded,
    NotificationType.forumReply: Icons.forum_rounded,
  };

  static const Map<NotificationType, Color> _colors = <NotificationType, Color>{
    NotificationType.newMessage: Color(0xFF1E8E3E),
    NotificationType.eventJoin: Color(0xFF1565C0),
    NotificationType.forumLike: Color(0xFFE65100),
    NotificationType.forumReply: Color(0xFF6A1B9A),
  };

  String _timeAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'przed chwilą';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min temu';
    if (diff.inHours < 24) return '${diff.inHours} godz. temu';
    if (diff.inDays < 7) return '${diff.inDays} dni temu';
    final DateTime l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor =
        _colors[notification.type] ?? cs.primary;
    final IconData icon = _icons[notification.type] ?? Icons.notifications;
    final bool unread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread
            ? cs.primaryContainer.withValues(alpha: 0.18)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          notification.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(notification.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (notification.body != null &&
                      notification.body!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      notification.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (unread) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Empty / Error views ──────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.filter,
    required this.cs,
    required this.theme,
  });

  final _Filter filter;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
        Icon(
          Icons.notifications_none_rounded,
          size: 72,
          color: cs.primary.withValues(alpha: 0.45),
        ),
        const SizedBox(height: 20),
        Text(
          'Brak powiadomień',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tu pojawią się Twoje powiadomienia.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Odśwież'),
            ),
          ],
        ),
      ),
    );
  }
}
