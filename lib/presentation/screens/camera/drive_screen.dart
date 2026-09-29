import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:safedrive/core/theme/theme_service.dart';
import 'package:safedrive/core/constants/app_constants.dart';
import 'package:safedrive/core/constants/map_config.dart';
import 'package:safedrive/core/services/location_service.dart';
import 'package:safedrive/data/models/emergency_contact_model.dart';
import 'package:safedrive/data/repositories/emergency_contact_repository.dart';
import 'package:safedrive/data/repositories/settings_repository.dart';
import 'package:safedrive/domain/monitoring/fatigue_evaluator.dart';
import 'package:safedrive/presentation/components/cards/app_card.dart';
import 'package:safedrive/presentation/components/buttons/danger_button.dart';
import 'package:safedrive/presentation/components/dialogs/confirmation_dialog.dart';
import 'package:safedrive/presentation/components/maps/free_drive_map_widget.dart';

class DriveScreen extends StatefulWidget {
  final double baselineEar;
  final double baselineHeadAngle;

  const DriveScreen({
    super.key,
    this.baselineEar = 0.75,
    this.baselineHeadAngle = 0.0,
  });

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> with SingleTickerProviderStateMixin {
  final _settingsRepo = SettingsRepository();
  final _contactsRepo = EmergencyContactRepository();
  final _locationService = LocationService.instance;

  late FatigueEvaluator _evaluator;
  EmergencyContactModel? _primaryContact;

  LatLng _currentLocation = MapConfig.defaultLocation;
  double _currentSpeedKmh = 0.0;
  double _currentHeading = 0.0;
  final double _currentEar = 0.75;
  final double _currentHeadAngle = 0.0;
  FatigueEvaluationResult? _latestResult;

  late AnimationController _pulseCtrl;
  StreamSubscription<LocationTelemetry>? _telemetrySub;

  @override
  void initState() {
    super.initState();

    _evaluator = FatigueEvaluator(
      baselineEar: widget.baselineEar,
      baselineHeadAngle: widget.baselineHeadAngle,
      alarmToleranceSeconds: AppConstants.defaultAlarmToleranceSeconds,
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _loadData();
    _startLocationAndMonitoring();
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
            baselineHeadAngle: settings.baselineHeadAngle ?? widget.baselineHeadAngle,
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
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
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
    final result = _latestResult ??
        _evaluator.evaluate(
          currentEar: _currentEar,
          currentHeadAngleY: _currentHeadAngle,
          currentSpeedKmh: _currentSpeedKmh,
        );
    final statusColor = _getStatusColor(result.state);
    final isAlarmActive = result.state == MonitoringState.alertWarning ||
        result.state == MonitoringState.emergencyEscalated;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Barra Superior del Cockpit
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
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
                        const Text(
                          'FREE-DRIVE COCKPIT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
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
                            'EAR: ${(widget.baselineEar * 100).toInt()}%',
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
                        color: isAlarmActive ? statusColor : const Color(0xFF1E293B),
                        width: isAlarmActive ? 2.0 : 1.2,
                      ),
                    ),
                    child: FreeDriveMapWidget(
                      currentPosition: _currentLocation,
                      currentSpeedKmh: _currentSpeedKmh,
                      currentHeading: _currentHeading,
                    ),
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
                      color: isAlarmActive ? statusColor : const Color(0xFF1E293B),
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
                                border: Border.all(color: statusColor, width: 2),
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
                                    result.statusMessage,
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
                              border: Border.all(color: const Color(0xFF1E293B)),
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
    );
  }
}
