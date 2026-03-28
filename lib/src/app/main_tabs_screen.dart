import 'dart:async';

import 'package:activefriends/src/features/chat/data/chat_repository.dart';
import 'package:activefriends/src/features/chat/presentation/chat_conversations_screen.dart';
import 'package:activefriends/src/features/forum/presentation/forum_screen.dart';
import 'package:activefriends/src/features/map/presentation/map_screen.dart';
import 'package:activefriends/src/features/notifications/data/notification_repository.dart';
import 'package:activefriends/src/features/notifications/presentation/notifications_screen.dart';
import 'package:activefriends/src/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _currentIndex = 0;
  int _unreadChat = 0;
  int _unreadNotifications = 0;

  final ChatRepository _chatRepo = ChatRepository();
  final NotificationRepository _notifRepo = NotificationRepository();
  final SupabaseClient _client = Supabase.instance.client;

  RealtimeChannel? _msgChannel;
  RealtimeChannel? _notifChannel;

  static const int _chatTabIndex = 1;
  static const int _notifTabIndex = 3;

  late final List<Widget> _tabs = <Widget>[
    const MapScreen(),
    const ChatConversationsScreen(),
    const ForumScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _subscribeToMessages();
    _subscribeToNotifications();
  }

  void _subscribeToMessages() {
    _msgChannel = _chatRepo.subscribeToAllNewMessages((String senderId) {
      final String? myId = _client.auth.currentUser?.id;
      if (senderId == myId) return;
      if (_currentIndex == _chatTabIndex) return;
      if (mounted) setState(() => _unreadChat++);
    });
  }

  void _subscribeToNotifications() {
    _notifChannel = _notifRepo.subscribeToUnreadCount(() {
      if (_currentIndex == _notifTabIndex) return;
      if (mounted) setState(() => _unreadNotifications++);
    });
  }

  @override
  void dispose() {
    final RealtimeChannel? m = _msgChannel;
    final RealtimeChannel? n = _notifChannel;
    if (m != null) unawaited(_client.removeChannel(m));
    if (n != null) unawaited(_client.removeChannel(n));
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
      if (index == _chatTabIndex) _unreadChat = 0;
      if (index == _notifTabIndex) _unreadNotifications = 0;
    });
  }

  Widget _badgeIcon(Widget icon, int count) {
    if (count == 0) return icon;
    return Badge(
      label: count > 9 ? const Text('9+') : Text('$count'),
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          destinations: <NavigationDestination>[
            const NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: _badgeIcon(const Icon(Icons.chat_bubble_outline), _unreadChat),
              selectedIcon: _badgeIcon(const Icon(Icons.chat_bubble), _unreadChat),
              label: 'Czat',
            ),
            const NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'Forum',
            ),
            NavigationDestination(
              icon: _badgeIcon(const Icon(Icons.notifications_outlined), _unreadNotifications),
              selectedIcon: _badgeIcon(const Icon(Icons.notifications), _unreadNotifications),
              label: 'Powiadomienia',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
