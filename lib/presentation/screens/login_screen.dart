import 'package:flutter/material.dart';
import 'package:safedrive/components/loginForm/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Iniciar Sesion')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Login Screen'),
            Text('Welcome to the Login Screen'),
            LoginForm(),
          ],
        ),
      ),
    );
  }
}
