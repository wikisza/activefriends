import 'package:activefriends/src/app/main_tabs_screen.dart';
import 'package:activefriends/src/app/theme/app_palette.dart';
import 'package:activefriends/src/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveFriendsApp extends StatelessWidget {
  const ActiveFriendsApp({super.key});

  ThemeData _buildDarkTheme() {
    final ColorScheme scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppPalette.brandStart,
      onPrimary: Colors.black,
      primaryContainer: AppPalette.dark2,
      onPrimaryContainer: AppPalette.brandEnd,
      secondary: AppPalette.brandEnd,
      onSecondary: Colors.black,
      secondaryContainer: AppPalette.dark2,
      onSecondaryContainer: AppPalette.brandEnd,
      tertiary: AppPalette.social,
      onTertiary: Colors.white,
      tertiaryContainer: AppPalette.dark2,
      onTertiaryContainer: AppPalette.social,
      error: AppPalette.emergency,
      onError: Colors.white,
      errorContainer: const Color(0xFF7F1D1D),
      onErrorContainer: AppPalette.emergency,
      surface: AppPalette.dark1,
      onSurface: Colors.white,
      surfaceContainerHighest: AppPalette.dark2,
      onSurfaceVariant: AppPalette.darkMuted,
      outline: AppPalette.darkBorder,
      outlineVariant: AppPalette.darkBorder,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Colors.white,
      onInverseSurface: AppPalette.dark0,
      inversePrimary: AppPalette.brandStart,
    );

    final TextTheme textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(bodyColor: Colors.white, displayColor: Colors.white);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.dark0,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppPalette.dark1,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppPalette.dark1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppPalette.darkBorder.withValues(alpha: 0.6)),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.dark2,
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppPalette.darkMuted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppPalette.darkMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.brandStart, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.brandStart,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: AppPalette.darkBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppPalette.brandStart),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.brandStart,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.dark2,
        selectedColor: AppPalette.brandStart.withValues(alpha: 0.25),
        checkmarkColor: AppPalette.brandStart,
        labelStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        side: const BorderSide(color: AppPalette.darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: AppPalette.dark1,
        iconColor: AppPalette.darkMuted,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: AppPalette.darkMuted),
      ),
      dividerTheme: const DividerThemeData(color: AppPalette.darkBorder, thickness: 0.5),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.black);
          }
          return const IconThemeData(color: AppPalette.darkMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall!.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            );
          }
          return textTheme.labelSmall!.copyWith(
            color: AppPalette.darkMuted,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.dark2,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.dark1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppPalette.darkMuted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.brandStart;
          return AppPalette.darkMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppPalette.brandStart.withValues(alpha: 0.3);
          }
          return AppPalette.dark2;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blisko',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (BuildContext context, AsyncSnapshot<AuthState> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final Session? session = snapshot.data?.session;
          if (session != null) return const MainTabsScreen();
          return const LoginScreen();
        },
      ),
    );
  }
}
