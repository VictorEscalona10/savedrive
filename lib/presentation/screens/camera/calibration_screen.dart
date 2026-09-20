import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import "package:safedrive/presentation/screens/camera/drive_screen.dart";
import 'dart:io';
import 'dart:typed_data';

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

  // Aquí guardaremos las lecturas de los ojos durante los 5 segundos
  final List<double> _eyeOpenReadings = [];
  // Aquí guardamos el área relativa del rostro detectado en cada lectura
  final List<double> _faceAreas = [];
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _inicializarCamara();

    // Configuramos el detector para que busque rostros y nos dé el estado de los ojos
    final options = FaceDetectorOptions(
      enableClassification:
          true, // ¡Vital! Esto activa la detección de ojos abiertos/cerrados
      enableTracking: true, // Ayuda a mantener el mismo rostro
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<void> _inicializarCamara() async {
    _cameraController = CameraController(
      widget.frontCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController.initialize();
    if (mounted) setState(() {});
  }

  // --- INICIO DE LA CALIBRACIÓN ---
  void _iniciarCalibracion() {
    setState(() {
      _isCalibrating = true;
      _eyeOpenReadings.clear();
      _progress = 0.0;
    });

    // Empezamos a escuchar los frames de la cámara
    // Empezamos a escuchar los frames de la cámara
    _cameraController.startImageStream((CameraImage image) {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;

      // Llamamos a la función asíncrona
      _procesarFrame(image);
    });

    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!mounted) return;

      setState(() {
        _progress += 0.02;
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

        // Guardamos además el área del bounding box normalizada
        final faceArea = (face.boundingBox.width * face.boundingBox.height) /
            (image.width * image.height);
        _faceAreas.add(faceArea);

        if (leftEye != null && rightEye != null) {
          _eyeOpenReadings.add((leftEye + rightEye) / 2.0);
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
          // Vista de la cámara
          SizedBox.expand(child: CameraPreview(_cameraController)),

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
                  Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0CBA70),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _iniciarCalibracion,
                      child: const Text(
                        'Mirar al frente e Iniciar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        const Text(
                          'Mantén la vista al frente...',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 20),
                        LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.white24,
                          color: const Color(0xFF0CBA70),
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
