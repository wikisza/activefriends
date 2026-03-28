import 'package:activefriends/src/app/main_tabs_screen.dart';
import 'package:activefriends/src/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveFriendsApp extends StatelessWidget {
  const ActiveFriendsApp({super.key});

  static const Color _brandInk = Color(0xFF111827);
  static const Color _brandMuted = Color(0xFF6B7280);
  static const Color _brandBorder = Color(0xFFE5E7EB);
  static const Color _brandPanel = Color(0xFFF9FAFB);

  ThemeData _buildAgoraTheme() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.light,
      surface: Colors.white,
      onSurface: _brandInk,
      primary: _brandInk,
      onPrimary: Colors.white,
      secondary: const Color(0xFF2563EB),
      onSecondary: Colors.white,
      outline: _brandBorder,
    );

    final TextTheme textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: _brandInk,
      displayColor: _brandInk,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _brandInk,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _brandBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _brandPanel,
        labelStyle: textTheme.bodyMedium?.copyWith(color: _brandMuted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: _brandMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _brandBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _brandBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9CA3AF), width: 1.1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandInk,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _brandInk,
          side: const BorderSide(color: _brandBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _brandPanel,
        selectedColor: const Color(0xFFE5E7EB),
        labelStyle: textTheme.bodySmall?.copyWith(color: _brandInk),
        side: const BorderSide(color: _brandBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: _brandMuted,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: _brandMuted),
      ),
      dividerTheme: const DividerThemeData(color: _brandBorder, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        indicatorColor: const Color(0xFFE5E7EB),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall!.copyWith(
              color: _brandInk,
              fontWeight: FontWeight.w600,
            );
          }
          return textTheme.labelSmall!.copyWith(
            color: _brandMuted,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _brandInk,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Active Friends',
      debugShowCheckedModeBanner: false,
      theme: _buildAgoraTheme(),
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
