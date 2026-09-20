import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import "package:safedrive/presentation/screens/camera/drive_screen.dart";
import 'dart:io';
import 'dart:typed_data';

class _FaceGuidePainter extends CustomPainter {
  final bool isActive;

  const _FaceGuidePainter({required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final faceWidth = (size.width * 0.72).clamp(230.0, 340.0).toDouble();
    final faceHeight = (size.height * 0.37).clamp(265.0, 355.0).toDouble();
    final faceLeft = (size.width - faceWidth) / 2;
    final faceTop = size.height * 0.45 - faceHeight / 2;
    final faceRight = faceLeft + faceWidth;
    final faceBottom = faceTop + faceHeight;
    final centerX = size.width / 2;

    final facePath = Path()
      ..moveTo(centerX, faceTop)
      ..cubicTo(
        faceLeft + faceWidth * 0.18,
        faceTop,
        faceLeft + faceWidth * 0.09,
        faceTop + faceHeight * 0.17,
        faceLeft + faceWidth * 0.12,
        faceTop + faceHeight * 0.4,
      )
      ..cubicTo(
        faceLeft + faceWidth * 0.15,
        faceTop + faceHeight * 0.73,
        faceLeft + faceWidth * 0.29,
        faceBottom - faceHeight * 0.08,
        centerX - faceWidth * 0.16,
        faceBottom - faceHeight * 0.04,
      )
      ..cubicTo(
        centerX - faceWidth * 0.08,
        faceBottom + faceHeight * 0.005,
        centerX + faceWidth * 0.08,
        faceBottom + faceHeight * 0.005,
        centerX + faceWidth * 0.16,
        faceBottom - faceHeight * 0.04,
      )
      ..cubicTo(
        faceRight - faceWidth * 0.29,
        faceBottom - faceHeight * 0.08,
        faceRight - faceWidth * 0.15,
        faceTop + faceHeight * 0.73,
        faceRight - faceWidth * 0.12,
        faceTop + faceHeight * 0.48,
      )
      ..cubicTo(
        faceRight - faceWidth * 0.09,
        faceTop + faceHeight * 0.17,
        faceRight - faceWidth * 0.18,
        faceTop,
        centerX,
        faceTop,
      )
      ..close();

    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(facePath, Offset.zero);
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );

    final guidePaint = Paint()
      ..color = isActive ? const Color(0xFF0CBA70) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(facePath, guidePaint);
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) =>
      oldDelegate.isActive != isActive;
}

class CalibrationScreen extends StatefulWidget {
  final CameraDescription frontCamera;

  const CalibrationScreen({super.key, required this.frontCamera});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  late CameraController _cameraController;
  late FaceDetector _faceDetector;

  bool _isCalibrating = false;
  bool _isProcessingFrame = false;
  bool _isFaceAligned = false;
  bool _isScanFrameValid = false;
  int _stableFrameCount = 0;
  Offset? _lastFaceCenter;
  double? _lastFaceArea;

