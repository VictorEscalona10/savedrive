import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safedrive/core/theme/theme_service.dart';
import 'package:safedrive/core/utils/input_sanitizer.dart';
import 'package:safedrive/core/services/snackbar_service.dart';
import 'package:safedrive/core/services/app_preferences_service.dart';
import 'package:safedrive/data/repositories/auth_repository.dart';
import 'package:safedrive/presentation/components/buttons/primary_button.dart';
import 'package:safedrive/presentation/components/buttons/secondary_button.dart';
import 'package:safedrive/presentation/components/cards/app_card.dart';
import 'package:safedrive/presentation/components/inputs/app_text_field.dart';
import 'package:safedrive/presentation/components/common/theme_toggle_button.dart';
import 'package:safedrive/presentation/layouts/main_layout_screen.dart';
import 'package:safedrive/presentation/screens/auth/login_screen.dart';
import 'package:safedrive/presentation/screens/auth/widgets/register_dots_indicator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final AuthRepository _authRepo = AuthRepository();

  int _currentPage = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Controladores de datos del registro
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _medicalNotesController = TextEditingController();

  String _selectedCountryCode = '+58';
  String? _selectedBloodType;

  late final StreamSubscription<AuthState> _authStateSubscription;

  final List<Map<String, String>> _countryCodes = [
    {'flag': '🇻🇪', 'code': '+58', 'name': 'Venezuela'},
    {'flag': '🇨🇴', 'code': '+57', 'name': 'Colombia'},
    {'flag': '🇲🇽', 'code': '+52', 'name': 'México'},
    {'flag': '🇪🇸', 'code': '+34', 'name': 'España'},
    {'flag': '🇺🇸', 'code': '+1', 'name': 'Estados Unidos'},
    {'flag': '🇦🇷', 'code': '+54', 'name': 'Argentina'},
    {'flag': '🇨🇱', 'code': '+56', 'name': 'Chile'},
    {'flag': '🇵🇪', 'code': '+51', 'name': 'Perú'},
  ];

  final List<String> _bloodTypes = [
    'O+',
    'O-',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authStateSubscription = _authRepo.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null && mounted) {
        AppPreferencesService.markOnboardingCompleted();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainLayoutScreen()),
          (route) => false,
        );
      }
    });

    _nameController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isLoading && mounted) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _authRepo.currentSession == null && _isLoading) {
          setState(() => _isLoading = false);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _medicalNotesController.dispose();
    _authStateSubscription.cancel();
    super.dispose();
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _previousPage() {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goToLogin() {
    AppPreferencesService.markOnboardingCompleted();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _submitRegistration() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _nameController.text.trim();
    final fullPhone = '$_selectedCountryCode ${_phoneController.text.trim()}';

    setState(() => _isLoading = true);

    final result = await _authRepo.signUpWithEmailPassword(
      email: email,
      password: password,
      fullName: fullName,
      phone: fullPhone,
      bloodType: _selectedBloodType,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.error != null) {
      SnackBarService.showError(context, result.error!);
      return;
    }

    await AppPreferencesService.markOnboardingCompleted();

    if (result.requiresConfirmation) {
      if (!mounted) return;
      _showConfirmationDialog();
    } else {
      if (!mounted) return;
      _nextPage(); // Ir a pantalla de éxito
    }
  }

  Future<void> _iniciarSesionGoogle() async {
    setState(() => _isLoading = true);
    try {
      final error = await _authRepo.signInWithGoogle();
      if (!mounted) return;

      if (error != null) {
        setState(() => _isLoading = false);
        final lower = error.toLowerCase();
        if (!lower.contains('cancel') && !lower.contains('closed')) {
          SnackBarService.showError(context, error);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = ThemeService.isDark;
        return AlertDialog(
          backgroundColor: AppColors.card(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.mark_email_read_rounded, color: AppColors.brand, size: 28),
              const SizedBox(width: 10),
              Text(
                'Confirma tu correo',
                style: TextStyle(
                  color: AppColors.t1(isDark),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            'Hemos enviado un enlace de confirmación a ${_emailController.text.trim()}.\n\nPor favor revisa tu bandeja de entrada para verificar tu cuenta y poder ingresar.',
            style: TextStyle(
              color: AppColors.t2(isDark),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            PrimaryButton(
              label: 'Ir a Iniciar Sesión',
              onPressed: () {
                Navigator.of(context).pop();
                _goToLogin();
              },
            ),
          ],
        );
      },
    );
  }

  // Validaciones
  bool get _isNameValid => _nameController.text.trim().length >= 2;
  bool get _isPhoneValid => _phoneController.text.trim().replaceAll(RegExp(r'\D'), '').length >= 7;
  bool get _isEmailValid => InputSanitizer.isValidEmail(_emailController.text.trim());

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumberOrSpecial =>
      _passwordController.text.contains(RegExp(r'[0-9!@#\$&*~]'));
  bool get _isPasswordValid => _hasMinLength && _hasUppercase && _hasNumberOrSpecial;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: AppColors.bg(isDark),
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: AppColors.bg(isDark),
            body: SafeArea(
              child: Column(
                children: [
                  // Barra superior con indicadores de puntos (oculta en bienvenida y éxito)
                  if (_currentPage > 0 && _currentPage < 6)
                    _buildTopHeader(isDark),

                  // Páginas del flujo
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (page) => setState(() => _currentPage = page),
                      children: [
                        _buildWelcomeStep(isDark),
                        _buildNameStep(isDark),
                        _buildPhoneStep(isDark),
                        _buildEmailStep(isDark),
                        _buildPasswordStep(isDark),
                        _buildEmergencyStep(isDark),
                        _buildSuccessStep(isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousPage,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.t1(isDark),
              size: 20,
            ),
            tooltip: 'Volver',
          ),
          RegisterDotsIndicator(
            currentIndex: _currentPage - 1,
            totalSteps: 5,
          ),
          const ThemeToggleButton(),
        ],
      ),
    );
  }

  // --- PASO 0: BIENVENIDA ---
  Widget _buildWelcomeStep(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: const ThemeToggleButton(),
              ),
              const SizedBox(height: 20),
              // Icono con resplandor moderno
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brand, AppColors.brandDim],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.45),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'SafeDrive',
                style: TextStyle(
                  color: AppColors.t1(isDark),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tu copiloto inteligente para viajes seguros y protegidos con visión por computadora.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.t2(isDark),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 40),
              PrimaryButton(
                label: 'Comenzar registro',
                icon: Icons.arrow_forward_rounded,
                onPressed: _nextPage,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿Ya tienes una cuenta?',
                    style: TextStyle(
                      color: AppColors.t3(isDark),
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: _goToLogin,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Iniciar sesión',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- PASO 1: NOMBRE ---
  Widget _buildNameStep(bool isDark) {
    return _buildStepContainer(
      isDark: isDark,
      title: '¿Cómo te llamas?',
      subtitle: 'Personalizaremos las alertas y tu perfil de conducción.',
      icon: Icons.badge_outlined,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardSecondary(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isNameValid ? AppColors.brand : AppColors.border(isDark),
            width: _isNameValid ? 1.5 : 1.0,
          ),
        ),
        child: AppTextField(
          controller: _nameController,
          label: 'Nombre Completo',
          hint: 'Ej. Carlos Méndez',
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
        ),
      ),
      bottomButton: PrimaryButton(
        label: 'Continuar',
        icon: Icons.arrow_forward_rounded,
        onPressed: _isNameValid ? _nextPage : null,
      ),
    );
  }

  // --- PASO 2: TELÉFONO ---
  Widget _buildPhoneStep(bool isDark) {
    return _buildStepContainer(
      isDark: isDark,
      title: 'Tu número de teléfono',
      subtitle: 'Se utilizará para vincular tus alertas de emergencia y contactos SOS.',
      icon: Icons.phone_android_rounded,
      body: Column(
        children: [
          Row(
            children: [
              // Selector de código de país
              InkWell(
                onTap: () => _showCountryPicker(isDark),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.cardSecondary(isDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border(isDark)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _countryCodes.firstWhere(
                          (c) => c['code'] == _selectedCountryCode,
                          orElse: () => {'flag': '🌐'},
                        )['flag']!,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedCountryCode,
                        style: TextStyle(
                          color: AppColors.t1(isDark),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.t3(isDark), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Campo del número de teléfono
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.cardSecondary(isDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isPhoneValid ? AppColors.brand : AppColors.border(isDark),
                      width: _isPhoneValid ? 1.5 : 1.0,
                    ),
                  ),
                  child: AppTextField(
                    controller: _phoneController,
                    label: 'Teléfono',
                    hint: '412 1234567',
                    prefixIcon: Icons.call_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.lock_clock_outlined, size: 16, color: AppColors.t3(isDark)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tus datos están protegidos y solo se usan en caso de emergencia.',
                  style: TextStyle(fontSize: 12, color: AppColors.t3(isDark)),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomButton: PrimaryButton(
        label: 'Continuar',
        icon: Icons.arrow_forward_rounded,
        onPressed: _isPhoneValid ? _nextPage : null,
      ),
    );
  }

  void _showCountryPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Selecciona tu país',
                  style: TextStyle(
                    color: AppColors.t1(isDark),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _countryCodes.length,
                  itemBuilder: (context, index) {
                    final item = _countryCodes[index];
                    final isSelected = item['code'] == _selectedCountryCode;
                    return ListTile(
                      leading: Text(item['flag']!, style: const TextStyle(fontSize: 24)),
                      title: Text(item['name']!, style: TextStyle(color: AppColors.t1(isDark))),
                      trailing: Text(
                        item['code']!,
                        style: TextStyle(
                          color: isSelected ? AppColors.brand : AppColors.t2(isDark),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        setState(() => _selectedCountryCode = item['code']!);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- PASO 3: CORREO ELECTRÓNICO ---
  Widget _buildEmailStep(bool isDark) {
    return _buildStepContainer(
      isDark: isDark,
      title: 'Tu correo electrónico',
      subtitle: 'Con este correo accederás a SafeDrive y recibirás tus resúmenes de viaje.',
      icon: Icons.alternate_email_rounded,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardSecondary(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isEmailValid ? AppColors.brand : AppColors.border(isDark),
            width: _isEmailValid ? 1.5 : 1.0,
          ),
        ),
        child: AppTextField(
          controller: _emailController,
          label: 'Correo Electrónico',
          hint: 'conductor@ejemplo.com',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          suffixIcon: _isEmailValid
              ? const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 20)
              : null,
        ),
      ),
      bottomButton: PrimaryButton(
        label: 'Continuar',
        icon: Icons.arrow_forward_rounded,
        onPressed: _isEmailValid ? _nextPage : null,
      ),
    );
  }

  // --- PASO 4: CONTRASEÑA (PANTALLA SEPARADA) ---
  Widget _buildPasswordStep(bool isDark) {
    return _buildStepContainer(
      isDark: isDark,
      title: 'Crea tu contraseña',
      subtitle: 'Protege tu cuenta con una clave segura.',
      icon: Icons.lock_outline_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardSecondary(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isPasswordValid ? AppColors.brand : AppColors.border(isDark),
                width: _isPasswordValid ? 1.5 : 1.0,
              ),
            ),
            child: AppTextField(
              controller: _passwordController,
              label: 'Contraseña',
              hint: '••••••••',
              prefixIcon: Icons.key_rounded,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.t3(isDark),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Requisitos de seguridad:',
            style: TextStyle(
              color: AppColors.t2(isDark),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _buildPasswordRequirement('Mínimo 8 caracteres', _hasMinLength, isDark),
          const SizedBox(height: 8),
          _buildPasswordRequirement('Al menos una letra mayúscula', _hasUppercase, isDark),
          const SizedBox(height: 8),
          _buildPasswordRequirement('Al menos un número o símbolo especial', _hasNumberOrSpecial, isDark),
        ],
      ),
      bottomButton: PrimaryButton(
        label: 'Continuar',
        icon: Icons.arrow_forward_rounded,
        onPressed: _isPasswordValid ? _nextPage : null,
      ),
    );
  }

  Widget _buildPasswordRequirement(String label, bool isMet, bool isDark) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isMet ? AppColors.brand : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isMet ? AppColors.brand : AppColors.t3(isDark),
              width: 1.5,
            ),
          ),
          child: isMet
              ? const Icon(Icons.check, size: 13, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: isMet ? AppColors.t1(isDark) : AppColors.t3(isDark),
            fontSize: 13,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // --- PASO 5: INFORMACIÓN DE CONDUCTOR / MÉDICA (OPCIONAL) ---
  Widget _buildEmergencyStep(bool isDark) {
    return _buildStepContainer(
      isDark: isDark,
      title: 'Información del Conductor',
      subtitle: 'Datos médicos para paramédicos en caso de accidente. Puedes omitirlo si prefieres.',
      icon: Icons.health_and_safety_outlined,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipo de Sangre',
            style: TextStyle(
              color: AppColors.t1(isDark),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bloodTypes.map((type) {
              final isSelected = _selectedBloodType == type;
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                selectedColor: AppColors.brand,
                backgroundColor: AppColors.cardSecondary(isDark),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.t1(isDark),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? AppColors.brand : AppColors.border(isDark),
                  ),
                ),
                onSelected: (selected) {
                  setState(() {
                    _selectedBloodType = selected ? type : null;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardSecondary(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(isDark)),
            ),
            child: AppTextField(
              controller: _medicalNotesController,
              label: 'Alergias o notas médicas (Opcional)',
              hint: 'Ej. Alérgico a penicilina, asma...',
              prefixIcon: Icons.medical_services_outlined,
              maxLines: 2,
            ),
          ),
        ],
      ),
      bottomButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: 'Crear mi cuenta',
            icon: Icons.check_circle_outline_rounded,
            isLoading: _isLoading,
            loadingText: 'Creando cuenta...',
            onPressed: _submitRegistration,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoading ? null : _submitRegistration,
            child: Text(
              'Omitir este paso y finalizar',
              style: TextStyle(
                color: AppColors.t3(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PASO 6: ÉXITO Y CELEBRACIÓN ---
  Widget _buildSuccessStep(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brand.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.brand, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.brand,
                  size: 60,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '¡Todo listo, ${_nameController.text.trim().split(' ').first}!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.t1(isDark),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tu cuenta en SafeDrive ha sido creada exitosamente. Ya puedes calibrar tu cámara y comenzar a conducir protegido.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.t2(isDark),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              PrimaryButton(
                label: 'Ir a mi panel de conducción',
                icon: Icons.directions_car_rounded,
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const MainLayoutScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper para estructurar los pasos consistentes
  Widget _buildStepContainer({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget body,
    required Widget bottomButton,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.brandGlow(isDark),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: AppColors.brand, size: 24),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.t1(isDark),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.t2(isDark),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    body,
                    const SizedBox(height: 32),
                    bottomButton,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

