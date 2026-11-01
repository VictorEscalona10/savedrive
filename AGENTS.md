# AGENTS.md - SafeDrive

Aplicación móvil multiplataforma en Flutter para monitoreo de conducción segura, calibración de cámara y asistencia al conductor en tiempo real.

## Stack y estructura
- **Stack:** Flutter y Dart (ver versiones y paquetes en `pubspec.yaml`).
- `lib/main.dart`: Punto de entrada y configuración global.
- `lib/presentation/layouts/`: Estructuras base de navegación (`main_layout_screen.dart`).
- `lib/presentation/screens/`: Vistas principales (`home_screen.dart`, `login_screen.dart`, `profile_screen.dart`) y módulo de cámara en `camera/` (`calibration_screen.dart`, `drive_screen.dart`).
- `lib/components/`: Widgets reutilizables (ej. `loginForm/login_form.dart`).
- `lib/server/`: Lógica de conexión, servicios y autenticación (`login.dart`).
- `agent_context/agent_context.md`: Contexto adicional del proyecto que debes consultar.

## Comandos
- Instalar paquetes: `flutter pub get`
- Analizar código (Lint): `flutter analyze`
- Ejecutar tests: `flutter test`
- Compilar/Ejecutar: `flutter run`

## Convenciones y Skills
- **Estilo:** Sigue las reglas de `analysis_options.yaml`. Nombres de archivos en `snake_case` y clases en `PascalCase`.
- **Idioma:** Textos de la interfaz en español; código e identificadores en inglés.
- **UI/UX:** Usa las skills instaladas en `.agents/skills/` (`sleek-design-mobile-apps` y `ui-ux-pro-max`) antes de crear o modificar pantallas. Toma `main_layout_screen.dart` como referencia de estructura visual.

## Reglas de dominio / trampas conocidas
- **Cámara y ciclo de vida:** En `calibration_screen.dart` y `drive_screen.dart`, libera siempre los controladores de cámara y streams en `dispose()` para evitar fugas de memoria o bloqueos del hardware.
- **Separación de responsabilidades:** No mezcles llamadas HTTP/servidor directamente dentro de los métodos `build()` de la UI; ubícalas en `lib/server/`.

## Forma de trabajar y Memoria
- Al empezar, lee `MEMORY.md` y `agent_context/agent_context.md` para conocer el estado actual.
- Para tareas grandes o cambios en el flujo de cámara, usa el modo **Plan** antes de tocar código.

## Límites
- **Siempre:** Ejecutar `flutter analyze` tras cada cambio y actualizar `MEMORY.md` al terminar una tarea.
- **Pregunta antes:** Añadir dependencias en `pubspec.yaml`, crear nuevas carpetas en `lib/` o modificar permisos nativos (`AndroidManifest.xml` / `Info.plist`).
- **Nunca:** Romper el flujo entre `calibration_screen.dart` y `drive_screen.dart` ni exponer credenciales en el código.

## Verificación
- Comprobar que `flutter analyze` no arroje errores ni warnings y que `flutter test` pase en verde antes de dar una tarea por terminada.

## Memoria 
- Al empezar, lee `MEMORY.md` para conocer el estado del proyecto y las decisiones tomadas. 
- Al terminar una tarea, actualízalo: estado actual, decisiones importantes (con su porqué) y errores a evitar. 
- Mantenlo breve (máximo ~50 líneas): resume o elimina lo que ya no aporte. 
- Si algo se convierte en una regla permanente, propón moverlo a `AGENTS.md` en lugar de dejarlo en la memoria. - No guardes nunca datos sensibles (claves, tokens, datos personales).

## Comandos
- Tests: `flutter test`
- Linter: `flutter analyze`

## Reglas
- Lee `docs/constitution.md` y la spec activa (`specs/NNN-*/`) antes de tocar código.