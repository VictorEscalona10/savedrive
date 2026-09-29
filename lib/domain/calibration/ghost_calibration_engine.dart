import 'package:safedrive/core/constants/app_constants.dart';

class GhostCalibrationResult {
  final double baselineEar;
  final double baselineHeadAngle;
  final int validFramesCount;

  const GhostCalibrationResult({
    required this.baselineEar,
    required this.baselineHeadAngle,
    required this.validFramesCount,
  });
}

class GhostCalibrationEngine {
  final int targetFrames;
  final List<double> _validEarSamples = [];
  final List<double> _validHeadAngleSamples = [];

  GhostCalibrationEngine({
    this.targetFrames = AppConstants.ghostCalibrationFrameQuota,
  });

  int get currentFramesCount => _validEarSamples.length;
  double get progress => (_validEarSamples.length / targetFrames).clamp(0.0, 1.0);
  bool get isComplete => _validEarSamples.length >= targetFrames;

  /// Limpia muestras para una nueva sesión de calibración
  void reset() {
    _validEarSamples.clear();
    _validHeadAngleSamples.clear();
  }

  /// Procesa un frame de visión y filtra por postura (Phase 2)
  /// Solo acepta frames con headEulerAngleY entre -15° y +15°
  bool processFrame({
    required double? leftEyeOpenProb,
    required double? rightEyeOpenProb,
    required double? headEulerAngleY,
    required double? headEulerAngleX,
    required double? headEulerAngleZ,
  }) {
    if (isComplete) return false;
    if (leftEyeOpenProb == null || rightEyeOpenProb == null || headEulerAngleY == null) {
      return false;
    }

    // Filtro de Postura: Asegurar que el conductor mira razonablemente al frente
    final isAngleYValid = headEulerAngleY.abs() <= AppConstants.maxHeadAngleYDeg;
    final isAngleXValid = (headEulerAngleX ?? 0).abs() <= AppConstants.maxHeadAngleXDeg;
    final isAngleZValid = (headEulerAngleZ ?? 0).abs() <= AppConstants.maxHeadAngleZDeg;

    if (!isAngleYValid || !isAngleXValid || !isAngleZValid) {
      return false;
    }

    final currentEar = (leftEyeOpenProb + rightEyeOpenProb) / 2.0;
    _validEarSamples.add(currentEar);
    _validHeadAngleSamples.add(headEulerAngleY);

    return true;
  }

  /// Calcula el Cero Relativo (Phase 4 Baseline)
  GhostCalibrationResult? computeBaseline() {
    if (_validEarSamples.isEmpty) return null;

    final avgEar =
        _validEarSamples.reduce((a, b) => a + b) / _validEarSamples.length;
    final avgHeadAngle = _validHeadAngleSamples.reduce((a, b) => a + b) /
        _validHeadAngleSamples.length;

    return GhostCalibrationResult(
      baselineEar: avgEar,
      baselineHeadAngle: avgHeadAngle,
      validFramesCount: _validEarSamples.length,
    );
  }
}
