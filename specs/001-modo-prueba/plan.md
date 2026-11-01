# Plan 001 — Modo de Prueba (Demo)

## Alcance
Implementa los 12 RF de `specs/001-modo-prueba/spec.md` sin tocar la calibración real ni el flujo normal. Sin paquetes nuevos: `SystemSound` + `HapticFeedback`.

## Arquitectura (archivos y responsabilidades)
| Archivo | Responsabilidad |
|---|---|
| `lib/domain/test_mode/test_mode_sequence.dart` (nuevo) | Constantes y lógica pura de la secuencia (ms → disparo/destello). |
| `lib/core/services/test_mode_controller.dart` (nuevo) | Estado de sesión global observable, singleton en memoria, sin persistencia. |
| `lib/presentation/components/test_mode/test_mode_badge.dart` (nuevo) | Chip «MODO PRUEBA» reutilizable (dashboard y cabina). |
| `lib/presentation/components/test_mode/test_mode_alert_driver.dart` (nuevo) | Orquesta 6 timers, sonido, háptico, destello y cancelación por ciclo de vida. |
| `lib/presentation/screens/settings/settings_screen.dart` | Interruptor en «Tolerancia & Telemetría» + inyección opcional de repositorio. |
| `lib/presentation/screens/dashboard/home_screen.dart` | Chip/subtítulo de demo y rama directa a cabina sin cámara. |
| `lib/presentation/screens/camera/drive_screen.dart` | `isTestMode`, valores fijos, panel forzado, chip EAR e integración del driver. |
| `lib/presentation/screens/profile/profile_screen.dart` | Borra el modo al cerrar sesión de usuario. |
| `test/*` | Tests nuevos y saneamiento del test plantilla. |

`SettingsRepository.saveUserSettings` y `UserSettingsModel` NO se modifican: el modo no es campo de ajustes; el interruptor no forma parte del payload de «Guardar Ajustes».

## Interfaces públicas
```dart
// domain
class TestModeCue { final int index; final int atMs; const TestModeCue(...); }
abstract final class TestModeSequence {
  static const List<int> cueOffsetsMs = [0, 2000, 4000, 6000, 8000, 10000];
  static const int flashDurationMs = 400;
  static const double fixedEar = 0.75;
  static const double fixedHeadAngleDeg = 0.0;
  static TestModeCue? cueAt(int elapsedMs); // exacto; null fuera de offsets
  static bool isFinished(int elapsedMs) => elapsedMs > 10000;
}
// estado de sesión
class TestModeController {
  static final TestModeController instance = TestModeController._();
  final ValueNotifier<bool> isActive; // false inicial
  bool get enabled; void enable(); void disable();
  void handleTripFinished(); void handleSignOut(); // alias de disable, idempotentes
}
// UI
class TestModeBadge extends StatelessWidget { const TestModeBadge({super.key, this.compact = false}); }
class TestModeAlertDriver extends StatefulWidget {
  const TestModeAlertDriver({super.key, required this.active, required this.child,
    this.onCue, this.onRunningChanged});
  final bool active; final Widget child;
  final ValueChanged<int>? onCue;          // índice 0..5
  final ValueChanged<bool>? onRunningChanged;
}
```
Conexión: `ValueListenableBuilder<bool>(valueListenable: TestModeController.instance.isActive)` en Ajustes, dashboard y cabina. `onRunningChanged` alimenta `_sequenceRunning` de `DriveScreen`; `onCue` es opcional para telemetría visual.

## Algoritmo / pseudocódigo
```
ENABLE: controller.enable() → isActive.value = true  // sin repos, sin red
DISABLE/TRIP_END/SIGN_OUT/APP_CLOSE: isActive.value = false; timers cancelados por dispose

HOME._iniciarViaje:
  SI controller.enabled:
    HapticFeedback.mediumImpact(); push DriveScreen(isTestMode:true)
  SINO: flujo actual intacto (permiso → availableCameras → CalibrationScreen)

DRIVE.initState(isTestMode):
  evaluator = FatigueEvaluator(baselineEar:0.75, baselineHeadAngle:0)
  NO _loadData(); NO SettingsRepository/EmergencyContactRepository (lazy)
  SI enableTelemetry: startTracking(...)   // false en tests
  _sequenceRunning = true

DRIVER(active):
  initState: para offset en cueOffsetsMs: Timer(offset, fireCue)
  fireCue(i): SystemSound.play(alert); heavyImpact(); destello on
              Timer(400ms, destello off); onCue(i)
              si i == 5 → Timer(400ms, onRunningChanged(false))
  paused|inactive|hidden → _cancelled=true; cancelar todos; onRunningChanged(false)
  dispose → cancelar todos; nunca reanudar si _cancelled

DRIVE.build:
  EAR visible = isTestMode ? 0.75 : widget.baselineEar  // chip «EAR: 75%»
  SI isTestMode y _sequenceRunning:
    estado panel = alertWarning; mensaje «¡ALERTA DE SOMNOLENCIA! (MODO PRUEBA)»
  SI isTestMode: envolver Scaffold en TestModeAlertDriver + TestModeBadge
FINALIZAR VIAJE: si test mode → controller.disable(); pop
```

