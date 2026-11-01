import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safedrive/core/constants/app_constants.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<String?> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        return null;
      }
      return 'Error desconocido al iniciar sesión';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error de conexión: $e';
    }
  }

  Future<({String? error, bool requiresConfirmation, User? user})> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? bloodType,
  }) async {
    try {
      final metadata = <String, dynamic>{
        'full_name': fullName.trim(),
      };
      if (phone != null && phone.trim().isNotEmpty) {
        metadata['phone'] = phone.trim();
      }
      if (bloodType != null && bloodType.trim().isNotEmpty) {
        metadata['blood_type'] = bloodType.trim();
      }

      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: metadata,
      );

      final user = response.user;
      final session = response.session;

      if (user != null) {
        try {
          await _client.from(AppConstants.tableUsers).upsert({
            'id': user.id,
            'email': email.trim(),
            'full_name': fullName.trim(),
            if (bloodType != null && bloodType.trim().isNotEmpty)
              'blood_type': bloodType.trim(),
          });
        } catch (e) {
          debugPrint('Error sincronizando en tabla users: $e');
        }

        final requiresConfirmation = session == null;
        return (error: null, requiresConfirmation: requiresConfirmation, user: user);
      }

      return (error: 'No se pudo crear la cuenta', requiresConfirmation: false, user: null);
    } on AuthException catch (e) {
      return (error: e.message, requiresConfirmation: false, user: null);
    } catch (e) {
      return (error: 'Error de conexión: $e', requiresConfirmation: false, user: null);
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.safedrive://login-callback',
      );

      if (!launched) {
        return 'No se pudo abrir la ventana de autenticación de Google';
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('cancel') || str.contains('closed') || str.contains('aborted')) {
        return 'canceled';
      }
      return 'Error al conectar con Google: $e';
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }
  }
}
