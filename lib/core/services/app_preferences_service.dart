import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesService {
  AppPreferencesService._();

  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';

  /// Retorna true si es la primera vez que se abre la aplicación
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(_keyHasSeenOnboarding) ?? false;
    return !hasSeen;
  }

  /// Marca que el usuario ya completó o vio el flujo de registro inicial
  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenOnboarding, true);
  }

  /// Reinicia el flag para propósitos de pruebas
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHasSeenOnboarding);
  }
}

