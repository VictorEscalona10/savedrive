# Constitución SafeDrive
Principios innegociables. Toda spec, plan y tarea debe cumplirlos.

1. **Simplicidad del stack**: Flutter (Dart) con Null Safety, Supabase, `camera` y `google_mlkit_face_detection`. Prohibido añadir paquetes externos sin aprobación previa.
2. **La spec manda (Spec-anchored)**: Nada se implementa si no está en la spec activa (`specs/NNN-*/spec.md`). Cualquier cambio de requisito actualiza primero la spec antes que el código.
3. **Lógica separada de interfaz**: Los cálculos de somnolencia (EAR, ángulos Euler, umbrales de velocidad e inhibición en paradas/semáforos) deben ser funciones puras desacopladas de los Widgets y de la cámara.
4. **Tests y análisis como puerta**: La lógica pura se prueba con `flutter test` y el código se valida con `flutter analyze`. Prohibido avanzar de tarea con tests en rojo o errores de linter.
5. **Protección de datos y memoria**: Respetar las políticas RLS de Supabase (`users`, `user_settings`, `emergency_contacts`) y usar siempre el flag `_isProcessingFrame` en el stream de cámara para evitar desbordamientos de memoria.
6. **Reglas de UX e idioma**: Sensibilidad facial fija por calibración (no personalizable por el usuario), mapa integrado en `DriveScreen` y textos de interfaz/documentación en español.