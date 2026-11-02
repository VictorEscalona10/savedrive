# Spec 001 — Modo de Prueba (Demo Interactivo con Cámara)

Estado: aprobada

## Contexto y objetivo
Actualmente, iniciar el monitoreo exige completar la Calibración Fantasma (50 frames válidos y timeout de 30 s), lo que dificulta demostraciones rápidas e interactivas. El usuario necesita un Modo de Prueba interactivo activable desde Ajustes que permita entrar de inmediato a la cabina con la cámara frontal y la detección facial activas (sin esperar calibración), para que al cerrar los ojos, apartar la mirada o retirar el rostro frente a la cámara, se dispare de inmediato la alarma sonora, háptica y visual, aun con el vehículo detenido (0 km/h), sin alterar los datos reales del conductor ni notificar a emergencias.

## Usuarios
- Conductor o demostrador con sesión de usuario iniciada que desea probar interactivamente las alertas del sistema ante somnolencia y distracción.

## Historias de usuario
- HU-1. Como demostrador, quiero activar el modo de prueba para acceder directamente a la cabina con la cámara activa sin pasar por la pantalla de calibración.
- HU-2. Como demostrador, quiero que al cerrar los ojos, apartar la mirada o quitar mi rostro durante ~1 segundo frente a la cámara, SafeDrive active de inmediato la alarma sonora, háptica y visual para validar que el sistema responde.
- HU-3. Como demostrador, quiero que al volver a mirar al frente con los ojos abiertos, la alarma cese y vuelva al estado normal de atención.
- HU-4. Como conductor real, quiero que el modo de prueba no altere mi calibración guardada ni mis ajustes en la nube ni alerte a mis contactos de emergencia.

## Definiciones
- **Modo de prueba:** estado temporal ligado a la sesión en memoria; no se guarda en base de datos ni sobrevive al cierre de sesión, cierre de la app o fin del viaje.
- **Detección facial interactiva en prueba:** flujo de frames de la cámara frontal analizados en tiempo real por el detector facial, evaluando apertura ocular (EAR) y orientación cefálica (Euler Y) respecto a un baseline neutro predeterminado (EAR 0.75, 0°).
- **Disparo de alarma interactiva:** emisión recurrente de sonido del sistema + vibración háptica + destello visual mientras persista la condición anómala.
- **Cabina de monitoreo:** pantalla que muestra el mapa, el indicador MODO PRUEBA, el valor instantáneo de EAR y el estado de alerta del conductor.

