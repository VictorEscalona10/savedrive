# MEMORY.md - SafeDrive

Memoria del proyecto entre sesiones. Máximo ~50 líneas: resume o elimina lo que ya no aporte.

## Estado actual

* Base en Flutter multiplataforma con autenticación en Supabase y mapas interactivos con seguimiento GPS.
* Spec 001 Modo de Prueba con cámara interactiva completamente calibrada y optimizada para dispositivos físicos (ej. Xiaomi Redmi Note 13 Pro):
  - Conversión de cámara corregida: `WriteBuffer` con `ByteData.offsetInBytes`/`lengthInBytes` y rotación sensor compensada.
  - Autocalibración de postura inicial al detectar el rostro + tolerancia ampliada a ±30° para sostener cómodamente en mano.
  - Alarma real con canal nativo Android: `ToneGenerator` (canal ALARM a máximo volumen) + `Vibrator` físico de 400 ms + permiso `android.permission.VIBRATE`.
  - Chip superior informa estado en tiempo real: `EAR: XX%` o `SIN ROSTRO`.
* Suite completa validada: 57/57 tests pasando en `flutter test` y 0 errores/warnings en `flutter analyze`.

## Decisiones (y por qué)

* **Alarma sonora y vibración nativas en Android:** `SystemSound.play(alert)` y `heavyImpact` en Flutter solo producen clicks mudos en dispositivos Android como Xiaomi/MIUI. Se implementó `ToneGenerator` y `Vibrator` nativo en `MainActivity.kt` sin dependencias externas.
* **Autocalibración de postura inicial en demo:** Permite que el ángulo del rostro al entrar sea el baseline cero relativo, evitando falsas alarmas por cómo se sostiene el teléfono.
* **WriteBuffer sin desalineación:** Se corrigió la copia de planos para respetar el padding de memoria de CameraX/ML Kit.

## Aprendizajes y errores a evitar

* En Flutter `WriteBuffer.done().buffer.asUint8List()` devuelve el buffer entero con ceros al final salvo que se usen `offsetInBytes` y `lengthInBytes`.
* Para sonido audible de emergencia en Android no depender de `SystemSoundType.alert`.

## Próximos pasos

* T7: Validación por el usuario en su teléfono físico recargando la app (`flutter run`).
