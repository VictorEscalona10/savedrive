import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:latlong2/latlong.dart';
import 'package:safedrive/core/constants/app_constants.dart';
import 'package:safedrive/core/constants/map_config.dart';
import 'package:safedrive/core/services/alert_feedback_service.dart';
import 'package:safedrive/core/services/location_service.dart';
import 'package:safedrive/core/services/test_mode_controller.dart';
import 'package:safedrive/core/theme/theme_service.dart';
import 'package:safedrive/core/utils/camera_image_converter.dart';
import 'package:safedrive/data/models/emergency_contact_model.dart';
import 'package:safedrive/data/repositories/emergency_contact_repository.dart';
import 'package:safedrive/data/repositories/settings_repository.dart';
import 'package:safedrive/domain/monitoring/fatigue_evaluator.dart';
import 'package:safedrive/presentation/components/buttons/danger_button.dart';
import 'package:safedrive/presentation/components/cards/app_card.dart';
import 'package:safedrive/presentation/components/dialogs/confirmation_dialog.dart';
import 'package:safedrive/presentation/components/maps/free_drive_map_widget.dart';
import 'package:safedrive/presentation/components/test_mode/test_mode_badge.dart';

class DriveScreen extends StatefulWidget {
  final double baselineEar;
  final double baselineHeadAngle;

  /// Cabina de demostración: usa baseline predeterminado (0.75 / 0°),
  /// tolerancia de 1 segundo, ignora silenciador de velocidad y evalúa
  /// visión interactiva en tiempo real (RF-4, RF-6, RF-7, RF-8, RF-11).
  final bool isTestMode;

  /// Permite desactivar GPS y cargas remotas en tests de widget.
  final bool enableTelemetry;

  /// Permite sustituir el mapa real por un marcador de posición en tests.
  final bool showMap;

  /// Cámara frontal para procesamiento en tiempo real en la cabina (RF-4, RF-7).
  final CameraDescription? frontCamera;

  const DriveScreen({
    super.key,
    this.baselineEar = 0.75,
    this.baselineHeadAngle = 0.0,
    this.isTestMode = false,
    this.enableTelemetry = true,
    this.showMap = true,
    this.frontCamera,
  });

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Key flashKey = Key('test-mode-flash');

  // Se instancian solo cuando hay telemetría y no es una demo: sus
  // constructores acceden a `Supabase.instance` (RF-12).
  late final SettingsRepository _settingsRepo;
  late final EmergencyContactRepository _contactsRepo;
  final _locationService = LocationService.instance;

  late FatigueEvaluator _evaluator;
  EmergencyContactModel? _primaryContact;

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isProcessingFrame = false;

  LatLng _currentLocation = MapConfig.defaultLocation;
  double _currentSpeedKmh = 0.0;
  double _currentHeading = 0.0;
  double _currentEar = 0.75;
  double _currentHeadAngle = 0.0;
  bool _hasCalibratedInitialAngle = false;
  bool _isFaceCurrentlyDetected = true;
  FatigueEvaluationResult? _latestResult;

  late AnimationController _pulseCtrl;
  StreamSubscription<LocationTelemetry>? _telemetrySub;

  bool _isFlashing = false;
  Timer? _alertLoopTimer;
  Timer? _flashDurationTimer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final bool testMode = widget.isTestMode;
    _evaluator = FatigueEvaluator(
      baselineEar: testMode ? 0.75 : widget.baselineEar,
      baselineHeadAngle: testMode ? 0.0 : widget.baselineHeadAngle,
      alarmToleranceSeconds:
          testMode ? 1 : AppConstants.defaultAlarmToleranceSeconds,
      ignoreSpeedLimit: testMode,
      distractionAngleThresholdDeg:
          testMode ? 30.0 : AppConstants.distractionHeadAngleRelativeDeg,
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

    if (widget.frontCamera != null) {
      _initializeCamera(widget.frontCamera!);
    }
  }

