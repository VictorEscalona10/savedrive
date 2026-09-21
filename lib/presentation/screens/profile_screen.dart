import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safedrive/core/theme/theme_service.dart';

// =============================================================================
//  HELPERS DE SANITIZACIÓN & VALIDACIÓN
// =============================================================================
abstract final class _InputSanitizer {
  // Limpia y sanitiza nombres de personas (permite letras, acentos, espacios y guiones)
  static String sanitizeName(String input) {
    var cleaned = input.trim();
    cleaned = cleaned.replaceAll(RegExp(r'[<>"/\\;%()={}\$\^\*\[\]]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length > 70) {
      cleaned = cleaned.substring(0, 70);
    }
    return cleaned;
  }

  // Sanitiza teléfonos (conserva solo dígitos, +, -, espacios y paréntesis)
  static String sanitizePhone(String input) {
    var cleaned = input.trim();
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9+\-\s()]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length > 25) {
      cleaned = cleaned.substring(0, 25);
    }
    return cleaned;
  }

  // Sanitiza notas médicas y observaciones clínicas
  static String sanitizeNotes(String input) {
    var cleaned = input.trim();
    cleaned = cleaned.replaceAll(RegExp(r'[<>"/\\;{}\$\^]'), '');
    if (cleaned.length > 500) {
      cleaned = cleaned.substring(0, 500);
    }
    return cleaned;
  }

  static bool isValidPhoneDigits(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length >= 7 && digitsOnly.length <= 16;
  }

  static bool isValidName(String name) {
    return name.trim().length >= 2;
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supa = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;

  // Controladores de Usuario
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _bloodType;

  // Controladores de Contacto de Emergencia
  String? _emergencyContactId;
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _relationshipCtrl = TextEditingController(text: 'Familiar');

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

  final List<String> _relationships = const [
    'Familiar',
    'Cónyuge',
    'Padre / Madre',
    'Hijo / Hija',
    'Amigo / Amiga',
    'Compañero de Trabajo',
    'Médico Personal',
    'Otro',
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
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _relationshipCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supa.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final uid = user.id;

      // 1. Cargar datos de la tabla `users`
      try {
        final userRecord =
            await _supa.from('users').select().eq('id', uid).maybeSingle();

        if (userRecord != null) {
          _nameCtrl.text = (userRecord['full_name'] as String?) ?? '';
          _bloodType = userRecord['blood_type'] as String?;
          _notesCtrl.text = (userRecord['medical_notes'] as String?) ?? '';
        } else {
          final meta = user.userMetadata;
          _nameCtrl.text =
              (meta?['full_name'] as String?) ??
              (meta?['name'] as String?) ??
              '';
        }
      } catch (e) {
        debugPrint('Aviso al cargar users: $e');
      }

      // 2. Cargar contacto de emergencia principal de `emergency_contacts`
      try {
        final contactRecord =
            await _supa
                .from('emergency_contacts')
                .select()
                .eq('user_id', uid)
                .order('is_primary', ascending: false)
                .limit(1)
                .maybeSingle();

        if (contactRecord != null) {
          _emergencyContactId = contactRecord['id'] as String?;
          _contactNameCtrl.text =
              (contactRecord['contact_name'] as String?) ?? '';
          _contactPhoneCtrl.text =
              (contactRecord['phone_number'] as String?) ?? '';
          _relationshipCtrl.text =
              (contactRecord['relationship'] as String?) ?? 'Familiar';
        } else {
          _relationshipCtrl.text = 'Familiar';
        }
      } catch (e) {
        debugPrint('Aviso al cargar emergency_contacts: $e');
        _relationshipCtrl.text = 'Familiar';
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error general al cargar perfil: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();

    // ─── SANITIZACIÓN & COMPROBACIONES DE INPUTS ───
    final sanitizedName = _InputSanitizer.sanitizeName(_nameCtrl.text);
    final sanitizedNotes = _InputSanitizer.sanitizeNotes(_notesCtrl.text);
    final sanitizedContactName = _InputSanitizer.sanitizeName(_contactNameCtrl.text);
    final sanitizedContactPhone = _InputSanitizer.sanitizePhone(_contactPhoneCtrl.text);
    final sanitizedRelationship = _relationshipCtrl.text.trim();

    _nameCtrl.text = sanitizedName;
    _notesCtrl.text = sanitizedNotes;
    _contactNameCtrl.text = sanitizedContactName;
    _contactPhoneCtrl.text = sanitizedContactPhone;

    if (sanitizedName.isNotEmpty && !_InputSanitizer.isValidName(sanitizedName)) {
      _snack('El nombre del conductor debe tener al menos 2 caracteres válidos.', isError: true);
      return;
    }

    if (sanitizedContactName.isNotEmpty && sanitizedContactPhone.isEmpty) {
      _snack('Por favor ingresa un teléfono para el contacto de emergencia.', isError: true);
      return;
    }
    if (sanitizedContactPhone.isNotEmpty && sanitizedContactName.isEmpty) {
      _snack('Por favor ingresa el nombre de la persona de contacto de emergencia.', isError: true);
      return;
    }
    if (sanitizedContactPhone.isNotEmpty && !_InputSanitizer.isValidPhoneDigits(sanitizedContactPhone)) {
      _snack('El teléfono de emergencia debe contener al menos 7 dígitos numéricos.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _supa.auth.currentUser;
      if (user == null) {
        throw 'No hay una sesión activa en Supabase. Inicia sesión nuevamente.';
      }

      final uid = user.id;

      // PASO 1: Guardar en public.users
      final existingUser =
          await _supa.from('users').select('id').eq('id', uid).maybeSingle();

      if (existingUser != null) {
        await _supa.from('users').update({
          'full_name': sanitizedName.isNotEmpty ? sanitizedName : null,
          'blood_type': _bloodType,
          'medical_notes': sanitizedNotes.isNotEmpty ? sanitizedNotes : null,
        }).eq('id', uid);
      } else {
        await _supa.from('users').insert({
          'id': uid,
          'email': user.email,
          'full_name': sanitizedName.isNotEmpty ? sanitizedName : null,
          'blood_type': _bloodType,
          'medical_notes': sanitizedNotes.isNotEmpty ? sanitizedNotes : null,
        });
      }

      // PASO 2: Guardar o actualizar contacto de emergencia
      if (sanitizedContactName.isNotEmpty && sanitizedContactPhone.isNotEmpty) {
        if (_emergencyContactId != null) {
          await _supa.from('emergency_contacts').update({
            'contact_name': sanitizedContactName,
            'phone_number': sanitizedContactPhone,
            'relationship': sanitizedRelationship.isNotEmpty ? sanitizedRelationship : 'Familiar',
            'is_primary': true,
          }).eq('id', _emergencyContactId!);
        } else {
          final res = await _supa.from('emergency_contacts').insert({
            'user_id': uid,
            'contact_name': sanitizedContactName,
            'phone_number': sanitizedContactPhone,
            'relationship': sanitizedRelationship.isNotEmpty ? sanitizedRelationship : 'Familiar',
            'is_primary': true,
          }).select('id').single();

          _emergencyContactId = res['id'] as String?;
        }
      }

      _snack('¡Perfil médico y contacto guardados exitosamente!');
    } catch (e) {
      debugPrint('Error al guardar datos de perfil: $e');
      final errStr = e.toString();
      if (errStr.contains('violates row-level security')) {
        _snack(
          'Error RLS: Debes habilitar políticas INSERT/UPDATE en Supabase.',
          isError: true,
        );
      } else {
        _snack('Error al guardar en Supabase: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ValueListenableBuilder<bool>(
        valueListenable: ThemeService.isDarkMode,
        builder: (_, isDark, __) => _LogoutDialog(
          isDark: isDark,
          onConfirm: () => Navigator.of(ctx).pop(true),
          onCancel: () => Navigator.of(ctx).pop(false),
        ),
      ),
    );
    if (ok == true) {
      await _supa.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.red : AppColors.brand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supa.auth.currentUser;
    final meta = user?.userMetadata;
    final name =
        _nameCtrl.text.isNotEmpty
            ? _nameCtrl.text
            : (meta?['full_name'] as String?) ??
                user?.email?.split('@').first ??
                'Conductor';
    final email = user?.email ?? '';
    final avatar = meta?['avatar_url'] as String?;
    final bottomPad = MediaQuery.of(context).padding.bottom + 88.0;

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
                      strokeWidth: 2,
                    ),
                  )
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _ProfileHeader(
                          name: name,
                          email: email,
                          avatar: avatar,
                          bloodType: _bloodType,
                          isDark: isDark,
                        ),
                      ),
                      // Sección 1: Información Personal del Conductor
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        sliver: SliverToBoxAdapter(child: _driverInfoSection(isDark)),
                      ),
                      // Sección 2: Ficha Médica y Tipo de Sangre
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        sliver: SliverToBoxAdapter(child: _medicalSection(isDark)),
                      ),
                      // Sección 3: Contacto de Emergencia
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        sliver: SliverToBoxAdapter(child: _emergencySection(isDark)),
                      ),
                      // Botón Guardar Cambios
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        sliver: SliverToBoxAdapter(child: _saveBtn(isDark)),
                      ),
                      // Botón Cerrar Sesión
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        sliver: SliverToBoxAdapter(child: _logoutBtn(isDark)),
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SECCIÓN 1: DATOS DEL CONDUCTOR
  // ---------------------------------------------------------------------------
  Widget _driverInfoSection(bool isDark) => _Section(
        icon: Icons.person_outline_rounded,
        iconColor: AppColors.cyan,
        title: 'Información del Conductor',
        isDark: isDark,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _IconBox(icon: Icons.badge_outlined, color: AppColors.cyan),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  maxLength: 70,
                  style: TextStyle(
                    color: AppColors.t1(isDark),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nombre completo',
                    labelStyle: TextStyle(color: AppColors.t2(isDark), fontSize: 13),
                    hintText: 'Tu nombre y apellido',
                    hintStyle: TextStyle(color: AppColors.t3(isDark), fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // ---------------------------------------------------------------------------
  // SECCIÓN 2: DATOS MÉDICOS
  // ---------------------------------------------------------------------------
  Widget _medicalSection(bool isDark) => _Section(
        icon: Icons.medical_services_outlined,
        iconColor: AppColors.red,
        title: 'Ficha Médica de Emergencia',
        isDark: isDark,
        child: Column(
          children: [
            // Selector de Tipo de Sangre
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _IconBox(icon: Icons.bloodtype_outlined, color: AppColors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _bloodType,
                      dropdownColor: AppColors.card(isDark),
                      style: TextStyle(
                        color: AppColors.t1(isDark),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      iconEnabledColor: AppColors.t2(isDark),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Sangre',
                        labelStyle: TextStyle(color: AppColors.t2(isDark), fontSize: 13),
                        hintText: 'Selecciona tu grupo sanguíneo',
                        hintStyle: TextStyle(color: AppColors.t3(isDark), fontSize: 13),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                      ),
                      items: _bloodTypes
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0x20EF4444),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      t,
                                      style: const TextStyle(
                                        color: AppColors.red,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Grupo $t', style: TextStyle(color: AppColors.t1(isDark))),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _bloodType = val);
                      },
                    ),
                  ),
                ],
              ),
            ),
            _SDivider(isDark: isDark),
            // Notas Médicas / Alergias
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: _IconBox(icon: Icons.note_alt_outlined, color: AppColors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      maxLength: 500,
                      style: TextStyle(
                        color: AppColors.t1(isDark),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Condiciones médicas, alergias o fármacos',
                        labelStyle: TextStyle(color: AppColors.t2(isDark), fontSize: 13),
                        hintText: 'Ej. Alérgico a penicilina, hipertenso, uso de lentes...',
                        hintStyle: TextStyle(color: AppColors.t3(isDark), fontSize: 12),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        counterStyle: TextStyle(color: AppColors.t3(isDark), fontSize: 11),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------------------
  // SECCIÓN 3: CONTACTO DE EMERGENCIA
  // ---------------------------------------------------------------------------
  Widget _emergencySection(bool isDark) => _Section(
        icon: Icons.contact_phone_outlined,
        iconColor: AppColors.brand,
        title: 'Contacto de Emergencia en Ruta',
        isDark: isDark,
        child: Column(
          children: [
            // Nombre del contacto
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _IconBox(icon: Icons.person_add_alt_1_outlined, color: AppColors.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _contactNameCtrl,
                      maxLength: 70,
                      style: TextStyle(
                        color: AppColors.t1(isDark),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Nombre del Contacto',
                        labelStyle: TextStyle(color: AppColors.t2(isDark), fontSize: 13),
                        hintText: 'Ej. María Pérez (Madre)',
                        hintStyle: TextStyle(color: AppColors.t3(isDark), fontSize: 13),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _SDivider(isDark: isDark),
            // Teléfono del contacto
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _IconBox(icon: Icons.phone_forwarded_outlined, color: AppColors.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _contactPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 25,
                      style: TextStyle(
                        color: AppColors.t1(isDark),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Número de Teléfono',
                        labelStyle: TextStyle(color: AppColors.t2(isDark), fontSize: 13),
                        hintText: '+1 234 567 8900',
                        hintStyle: TextStyle(color: AppColors.t3(isDark), fontSize: 13),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _SDivider(isDark: isDark),
            // Parentesco
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  _IconBox(icon: Icons.family_restroom_outlined, color: AppColors.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _relationships.contains(_relationshipCtrl.text)
                          ? _relationshipCtrl.text
                          : 'Familiar',
                      dropdownColor: AppColors.card(isDark),
                      style: TextStyle(
                        color: AppColors.t1(isDark),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      iconEnabledColor: AppColors.t2(isDark),
                      decoration: InputDecoration(
                        labelText: 'Parentesco / Relación',
                        labelStyle: TextStyle(color: AppColors.t2(isDark), fontSize: 13),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                      ),
                      items: _relationships
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          HapticFeedback.selectionClick();
                          setState(() => _relationshipCtrl.text = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------------------
  // BOTÓN GUARDAR CAMBIOS
  // ---------------------------------------------------------------------------
  Widget _saveBtn(bool isDark) => GestureDetector(
        onTap: _isSaving ? null : _save,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: _isSaving
                ? null
                : const LinearGradient(
                    colors: [AppColors.brand, AppColors.brandDim],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: _isSaving ? AppColors.card(isDark) : null,
            borderRadius: BorderRadius.circular(20),
            border: _isSaving ? Border.all(color: AppColors.border(isDark)) : null,
            boxShadow: _isSaving
                ? null
                : [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Center(
            child: _isSaving
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: AppColors.brand,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Guardando en Supabase...',
                        style: TextStyle(
                          color: AppColors.t2(isDark),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Guardar Datos Médicos y Contacto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );

  // ---------------------------------------------------------------------------
  // BOTÓN CERRAR SESIÓN
  // ---------------------------------------------------------------------------
  Widget _logoutBtn(bool isDark) => GestureDetector(
        onTap: _logout,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
          ),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout_rounded, color: AppColors.red, size: 18),
                SizedBox(width: 8),
                Text(
                  'Cerrar sesión segura',
                  style: TextStyle(
                    color: AppColors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// =============================================================================
//  WIDGETS REUTILIZABLES
// =============================================================================

class _ProfileHeader extends StatelessWidget {
  final String name, email;
  final String? avatar;
  final String? bloodType;
  final bool isDark;

  const _ProfileHeader({
    required this.name,
    required this.email,
    this.avatar,
    this.bloodType,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0x3310B981) : const Color(0x3310B981),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x1810B981) : const Color(0x0A000000),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brand, width: 2.5),
              color: AppColors.cardSecondary(isDark),
            ),
            child: ClipOval(
              child: avatar != null
                  ? Image.network(
                      avatar!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(firstName),
                    )
                  : _fallback(firstName),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: AppColors.t1(isDark),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(color: AppColors.t2(isDark), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                if (bloodType != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x25EF4444),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x55EF4444), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bloodtype, color: AppColors.red, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Tipo $bloodType',
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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

  Widget _fallback(String first) => Center(
        child: Text(
          first.isNotEmpty ? first[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: AppColors.brand,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final bool isDark;

  const _Section({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: AppColors.t1(isDark),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border(isDark)),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0x14000000) : const Color(0x08000000),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 17),
      );
}

class _SDivider extends StatelessWidget {
  final bool isDark;
  const _SDivider({required this.isDark});

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        color: AppColors.border(isDark),
        indent: 16,
        endIndent: 16,
      );
}

class _LogoutDialog extends StatelessWidget {
  final bool isDark;
  final VoidCallback onConfirm, onCancel;

  const _LogoutDialog({
    required this.isDark,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.border(isDark)),
      ),
      title: Text(
        'Cerrar sesión',
        style: TextStyle(
          color: AppColors.t1(isDark),
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      content: Text(
        'Tu sesión se cerrará de forma segura. Deberás ingresar tus credenciales para volver a entrar.',
        style: TextStyle(color: AppColors.t2(isDark), fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(
            'Cancelar',
            style: TextStyle(color: AppColors.t2(isDark), fontWeight: FontWeight.w500),
          ),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text(
            'Cerrar sesión',
            style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
