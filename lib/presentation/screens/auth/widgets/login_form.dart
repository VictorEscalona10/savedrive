import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safedrive/core/theme/theme_service.dart';
import 'package:safedrive/core/utils/input_sanitizer.dart';
import 'package:safedrive/core/services/snackbar_service.dart';
import 'package:safedrive/data/repositories/auth_repository.dart';
import 'package:safedrive/presentation/components/buttons/primary_button.dart';
import 'package:safedrive/presentation/components/buttons/secondary_button.dart';
import 'package:safedrive/presentation/components/cards/app_card.dart';
import 'package:safedrive/presentation/components/inputs/app_text_field.dart';
import 'package:safedrive/presentation/layouts/main_layout_screen.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _authRepo = AuthRepository();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _authStateSubscription = _authRepo.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayoutScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _authStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      SnackBarService.showError(context, 'Por favor completa todos los campos.');
      return;
    }

    if (!InputSanitizer.isValidEmail(email)) {
      SnackBarService.showError(context, 'Ingresa un correo electrónico válido.');
      return;
    }

    if (password.length < 6) {
      SnackBarService.showError(context, 'La contraseña debe tener al menos 6 caracteres.');
      return;
    }

    setState(() => _isLoading = true);

    final error = await _authRepo.signInWithEmailPassword(email, password);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (error != null) {
      SnackBarService.showError(context, error);
    }
  }

  Future<void> _iniciarSesionGoogle() async {
    setState(() => _isLoading = true);

    final error = await _authRepo.signInWithGoogle();

    if (!mounted) return;

    if (error != null && !error.contains('cancel')) {
      setState(() => _isLoading = false);
      SnackBarService.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AppCard(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        color: AppColors.t1(isDark),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      'Accede a tu asistente de conducción inteligente',
                      style: TextStyle(
                        color: AppColors.t2(isDark),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cardSecondary(isDark),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border(isDark)),
                      ),
                      child: AppTextField(
                        controller: _emailController,
                        label: 'Correo Electrónico',
                        hint: 'conductor@correo.com',
                        prefixIcon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cardSecondary(isDark),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border(isDark)),
                      ),
                      child: AppTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        hint: '••••••••',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.t3(isDark),
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    PrimaryButton(
                      label: 'Entrar a SafeDrive',
                      icon: Icons.login_rounded,
                      isLoading: _isLoading,
                      loadingText: 'Iniciando sesión...',
                      onPressed: _iniciarSesion,
                    ),
                    const SizedBox(height: 18.0),
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.border(isDark))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            'o continúa con',
                            style: TextStyle(
                              color: AppColors.t3(isDark),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.border(isDark))),
                      ],
                    ),
                    const SizedBox(height: 18.0),
                    SecondaryButton(
                      label: 'Continuar con Google',
                      leading: Image.network(
                        'https://developers.google.com/identity/images/g-logo.png',
                        height: 20,
                        width: 20,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.g_mobiledata,
                          size: 22,
                          color: AppColors.brand,
                        ),
                      ),
                      isLoading: _isLoading,
                      onPressed: _iniciarSesionGoogle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