  Future<void> _initializeCamera(CameraDescription camera) async {
    try {
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _cameraController = controller;
      await controller.initialize();
      if (_disposed || !mounted) {
        await controller.dispose();
        return;
      }

      final options = FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
      );
      _faceDetector = FaceDetector(options: options);

      await controller.startImageStream((CameraImage image) {
        if (_isProcessingFrame || _disposed || !mounted) return;
        _isProcessingFrame = true;
        _processCameraFrame(image);
      });

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Aviso: no se pudo iniciar cámara en cabina: $e');
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    try {
      if (_cameraController == null ||
          _faceDetector == null ||
          _disposed ||
          !mounted) {
        return;
      }

      final inputImage = CameraImageConverter.convertCameraImageToInputImage(
        image: image,
        description: _cameraController!.description,
      );
      if (inputImage == null || _disposed || !mounted) return;

      final faces = await _faceDetector!.processImage(inputImage);
      if (_disposed || !mounted) return;

      if (faces.isNotEmpty) {
        final face = faces.first;
        final leftEye = face.leftEyeOpenProbability ?? 0.75;
        final rightEye = face.rightEyeOpenProbability ?? 0.75;
        final ear = (leftEye + rightEye) / 2.0;
        final headAngleY = face.headEulerAngleY ?? 0.0;
        _updateMonitoring(
          ear: ear,
          headAngleY: headAngleY,
          isFaceDetected: true,
        );
      } else {
        _updateMonitoring(
          ear: 0.0,
          headAngleY: 0.0,
          isFaceDetected: false,
        );
      }
    } catch (e) {
      debugPrint('Error procesando frame en cabina: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _updateMonitoring({
    required double ear,
    required double headAngleY,
    required bool isFaceDetected,
    DateTime? currentTime,
  }) {
    if (_disposed || !mounted) return;

    // Autocalibrar el ángulo de postura inicial al primer rostro detectado (en modo prueba)
    if (widget.isTestMode && !_hasCalibratedInitialAngle && isFaceDetected) {
      _evaluator.baselineHeadAngle = headAngleY;
      _hasCalibratedInitialAngle = true;
    }

    final result = _evaluator.evaluate(
      currentEar: ear,
      currentHeadAngleY: headAngleY,
      currentSpeedKmh: _currentSpeedKmh,
      isFaceDetected: isFaceDetected,
      currentTime: currentTime,
    );

    final bool isAlarm = result.state == MonitoringState.alertWarning ||
        result.state == MonitoringState.emergencyEscalated;

    setState(() {
      _currentEar = isFaceDetected ? ear : 0.0;
      _currentHeadAngle = headAngleY;
      _isFaceCurrentlyDetected = isFaceDetected;
      _latestResult = result;
    });

    if (isAlarm) {
      _startAlertLoop();
    } else {
      _stopAlertLoop();
    }
  }

  @visibleForTesting
  void simulateAttentionUpdateForTesting({
    required double ear,
    required double headAngleY,
    required bool isFaceDetected,
    DateTime? currentTime,
  }) {
    _updateMonitoring(
      ear: ear,
      headAngleY: headAngleY,
      isFaceDetected: isFaceDetected,
      currentTime: currentTime,
    );
  }

  void _startAlertLoop() {
    if (_alertLoopTimer != null) return;
    _fireAlertCue();
    _alertLoopTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _fireAlertCue();
    });
  }

  void _fireAlertCue() {
    if (_disposed || !mounted) return;
    AlertFeedbackService.playAlert();
    setState(() => _isFlashing = true);
    _flashDurationTimer?.cancel();
    _flashDurationTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && !_disposed) {
        setState(() => _isFlashing = false);
      }
    });
  }

  void _stopAlertLoop() {
    _alertLoopTimer?.cancel();
    _alertLoopTimer = null;
    _flashDurationTimer?.cancel();
    _flashDurationTimer = null;
    AlertFeedbackService.stopAlert();
    if (_isFlashing && mounted) {
      setState(() => _isFlashing = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stopAlertLoop();
        if (_cameraController?.value.isStreamingImages == true) {
          _cameraController?.stopImageStream().catchError((_) {});
        }
      case AppLifecycleState.resumed:
        break;
    }
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
            ignoreSpeedLimit: widget.isTestMode,
          );
        }
      });
    }
  }

  void _startLocationAndMonitoring() {
    _locationService.startTracking(
      onUpdate: (telemetry) {
        if (!mounted || _disposed) return;

        setState(() {
          _currentLocation = telemetry.position;
          _currentSpeedKmh = telemetry.speedKmh;
          _currentHeading = telemetry.heading;
        });

        // Si no hay cámara activa, evaluar con los valores actuales
        if (_cameraController == null) {
          _updateMonitoring(
            ear: _currentEar,
            headAngleY: _currentHeadAngle,
            isFaceDetected: true,
          );
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
      _stopAlertLoop();
      _locationService.stopTracking();
      if (widget.isTestMode) {
        TestModeController.instance.handleTripFinished();
      }
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stopAlertLoop();
    _telemetrySub?.cancel();
    _locationService.stopTracking();
    _pulseCtrl.dispose();

    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream().catchError((_) {});
      }
      controller.dispose().catchError((_) {});
    }
    _faceDetector?.close();
    _faceDetector = null;

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
          isFaceDetected: true,
        );

    final MonitoringState displayState = result.state;
    final statusColor = _getStatusColor(displayState);
    final isAlarmActive =
        displayState == MonitoringState.alertWarning ||
        displayState == MonitoringState.emergencyEscalated;
    final statusMessage = result.statusMessage;
    final double displayedEar = _currentEar;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
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
                                            alpha: 0.4 +
                                                (_pulseCtrl.value * 0.4),
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
                                _isFaceCurrentlyDetected
                                    ? 'EAR: ${(displayedEar * 100).toInt()}%'
                                    : 'SIN ROSTRO',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
            // Destello visual incondicional de alerta (RF-8, RF-10)
            if (_isFlashing)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    key: flashKey,
                    color: AppColors.red.withValues(alpha: 0.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