  // Aquí guardaremos las lecturas de los ojos durante los 5 segundos
  final List<double> _eyeOpenReadings = [];
  // Aquí guardamos el área relativa del rostro detectado en cada lectura
  final List<double> _faceAreas = [];
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    // Configuramos el detector para que busque rostros y nos dé el estado de los ojos
    final options = FaceDetectorOptions(
      enableClassification:
          true, // ¡Vital! Esto activa la detección de ojos abiertos/cerrados
      enableLandmarks: true,
      enableTracking: true, // Ayuda a mantener el mismo rostro
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

  // --- INICIO DE LA CALIBRACIÓN ---
  void _iniciarCalibracion() {
    setState(() {
      _isCalibrating = true;
      _eyeOpenReadings.clear();
      _progress = 0.0;
    });

    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!mounted) return;

      setState(() {
        if (_isScanFrameValid) {
          _progress += 0.02;
        }
      });

      if (_progress >= 1.0) {
        timer.cancel();
        try {
          await _finalizarCalibracion();
        } catch (e, st) {
          debugPrint('Error en _finalizarCalibracion (capturado): $e');
          debugPrint('$st');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ocurrió un error finalizando la calibración.'),
                backgroundColor: Colors.orange,
              ),
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriveScreen()),
            );
          }
        }
      }
    });
  }

  Future<void> _procesarFrame(CameraImage image) async {
    try {
      // Convertir los planos de la cámara al formato que ML Kit entiende.
      // En Android convertimos YUV420 -> NV21; en iOS usamos BGRA.
      final bytes = _concatenatePlanes(image);

      // 1. Calculamos la rotación exacta del sensor de tu teléfono
      final sensorOrientation = _cameraController.description.sensorOrientation;
      final rotation =
          InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation270deg;
      // 2. Asignamos el formato de color correcto según la plataforma
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

      // 3. Procesamos y extraemos la data
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

        // Guardamos además el área del bounding box normalizada
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
            : (faceCenter - _lastFaceCenter!).distance /
                image.width.toDouble();
        final areaMovement = _lastFaceArea == null
            ? 0.0
            : ((_lastFaceArea! - faceArea).abs() / _lastFaceArea!);
        final isStable = isAligned &&
            centerMovement <= 0.035 &&
            areaMovement <= 0.15;

        if (isStable) {
          _stableFrameCount++;
        } else {
          _stableFrameCount = 0;
        }
        _lastFaceCenter = faceCenter;
        _lastFaceArea = faceArea;
        final scanFrameValid = isStable && _stableFrameCount >= 3;

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
          _faceAreas.add(faceArea);

          if (leftEye != null && rightEye != null) {
            _eyeOpenReadings.add((leftEye + rightEye) / 2.0);
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
      debugPrint('Error silenciado en ML Kit: $e');
    } finally {
      // ESTO ES VITAL: Pase lo que pase, liberamos el frame para que no se quede pegado
      _isProcessingFrame = false;
    }
  }

  // Concatenate or convert CameraImage planes into a single bytes buffer
  Uint8List _concatenatePlanes(CameraImage image) {
    if (Platform.isAndroid) {
      return _yuv420ToNv21(image);
    }

    // iOS / web: simple concatenation
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  // Convert YUV420 (CameraImage) to NV21 byte array (expected by ML Kit on Android)
  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;

    final bytes = Uint8List(ySize + uvSize);

    // Copy Y
    bytes.setRange(0, ySize, yPlane.bytes);

    // Interleave V and U (NV21 format = VU)
    int index = ySize;
    final int rowStride = uPlane.bytesPerRow;
    final int pixelStride = uPlane.bytesPerPixel ?? 1;

    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final int uvIndex = row * rowStride + col * pixelStride;
        // v then u
        bytes[index++] = vPlane.bytes[uvIndex];
        bytes[index++] = uPlane.bytes[uvIndex];
      }
    }

    return bytes;
  }

  Future<void> _finalizarCalibracion() async {
    await _cameraController.stopImageStream();

    if (_eyeOpenReadings.isEmpty) {
      // Si no se detectó ningún rostro, pedimos reintentar
      setState(() => _isCalibrating = false);
      _iniciarStreamDeCamara();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se detectó un rostro claro. Intenta de nuevo.'),
        ),
      );
      return;
    }

    // 1. Calculamos el promedio personal del usuario (su Baseline)
    final double baseline =
        _eyeOpenReadings.reduce((a, b) => a + b) / _eyeOpenReadings.length;

    // 1.b Validaciones adicionales: suficientes lecturas y rostro estable
    final int minReadings = 10; // mínimo de lecturas aceptables
    final double minFaceArea = 0.02; // rostro debe cubrir al menos 2% del frame

    final double avgFaceArea = _faceAreas.isNotEmpty
        ? _faceAreas.reduce((a, b) => a + b) / _faceAreas.length
        : 0.0;

    if (_eyeOpenReadings.length < minReadings || avgFaceArea < minFaceArea) {
      setState(() => _isCalibrating = false);
      _iniciarStreamDeCamara();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No se detectó un rostro estable durante la calibración. Asegúrate de mirar la cámara y quítate objetos que cubran la cara.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 1.c Validación del baseline (por seguridad): si quedó extremadamente bajo,
    // pedimos reintentar.
    if (baseline < 0.05) {
      setState(() => _isCalibrating = false);
      _iniciarStreamDeCamara();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lecturas inválidas durante la calibración. Intenta de nuevo.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Intentamos guardar este valor en Supabase (si hay red). Si falla,
    // guardamos localmente y continuamos la navegación hacia el viaje.
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await Supabase.instance.client.from('user_settings').upsert({
          'user_id': userId,
          'baseline_eye_open': baseline,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('No se pudo guardar baseline en Supabase: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calibración completada, pero no se pudo guardar en la nube.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }

    if (mounted) {
      // 3. Pasamos a la pantalla del viaje
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Calibración exitosa! Iniciando viaje...'),
          backgroundColor: Colors.green,
        ),
      );

      // AGREGA ESTAS LÍNEAS PARA NAVEGAR (Y asegúrate de importar drive_screen.dart arriba)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DriveScreen()),
      );
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // CameraPreview ya corrige la orientación y la relación de aspecto
          // según la posición real del teléfono.
          Center(child: CameraPreview(_cameraController)),

          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FaceGuidePainter(
                  isActive: _isCalibrating && _isScanFrameValid,
                ),
              ),
            ),
          ),

          // Interfaz superpuesta
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'Calibración Facial',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                if (!_isCalibrating)
                  const Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Text(
                      'Alinea tu rostro con la silueta',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        const Text(
                          'Mantén el rostro completo y quédate quieto...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.white24,
                          color: _isScanFrameValid
                              ? const Color(0xFF0CBA70)
                              : Colors.orange,
                        ),
                      ],
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
