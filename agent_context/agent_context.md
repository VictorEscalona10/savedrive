# Contexto del Proyecto: SafeDrive

## 📝 Descripción General
SafeDrive es una aplicación móvil diseñada para mejorar la seguridad vial previniendo accidentes por somnolencia o microsueños. Utiliza visión artificial (Computer Vision) en tiempo real procesada directamente en el dispositivo (On-Device ML) para analizar el rostro del conductor y disparar alarmas preventivas.

## 🛠️ Stack Tecnológico
* **Frontend:** Flutter (Dart).
* **Backend / BaaS:** Supabase (PostgreSQL, Autenticación, Storage).
* **Machine Learning:** Google ML Kit (Face Detection).
* **Cámara:** Paquete `camera` de Flutter.

## 🗄️ Esquema de la Base de Datos (PostgreSQL / Supabase)
El proyecto utiliza Row Level Security (RLS) habilitado en todas las tablas. El `id` de autenticación de Supabase se sincroniza automáticamente mediante un Trigger con la tabla pública `users`.

### 1. Tabla `users` (Perfil principal)
Guarda los datos personales.
* `id` (UUID, Primary Key, Foreign Key de auth.users)
* `email` (VARCHAR, Unique)
* `full_name` (VARCHAR)
* `blood_type` (VARCHAR)
* `medical_notes` (TEXT)
* `created_at` (TIMESTAMP)

### 2. Tabla `user_settings` (Configuraciones de la app)
Relación 1-a-1 con `users`.
* `user_id` (UUID, Primary Key, REFERENCES users)
* `selected_alarm_type_id` (INTEGER, REFERENCES alarm_types)
* `sensitivity_level` (INTEGER, Default 5)
* `auto_trigger_enabled` (BOOLEAN, Default true)
* `baseline_eye_open` (NUMERIC(4,3)) -> *Guarda la calibración del ojo del usuario.*

### 3. Tabla `alarm_types` (Catálogo de audios)
* `id` (SERIAL, Primary Key)
* `name` (VARCHAR)
* `file_path` (VARCHAR)
* `description` (TEXT)

### 4. Tabla `emergency_contacts` (Contactos del usuario)
Relación 1-a-Muchos con `users`.
* `id` (UUID, Primary Key)
* `user_id` (UUID, REFERENCES users)
* `contact_name` (VARCHAR)
* `phone_number` (VARCHAR)
* `relationship` (VARCHAR)
* `is_primary` (BOOLEAN)

## 🚗 Flujos Principales de la Aplicación

1.  **Autenticación:**
    * Soporta Login tradicional (Email/Password) y Login con Google OAuth.
    * Las sesiones se escuchan mediante `Supabase.instance.client.auth.onAuthStateChange`.
2.  **Calibración Facial (`CalibrationScreen`):**
    * Antes de iniciar el viaje, la app lee la cámara frontal por 5 segundos.
    * Calcula el EAR (Eye Aspect Ratio / Probabilidad de ojo abierto) usando `google_mlkit_face_detection`.
    * Guarda el promedio personal en `user_settings.baseline_eye_open` para evitar falsos positivos en personas con ojos rasgados.
3.  **Monitoreo Activo (`DriveScreen`):**
    * **Plan A (Ojos):** Si la apertura actual cae por debajo del 50% del *baseline* del usuario, suena la alarma.
    * **Plan B (Cabeceo/Lentes de sol):** Si no se detectan ojos, el sistema lee el ángulo de la cabeza (`headEulerAngleX`). Si cae bruscamente a negativo (microsueño), suena la alarma.

## 🤖 Instrucciones para la IA (System Prompt)
* Todo el código Flutter generado debe usar **Null Safety**.
* El manejo del estado actual se hace mediante `StatefulWidgets` y `setState` (a menos que se especifique un gestor de estado global).
* Las consultas a Supabase deben asumir que el usuario ya está autenticado y las políticas RLS se encargarán del filtrado.
* Evita procesar imágenes asíncronamente sin manejar el desbordamiento de memoria (usa `_isProcessingFrame` como flag limitador).