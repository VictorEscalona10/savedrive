import 'package:flutter/material.dart';
import 'package:safedrive/presentation/layouts/main_layout_screen.dart';
// ¡Importante! Asegúrate de importar el archivo donde creaste la función loginUsuario
import 'package:safedrive/server/login.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // NUEVO: Variable para controlar el estado de carga
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // NUEVO: Transformamos la función a asíncrona (Future)
  Future<void> _iniciarSesion() async {
    // 1. Validación básica (que no envíen campos vacíos)
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos')),
      );
      return;
    }

    // 2. Activamos el estado de carga
    setState(() {
      _isLoading = true;
    });

    // 3. Llamamos a nuestra función de servidor de Supabase
    // Usamos .trim() para quitar espacios accidentales al inicio o final del correo
    final error = await loginUsuario(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    // 4. Regla de oro en Flutter: verificar si el widget sigue en pantalla después de un `await`
    if (!mounted) return;

    // 5. Apagamos el estado de carga
    setState(() {
      _isLoading = false;
    });

    // 6. Decidimos qué hacer según el resultado
    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayoutScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor:
              Colors.red.shade400, // Un toque de color rojo para errores
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20.0),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              prefixIcon: const Icon(Icons.lock),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 30.0),

          // NUEVO: Botón adaptado al estado de carga
          SizedBox(
            width: double.infinity, // Hace que el botón ocupe un buen ancho
            height: 50.0,
            child: ElevatedButton(
              // Si está cargando, deshabilitamos el botón (null). Si no, pasamos la función.
              onPressed: _isLoading ? null : _iniciarSesion,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              // Si está cargando, mostramos la ruedita. Si no, mostramos el texto.
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Login', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
