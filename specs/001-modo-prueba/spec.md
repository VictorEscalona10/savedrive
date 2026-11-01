# Spec 001 — Modo de Prueba (Demo)

Estado: aprobada

## Contexto y objetivo
Iniciar el monitoreo exige completar la Calibración Fantasma (50 frames válidos y aviso a los 30 s), lo que impide mostrar el ciclo de alerta en una demo breve; además, la cabina trabaja con señal facial neutra fija y la alarma no se dispara sola. Objetivo: un modo de prueba activable solo desde Ajustes que lleve directo a la cabina y emita una secuencia de alerta sonora y visual inmediata, sin alterar la calibración ni los datos reales del conductor.

## Usuarios
- Conductor con sesión de usuario iniciada que realiza demos o pruebas del producto.

## Historias de usuario
- HU-1. Como demostrador, quiero activar el modo de prueba para llegar a la cabina sin calibrar y con un aviso claro de que es una demo.
- HU-2. Como demostrador, quiero ver y oír la alerta de SafeDrive de inmediato para mostrar el ciclo completo y repetirlo cuando lo necesite.
- HU-3. Como conductor real, quiero que el modo de prueba no altere mi calibración ni mis ajustes guardados.

## Definiciones
- **Modo de prueba:** estado temporal ligado a la sesión, entendida como la ejecución actual de la app; no se guarda y no sobrevive al cierre de la app ni al cierre de sesión de usuario.
- **Secuencia de prueba:** seis disparos programados al entrar en la cabina, gobernados por lógica propia e independiente del evaluador de fatiga.
- **Disparo:** un sonido de sistema (duración del tono la del sistema) + un destello + una vibración háptica.
- **Cabina de monitoreo:** pantalla que muestra el mapa y el estado de fatiga durante la conducción.

## Requisitos funcionales
- RF-1: EL SISTEMA DEBE ofrecer el modo de prueba únicamente mediante un interruptor etiquetado "Modo de prueba" en la sección "Tolerancia & Telemetría" de Ajustes, sin acceso desde otra pantalla ni gesto oculto.
- RF-2: CUANDO el usuario active el interruptor, EL SISTEMA DEBE marcar el modo activo en ≤1 s y conservarlo al cambiar de pestaña o recargar Ajustes; su estado no forma parte de los ajustes guardados ni se envía al pulsar "Guardar Ajustes", y solo se borra al desactivarlo, cerrar la sesión de usuario, cerrar la app o finalizar el viaje.
- RF-3: MIENTRAS el modo esté activo, EL SISTEMA DEBE mostrar en el dashboard un chip "MODO PRUEBA" y un subtítulo de demo en la tarjeta "Iniciar Monitoreo", sin mostrar "Calibración Fantasma & Cámara Frontal".
- RF-4: CUANDO el usuario pulse "Iniciar Monitoreo" con el modo activo, EL SISTEMA DEBE abrir la cabina en ≤2 s sin mostrar la pantalla de Calibración Fantasma, sin pedir permiso de cámara y sin inicializar ni previsualizar ninguna cámara, por lo que no existen los 50 frames ni el timeout de 30 s.
- RF-5: SI el modo está desactivado, ENTONCES EL SISTEMA DEBE mantener intacto el flujo dashboard → Calibración Fantasma → cabina, sin regresiones.
- RF-6: MIENTRAS el modo esté activo, EL SISTEMA DEBE usar siempre apertura ocular 0.75 y ángulo 0° en la cabina, mostrar 0.75 en el chip "EAR" e ignorar cualquier baseline real, que solo se lee y nunca se sobrescribe.
- RF-7: CUANDO la cabina se abra con el modo activo, EL SISTEMA DEBE iniciar una secuencia propia e independiente del evaluador de fatiga: un disparo en t=0 s y repeticiones a los 2, 4, 6, 8 y 10 s (±300 ms), seis en total, sin ningún disparo después de t=10 s.
- RF-8: MIENTRAS dure la secuencia, EL SISTEMA DEBE mostrar en el panel un estado de alerta con mensaje de somnolencia o atención, nunca estado normal, e ignorar la ventana de gracia de 3 s y la atenuación por tráfico <10 km/h.
- RF-9: CUANDO el usuario finalice el viaje, salga de la cabina o la app pase a segundo plano, EL SISTEMA DEBE detener sonido y destello en ≤300 ms y cancelar la secuencia de forma definitiva, sin reanudarla al volver; el modo sigue activo, el indicador visible y la telemetría continúa sin volver a sonar.
- RF-10: CUANDO se produzca un disparo, EL SISTEMA DEBE mostrar siempre, de forma incondicional y simultánea, un destello de 400 ms (±100 ms) con contraste ≥4.5:1, sin depender de detectar si el audio suena.
- RF-11: MIENTRAS el modo esté activo, EL SISTEMA DEBE mostrar un indicador "MODO PRUEBA" permanente y legible en la cabina.
- RF-12: MIENTRAS el modo esté activo, EL SISTEMA NO DEBE escribir en los ajustes del usuario, ni calibración ni preferencias, ni notificar a contactos de emergencia; se verifica con un repositorio de ajustes simulado que no recibe llamadas de escritura durante los tests.

