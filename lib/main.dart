import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safedrive/presentation/screens/login_screen.dart';
import 'package:safedrive/presentation/layouts/main_layout_screen.dart';
import 'package:safedrive/core/theme/theme_service.dart';

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
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: AppColors.bg(false),
            colorSchemeSeed: AppColors.brand,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.bg(true),
            colorSchemeSeed: AppColors.brand,
          ),
          home: const AuthGate(),
        );
      },
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
