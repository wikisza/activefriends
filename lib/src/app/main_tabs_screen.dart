import 'dart:async';

import 'package:activefriends/src/features/chat/data/chat_repository.dart';
import 'package:activefriends/src/features/chat/presentation/chat_conversations_screen.dart';
import 'package:activefriends/src/features/forum/presentation/forum_screen.dart';
import 'package:activefriends/src/features/map/presentation/map_screen.dart';
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
  int _unreadCount = 0;

  final GlobalKey<MapScreenState> _mapKey = GlobalKey<MapScreenState>();

  final ChatRepository _chatRepo = ChatRepository();
  final SupabaseClient _client = Supabase.instance.client;
  RealtimeChannel? _msgChannel;

  static const int _chatTabIndex = 1;

  late final List<Widget> _tabs = <Widget>[
    MapScreen(key: _mapKey),
    const ChatConversationsScreen(),
    const ForumScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _subscribeToMessages();
  }

  void _subscribeToMessages() {
    _msgChannel = _chatRepo.subscribeToAllNewMessages((String senderId) {
      final String? myId = _client.auth.currentUser?.id;
      if (senderId == myId) return;
      if (_currentIndex == _chatTabIndex) return;
      if (mounted) setState(() => _unreadCount++);
    });
  }

  @override
  void dispose() {
    final RealtimeChannel? ch = _msgChannel;
    if (ch != null) unawaited(_client.removeChannel(ch));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (int index) {
            // 3. LOGIKA ODŚWIEŻANIA:
            if (index == 0) { // Jeśli użytkownik klika w zakladkę Mapa (indeks 0)
              _mapKey.currentState?.loadPins(); // WYMUŚ ODŚWIEŻENIE PINÓW
            }

            if (index == _chatTabIndex) {
              setState(() {
                _currentIndex = index;
                _unreadCount = 0;
              });
            } else {
              setState(() => _currentIndex = index);
            }
          },
          destinations: <NavigationDestination>[
            const NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: _unreadCount > 9
                    ? const Text('9+')
                    : Text('$_unreadCount'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              selectedIcon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: _unreadCount > 9
                    ? const Text('9+')
                    : Text('$_unreadCount'),
                child: const Icon(Icons.chat_bubble),
              ),
              label: 'Czat',
            ),
            const NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'Forum',
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
