import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safedrive/core/constants/app_constants.dart';
import 'package:safedrive/data/models/alarm_type_model.dart';

class AlarmTypeRepository {
  final SupabaseClient _client;

  AlarmTypeRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<AlarmTypeModel>> getAlarmTypes() async {
    try {
      final List<dynamic> data =
          await _client.from(AppConstants.tableAlarmTypes).select().order('id');

      return data
          .map((item) => AlarmTypeModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener catálogo de alarmas: $e');
      // Retorna catálogo por defecto si la tabla no está poblada aún
      return const [
        AlarmTypeModel(
          id: 1,
          name: 'Alarma Progresiva Sonora',
          description: 'Tono acústico intermitente con incremento gradual de volumen.',
        ),
        AlarmTypeModel(
          id: 2,
          name: 'Alarma Pulsante de Emergencia',
          description: 'Tono agudo de alta frecuencia para reacción inmediata.',
        ),
        AlarmTypeModel(
          id: 3,
          name: 'Aviso por Voz (TTS)',
          description: 'Instrucciones habladas de seguridad y concentración.',
        ),
      ];
    }
  }
}
