import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette._();

  static const Color success = Color(0xFF0F7D31);
  static const Color emergency = Color(0xFFD14343);
  static const Color social = Color(0xFF7B4AC8);

  static const Color warning = Color(0xFFF1B500);
  static const Color warningOn = Colors.black;

  static const Color successSoft = Color(0xFFE4F2E7);

  static Color scenarioColorByName(String scenarioName) {
    switch (scenarioName) {
      case 'bikeRide':
        return success;
      case 'emergency':
        return emergency;
      case 'social':
        return social;
      default:
        return success;
    }
  }
}
