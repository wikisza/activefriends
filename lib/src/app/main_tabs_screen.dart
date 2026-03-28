import 'dart:async';

import 'package:activefriends/src/app/ui/premium_widgets.dart';
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

  final GlobalKey<MapScreenState> _mapKey = GlobalKey<MapScreenState>();

  final ChatRepository _chatRepo = ChatRepository();
  final NotificationRepository _notifRepo = NotificationRepository();
  final SupabaseClient _client = Supabase.instance.client;

  RealtimeChannel? _msgChannel;
  RealtimeChannel? _notifChannel;

  static const int _chatTabIndex = 1;
  static const int _notifTabIndex = 3;

  late final List<Widget> _tabs = <Widget>[
    MapScreen(key: _mapKey),
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

  void _handleTabSelection(int index) {
    if (index == 0) {
      _mapKey.currentState?.loadPins();
    }
    setState(() {
      _currentIndex = index;
      if (index == _chatTabIndex) _unreadChat = 0;
      if (index == _notifTabIndex) _unreadNotifications = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: AnimatedGradientTabBar(
        selectedIndex: _currentIndex,
        onTap: _handleTabSelection,
        items: <TabItem>[
          const TabItem(
            icon: Icons.map_outlined,
            activeIcon: Icons.map,
            label: 'Mapa',
          ),
          TabItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            label: 'Czat',
            badge: _unreadChat,
          ),
          const TabItem(
            icon: Icons.forum_outlined,
            activeIcon: Icons.forum,
            label: 'Forum',
          ),
          TabItem(
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications,
            label: 'Powiadomienia',
            badge: _unreadNotifications,
          ),
          const TabItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
