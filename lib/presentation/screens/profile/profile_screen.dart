import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safedrive/core/theme/theme_service.dart';
import 'package:safedrive/core/services/snackbar_service.dart';
import 'package:safedrive/core/utils/input_sanitizer.dart';
import 'package:safedrive/data/models/user_model.dart';
import 'package:safedrive/data/repositories/auth_repository.dart';
import 'package:safedrive/data/repositories/user_repository.dart';
import 'package:safedrive/presentation/components/buttons/danger_button.dart';
import 'package:safedrive/presentation/components/buttons/primary_button.dart';
import 'package:safedrive/presentation/components/cards/app_card.dart';
import 'package:safedrive/presentation/components/cards/app_section.dart';
import 'package:safedrive/presentation/components/common/user_avatar.dart';
import 'package:safedrive/presentation/components/dialogs/confirmation_dialog.dart';
import 'package:safedrive/presentation/components/inputs/app_dropdown.dart';
import 'package:safedrive/presentation/components/inputs/app_text_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userRepo = UserRepository();
  final _authRepo = AuthRepository();

  bool _isLoading = true;
  bool _isSaving = false;

  UserModel? _user;
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _bloodType;

  final List<String> _bloodTypes = const [
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
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _userRepo.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _user = user;
          if (user != null) {
            _nameCtrl.text = user.fullName ?? '';
            _bloodType = user.bloodType;
            _notesCtrl.text = user.medicalNotes ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar perfil: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    HapticFeedback.mediumImpact();
    final sName = InputSanitizer.sanitizeName(_nameCtrl.text);
    final sNotes = InputSanitizer.sanitizeNotes(_notesCtrl.text);

    _nameCtrl.text = sName;
    _notesCtrl.text = sNotes;

    if (sName.isNotEmpty && !InputSanitizer.isValidName(sName)) {
      SnackBarService.showError(
        context,
        'El nombre debe tener al menos 2 caracteres válidos.',
      );
      return;
    }

    final currentUser = _authRepo.currentUser;
    if (currentUser == null) {
      SnackBarService.showError(context, 'No hay una sesión activa.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedUser = UserModel(
        id: currentUser.id,
        email: currentUser.email ?? '',
        fullName: sName.isNotEmpty ? sName : null,
        bloodType: _bloodType,
        medicalNotes: sNotes.isNotEmpty ? sNotes : null,
      );

      await _userRepo.saveUserProfile(updatedUser);
      _user = updatedUser;

      if (mounted) {
        SnackBarService.showSuccess(context, '¡Perfil actualizado con éxito!');
      }
    } catch (e) {
      debugPrint('Error al guardar perfil: $e');
      if (mounted) {
        SnackBarService.showError(context, 'Error al guardar en Supabase: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Cerrar sesión',
      message: '¿Estás seguro de que deseas cerrar tu sesión en SafeDrive?',
      confirmLabel: 'Cerrar sesión',
      confirmColor: AppColors.red,
    );

    if (confirmed == true && mounted) {
      await _authRepo.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 96.0;

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(isDark),
          body: SafeArea(
            bottom: false,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brand,
                      strokeWidth: 2.5,
                    ),
                  )
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeaderCard(isDark)),
                      // Sección 1: Información Personal
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildDriverInfoSection(isDark),
                        ),
                      ),
                      // Sección 2: Ficha Médica de Emergencia
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildMedicalSection(isDark),
                        ),
                      ),
                      // Botón Guardar
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: PrimaryButton(
                            label: 'Guardar Perfil',
                            icon: Icons.cloud_done_rounded,
                            isLoading: _isSaving,
                            loadingText: 'Guardando en Supabase...',
                            onPressed: _saveProfile,
                          ),
                        ),
                      ),
                      // Botón Cerrar Sesión
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: DangerButton(
                            label: 'Cerrar sesión segura',
                            icon: Icons.logout_rounded,
                            onPressed: _logout,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    final displayName = _nameCtrl.text.isNotEmpty
        ? _nameCtrl.text
        : (_user?.fullName ?? _user?.email.split('@').first ?? 'Conductor');
    final email = _user?.email ?? '';

    return AppCard(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          UserAvatar(name: displayName, size: 68, borderWidth: 2.5),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: AppColors.t1(isDark),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(color: AppColors.t2(isDark), fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_bloodType != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.red.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bloodtype_rounded,
                          color: AppColors.red,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tipo $_bloodType',
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoSection(bool isDark) {
    return AppSection(
      icon: Icons.person_outline_rounded,
      iconColor: AppColors.cyan,
      title: 'Información del Conductor',
      padding: const EdgeInsets.all(18),
      child: AppTextField(
        controller: _nameCtrl,
        label: 'Nombre Completo',
        hint: 'Tu nombre y apellido',
        prefixIcon: Icons.badge_outlined,
      ),
    );
  }

  Widget _buildMedicalSection(bool isDark) {
    return AppSection(
      icon: Icons.medical_services_outlined,
      iconColor: AppColors.red,
      title: 'Ficha Médica de Emergencia',
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          AppDropdown<String>(
            value: _bloodType,
            label: 'Tipo de Sangre',
            hint: 'Selecciona grupo sanguíneo',
            prefixIcon: Icons.bloodtype_outlined,
            items: _bloodTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type,
                        style: const TextStyle(
                          color: AppColors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Grupo $type'),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) => setState(() => _bloodType = val),
          ),
          Divider(color: AppColors.border(isDark), height: 24),
          AppTextField(
            controller: _notesCtrl,
            label: 'Condiciones médicas o alergias',
            hint: 'Ej. Alérgico a penicilina, hipertenso...',
            maxLines: 3,
            maxLength: 500,
            prefixIcon: Icons.note_alt_outlined,
          ),
        ],
      ),
    );
  }
}
