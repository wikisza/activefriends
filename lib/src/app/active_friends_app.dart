import 'package:activefriends/src/app/main_tabs_screen.dart';
import 'package:flutter/material.dart';

class ActiveFriendsApp extends StatelessWidget {
  const ActiveFriendsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Active Friends',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E8E3E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFE9EEF2),
        useMaterial3: true,
      ),
      home: const MainTabsScreen(),
    );
  }
}
