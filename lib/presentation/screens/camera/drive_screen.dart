import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:safedrive/core/theme/theme_service.dart';
import 'package:safedrive/core/constants/app_constants.dart';
import 'package:safedrive/core/constants/map_config.dart';
import 'package:safedrive/core/services/location_service.dart';
import 'package:safedrive/core/services/test_mode_controller.dart';
import 'package:safedrive/data/models/emergency_contact_model.dart';
import 'package:safedrive/data/repositories/emergency_contact_repository.dart';
import 'package:safedrive/data/repositories/settings_repository.dart';
import 'package:safedrive/domain/monitoring/fatigue_evaluator.dart';
import 'package:safedrive/domain/test_mode/test_mode_sequence.dart';
import 'package:safedrive/presentation/components/cards/app_card.dart';
import 'package:safedrive/presentation/components/buttons/danger_button.dart';
import 'package:safedrive/presentation/components/dialogs/confirmation_dialog.dart';
import 'package:safedrive/presentation/components/maps/free_drive_map_widget.dart';
import 'package:safedrive/presentation/components/test_mode/test_mode_alert_driver.dart';
import 'package:safedrive/presentation/components/test_mode/test_mode_badge.dart';

class DriveScreen extends StatefulWidget {
  final double baselineEar;
  final double baselineHeadAngle;

  /// Cabina de demostración: usa valores fijos, ejecuta la secuencia de prueba
  /// y no lee ajustes ni contactos de Supabase (RF-4, RF-6, RF-8, RF-11).
  final bool isTestMode;

  /// Permite desactivar GPS y cargas remotas en tests de widget.
  final bool enableTelemetry;

  /// Permite sustituir el mapa real por un marcador de posición en tests.
  final bool showMap;

  const DriveScreen({
    super.key,
    this.baselineEar = 0.75,
    this.baselineHeadAngle = 0.0,
    this.isTestMode = false,
    this.enableTelemetry = true,
    this.showMap = true,
  });

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen>
    with SingleTickerProviderStateMixin {
  // Se instancian solo cuando hay telemetría y no es una demo: sus
  // constructores acceden a `Supabase.instance` (RF-12).
  late final SettingsRepository _settingsRepo;
  late final EmergencyContactRepository _contactsRepo;
  final _locationService = LocationService.instance;

  late FatigueEvaluator _evaluator;
  EmergencyContactModel? _primaryContact;

  LatLng _currentLocation = MapConfig.defaultLocation;
  double _currentSpeedKmh = 0.0;
  double _currentHeading = 0.0;
  final double _currentEar = TestModeSequence.fixedEar;
  final double _currentHeadAngle = TestModeSequence.fixedHeadAngleDeg;
  FatigueEvaluationResult? _latestResult;

  late AnimationController _pulseCtrl;
  StreamSubscription<LocationTelemetry>? _telemetrySub;

  /// Indica si la secuencia de alerta de la demo sigue en marcha (RF-8).
  bool _sequenceRunning = false;

  /// Evita `setState` cuando el driver avisa durante el desmontaje.
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    final bool testMode = widget.isTestMode;
    _evaluator = FatigueEvaluator(
      baselineEar: testMode ? TestModeSequence.fixedEar : widget.baselineEar,
      baselineHeadAngle: testMode
          ? TestModeSequence.fixedHeadAngleDeg
          : widget.baselineHeadAngle,
      alarmToleranceSeconds: AppConstants.defaultAlarmToleranceSeconds,
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // En modo prueba no se tocan ajustes ni contactos (RF-12); con la
    // telemetría desactivada (tests) tampoco se inicializan los repositorios.
    if (!testMode && widget.enableTelemetry) {
      _settingsRepo = SettingsRepository();
      _contactsRepo = EmergencyContactRepository();
      _loadData();
    }

    if (widget.enableTelemetry) {
      _startLocationAndMonitoring();
    }
  }

  /// Avisa del arranque y del final de la secuencia de prueba (RF-8).
  void _handleSequenceRunningChanged(bool running) {
    if (_disposed || !mounted || _sequenceRunning == running) {
      return;
    }
    setState(() => _sequenceRunning = running);
  }

  Future<void> _loadData() async {
    final settings = await _settingsRepo.getUserSettings();
    final primary = await _contactsRepo.getPrimaryContact();

    if (mounted) {
      setState(() {
        _primaryContact = primary;
        if (settings != null) {
          _evaluator = FatigueEvaluator(
            baselineEar: settings.baselineEar ?? widget.baselineEar,
            baselineHeadAngle:
                settings.baselineHeadAngle ?? widget.baselineHeadAngle,
            alarmToleranceSeconds: settings.alarmToleranceSeconds,
          );
        }
      });
    }
  }

  void _startLocationAndMonitoring() {
    _locationService.startTracking(
      onUpdate: (telemetry) {
        if (!mounted) return;

        final result = _evaluator.evaluate(
          currentEar: _currentEar,
          currentHeadAngleY: _currentHeadAngle,
          currentSpeedKmh: telemetry.speedKmh,
        );

        setState(() {
          _currentLocation = telemetry.position;
          _currentSpeedKmh = telemetry.speedKmh;
          _currentHeading = telemetry.heading;
          _latestResult = result;
        });

        if (result.state == MonitoringState.alertWarning) {
          HapticFeedback.heavyImpact();
        }
      },
    );
  }

  Future<void> _finalizarViaje() async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Finalizar Viaje',
      message: '¿Deseas concluir la sesión de monitoreo activo y navegación?',
      confirmLabel: 'Finalizar',
      confirmColor: AppColors.red,
    );

