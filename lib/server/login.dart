import 'package:supabase_flutter/supabase_flutter.dart';

// Cambiamos la función a Future porque es un proceso asíncrono que toma tiempo
Future<String?> loginUsuario(String email, String password) async {
  try {
    // Intentamos iniciar sesión con Supabase
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // Login exitoso, retornamos null (sin error)
      return null;
    }
    return "Error desconocido al iniciar sesión";
  } on AuthException catch (e) {
    // Si la contraseña o correo están mal, Supabase nos dice aquí
    return e.message;
  } catch (e) {
    return "Ocurrió un error de conexión: $e";
  }
}
