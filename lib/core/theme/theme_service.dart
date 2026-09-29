import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

export 'app_colors.dart';

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
