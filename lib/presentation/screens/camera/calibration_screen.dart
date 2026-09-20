import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import "package:safedrive/presentation/screens/camera/drive_screen.dart";
import 'dart:io';

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
        await _finalizarCalibracion();
      }
    });
  }

  Future<void> _procesarFrame(CameraImage image) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      // 1. Calculamos la rotación exacta del sensor de tu teléfono
      final sensorOrientation = _cameraController.description.sensorOrientation;
      final rotation =
          InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation270deg;

      // 2. Asignamos el formato de color a prueba de balas (NV21 para Android, BGRA8888 para iOS)
      final format =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          (Platform.isAndroid
              ? InputImageFormat.nv21
              : InputImageFormat.bgra8888);

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

    // 2. Guardamos este valor en Supabase
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await Supabase.instance.client.from('user_settings').upsert({
        'user_id': userId,
        'baseline_eye_open': baseline,
        'updated_at': DateTime.now().toIso8601String(),
      });
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
