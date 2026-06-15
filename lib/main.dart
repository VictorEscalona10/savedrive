import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safedrive/presentation/screens/login_screen.dart';
import 'package:safedrive/presentation/layouts/main_layout_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://aqgesfbxiwuaijdujoai.supabase.co',
    publishableKey: 'sb_publishable_-DlwhfkPAMz16p3alkES8g_HrHj30Ji',
  );

  runApp(const Safedrive());
}

class Safedrive extends StatelessWidget {
  const Safedrive({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      // En lugar de ir directo al LoginScreen, usamos un "Guardia"
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      return const MainLayoutScreen();
    }

    return const LoginScreen();
  }
}
