import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safedrive/core/constants/app_constants.dart';
import 'package:safedrive/data/models/user_settings_model.dart';

class SettingsRepository {
  final SupabaseClient _client;

  SettingsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<UserSettingsModel?> getUserSettings() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from(AppConstants.tableUserSettings)
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null) {
        return UserSettingsModel.fromMap(data);
      }

      // Si no existe fila, retornar configuración por defecto en memoria
      return UserSettingsModel(userId: user.id);
    } catch (e) {
      debugPrint('Error en getUserSettings: $e');
      return UserSettingsModel(userId: user.id);
    }
  }

  Future<void> saveUserSettings(UserSettingsModel settings) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final existing = await _client
          .from(AppConstants.tableUserSettings)
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final payload = {
        'user_id': user.id,
        'selected_alarm_type_id': settings.selectedAlarmTypeId,
        'auto_trigger_enabled': settings.autoTriggerEnabled,
        'alarm_tolerance_seconds': settings.alarmToleranceSeconds,
        'baseline_ear': settings.baselineEar,
        'baseline_head_angle': settings.baselineHeadAngle,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing != null) {
        await _client
            .from(AppConstants.tableUserSettings)
            .update(payload)
            .eq('user_id', user.id);
      } else {
        await _client
            .from(AppConstants.tableUserSettings)
            .insert(payload);
      }
    } catch (e) {
      debugPrint('Error al guardar configuración de usuario: $e');
      rethrow;
    }
  }

  Future<void> updateGhostCalibrationBaselines({
    required double baselineEar,
    required double baselineHeadAngle,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final existing = await _client
          .from(AppConstants.tableUserSettings)
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final payload = {
        'user_id': user.id,
        'baseline_ear': baselineEar,
        'baseline_head_angle': baselineHeadAngle,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing != null) {
        await _client
            .from(AppConstants.tableUserSettings)
            .update(payload)
            .eq('user_id', user.id);
      } else {
        await _client
            .from(AppConstants.tableUserSettings)
            .insert(payload);
      }
    } catch (e) {
      debugPrint('Error al actualizar baselines en Supabase: $e');
      rethrow;
    }
  }
}
