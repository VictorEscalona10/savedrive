import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safedrive/core/constants/app_constants.dart';
import 'package:safedrive/data/models/user_model.dart';

class UserRepository {
  final SupabaseClient _client;

  UserRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<UserModel?> getCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from(AppConstants.tableUsers)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        return UserModel.fromMap(data);
      }

      // Fallback a metadata de auth si aún no se ha sincronizado el trigger
      final meta = user.userMetadata;
      final fallbackName = (meta?['full_name'] as String?) ??
          (meta?['name'] as String?) ??
          user.email?.split('@').first ??
          'Conductor';

      return UserModel(
        id: user.id,
        email: user.email ?? '',
        fullName: fallbackName,
      );
    } catch (e) {
      debugPrint('Error en getCurrentUserProfile: $e');
      return UserModel(
        id: user.id,
        email: user.email ?? '',
        fullName: user.email?.split('@').first ?? 'Conductor',
      );
    }
  }

  Future<void> saveUserProfile(UserModel userModel) async {
    try {
      final existing = await _client
          .from(AppConstants.tableUsers)
          .select('id')
          .eq('id', userModel.id)
          .maybeSingle();

      if (existing != null) {
        await _client.from(AppConstants.tableUsers).update({
          'full_name': userModel.fullName,
          'blood_type': userModel.bloodType,
          'medical_notes': userModel.medicalNotes,
        }).eq('id', userModel.id);
      } else {
        await _client.from(AppConstants.tableUsers).insert(userModel.toMap());
      }
    } catch (e) {
      debugPrint('Error al guardar perfil de usuario: $e');
      rethrow;
    }
  }
}
