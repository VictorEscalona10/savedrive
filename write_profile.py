code = '''import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
//  DESIGN TOKENS — Obsidian Telemetry UI/UX
// =============================================================================
class _C {
  static const bg = Color(0xFF0B0F19);
  static const surface = Color(0xFF141922);
  static const surfaceHi = Color(0xFF1C2433);
  static const brand = Color(0xFF10B981);
  static const brandDim = Color(0xFF059669);
  static const cyan = Color(0xFF06B6D4);
  static const blue = Color(0xFF3B82F6);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const t1 = Color(0xFFF8FAFC);
  static const t2 = Color(0xFF94A3B8);
  static const t3 = Color(0xFF64748B);
  static const border = Color(0xFF262D3D);
  static const r8 = 8.0;
  static const r12 = 12.0;
  static const r20 = 20.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
}

// =============================================================================
//  HELPERS DE SANITIZACIÓN & VALIDACIÓN
// =============================================================================
abstract final class _InputSanitizer {
  // Limpia y sanitiza nombres de personas (permite letras, acentos, espacios y guiones)
  static String sanitizeName(String input) {
    var cleaned = input.trim();
    // Eliminar etiquetas HTML o caracteres de script peligrosos
    cleaned = cleaned.replaceAll(RegExp(r'[<>"/\\\\;%()={}\\$\\^\\*\\[\\]]'), '');
    // Colapsar espacios múltiples en uno solo
    cleaned = cleaned.replaceAll(RegExp(r'\\s+'), ' ');
    if (cleaned.length > 70) {
      cleaned = cleaned.substring(0, 70);
    }
    return cleaned;
  }

  // Sanitiza teléfonos (conserva solo dígitos, +, -, espacios y paréntesis)
  static String sanitizePhone(String input) {
    var cleaned = input.trim();
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9+\\-\\s()]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\\s+'), ' ');
    if (cleaned.length > 25) {
      cleaned = cleaned.substring(0, 25);
    }
    return cleaned;
  }

  // Sanitiza notas médicas y observaciones clínicas
  static String sanitizeNotes(String input) {
    var cleaned = input.trim();
    cleaned = cleaned.replaceAll(RegExp(r'[<>"/\\\\;{}\\$\\^]'), '');
    if (cleaned.length > 500) {
      cleaned = cleaned.substring(0, 500);
    }
    return cleaned;
  }

  // Comprueba si un teléfono contiene al menos 7 dígitos reales
  static bool isValidPhoneDigits(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length >= 7 && digitsOnly.length <= 16;
  }

  // Comprueba si un nombre tiene al menos 2 letras
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
  final _relationshipCtrl = TextEditingController();

  final _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final _relationships = [
    'Familiar',
    'Pareja',
    'Padre / Madre',
    'Hijo / Hija',
    'Hermano / a',
    'Amigo / a',
    'Médico',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
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

  Future<void> _loadProfileData() async {
    try {
      final user = _supa.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final uid = user.id;
      final meta = user.userMetadata;
      final fallbackName =
          (meta?['full_name'] as String?) ??
          (meta?['name'] as String?) ??
          user.email?.split('@').first ??
          '';

      // 1. Cargar datos de la tabla 'users'
      try {
        final userRecord =
            await _supa.from('users').select().eq('id', uid).maybeSingle();

        if (userRecord != null) {
          _nameCtrl.text =
              (userRecord['full_name'] as String?) ?? fallbackName;
          _bloodType = userRecord['blood_type'] as String?;
          _notesCtrl.text = (userRecord['medical_notes'] as String?) ?? '';
        } else {
          _nameCtrl.text = fallbackName;
        }
      } catch (e) {
        debugPrint('Aviso al cargar users: $e');
        _nameCtrl.text = fallbackName;
      }

      // 2. Cargar contacto de emergencia de 'emergency_contacts'
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

    // Actualizar controllers con valores limpios
    _nameCtrl.text = sanitizedName;
    _notesCtrl.text = sanitizedNotes;
    _contactNameCtrl.text = sanitizedContactName;
    _contactPhoneCtrl.text = sanitizedContactPhone;

    // Validación 1: Nombre de conductor
    if (sanitizedName.isNotEmpty && !_InputSanitizer.isValidName(sanitizedName)) {
      _snack('El nombre del conductor debe tener al menos 2 caracteres válidos.', isError: true);
      return;
    }

    // Validación 2: Contacto de emergencia cruzado
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

      // PASO 2: Sincronizar metadatos de usuario en Supabase Auth
      if (sanitizedName.isNotEmpty) {
        try {
          await _supa.auth.updateUser(
            UserAttributes(data: {'full_name': sanitizedName}),
          );
        } catch (_) {}
      }

      // PASO 3: Guardar Contacto de Emergencia
      if (sanitizedContactName.isNotEmpty && sanitizedContactPhone.isNotEmpty) {
        final existingContact =
            await _supa
                .from('emergency_contacts')
                .select('id')
                .eq('user_id', uid)
                .maybeSingle();

        final contactData = <String, dynamic>{
          'contact_name': sanitizedContactName,
          'phone_number': sanitizedContactPhone,
          'relationship': sanitizedRelationship.isNotEmpty ? sanitizedRelationship : 'Familiar',
          'is_primary': true,
        };

        if (existingContact != null) {
          _emergencyContactId = existingContact['id'] as String?;
          await _supa
              .from('emergency_contacts')
              .update(contactData)
              .eq('id', _emergencyContactId!);
        } else {
          contactData['user_id'] = uid;
          final inserted =
              await _supa
                  .from('emergency_contacts')
                  .insert(contactData)
                  .select('id')
                  .maybeSingle();

          if (inserted != null) {
            _emergencyContactId = inserted['id'] as String?;
          }
        }
      }

      if (mounted) {
        _snack('¡Datos médicos y contacto guardados exitosamente!');
      }
    } catch (e) {
      debugPrint('ERROR REAL SUPABASE AL GUARDAR: $e');
      if (mounted) {
        final errText = e.toString();
        if (errText.contains('row-level security') ||
            errText.contains('forbidden') ||
            errText.contains('42501')) {
          _snack(
            'Error RLS: Ejecuta el script SQL en Supabase para habilitar INSERT/UPDATE.',
            isError: true,
          );
        } else {
          _snack('Error al guardar en Supabase: $e', isError: true);
        }
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
      builder:
          (ctx) => _LogoutDialog(
            onConfirm: () => Navigator.of(ctx).pop(true),
            onCancel: () => Navigator.of(ctx).pop(false),
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
        backgroundColor: isError ? _C.red : _C.brand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_C.r12),
        ),
        margin: const EdgeInsets.all(_C.s16),
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

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        bottom: false,
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    color: _C.brand,
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
                      ),
                    ),
                    // Sección 1: Información Personal del Conductor
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        _C.s16,
                        _C.s20,
                        _C.s16,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(child: _driverInfoSection()),
                    ),
                    // Sección 2: Ficha Médica y Tipo de Sangre
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        _C.s16,
                        _C.s16,
                        _C.s16,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(child: _medicalSection()),
                    ),
                    // Sección 3: Contacto de Emergencia
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        _C.s16,
                        _C.s16,
                        _C.s16,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(child: _emergencySection()),
                    ),
                    // Botón Guardar Cambios
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        _C.s16,
                        _C.s24,
                        _C.s16,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(child: _saveBtn()),
                    ),
                    // Botón Cerrar Sesión
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        _C.s16,
                        _C.s12,
                        _C.s16,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(child: _logoutBtn()),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
                  ],
                ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECCIÓN 1: DATOS DEL CONDUCTOR
  // ---------------------------------------------------------------------------
  Widget _driverInfoSection() => _Section(
    icon: Icons.person_outline_rounded,
    iconColor: _C.cyan,
    title: 'Información del Conductor',
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _C.s16,
        vertical: _C.s12,
      ),
      child: Row(
        children: [
          const _IconBox(icon: Icons.badge_outlined, color: _C.cyan),
          const SizedBox(width: _C.s12),
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              maxLength: 70,
              style: const TextStyle(
                color: _C.t1,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                labelStyle: TextStyle(color: _C.t2, fontSize: 13),
                hintText: 'Tu nombre y apellido',
                hintStyle: TextStyle(color: _C.t3, fontSize: 13),
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
  // SECCIÓN 2: DATOS MÉDICOS (users.blood_type & users.medical_notes)
  // ---------------------------------------------------------------------------
  Widget _medicalSection() => _Section(
    icon: Icons.medical_services_outlined,
    iconColor: _C.red,
    title: 'Ficha Médica de Emergencia',
    child: Column(
      children: [
        // Selector de Tipo de Sangre
        Padding(
          padding: const EdgeInsets.fromLTRB(_C.s16, _C.s12, _C.s16, _C.s8),
          child: Row(
            children: [
              const _IconBox(icon: Icons.bloodtype_outlined, color: _C.red),
              const SizedBox(width: _C.s12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _bloodType,
                  dropdownColor: _C.surfaceHi,
                  style: const TextStyle(
                    color: _C.t1,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  iconEnabledColor: _C.t2,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Sangre',
                    labelStyle: TextStyle(color: _C.t2, fontSize: 13),
                    hintText: 'Selecciona tu grupo sanguíneo',
                    hintStyle: TextStyle(color: _C.t3, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                  ),
                  items:
                      _bloodTypes
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x20EF4444),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      t,
                                      style: const TextStyle(
                                        color: _C.red,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Grupo $t',
                                    style: const TextStyle(color: _C.t1),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _bloodType = v),
                ),
              ),
            ],
          ),
        ),
        const _SDivider(),
        // Notas Médicas (Alergias, medicamentos)
        Padding(
          padding: const EdgeInsets.fromLTRB(_C.s16, _C.s8, _C.s16, _C.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: _IconBox(
                  icon: Icons.note_alt_outlined,
                  color: _C.orange,
                ),
              ),
              const SizedBox(width: _C.s12),
              Expanded(
                child: TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  style: const TextStyle(color: _C.t1, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Notas Médicas & Alergias',
                    labelStyle: TextStyle(color: _C.t2, fontSize: 13),
                    hintText:
                        'Alergias a medicamentos, asma, diabetes, donante de órganos...',
                    hintStyle: TextStyle(
                      color: _C.t3,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterStyle: TextStyle(color: _C.t3, fontSize: 10),
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
  // SECCIÓN 3: CONTACTO DE EMERGENCIA (emergency_contacts)
  // ---------------------------------------------------------------------------
  Widget _emergencySection() => _Section(
    icon: Icons.contact_phone_outlined,
    iconColor: _C.brand,
    title: 'Contacto de Auxilio Vial',
    child: Column(
      children: [
        // Nombre del Contacto
        Padding(
          padding: const EdgeInsets.fromLTRB(_C.s16, _C.s12, _C.s16, _C.s8),
          child: Row(
            children: [
              const _IconBox(icon: Icons.person_pin_outlined, color: _C.brand),
              const SizedBox(width: _C.s12),
              Expanded(
                child: TextField(
                  controller: _contactNameCtrl,
                  maxLength: 70,
                  style: const TextStyle(
                    color: _C.t1,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Contacto',
                    labelStyle: TextStyle(color: _C.t2, fontSize: 13),
                    hintText: 'Ej: María Gómez (Esposa / Familiar)',
                    hintStyle: TextStyle(color: _C.t3, fontSize: 13),
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
        const _SDivider(),
        // Teléfono del Contacto
        Padding(
          padding: const EdgeInsets.fromLTRB(_C.s16, _C.s8, _C.s16, _C.s8),
          child: Row(
            children: [
              const _IconBox(icon: Icons.phone_outlined, color: _C.blue),
              const SizedBox(width: _C.s12),
              Expanded(
                child: TextField(
                  controller: _contactPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 25,
                  style: const TextStyle(
                    color: _C.t1,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Teléfono / WhatsApp de Emergencia',
                    labelStyle: TextStyle(color: _C.t2, fontSize: 13),
                    hintText: '+58 412 1234567',
                    hintStyle: TextStyle(color: _C.t3, fontSize: 13),
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
        const _SDivider(),
        // Parentesco / Relación
        Padding(
          padding: const EdgeInsets.fromLTRB(_C.s16, _C.s8, _C.s16, _C.s12),
          child: Row(
            children: [
              const _IconBox(
                icon: Icons.family_restroom_outlined,
                color: _C.cyan,
              ),
              const SizedBox(width: _C.s12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue:
                      _relationships.contains(_relationshipCtrl.text)
                          ? _relationshipCtrl.text
                          : 'Familiar',
                  dropdownColor: _C.surfaceHi,
                  style: const TextStyle(
                    color: _C.t1,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  iconEnabledColor: _C.t2,
                  decoration: const InputDecoration(
                    labelText: 'Parentesco / Relación',
                    labelStyle: TextStyle(color: _C.t2, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                  ),
                  items:
                      _relationships
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                r,
                                style: const TextStyle(color: _C.t1),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _relationshipCtrl.text = v);
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
  Widget _saveBtn() => GestureDetector(
    onTap: _isSaving ? null : _save,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        gradient:
            _isSaving
                ? null
                : const LinearGradient(
                  colors: [_C.brand, _C.brandDim],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        color: _isSaving ? _C.surface : null,
        borderRadius: BorderRadius.circular(_C.r20),
        border: _isSaving ? Border.all(color: _C.border) : null,
        boxShadow:
            _isSaving
                ? null
                : const [
                  BoxShadow(
                    color: Color(0x4810B981),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: Offset(0, 8),
                  ),
                ],
      ),
      child: Center(
        child:
            _isSaving
                ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: _C.brand,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Validando y Sincronizando con Supabase...',
                      style: TextStyle(
                        color: _C.t2,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
                : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_done_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
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
  Widget _logoutBtn() => GestureDetector(
    onTap: _logout,
    child: Container(
      height: 54,
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(_C.r20),
        border: Border.all(color: _C.red.withValues(alpha: 0.3)),
      ),
      child: const Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout_rounded, color: _C.red, size: 18),
            SizedBox(width: 8),
            Text(
              'Cerrar sesión segura',
              style: TextStyle(
                color: _C.red,
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

  const _ProfileHeader({
    required this.name,
    required this.email,
    this.avatar,
    this.bloodType,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;
    return Container(
      margin: const EdgeInsets.fromLTRB(_C.s16, _C.s20, _C.s16, 0),
      padding: const EdgeInsets.all(_C.s20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C1929), Color(0xFF09121E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_C.r20),
        border: Border.all(color: const Color(0x3310B981)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1810B981),
            blurRadius: 24,
            spreadRadius: -4,
            offset: Offset(0, 6),
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
              border: Border.all(color: _C.brand, width: 2.5),
              color: const Color(0xFF0B141F),
            ),
            child: ClipOval(
              child:
                  avatar != null
                      ? Image.network(
                        avatar!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) =>
                                _fallback(firstName),
                      )
                      : _fallback(firstName),
            ),
          ),
          const SizedBox(width: _C.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _C.t1,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(color: _C.t2, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                if (bloodType != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x25EF4444),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x55EF4444), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bloodtype, color: _C.red, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Tipo $bloodType',
                          style: const TextStyle(
                            color: _C.red,
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
        color: _C.brand,
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

  const _Section({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
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
                borderRadius: BorderRadius.circular(_C.r8),
              ),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(width: _C.s8),
            Text(
              title,
              style: const TextStyle(
                color: _C.t1,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: _C.s12),
        Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(_C.r20),
            border: Border.all(color: _C.border),
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
      borderRadius: BorderRadius.circular(_C.r8),
    ),
    child: Icon(icon, color: color, size: 17),
  );
}

class _SDivider extends StatelessWidget {
  const _SDivider();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    thickness: 1,
    color: _C.border,
    indent: 16,
    endIndent: 16,
  );
}

class _LogoutDialog extends StatelessWidget {
  final VoidCallback onConfirm, onCancel;

  const _LogoutDialog({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _C.surfaceHi,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_C.r20),
        side: const BorderSide(color: _C.border),
      ),
      title: const Text(
        'Cerrar sesión',
        style: TextStyle(
          color: _C.t1,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      content: const Text(
        'Tu sesión se cerrará de forma segura. Deberás ingresar tus credenciales para volver a entrar.',
        style: TextStyle(color: _C.t2, fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text(
            'Cancelar',
            style: TextStyle(color: _C.t2, fontWeight: FontWeight.w500),
          ),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text(
            'Cerrar sesión',
            style: TextStyle(color: _C.red, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
'''

with open(r'c:\Users\Admin\Documents\Uni\PROYECTO_3ER_ANO\savedrive\lib\presentation\screens\profile_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("ProfileScreen updated with input sanitization, cross-field validation, and removed 'Conductor Verificado' badge!")
