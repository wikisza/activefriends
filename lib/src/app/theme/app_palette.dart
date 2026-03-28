import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette._();

  // ─── Brand gradient: deep grass → fresh green ────────────────
  static const Color brandStart = Color(0xFF16A34A);
  static const Color brandEnd   = Color(0xFF4ADE80);

  static const LinearGradient brandGradient = LinearGradient(
    colors: <Color>[brandStart, brandEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Tab bar pill gradient (same direction, slightly different angle for variety)
  static const LinearGradient tabGradient = LinearGradient(
    colors: <Color>[brandStart, brandEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static List<BoxShadow> get brandShadow => <BoxShadow>[
    BoxShadow(
      color: brandStart.withValues(alpha: 0.45),
      blurRadius: 22,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get tabGlow => <BoxShadow>[
    BoxShadow(
      color: brandStart.withValues(alpha: 0.50),
      blurRadius: 18,
      spreadRadius: -2,
    ),
  ];

  // ─── Dark surfaces ────────────────────────────────────────────
  static const Color dark0      = Color(0xFF0C0C0D); // scaffold bg
  static const Color dark1      = Color(0xFF161618); // cards
  static const Color dark2      = Color(0xFF1E1E21); // elevated
  static const Color darkBorder = Color(0xFF2A2A2E);
  static const Color darkMuted  = Color(0xFF88889A);

  // ─── Semantic ────────────────────────────────────────────────
  static const Color success    = Color(0xFF22C55E);
  static const Color emergency  = Color(0xFFEF4444);
  static const Color social     = Color(0xFFA855F7);
  static const Color warning    = Color(0xFFFFB300);
  static const Color warningOn  = Colors.black;
  static const Color successSoft = Color(0xFF14532D);

  static Color scenarioColorByName(String scenarioName) {
    return switch (scenarioName) {
      'bikeRide'  => success,
      'emergency' => emergency,
      'social'    => social,
      _           => brandStart,
    };
  }
}
