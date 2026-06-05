import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// Lista global para almacenar las cámaras disponibles del dispositivo
late List<CameraDescription> _cameras;

Future<void> main() async {
  // Asegura que los bindings nativos estén listos antes de inicializar la cámara
  WidgetsFlutterBinding.ensureInitialized();

  // Obtiene las cámaras de forma asíncrona antes de lanzar la interfaz
  _cameras = await availableCameras();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vista al Volante',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isReady = false;
  bool _isProcessing = false;

  // Inicialización del detector de rostros optimizado para rendimiento veloz
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification:
          true, // Requerido para evaluar si los ojos están abiertos
      enableTracking: true, // Mantiene consistencia de identidad entre frames
      performanceMode: FaceDetectorMode.fast, // Minimiza el uso de CPU/Batería
    ),
  );

  // Control de tiempo para limitar la tasa de procesamiento (Throttling)
  DateTime _ultimoProcesamiento = DateTime.now();

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    // Filtra para encontrar la cámara frontal encargada de enfocar al conductor
    final frontCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    // NUEVO FIX: Forzamos el formato que ML Kit soporta según el sistema operativo
    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _controller.initialize();
    if (!mounted) return;

    setState(() {
      _isReady = true;
    });

    // Escucha activa del flujo continuo de imágenes
    _controller.startImageStream((CameraImage image) {
      if (_isProcessing) return;

      final ahora = DateTime.now();
      // Restricción: solo se analiza un frame cada 300 milisegundos (~3 FPS)
      if (ahora.difference(_ultimoProcesamiento).inMilliseconds < 300) return;

      _ultimoProcesamiento = ahora;
      _processCameraImage(image);
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _isProcessing = true;

    try {
      // Transforma el formato crudo de la cámara al formato asimilable por el modelo
      final inputImage = _convertirAInputImage(image);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint("Alerta: No se detecta conductor en el encuadre.");
      }

      for (Face face in faces) {
        // Métricas de orientación de la estructura ósea facial
        final double? rotacionY =
            face.headEulerAngleY; // Desviación Izquierda/Derecha
        final double? rotacionX =
            face.headEulerAngleX; // Desviación Arriba/Abajo

        // Índices probabilísticos de apertura ocular (0.0 a 1.0)
        final double? ojoIzquierdo = face.leftEyeOpenProbability;
        final double? ojoDerecho = face.rightEyeOpenProbability;

        // Salida limpia de datos métricos por consola de depuración
        debugPrint('--- TELEMETRÍA DE CONDUCCIÓN ---');
        debugPrint(
          'Ángulo Cabeza X (Inclinación): ${rotacionX?.toStringAsFixed(2)}°',
        );
        debugPrint('Ángulo Cabeza Y (Giro): ${rotacionY?.toStringAsFixed(2)}°');
        debugPrint(
          'Estado Ojo Izquierdo: ${(ojoIzquierdo != null ? ojoIzquierdo * 100 : 0).toStringAsFixed(0)}% abierto',
        );
        debugPrint(
          'Estado Ojo Derecho: ${(ojoDerecho != null ? ojoDerecho * 100 : 0).toStringAsFixed(0)}% abierto',
        );
      }
    } catch (e) {
      debugPrint("Excepción en el procesamiento del flujo: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // NUEVO FIX: Asignamos el formato exacto de InputImageFormat en los metadatos
  InputImage _convertirAInputImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final InputImageFormat format = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotation
          .rotation270deg, // Compensación de rotación estándar para cámaras frontales
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  @override
  void dispose() {
    // Liberación estricta de hardware y recursos lógicos de IA para evitar fugas de memoria
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // MÉTODO BUILD: Vista de cámara sin zoom ni distorsión, centrada y con relación de aspecto original
  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black87)),
      );
    }

    // Obtenemos la relación de aspecto de la cámara
    final cameraAspectRatio = _controller.value.aspectRatio;

    return Scaffold(
      appBar: AppBar(title: const Text('Monitoreo Activo'), centerTitle: true),
      body: Container(
        color:
            Colors.black, // Fondo negro para los bordes que no cubra la cámara
        child: Center(
          child: AspectRatio(
            aspectRatio: cameraAspectRatio,
            child: CameraPreview(_controller),
          ),
        ),
      ),
    );
  }
}
