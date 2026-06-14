import 'package:flutter/material.dart';
import 'package:safedrive/presentation/screens/login_screen.dart';

void main() {
  runApp(Safedrive());
}

class Safedrive extends StatelessWidget {
  const Safedrive({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.yellow, useMaterial3: true),
      home: LoginScreen(),
    );
  }
}
