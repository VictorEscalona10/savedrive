import 'package:flutter/foundation.dart';

/// Controlador del modo de prueba como estado de sesión (RF-1, RF-2, RF-3, RF-11).
///
/// Vive únicamente en memoria mientras la app está abierta: no escribe en
/// Supabase, ni en `SharedPreferences`, ni en archivos, ni hace peticiones de
/// red. El modo se borra al desactivarlo, al finalizar el viaje, al cerrar la
/// sesión de usuario o al cerrar la app.
class TestModeController {
  TestModeController._();

  /// Instancia única usada por Ajustes, el dashboard y la cabina.
  static final TestModeController instance = TestModeController._();

  /// Estado observable del modo de prueba; empieza desactivado.
  final ValueNotifier<bool> isActive = ValueNotifier<bool>(false);

  /// Indica si el modo de prueba está activo en este momento.
  bool get enabled => isActive.value;

  /// Activa el modo de prueba. Si ya estaba activo no notifica de nuevo.
  void enable() => _setActive(true);

  /// Desactiva el modo de prueba. Si ya estaba inactivo no notifica de nuevo.
  void disable() => _setActive(false);

  /// Finaliza el viaje en curso: el modo deja de estar activo (RF-9).
  void handleTripFinished() => disable();

  /// Cierra la sesión de usuario: el modo deja de estar activo (RF-2).
  void handleSignOut() => disable();

  /// Cambia el estado solo cuando hay una transición real, para que cada
  /// cambio produzca exactamente una notificación.
  void _setActive(bool value) {
    if (isActive.value == value) {
      return;
    }
    isActive.value = value;
  }
}
