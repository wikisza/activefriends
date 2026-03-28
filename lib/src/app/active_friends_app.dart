import 'package:activefriends/src/app/main_tabs_screen.dart';
import 'package:activefriends/src/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (BuildContext context, AsyncSnapshot<AuthState> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final Session? session = snapshot.data?.session;
          if (session != null) {
            return const MainTabsScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