## Requisitos funcionales
- RF-1: EL SISTEMA DEBE ofrecer el modo de prueba únicamente mediante un interruptor etiquetado "Modo de prueba" en la sección "Tolerancia & Telemetría" de Ajustes, sin acceso desde otra pantalla ni gesto oculto.
- RF-2: CUANDO el usuario active el interruptor, EL SISTEMA DEBE marcar el modo activo en ≤1 s y conservarlo en memoria; su estado no forma parte de los ajustes guardados ni se envía al pulsar "Guardar Ajustes", y solo se borra al desactivarlo, cerrar la sesión de usuario, cerrar la app o finalizar el viaje.
- RF-3: MIENTRAS el modo esté activo, EL SISTEMA DEBE mostrar en el dashboard un chip "MODO PRUEBA" y un subtítulo de demo en la tarjeta "Iniciar Monitoreo", sin mostrar el texto de "Calibración Fantasma & Cámara Frontal".
- RF-4: CUANDO el usuario pulse "Iniciar Monitoreo" con el modo activo, EL SISTEMA DEBE verificar permiso de cámara, inicializar la cámara frontal y entrar a la cabina en ≤2 s sin mostrar la pantalla de Calibración Fantasma (0 frames de calibración requeridos).
- RF-5: SI el modo está desactivado, ENTONCES EL SISTEMA DEBE mantener intacto el flujo dashboard → Calibración Fantasma → cabina, sin regresiones.
- RF-6: MIENTRAS el modo esté activo, EL SISTEMA DEBE utilizar un baseline predeterminado (EAR 0.75 y ángulo 0°) en el evaluador de fatiga, reflejar en el chip "EAR" de la cabina el valor instantáneo detectado por la cámara (0.00 a 1.00) e ignorar y nunca sobrescribir el baseline real guardado en base de datos.
- RF-7: MIENTRAS el modo esté activo en la cabina, EL SISTEMA DEBE procesar los frames de la cámara frontal con ML Kit Face Detection e ignorar el silenciador de velocidad mínima (<10 km/h), permitiendo evaluar fatiga y distracción a velocidad 0 km/h (vehículo quieto o en mano).
- RF-8: CUANDO en modo prueba se detecten ojos cerrados (caída de EAR ≥35% respecto al baseline), ángulo cefálico desviado (Euler Y ≥20°) o ausencia de rostro detectado durante ≥1.0 segundo (±300 ms), EL SISTEMA DEBE activar el estado de alarma de atención (`alertWarning`), emitiendo sonido del sistema, vibración háptica y destello visual con el mensaje correspondiente ("¡ALERTA DE SOMNOLENCIA!", "¡ATENCIÓN AL FRENTE!" o "¡ROSTRO NO DETECTADO!").
- RF-9: CUANDO el usuario restablezca la atención (rostro centrado y ojos abiertos con EAR normal), EL SISTEMA DEBE detener el sonido y el destello y restaurar el estado normal en ≤500 ms.
- RF-10: CUANDO el usuario finalice el viaje, salga de la cabina o la app pase a segundo plano, EL SISTEMA DEBE detener el stream de cámara, liberar el hardware en `dispose()`, detener sonidos y destellos en ≤300 ms y desactivar el modo de prueba.
- RF-11: MIENTRAS el modo esté activo, EL SISTEMA DEBE mostrar un indicador "MODO PRUEBA" permanente y legible en la cabina.
- RF-12: MIENTRAS el modo esté activo, EL SISTEMA NO DEBE escribir en los ajustes del usuario ni notificar a contactos de emergencia.

## Requisitos no funcionales
- RNF-1: Respuesta de alarma en ≤1.5 s desde que se cierran los ojos o se aparta la cara.
- RNF-2: Prohibido añadir paquetes externos nuevos: usar únicamente los paquetes aprobados (`camera`, `google_mlkit_face_detection`, `SystemSound`, `HapticFeedback`).
- RNF-3: La evaluación de condiciones anómalas (ojos cerrados, ángulo desviado, rostro ausente) y tiempos debe ser una unidad desacoplada y determinista, testeable con `flutter_test`.
- RNF-4: `flutter analyze` debe dar 0 errores y 0 warnings, y `flutter test` debe pasar en verde en su totalidad.
- RNF-5: La cámara y los streams deben liberarse rigurosamente en `dispose()` para evitar fugas de memoria o bloqueos de hardware (`AGENTS.md`).

## Casos límite
- Teléfono en la mano o detenido (0 km/h): el sistema evalúa y dispara alertas sin silenciarse por baja velocidad.
- Pérdida de rostro (tapar cámara o quitarse del encuadre): cuenta como distracción y dispara alarma tras 1 s.
- Regreso inmediato de atención: cancela la alarma y regresa a estado normal.
- Salida de la cabina o cambio a segundo plano: cámara, streams y alarmas se detienen de inmediato.
- Cámara no disponible o permiso denegado: muestra aviso amigable sin crashear la cabina.

## Fuera de alcance
- Calibración Fantasma de 50 frames en modo prueba.
- Llamadas telefónicas o SMS automáticos a contactos de emergencia en modo prueba.
- Grabación o almacenamiento local o remoto de fotogramas o video.

## Criterios de finalización
- Entrar a cabina en modo prueba activa la cámara frontal y muestra el EAR en tiempo real en ≤2 s.
- Ojos cerrados por ~1 s dispara alarma sonora, vibración y destello con mensaje de somnolencia.
- Mirada apartada o rostro no detectado por ~1 s dispara alarma con mensaje de distracción/rostro no detectado.
- Volver a mirar al frente con ojos abiertos cancela la alarma y restaura estado normal en ≤500 ms.
- Salir de la cabina apaga todo y desactiva el modo de prueba.
- 0 errores en `flutter analyze` y suite completa de `flutter test` en verde.
