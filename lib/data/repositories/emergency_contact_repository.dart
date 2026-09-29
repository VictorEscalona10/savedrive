import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safedrive/core/constants/app_constants.dart';
import 'package:safedrive/data/models/emergency_contact_model.dart';

class EmergencyContactRepository {
  final SupabaseClient _client;

  EmergencyContactRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<EmergencyContactModel>> getContacts() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final List<dynamic> data = await _client
          .from(AppConstants.tableEmergencyContacts)
          .select()
          .eq('user_id', user.id)
          .order('is_primary', ascending: false);

      return data
          .map((item) => EmergencyContactModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener contactos de emergencia: $e');
      return [];
    }
  }

  Future<EmergencyContactModel?> getPrimaryContact() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from(AppConstants.tableEmergencyContacts)
          .select()
          .eq('user_id', user.id)
          .order('is_primary', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        return EmergencyContactModel.fromMap(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error al obtener contacto principal: $e');
      return null;
    }
  }

  Future<EmergencyContactModel> saveContact(EmergencyContactModel contact) async {
    try {
      if (contact.isPrimary) {
        // Desmarcar otros contactos como primarios si este se establece como principal
        await _client
            .from(AppConstants.tableEmergencyContacts)
            .update({'is_primary': false})
            .eq('user_id', contact.userId);
      }

      if (contact.id != null) {
        final res = await _client
            .from(AppConstants.tableEmergencyContacts)
            .update(contact.toMap())
            .eq('id', contact.id!)
            .select()
            .single();
        return EmergencyContactModel.fromMap(res);
      } else {
        final res = await _client
            .from(AppConstants.tableEmergencyContacts)
            .insert(contact.toMap())
            .select()
            .single();
        return EmergencyContactModel.fromMap(res);
      }
    } catch (e) {
      debugPrint('Error al guardar contacto de emergencia: $e');
      rethrow;
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await _client
          .from(AppConstants.tableEmergencyContacts)
          .delete()
          .eq('id', contactId);
    } catch (e) {
      debugPrint('Error al eliminar contacto de emergencia: $e');
      rethrow;
    }
  }
}
