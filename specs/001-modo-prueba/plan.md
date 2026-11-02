# Plan 001 — Modo de Prueba (Demo Interactivo con Cámara)

## Alcance
Implementa los requisitos revisados de `specs/001-modo-prueba/spec.md` (RF-1 a RF-12). Reemplaza la secuencia de simulación estática por un ciclo de detección facial interactivo en tiempo real con la cámara frontal en la cabina, con baseline predeterminado (EAR 0.75, ángulo 0°), tolerancia reducida a 1 segundo e ignorando el límite de velocidad de 10 km/h para pruebas inmediatas en mano o detenido.

## Arquitectura (archivos y responsabilidades)

| Archivo | Responsabilidad |
|---|---|
| `lib/domain/monitoring/fatigue_evaluator.dart` | Lógica pura del evaluador: soporte para `ignoreSpeedThreshold`, detección de ausencia de rostro (`isFaceDetected`) y tolerancia de 1 s. |
| `lib/core/utils/camera_image_converter.dart` (nuevo) | Función pura desacoplada para convertir `CameraImage` a `InputImage` para ML Kit (Constitución §3). |
| `lib/core/services/test_mode_controller.dart` | Estado de sesión global observable en memoria (singleton). |
| `lib/presentation/components/test_mode/test_mode_badge.dart` | Chip «MODO PRUEBA» reutilizable para dashboard y cabina. |
| `lib/presentation/screens/dashboard/home_screen.dart` | Entrada directa a `DriveScreen` con cámara frontal sin pasar por `CalibrationScreen`. |
| `lib/presentation/screens/camera/drive_screen.dart` | Ciclo de vida de cámara/detector en segundo plano, stream con flag `_isProcessingFrame`, evaluación en tiempo real, actualización de chip EAR, alertas inmediatas y `dispose()` seguro. |
| `lib/presentation/screens/settings/settings_screen.dart` | Interruptor del modo de prueba en «Tolerancia & Telemetría». |
| `lib/presentation/screens/profile/profile_screen.dart` | Borrado del modo de prueba al cerrar sesión. |
| `test/*` | Tests unitarios de lógica pura (`fatigue_evaluator_test.dart`), controlador y widgets de cabina. |

## Interfaces públicas y modelos

```dart
// domain/monitoring/fatigue_evaluator.dart
class FatigueEvaluationResult {
  final MonitoringState state;
  final double earDropPercent;
  final double headAngleDeviation;
  final bool isDrowsy;
  final bool isDistracted;
  final bool isFaceLost;
  final bool isSilencedByTraffic;
  final String statusMessage;
  // ...
}

class FatigueEvaluator {
  final double baselineEar;
  final double baselineHeadAngle;
  final int alarmToleranceSeconds;
  final bool ignoreSpeedLimit; // Para modo prueba: no silencia a 0 km/h

  FatigueEvaluationResult evaluate({
    required double currentEar,
    required double currentHeadAngleY,
    required double currentSpeedKmh,
    bool isFaceDetected = true,
  });
}

// core/utils/camera_image_converter.dart
InputImage? convertCameraImageToInputImage({
  required CameraImage image,
  required CameraDescription description,
});
```

## Algoritmo / pseudocódigo de Cabina Interactiva

```
HOME._iniciarViaje:
  SI TestModeController.instance.enabled:
    solicitar permiso de cámara
    obtener cámara frontal de availableCameras()
    push DriveScreen(isTestMode: true, frontCamera: frontCamera)
  SINO:
    flujo normal intacto (permiso → availableCameras → push CalibrationScreen)

DRIVE.initState:
  baseline = 0.75 / 0°
  evaluator = FatigueEvaluator(baselineEar: 0.75, baselineHeadAngle: 0.0, alarmToleranceSeconds: 1, ignoreSpeedLimit: true)
  SI frontCamera != null:
    cameraController = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false)
    await cameraController.initialize()
    cameraController.startImageStream((image) {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;
      try:
        faces = await faceDetector.processImage(convertedInputImage)
        if faces.isNotEmpty:
          face = faces.first
          ear = calculateEar(face) // promedio de leftEyeOpen y rightEyeOpen
          angle = face.headEulerAngleY
          evalResult = evaluator.evaluate(currentEar: ear, currentHeadAngleY: angle, currentSpeedKmh: 0, isFaceDetected: true)
        else:
          evalResult = evaluator.evaluate(currentEar: 0.0, currentHeadAngleY: 0.0, currentSpeedKmh: 0, isFaceDetected: false)
        
        actualizar UI (EAR chip, mensaje, alertState)
        si evalResult.state == alertWarning:
          emitir sonido (SystemSound.alert) + vibración (HapticFeedback.heavyImpact) + destello visual
      finally:
        _isProcessingFrame = false
    })

DRIVE.dispose:
  _isProcessingFrame = false
  cameraController?.stopImageStream()
  cameraController?.dispose()
  faceDetector.close()
  locationService.stopTracking()
  TestModeController.instance.handleTripFinished()
```

## Decisiones justificadas (alternativas descartadas)
1. **Detección facial en tiempo real en la cabina (no simulación por timers):**
   - Justificación: Permite al usuario verificar que la app responde físicamente cuando él cierra los ojos, gira la cabeza o se retira del plano.
   - Alternativa descartada: Secuencia prefijada por timers (descartada porque no reacciona al usuario real).
2. **Baseline predeterminado (EAR 0.75, 0°) en modo prueba:**
   - Justificación: Elimina el requisito de 50 frames y 30 s de espera de la Calibración Fantasma, cumpliendo el requisito de entrada inmediata en ≤2 s.
   - Alternativa descartada: Calibración abreviada de 5 frames (descartada porque aún añade una pantalla de bloqueo intermedia).
3. **`ignoreSpeedLimit: true` en modo prueba:**
   - Justificación: Permite al usuario sentarse o tener el teléfono en la mano (0 km/h) y ver sonar la alarma sin tener que conducir un coche real a >10 km/h para testear.
   - Alternativa descartada: Requerir simulación de movimiento GPS (complejo de activar en dispositivo real).
4. **Tolerancia de 1 segundo (en vez de 3 s):**
   - Justificación: Ofrece una respuesta ágil para demostración, mientras evita disparos accidentales por un parpadeo normal de 200-300 ms.
   - Alternativa descartada: Reacción instantánea a 0 ms (descartada porque dispararía la alarma en cada parpadeo fisiológico natural).

## Estrategia de pruebas
- `test/domain/fatigue_evaluator_test.dart`: Validar `ignoreSpeedLimit`, `isFaceDetected: false` tras 1 s, `earDropPercent >= 0.35` tras 1 s y retorno a `normal`.
- `test/presentation/drive_screen_test_mode_test.dart`: Verificar renderizado en modo prueba sin hardware real, badge presente, y `dispose()` limpio.
- `flutter test` y `flutter analyze`: 100% en verde.