## Requisitos no funcionales
- RNF-1: El primer disparo debe ocurrir en ≤1 s desde la entrada a la cabina y en ≤3 s desde la pulsación de "Iniciar Monitoreo", medido con cronómetro en un dispositivo de gama media.
- RNF-2: Prohibido añadir paquetes; solo sonido de sistema, destello y hápticos nativos (constitución).
- RNF-3: La secuencia debe residir en una unidad de lógica pura y determinista que reciba el tiempo transcurrido en milisegundos y devuelva si toca sonido y si toca destello; los tests usan solo `flutter_test`, sin `fake_async` ni dependencias nuevas.
- RNF-4: `flutter analyze` debe dar 0 errores y 0 warnings, y `flutter test` debe quedar en verde, incluido el test plantilla obsoleto, conforme a la constitución §4.
- RNF-5: Textos en español, contraste ≥4.5:1, sin temporizadores ni audio activos tras salir de la cabina; la vibración se verifica en dispositivo físico y en emulador o web se acepta el destello como alerta.

## Casos límite
- Existe un baseline real guardado: se ignora en cabina y permanece intacto.
- Vuelta desde segundo plano: sin sonido ni destello; modo e indicador siguen activos.
- Toques repetidos en el interruptor: una sola secuencia activa, sin solapamientos.
- Sin preferencias guardadas, sin GPS o a 0 km/h: valores fijos y disparos por temporizador.
- Finalización antes de t=10 s: la secuencia termina y una nueva demo exige reactivar el modo en Ajustes.
- Audio no audible (emulador, web o silencio): el destello cubre la alerta y la cabina no se bloquea.

## Fuera de alcance
- Detección facial real dentro de la cabina.
- Botón manual de simulación, sirena continua y catálogo completo de tonos.
- Acceso al modo desde el dashboard o mediante gesto oculto.
- Cuentas o roles de demostración y avisos reales a contactos de emergencia.
- Persistencia del modo entre sesiones, dispositivos o usuarios.
- Calibrar o modificar el baseline durante el modo de prueba.

## Criterios de finalización
- Guion medido: cabina en ≤2 s y primer disparo en ≤3 s desde pulsar "Iniciar Monitoreo"; seis disparos hasta t=10 s; salida detiene todo en ≤300 ms.
- Suite completa en verde, incluido el test plantilla, y `flutter analyze` con 0 errores y 0 warnings.
- Repositorio de ajustes simulado sin llamadas de escritura durante la clase de tests del modo.
- Chip y subtítulo del dashboard, chip EAR a 0.75 e indicador de cabina verificados; flujo con el modo desactivado sin regresiones.
- Destello visible y vibración aceptada según RNF-5.

## Dudas abiertas
- Ninguna pendiente: las decisiones A–C y las 16 correcciones del reviewer están incorporadas.