    if (ok == true && mounted) {
      _locationService.stopTracking();
      // Una segunda demo exige reactivar el modo en Ajustes (RF-9).
      if (widget.isTestMode) {
        TestModeController.instance.handleTripFinished();
      }
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _telemetrySub?.cancel();
    _locationService.stopTracking();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color _getStatusColor(MonitoringState state) {
    switch (state) {
      case MonitoringState.normal:
        return AppColors.brand;
      case MonitoringState.gracePeriod:
        return AppColors.cyan;
      case MonitoringState.alertWarning:
        return AppColors.orange;
      case MonitoringState.emergencyEscalated:
        return AppColors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result =
        _latestResult ??
        _evaluator.evaluate(
          currentEar: _currentEar,
          currentHeadAngleY: _currentHeadAngle,
          currentSpeedKmh: _currentSpeedKmh,
        );

    // Durante la secuencia de prueba el panel muestra siempre alerta (RF-8).
    final bool forcedTestAlert = widget.isTestMode && _sequenceRunning;
    final MonitoringState displayState = forcedTestAlert
        ? MonitoringState.alertWarning
        : result.state;
    final statusColor = _getStatusColor(displayState);
    final isAlarmActive =
        displayState == MonitoringState.alertWarning ||
        displayState == MonitoringState.emergencyEscalated;
    final statusMessage = forcedTestAlert
        ? '¡ALERTA DE SOMNOLENCIA! (MODO PRUEBA)'
        : result.statusMessage;
    final double displayedEar = widget.isTestMode
        ? TestModeSequence.fixedEar
        : widget.baselineEar;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: TestModeAlertDriver(
        active: widget.isTestMode,
        onRunningChanged: _handleSequenceRunningChanged,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Barra Superior del Cockpit
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (context, child) {
                                return Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: statusColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: statusColor.withValues(
                                          alpha: 0.4 + (_pulseCtrl.value * 0.4),
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            const Flexible(
                              child: Text(
                                'FREE-DRIVE COCKPIT',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isTestMode) ...[
                        const TestModeBadge(compact: true),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161E2E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.face_retouching_natural_rounded,
                              color: AppColors.brand,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'EAR: ${(displayedEar * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 2. Mapa Híbrido Free-Drive en Modo Oscuro
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isAlarmActive
                              ? statusColor
                              : const Color(0xFF1E293B),
                          width: isAlarmActive ? 2.0 : 1.2,
                        ),
                      ),
                      child: widget.showMap
                          ? FreeDriveMapWidget(
                              currentPosition: _currentLocation,
                              currentSpeedKmh: _currentSpeedKmh,
                              currentHeading: _currentHeading,
                            )
                          : const ColoredBox(color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 3. Panel Inferior de Estado de Fatiga y Escalación
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: AppCard(
                      padding: const EdgeInsets.all(18),
                      border: Border.all(
                        color: isAlarmActive
                            ? statusColor
                            : const Color(0xFF1E293B),
                        width: isAlarmActive ? 2.0 : 1.2,
                      ),
                      gradient: LinearGradient(
                        colors: [
                          isAlarmActive
                              ? statusColor.withValues(alpha: 0.18)
                              : const Color(0xFF111722),
                          const Color(0xFF090D14),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusColor.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: statusColor,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  isAlarmActive
                                      ? Icons.warning_rounded
                                      : Icons.shield_rounded,
                                  color: statusColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      statusMessage,
                                      style: TextStyle(
                                        color: isAlarmActive
                                            ? Colors.white
                                            : AppColors.t1(true),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      result.isSilencedByTraffic
                                          ? 'Tráfico < 10 km/h: Alertas atenuadas'
                                          : 'Monitoreo activo contra Cero Relativo',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_primaryContact != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161E2E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.emergency_rounded,
                                    color: AppColors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Contacto SOS: ${_primaryContact!.contactName} (${_primaryContact!.phoneNumber})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          DangerButton(
                            label: 'Finalizar Viaje',
                            icon: Icons.stop_circle_rounded,
                            height: 50,
                            onPressed: _finalizarViaje,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
