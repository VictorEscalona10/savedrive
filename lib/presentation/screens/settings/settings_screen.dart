import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safedrive/core/theme/theme_service.dart';
import 'package:safedrive/core/services/snackbar_service.dart';
import 'package:safedrive/core/utils/input_sanitizer.dart';
import 'package:safedrive/data/models/alarm_type_model.dart';
import 'package:safedrive/data/models/emergency_contact_model.dart';
import 'package:safedrive/data/models/user_settings_model.dart';
import 'package:safedrive/data/repositories/alarm_type_repository.dart';
import 'package:safedrive/data/repositories/emergency_contact_repository.dart';
import 'package:safedrive/data/repositories/settings_repository.dart';
import 'package:safedrive/data/repositories/auth_repository.dart';
import 'package:safedrive/presentation/components/buttons/primary_button.dart';
import 'package:safedrive/presentation/components/cards/app_section.dart';
import 'package:safedrive/presentation/components/inputs/app_text_field.dart';
import 'package:safedrive/presentation/components/inputs/app_dropdown.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsRepo = SettingsRepository();
  final _contactsRepo = EmergencyContactRepository();
  final _alarmsRepo = AlarmTypeRepository();
  final _authRepo = AuthRepository();

  bool _isLoading = true;
  bool _isSaving = false;

  UserSettingsModel? _settings;
  List<AlarmTypeModel> _alarmTypes = [];
  EmergencyContactModel? _primaryContact;

  // Form controls
  int _alarmToleranceSeconds = 3;
  bool _autoTriggerEnabled = true;
  int? _selectedAlarmTypeId;

  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  String _relationship = 'Familiar';

  final List<String> _relationships = const [
    'Familiar',
    'Cónyuge',
    'Padre / Madre',
    'Hijo / Hija',
    'Amigo / Amiga',
    'Compañero de Trabajo',
    'Médico Personal',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsRepo.getUserSettings();
      final alarms = await _alarmsRepo.getAlarmTypes();
      final primary = await _contactsRepo.getPrimaryContact();

      if (mounted) {
        setState(() {
          _settings = settings;
          _alarmTypes = alarms;
          _primaryContact = primary;

          if (settings != null) {
            _alarmToleranceSeconds = settings.alarmToleranceSeconds;
            _autoTriggerEnabled = settings.autoTriggerEnabled;
            _selectedAlarmTypeId = settings.selectedAlarmTypeId ??
                (alarms.isNotEmpty ? alarms.first.id : null);
          }

          if (primary != null) {
            _contactNameCtrl.text = primary.contactName;
            _contactPhoneCtrl.text = primary.phoneNumber;
            _relationship = _relationships.contains(primary.relationship)
                ? primary.relationship!
                : 'Familiar';
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar ajustes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final user = _authRepo.currentUser;
    if (user == null) {
      SnackBarService.showError(context, 'No hay una sesión activa.');
      return;
    }

    final sContactName = InputSanitizer.sanitizeName(_contactNameCtrl.text);
    final sContactPhone = InputSanitizer.sanitizePhone(_contactPhoneCtrl.text);
    _contactNameCtrl.text = sContactName;
    _contactPhoneCtrl.text = sContactPhone;

    if (sContactPhone.isNotEmpty && !InputSanitizer.isValidPhoneDigits(sContactPhone)) {
      SnackBarService.showError(context, 'Ingresa un número telefónico válido (7 a 15 dígitos).');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Guardar user_settings
      final updatedSettings = (_settings ?? UserSettingsModel(userId: user.id)).copyWith(
        alarmToleranceSeconds: _alarmToleranceSeconds,
        autoTriggerEnabled: _autoTriggerEnabled,
        selectedAlarmTypeId: _selectedAlarmTypeId,
      );
      await _settingsRepo.saveUserSettings(updatedSettings);

      // 2. Guardar o actualizar contacto de emergencia
      if (sContactName.isNotEmpty && sContactPhone.isNotEmpty) {
        final contactModel = EmergencyContactModel(
          id: _primaryContact?.id,
          userId: user.id,
          contactName: sContactName,
          phoneNumber: sContactPhone,
          relationship: _relationship,
          isPrimary: true,
        );
        final savedContact = await _contactsRepo.saveContact(contactModel);
        _primaryContact = savedContact;
      }

      if (mounted) {
        SnackBarService.showSuccess(context, '¡Ajustes guardados correctamente!');
      }
    } catch (e) {
      debugPrint('Error al guardar ajustes: $e');
      if (mounted) {
        SnackBarService.showError(context, 'Error al guardar ajustes: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 96.0;

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(isDark),
          body: SafeArea(
            bottom: false,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brand,
                      strokeWidth: 2.5,
                    ),
                  )
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ajustes de Seguridad',
                                style: TextStyle(
                                  color: AppColors.t1(isDark),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Configuración minimalista y protocolo de auxilio',
                                style: TextStyle(
                                  color: AppColors.t2(isDark),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 1. Tolerancia y Telemetría
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildTelemetrySection(isDark),
                        ),
                      ),
                      // 2. Tipo de Alarma
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildAlarmCatalogSection(isDark),
                        ),
                      ),
                      // 3. Contacto de Emergencia
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildEmergencyContactSection(isDark),
                        ),
                      ),
                      // Botón Guardar
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: PrimaryButton(
                            label: 'Guardar Ajustes',
                            icon: Icons.save_rounded,
                            isLoading: _isSaving,
                            loadingText: 'Guardando...',
                            onPressed: _saveSettings,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTelemetrySection(bool isDark) {
    return AppSection(
      icon: Icons.tune_rounded,
      iconColor: AppColors.blue,
      title: 'Tolerancia & Telemetría',
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tiempo de Gracia (Buffer)',
                    style: TextStyle(
                      color: AppColors.t1(isDark),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ventana para espejos y cruces sin falsas alarmas',
                    style: TextStyle(
                      color: AppColors.t2(isDark),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_alarmToleranceSeconds}s',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.blue,
              inactiveTrackColor: AppColors.border(isDark),
              thumbColor: AppColors.blue,
              overlayColor: AppColors.blue.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _alarmToleranceSeconds.toDouble(),
              min: 1,
              max: 6,
              divisions: 5,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _alarmToleranceSeconds = val.round());
              },
            ),
          ),
          Divider(color: AppColors.border(isDark), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-Inicio por Velocidad',
                      style: TextStyle(
                        color: AppColors.t1(isDark),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Activa la cámara y Calibración Fantasma al superar 20 km/h',
                      style: TextStyle(
                        color: AppColors.t2(isDark),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _autoTriggerEnabled,
                activeTrackColor: AppColors.brand,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _autoTriggerEnabled = val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmCatalogSection(bool isDark) {
    return AppSection(
      icon: Icons.notifications_active_rounded,
      iconColor: AppColors.orange,
      title: 'Tono de Alarma Acústica',
      padding: const EdgeInsets.all(18),
      child: AppDropdown<int>(
        value: _selectedAlarmTypeId,
        label: 'Tipo de Alarma Seleccionada',
        items: _alarmTypes.map((alarm) {
          return DropdownMenuItem<int>(
            value: alarm.id,
            child: Text(
              alarm.name,
              style: TextStyle(
                color: AppColors.t1(isDark),
                fontSize: 15,
              ),
            ),
          );
        }).toList(),
        onChanged: (val) {
          setState(() => _selectedAlarmTypeId = val);
        },
      ),
    );
  }

  Widget _buildEmergencyContactSection(bool isDark) {
    return AppSection(
      icon: Icons.contact_phone_rounded,
      iconColor: AppColors.brand,
      title: 'Contacto de Emergencia Primario',
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          AppTextField(
            controller: _contactNameCtrl,
            label: 'Nombre Completo',
            hint: 'Ej. María Rodríguez',
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _contactPhoneCtrl,
            label: 'Teléfono (para SMS con GPS)',
            hint: '+1 234 567 8900',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_forwarded_rounded,
          ),
          const SizedBox(height: 14),
          AppDropdown<String>(
            value: _relationship,
            label: 'Parentesco / Relación',
            items: _relationships
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _relationship = val);
              }
            },
          ),
        ],
      ),
    );
  }
}
