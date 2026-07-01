import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importación de Supabase
import 'package:camera/camera.dart';
// Asegúrate de poner la ruta correcta hacia tu archivo
import 'package:safedrive/presentation/screens/camera/calibration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String nombreUsuario = "Usuario"; // Valor por defecto
  String? avatarUrl;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  void _cargarDatosUsuario() {
    final usuarioActual = Supabase.instance.client.auth.currentUser;

    if (usuarioActual != null) {
      final metadata = usuarioActual.userMetadata;

      setState(() {
        nombreUsuario =
            metadata?['full_name'] ??
            usuarioActual.email?.split('@').first ??
            "Usuario";

        avatarUrl = metadata?['avatar_url'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hola, $nombreUsuario",
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  "A donde iremos hoy?",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
            const Spacer(),
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey.shade300,

              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl!)
                  : null,
              // Si avatarUrl es nulo, mostramos un icono por defecto
              child: avatarUrl == null
                  ? const Icon(Icons.person, size: 30, color: Colors.grey)
                  : null,
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF4F6F8),
      ),
      backgroundColor: const Color(0xFFF4F6F8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Bienvenido a SafeDrive',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 150),
              Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  leading: const Text(
                    '15%+',
                    style: TextStyle(color: Color(0xFF0CBA70), fontSize: 14),
                  ),
                  title: const Text('Despliegame'),
                  shape: const Border(),
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.grey.shade50,
                      padding: const EdgeInsets.all(16.0),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informacion rapida acerca del usuario',
                            style: TextStyle(fontSize: 16.0),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Datosss, aqui van datoss',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 100,
                    vertical: 20,
                  ),
                ),
                child: const Text('Iniciar viaje'),
                onPressed: () async {
                  // Mostramos un indicador de carga opcional si tarda un segundo en buscar la cámara
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Iniciando cámara...'),
                      duration: Duration(seconds: 1),
                    ),
                  );

                  try {
                    // 1. Obtenemos todas las cámaras del teléfono
                    final cameras = await availableCameras();

                    // 2. Buscamos específicamente la cámara frontal (selfie)
                    final frontCamera = cameras.firstWhere(
                      (camera) =>
                          camera.lensDirection == CameraLensDirection.front,
                      orElse: () => cameras
                          .first, // Por si ocurre un error, usamos la principal
                    );

                    // 3. Navegamos a la pantalla de calibración pasándole la cámara
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CalibrationScreen(frontCamera: frontCamera),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al abrir la cámara: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
