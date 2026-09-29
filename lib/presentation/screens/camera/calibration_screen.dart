import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:safedrive/core/theme/theme_service.dart';
import 'package:safedrive/core/services/snackbar_service.dart';
import 'package:safedrive/data/repositories/settings_repository.dart';
import 'package:safedrive/domain/calibration/ghost_calibration_engine.dart';
import 'package:safedrive/presentation/components/vision/face_guide_painter.dart';
import 'package:safedrive/presentation/screens/camera/drive_screen.dart';

class CalibrationScreen extends StatefulWidget {
  final CameraDescription frontCamera;

  const CalibrationScreen({super.key, required this.frontCamera});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final _settingsRepo = SettingsRepository();
  final _calibrationEngine = GhostCalibrationEngine();

  late CameraController _cameraController;
  late FaceDetector _faceDetector;

  bool _isCalibrating = false;
  bool _isProcessingFrame = false;
  bool _isFaceAligned = false;
  bool _isScanFrameValid = false;
  int _stableFrameCount = 0;
  Offset? _lastFaceCenter;
  double? _lastFaceArea;

  double _progress = 0.0;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    final options = FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
    );
    _faceDetector = FaceDetector(options: options);
    _inicializarCamara();
  }

  Future<void> _inicializarCamara() async {
    _cameraController = CameraController(
      widget.frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController.initialize();
    if (mounted) {
      setState(() {});
      _iniciarStreamDeCamara();
    }
  }

  void _iniciarStreamDeCamara() {
    if (_cameraController.value.isStreamingImages) return;

    _cameraController.startImageStream((CameraImage image) {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;
      _procesarFrame(image);
    });
  }

  void _iniciarCalibracion() {
    setState(() {
      _isCalibrating = true;
      _calibrationEngine.reset();
      _progress = 0.0;
    });

    // Fallback: 30 segundos timeout según CONTEXT.md
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_calibrationEngine.isComplete) {
        SnackBarService.showWarning(
          context,
          'Ajusta la posición del teléfono para calibrar SafeDrive.',
        );
      }
    });
  }

  Future<void> _procesarFrame(CameraImage image) async {
    try {
      final bytes = _concatenatePlanes(image);
      final sensorOrientation = _cameraController.description.sensorOrientation;
      final rotation =
          InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation270deg;
      final format = Platform.isAndroid
          ? InputImageFormat.nv21
          : InputImageFormat.bgra8888;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final leftEye = face.leftEyeOpenProbability;
        final rightEye = face.rightEyeOpenProbability;
        final landmarks = face.landmarks;
        final hasCompleteFace =
            landmarks[FaceLandmarkType.leftEye] != null &&
            landmarks[FaceLandmarkType.rightEye] != null &&
            landmarks[FaceLandmarkType.noseBase] != null &&
            landmarks[FaceLandmarkType.bottomMouth] != null;

        final faceArea = (face.boundingBox.width * face.boundingBox.height) /
            (image.width * image.height);
        final faceCenter = face.boundingBox.center;
        final normalizedCenterX = faceCenter.dx / image.width;
        final normalizedCenterY = faceCenter.dy / image.height;

        final isAligned = hasCompleteFace &&
            (face.headEulerAngleX ?? 90).abs() <= 15 &&
            (face.headEulerAngleY ?? 90).abs() <= 15 &&
            (face.headEulerAngleZ ?? 90).abs() <= 15 &&
            normalizedCenterX >= 0.2 &&
            normalizedCenterX <= 0.8 &&
            normalizedCenterY >= 0.15 &&
            normalizedCenterY <= 0.85 &&
            faceArea >= 0.015 &&
            faceArea <= 0.65;

        final centerMovement = _lastFaceCenter == null
            ? 0.0
            : (faceCenter - _lastFaceCenter!).distance / image.width.toDouble();
        final areaMovement = _lastFaceArea == null
            ? 0.0
            : ((_lastFaceArea! - faceArea).abs() / _lastFaceArea!);
        final isStable =
            isAligned && centerMovement <= 0.035 && areaMovement <= 0.15;

        if (isStable) {
          _stableFrameCount++;
        } else {
          _stableFrameCount = 0;
        }
        _lastFaceCenter = faceCenter;
        _lastFaceArea = faceArea;
        final scanFrameValid = isStable && _stableFrameCount >= 2;

        if (mounted &&
            (_isFaceAligned != isAligned ||
                _isScanFrameValid != scanFrameValid)) {
          setState(() {
            _isFaceAligned = isAligned;
            _isScanFrameValid = scanFrameValid;
          });
        }

        if (isAligned && !_isCalibrating && mounted) {
          _iniciarCalibracion();
        }

        if (_isCalibrating && scanFrameValid) {
          final accepted = _calibrationEngine.processFrame(
            leftEyeOpenProb: leftEye,
            rightEyeOpenProb: rightEye,
            headEulerAngleY: face.headEulerAngleY,
            headEulerAngleX: face.headEulerAngleX,
            headEulerAngleZ: face.headEulerAngleZ,
          );

          if (accepted && mounted) {
            setState(() {
              _progress = _calibrationEngine.progress;
            });

            if (_calibrationEngine.isComplete) {
              await _finalizarCalibracion();
            }
          }
        }
      } else {
        _stableFrameCount = 0;
        _lastFaceCenter = null;
        _lastFaceArea = null;
        if (mounted && (_isFaceAligned || _isScanFrameValid)) {
          setState(() {
            _isFaceAligned = false;
            _isScanFrameValid = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error en procesamiento de frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  Uint8List _concatenatePlanes(CameraImage image) {
    if (Platform.isAndroid) {
      return _yuv420ToNv21(image);
    }
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final bytes = Uint8List(ySize + uvSize);

    bytes.setRange(0, ySize, yPlane.bytes);

    int index = ySize;
    final int rowStride = uPlane.bytesPerRow;
    final int pixelStride = uPlane.bytesPerPixel ?? 1;

    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final int uvIndex = row * rowStride + col * pixelStride;
        bytes[index++] = vPlane.bytes[uvIndex];
        bytes[index++] = uPlane.bytes[uvIndex];
      }
    }
    return bytes;
  }

  Future<void> _finalizarCalibracion() async {
    _timeoutTimer?.cancel();
    await _cameraController.stopImageStream();

    final result = _calibrationEngine.computeBaseline();
    if (result == null || result.baselineEar < 0.05) {
      if (!mounted) return;
      setState(() => _isCalibrating = false);
      _iniciarStreamDeCamara();
      SnackBarService.showWarning(
        context,
        'No se detectó un rostro claro. Intenta nuevamente.',
      );
      return;
    }

    try {
      await _settingsRepo.updateGhostCalibrationBaselines(
        baselineEar: result.baselineEar,
        baselineHeadAngle: result.baselineHeadAngle,
      );
    } catch (e) {
      debugPrint('Aviso: baseline guardado localmente: $e');
    }

    if (mounted) {
      HapticFeedback.mediumImpact();
      SnackBarService.showSuccess(context, '¡Calibración Fantasma completada!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DriveScreen(
            baselineEar: result.baselineEar,
            baselineHeadAngle: result.baselineHeadAngle,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _cameraController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: CameraPreview(_cameraController)),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: FaceGuidePainter(
                  isActive: _isCalibrating && _isScanFrameValid,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Text(
                        'Calibración Fantasma',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isScanFrameValid
                            ? AppColors.brand
                            : Colors.white24,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isCalibrating
                              ? 'Calculando Cero Relativo (${(_progress * 100).toInt()}%)'
                              : 'Alinea tu rostro dentro de la silueta',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isCalibrating
                              ? 'Mantén la mirada al frente sin mover el dispositivo'
                              : 'La calibración inicia de forma automática y silenciosa',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        if (_isCalibrating) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 8,
                              backgroundColor: Colors.white24,
                              color: _isScanFrameValid
                                  ? AppColors.brand
                                  : AppColors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
