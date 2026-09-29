import 'package:safedrive/data/repositories/auth_repository.dart';

final _authRepo = AuthRepository();

/// Helper legado para login manual
Future<String?> loginUsuario(String email, String password) {
  return _authRepo.signInWithEmailPassword(email, password);
}

/// Helper legado para login con Google
Future<String?> loginConGoogle() {
  return _authRepo.signInWithGoogle();
}