## Decisiones justificadas (alternativa descartada)
1. Lógica pura con `ms` (no `Timer` dentro del test): tabla determinista y rápida; los timers quedan solo en el driver. Descartado: testear con esperas reales o `fake_async` prohibido.
2. `TestModeController` propio (no campo en `UserSettingsModel`): no requiere migración, RLS ni escrituras, y sobrevive al `IndexedStack`. Descartado: persistir en Supabase, que viola RF-2/RF-12.
3. Secuencia independiente de `FatigueEvaluator`: el evaluador no puede disparar pitidos con señal fija; además evita acoplar demo y seguridad real. Descartado: forzar EAR bajo y reutilizar la escalación.
4. Cabina demo sin `CameraController`, `availableCameras()` ni permisos: elimina la espera y funciona en emulador; el flujo normal no se toca. Descartado: abrir calibración con cuota reducida.
5. `SystemSound` + hápticos sin paquete de audio: cumple la constitución; el destello cubre web/emulador. Descartado: añadir `audioplayers` (requiere aprobación y assets).
6. Saneo de `widget_test.dart` reemplazando el contador obsoleto por un smoke real del badge: conserva cobertura de widget y elimina el fallo por `Supabase.instance`. Descartado: borrar el archivo o inicializar Supabase en tests.

## Trazabilidad RF → piezas
- RF-1, RF-2: `settings_screen` + `TestModeController` + `profile_screen`.
- RF-3: `home_screen` + `TestModeBadge`.
- RF-4, RF-5: rama de `_iniciarViaje` (sin cámara) y flujo normal intacto.
- RF-6: `TestModeSequence.fixedEar/HeadAngle` + `drive_screen` (EAR y evaluador).
- RF-7, RF-10: `TestModeSequence` + `TestModeAlertDriver`.
- RF-8, RF-11: `drive_screen` (panel forzado, badge).
- RF-9: `TestModeAlertDriver` (dispose/ciclo de vida) + `_finalizarViaje`.
- RF-12: ausencia de repos en modo prueba + payload de ajustes sin cambios.

## Tests (`flutter test`) y análisis
- `test/domain/test_mode_sequence_test.dart`: `cueAt` en 0, 1999, 2000, 2300, 9999, 10000, 10001 y negativos; `isFinished(10000)=false`, `isFinished(10001)=true`; total exacto 6 cues; destello 400 ms.
- `test/core/test_mode_controller_test.dart`: enable/disable/`handleTripFinished`/`handleSignOut`, idempotencia y una sola notificación por cambio.
- `test/presentation/test_mode_alert_driver_test.dart`: con reloj falso de `tester.pump`, 1 disparo en 0 s, 6 hasta 10 s, ninguno tras 10.5 s; destello visible 400 ms; `paused` cancela y no reanuda; `dispose` sin timers pendientes.
- `test/presentation/drive_screen_test_mode_test.dart`: smoke con `DriveScreen(isTestMode:true, enableTelemetry:false)`: «MODO PRUEBA», «EAR: 75%», panel en alerta; sin Supabase, cámara ni GPS.
- `test/presentation/settings_test_mode_test.dart`: repo falso inyectado; alternar el interruptor no llama a `saveUserSettings`; «Guardar Ajustes» no incluye el modo; el modo sigue activo al recargar.
- `test/widget_test.dart`: smoke de `TestModeBadge` (texto visible), sin `Safedrive`/Supabase.
- Puerta: `flutter test` completo en verde y `flutter analyze` con 0 errores y 0 warnings. Antes de T1 se registra el baseline de analyze; cualquier warning preexistente se corrige en T8 sin desactivar lints.

## Riesgos y mitigación
- `SystemSound` inaudible en web/escritorio o volumen 0 → destello incondicional (RF-10) y háptico en dispositivo físico.
- Timers huérfanos o `setState` tras `dispose` → lista de timers cancelada en `dispose`/background, flag `_cancelled` y `mounted` antes de actualizar.
- `SettingsRepository`/`Supabase.instance` se construyen ansiosamente en `DriveScreen` → repos `late final` y `_loadData` omitido en modo prueba.
- `IndexedStack` conserva Ajustes y recarga datos → el switch se enlaza al controlador, nunca a un `bool` local.
- Contraste del destello difícil de medir → color sólido rojo sobre fondo oscuro y verificación visual en T9; sin texto sobre el destello.
