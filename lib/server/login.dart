import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Login manual
Future<String?> loginUsuario(String email, String password) async {
  try {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      return null;
    }
    return "Error desconocido al iniciar sesión";
  } on AuthException catch (e) {
    return e.message;
  } catch (e) {
    return "Ocurrió un error de conexión: $e";
  }
}

// Login con google ANDROID

/* Future<String?> loginConGoogle() async {
  try {
    // ⚠️ REEMPLAZA ESTO: Pega aquí tu "ID de cliente de aplicación web"
    const webClientId = 'TU_WEB_CLIENT_ID_AQUI.apps.googleusercontent.com';

    // 1. Usamos la instancia global (Singleton)
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;

    // 2. Inicializamos el SDK con la llave de Supabase
    await googleSignIn.initialize(serverClientId: webClientId);

    await googleSignIn.signOut();

    // 3. NUEVO V7: El método ahora se llama .authenticate()
    // Esto abre la nueva interfaz nativa de Android Credential Manager
    final googleUser = await googleSignIn.authenticate();

    // 4. Obtenemos los tokens de seguridad generados por Google
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.idToken;

    if (idToken == null) {
      return "Hubo un problema al obtener las credenciales de Google";
    }

    // 5. Le pasamos los tokens a Supabase para validar la sesión en tu BD
    final response = await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    if (response.user != null) {
      return null; // Login exitoso
    }

    return "No se pudo registrar al usuario en la base de datos";
  } catch (e) {
    // NUEVO V7: Si el usuario cierra la ventanita, ahora cae aquí como un error
    if (e.toString().contains('canceled') ||
        e.toString().contains('cancelado')) {
      return "El inicio de sesión fue cancelado";
    }
    return "Error al conectar con Google: $e";
  }
} */

// LOGIN GOOGLE WEB

Future<String?> loginConGoogle() async {
  try {
    // Esto abrirá una pestaña del navegador dentro de tu app.
    await Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.google);
    return null;
  } catch (e) {
    return "Error al conectar con Google: $e";
  }
}
