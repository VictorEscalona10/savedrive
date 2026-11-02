import 'package:safedrive/core/constants/app_constants.dart';

enum MonitoringState {
  normal,
  gracePeriod, // En ventana de tolerancia (espejos, cruces breves)
  alertWarning, // Alerta local (sonido/visual)
  emergencyEscalated, // Protocolo crítico
}

class FatigueEvaluationResult {
  final MonitoringState state;
  final double earDropPercent;
  final double headAngleDeviation;
  final bool isDrowsy;
  final bool isDistracted;
  final bool isFaceLost;
  final bool isSilencedByTraffic;
  final String statusMessage;

  const FatigueEvaluationResult({
    required this.state,
    required this.earDropPercent,
    required this.headAngleDeviation,
    required this.isDrowsy,
    required this.isDistracted,
    this.isFaceLost = false,
    required this.isSilencedByTraffic,
    required this.statusMessage,
  });
}

class FatigueEvaluator {
  final double baselineEar;
  double baselineHeadAngle;
  final int alarmToleranceSeconds;
  final bool ignoreSpeedLimit;
  final double distractionAngleThresholdDeg;

  DateTime? _distractionStartTime;

  FatigueEvaluator({
    required this.baselineEar,
    required this.baselineHeadAngle,
    this.alarmToleranceSeconds = AppConstants.defaultAlarmToleranceSeconds,
    this.ignoreSpeedLimit = false,
    this.distractionAngleThresholdDeg =
        AppConstants.distractionHeadAngleRelativeDeg,
  });

  FatigueEvaluationResult evaluate({
    required double currentEar,
    required double currentHeadAngleY,
    required double currentSpeedKmh,
    bool isFaceDetected = true,
    DateTime? currentTime,
  }) {
    // 1. Silenciador de Semáforo / Tráfico denso (<10 km/h) (ignorable en modo prueba)
    final isSilencedByTraffic = !ignoreSpeedLimit &&
        currentSpeedKmh < AppConstants.trafficLightSilenceSpeedKmh;

    // 2. Caída relativa de apertura ocular respecto al Cero Relativo (Anti-Bias)
    final earDropPercent = isFaceDetected && baselineEar > 0
        ? ((baselineEar - currentEar) / baselineEar).clamp(0.0, 1.0)
        : 0.0;
    final isDrowsy = isFaceDetected &&
        earDropPercent >= AppConstants.fatigueDropThresholdPercent;

    // 3. Desviación relativa de ángulo de cabeza respecto al cero del viaje
    final headAngleDeviation = isFaceDetected
        ? (currentHeadAngleY - baselineHeadAngle).abs()
        : 0.0;
    final isAngleDistracted = isFaceDetected &&
        headAngleDeviation >= distractionAngleThresholdDeg;

    final isFaceLost = !isFaceDetected;
    final isDistracted = isAngleDistracted || isFaceLost;
    final isAttentionLost = isDrowsy || isDistracted;

    if (isSilencedByTraffic) {
      _distractionStartTime = null;
      return FatigueEvaluationResult(
        state: MonitoringState.normal,
        earDropPercent: earDropPercent,
        headAngleDeviation: headAngleDeviation,
        isDrowsy: isDrowsy,
        isDistracted: isDistracted,
        isFaceLost: isFaceLost,
        isSilencedByTraffic: true,
        statusMessage: 'Tráfico lento: Alertas atenuadas',
      );
    }

    if (!isAttentionLost) {
      // Atención recuperada -> Reseteo silencioso de la ventana de buffer
      _distractionStartTime = null;
      return FatigueEvaluationResult(
        state: MonitoringState.normal,
        earDropPercent: earDropPercent,
        headAngleDeviation: headAngleDeviation,
        isDrowsy: false,
        isDistracted: false,
        isFaceLost: false,
        isSilencedByTraffic: false,
        statusMessage: 'Atención al camino',
      );
    }

    // Si perdió la atención, gestionar el protocolo de escalación
    final now = currentTime ?? DateTime.now();
    _distractionStartTime ??= now;
    final elapsedSec =
        now.difference(_distractionStartTime!).inMilliseconds / 1000.0;

    String getAlertMessage() {
      if (isFaceLost) return '¡ROSTRO NO DETECTADO!';
      if (isDrowsy) return '¡ALERTA DE SOMNOLENCIA!';
      return '¡ATENCIÓN AL FRENTE!';
    }

    if (elapsedSec < alarmToleranceSeconds) {
      // 1. Buffer Window (Ventana de gracia)
      return FatigueEvaluationResult(
        state: MonitoringState.gracePeriod,
        earDropPercent: earDropPercent,
        headAngleDeviation: headAngleDeviation,
        isDrowsy: isDrowsy,
        isDistracted: isDistracted,
        isFaceLost: isFaceLost,
        isSilencedByTraffic: false,
        statusMessage: 'Verificación de entorno...',
      );
    } else if (elapsedSec < (alarmToleranceSeconds + 10)) {
      // 2. Alarma Local Activa
      return FatigueEvaluationResult(
        state: MonitoringState.alertWarning,
        earDropPercent: earDropPercent,
        headAngleDeviation: headAngleDeviation,
        isDrowsy: isDrowsy,
        isDistracted: isDistracted,
        isFaceLost: isFaceLost,
        isSilencedByTraffic: false,
        statusMessage: getAlertMessage(),
      );
    } else {
      // 3. Protocolo de Emergencia
      return FatigueEvaluationResult(
        state: MonitoringState.emergencyEscalated,
        earDropPercent: earDropPercent,
        headAngleDeviation: headAngleDeviation,
        isDrowsy: isDrowsy,
        isDistracted: isDistracted,
        isFaceLost: isFaceLost,
        isSilencedByTraffic: false,
        statusMessage: getAlertMessage(),
      );
    }
  }
}
