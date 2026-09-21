import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThemeService {
  ThemeService._();

  /// Estado reactivo del modo oscuro (por defecto true: Modo Noche / Obsidian)
  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);

  static bool get isDark => isDarkMode.value;

  static void toggleTheme() {
    HapticFeedback.selectionClick();
    isDarkMode.value = !isDarkMode.value;
  }

  static void setDarkMode(bool value) {
    if (isDarkMode.value != value) {
      isDarkMode.value = value;
    }
  }
}

/// Paleta dinámica adaptativa para SafeDrive (Modo Noche / Modo Día)
class AppColors {
  AppColors._();

  // Fondos principales
  static Color bg(bool isDark) => isDark ? const Color(0xFF090D14) : const Color(0xFFF8FAFC);
  static Color card(bool isDark) => isDark ? const Color(0xFF111722) : const Color(0xFFFFFFFF);
  static Color cardSecondary(bool isDark) => isDark ? const Color(0xFF161E2E) : const Color(0xFFF1F5F9);
  static Color navBar(bool isDark) => isDark ? const Color(0xE6121722) : const Color(0xF2FFFFFF);

  // Tipografías
  static Color t1(bool isDark) => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  static Color t2(bool isDark) => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static Color t3(bool isDark) => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  // Bordes y separadores
  static Color border(bool isDark) => isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  static Color borderLight(bool isDark) => isDark ? const Color(0xFF283548) : const Color(0xFFCBD5E1);

  // Colores de acento de marca y estado (permanentes y vibrantes)
  static const Color brand = Color(0xFF00C472);
  static const Color brandDim = Color(0xFF009558);
  static Color brandGlow(bool isDark) => isDark ? const Color(0x2A00C472) : const Color(0x1F00C472);

  static const Color blue = Color(0xFF3B82F6);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color cyan = Color(0xFF06B6D4);
}
