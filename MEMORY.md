# MEMORY.md - SafeDrive

Memoria del proyecto entre sesiones. Máximo ~50 líneas: resume o elimina lo que ya no aporte.

## Estado actual

* Base en Flutter multiplataforma con autenticación en Supabase y mapas OpenStreetMap interactivos.
* Autenticación con Google robusta: manejo de cancelación y navegación atrás mediante `WidgetsBindingObserver` para liberar `isLoading` al volver a primer plano.
* Flujo de registro secuencial premium (`RegisterScreen`) con `RegisterDotsIndicator`.
* Módulo de mapa y GPS reparado con permisos nativos, posición inmediata y Auto-Follow en `FreeDriveMapWidget`.
* Módulo de cámara: calibración (`calibration_screen.dart`) y monitoreo (`drive_screen.dart`).
* Pruebas y análisis validados en verde (46 tests pasando, 0 advertencias de linter).

## Decisiones (y por qué)

* **WidgetsBindingObserver para OAuth móvil:** Al abrir el navegador/cuenta de Google y volver atrás o cancelar, el callback nunca llegaba de vuelta por deep-link; escuchar el ciclo de vida (`resumed`) desbloquea el botón si no se creó sesión, permitiendo reintentar de inmediato.
* **Modo Auto-Follow en mapas:** Centra la cámara automáticamente sobre el conductor. Si el usuario arrastra el mapa para explorar, el seguimiento se pausa y se ofrece el botón "Recentrar".
* **Flujo secuencial de registro paso a paso:** Divide bienvenida, nombre, teléfono SOS, correo, contraseña y datos médicos opcionales.

## Aprendizajes y errores a evitar

* No anidar el reseteo de `isLoading` dentro de un condicional que solo corre cuando hay error visible; si el usuario cancela, `error` puede contener 'cancel' o ser nulo y el estado de carga debe restablecerse siempre.
* Liberar controladores de cámara, GPS y observers en `dispose()` para prevenir fugas de memoria.
* Ejecutar `flutter analyze` y `flutter test` tras cada modificación.

## Próximos pasos

* Probar el inicio de sesión con Google y el flujo de registro en un dispositivo real.
