import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  DESIGN TOKENS — espejo de home_screen · ui-ux-pro-max
// ═══════════════════════════════════════════════════════════════════════════
class _C {
  static const bg        = Color(0xFF0A0D12);
  static const surface   = Color(0xFF141920);
  static const surfaceHi = Color(0xFF1C2330);
  static const brand     = Color(0xFF00C472);
  static const brandDim  = Color(0xFF009558);
  static const brandGlow = Color(0x2200C472);
  static const blue      = Color(0xFF3D8EFF);
  static const orange    = Color(0xFFFF9F3D);
  static const red       = Color(0xFFFF5252);
  static const t1        = Color(0xFFECF0F5);
  static const t2        = Color(0xFF8693A4);
  static const t3        = Color(0xFF4B5668);
  static const border    = Color(0xFF1E2736);
  static const r8  = 8.0;
  static const r12 = 12.0;
  static const r20 = 20.0;
  static const s8  = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
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

  final _notesCtrl = TextEditingController();
  String? _bloodType;
  double _sensitivity = 5.0;
  bool _autoTrigger = true;

  final _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uid = _supa.auth.currentUser?.id;
      if (uid == null) {
        return;
      }
      final perfil = await _supa.from('users').select().eq('id', uid).single();
      final ajustes = await _supa.from('user_settings').select().eq('user_id', uid).maybeSingle();
      if (mounted) {
        setState(() {
          _bloodType = perfil['blood_type'] as String?;
          _notesCtrl.text = (perfil['medical_notes'] ?? '') as String;
          if (ajustes != null) {
            _sensitivity = (ajustes['sensitivity_level'] ?? 5).toDouble();
            _autoTrigger = ajustes['auto_trigger_enabled'] ?? true;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Error al cargar el perfil', isError: true);
      }
    }
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
    try {
      final uid = _supa.auth.currentUser?.id;
      if (uid == null) {
        return;
      }
      await _supa.from('users').update({
        'blood_type': _bloodType,
        'medical_notes': _notesCtrl.text.trim()
      }).eq('id', uid);
      await _supa.from('user_settings').upsert({
        'user_id': uid,
        'sensitivity_level': _sensitivity.toInt(),
        'auto_trigger_enabled': _autoTrigger,
        'updated_at': DateTime.now().toIso8601String()
      });
      if (mounted) {
        _snack('Cambios guardados');
      }
    } catch (e) {
      if (mounted) {
        _snack('Error: $e', isError: true);
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
      builder: (ctx) => _LogoutDialog(
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: isError ? _C.red : _C.brand,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_C.r12)),
      margin: const EdgeInsets.all(_C.s16),
    ));
  }

  String get _sensitivityLabel {
    final v = _sensitivity.toInt();
    if (v <= 2) return 'Muy baja';
    if (v <= 4) return 'Baja';
    if (v <= 6) return 'Normal';
    if (v <= 8) return 'Alta';
    return 'Maxima';
  }

  @override
  Widget build(BuildContext context) {
    final user = _supa.auth.currentUser;
    final meta = user?.userMetadata;
    final name = (meta?['full_name'] as String?) ?? user?.email?.split('@').first ?? 'Usuario';
    final email = user?.email ?? '';
    final avatar = meta?['avatar_url'] as String?;
    final bottomPad = MediaQuery.of(context).padding.bottom + 88.0;

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        bottom: false,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _C.brand, strokeWidth: 2))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _ProfileHeader(name: name, email: email, avatar: avatar)),
                SliverPadding(padding: const EdgeInsets.fromLTRB(_C.s16, _C.s20, _C.s16, 0),
                  sliver: SliverToBoxAdapter(child: _medicalSection())),
                SliverPadding(padding: const EdgeInsets.fromLTRB(_C.s16, _C.s16, _C.s16, 0),
                  sliver: SliverToBoxAdapter(child: _settingsSection())),
                SliverPadding(padding: const EdgeInsets.fromLTRB(_C.s16, _C.s24, _C.s16, 0),
                  sliver: SliverToBoxAdapter(child: _saveBtn())),
                SliverPadding(padding: const EdgeInsets.fromLTRB(_C.s16, _C.s12, _C.s16, 0),
                  sliver: SliverToBoxAdapter(child: _logoutBtn())),
                SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
              ],
            ),
      ),
    );
  }

  Widget _medicalSection() => _Section(
    icon: Icons.favorite_border_rounded,
    iconColor: _C.red,
    title: 'Datos medicos',
    child: Column(children: [
      // Blood type
      Padding(padding: const EdgeInsets.fromLTRB(_C.s16, 4, _C.s16, 4),
        child: Row(children: [
          _IconBox(icon: Icons.bloodtype_outlined, color: _C.red),
          const SizedBox(width: _C.s12),
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _bloodType,
            dropdownColor: _C.surfaceHi,
            style: const TextStyle(color: _C.t1, fontSize: 14),
            iconEnabledColor: _C.t2,
            decoration: const InputDecoration(
              labelText: 'Tipo de sangre',
              labelStyle: TextStyle(color: _C.t2, fontSize: 13),
              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
            items: _bloodTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: _C.t1)))).toList(),
            onChanged: (v) => setState(() => _bloodType = v),
          )),
        ])),
      const _SDivider(),
      // Notes
      Padding(padding: const EdgeInsets.fromLTRB(_C.s16, 8, _C.s16, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 12), child: _IconBox(icon: Icons.medical_information_outlined, color: _C.blue)),
          const SizedBox(width: _C.s12),
          Expanded(child: TextField(
            controller: _notesCtrl, maxLines: 3,
            style: const TextStyle(color: _C.t1, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Alergias, condiciones medicas...',
              hintStyle: TextStyle(color: _C.t3, fontSize: 13),
              labelText: 'Notas medicas',
              labelStyle: TextStyle(color: _C.t2, fontSize: 13),
              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
          )),
        ])),
    ]),
  );

  Widget _settingsSection() => _Section(
    icon: Icons.tune_outlined,
    iconColor: _C.blue,
    title: 'Ajustes de SafeDrive',
    child: Column(children: [
      // Auto trigger
      Padding(padding: const EdgeInsets.symmetric(horizontal: _C.s16, vertical: 4),
        child: Row(children: [
          _IconBox(icon: Icons.alarm_outlined, color: _C.orange),
          const SizedBox(width: _C.s12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Disparo automatico', style: TextStyle(color: _C.t1, fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 2),
            Text('Activa la alarma al detectar somnolencia', style: TextStyle(color: _C.t2, fontSize: 12)),
          ])),
          Switch(value: _autoTrigger, onChanged: (v) => setState(() => _autoTrigger = v),
            activeThumbColor: _C.brand, activeTrackColor: _C.brandGlow,
            inactiveThumbColor: _C.t2, inactiveTrackColor: _C.border),
        ])),
      const _SDivider(),
      // Sensitivity
      Padding(padding: const EdgeInsets.fromLTRB(_C.s16, _C.s12, _C.s16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _IconBox(icon: Icons.sensors_outlined, color: _C.blue),
            const SizedBox(width: _C.s12),
            const Text('Sensibilidad del sensor', style: TextStyle(color: _C.t1, fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _C.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('$_sensitivityLabel (${_sensitivity.toInt()})',
                style: const TextStyle(color: _C.blue, fontSize: 11, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          SliderTheme(data: SliderTheme.of(context).copyWith(
            activeTrackColor: _C.blue, inactiveTrackColor: _C.border,
            thumbColor: _C.blue, overlayColor: _C.blue.withValues(alpha: 0.12),
            valueIndicatorColor: _C.surfaceHi,
            valueIndicatorTextStyle: const TextStyle(color: _C.t1),
            trackHeight: 3,
          ), child: Slider(value: _sensitivity, min: 1, max: 10, divisions: 9,
            label: _sensitivity.toInt().toString(), onChanged: (v) => setState(() => _sensitivity = v))),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Menos sensible', style: TextStyle(color: _C.t2, fontSize: 11)),
            Text('Muy sensible', style: TextStyle(color: _C.t2, fontSize: 11)),
          ]),
        ])),
    ]),
  );

  Widget _saveBtn() => GestureDetector(
    onTap: _isSaving ? null : _save,
    child: AnimatedContainer(duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        gradient: _isSaving ? null : const LinearGradient(colors: [_C.brand, _C.brandDim], begin: Alignment.topLeft, end: Alignment.bottomRight),
        color: _isSaving ? _C.surface : null,
        borderRadius: BorderRadius.circular(_C.r20),
        border: _isSaving ? Border.all(color: _C.border) : null,
        boxShadow: _isSaving ? null : const [BoxShadow(color: Color(0x4800C472), blurRadius: 24, spreadRadius: -4, offset: Offset(0, 8))],
      ),
      child: Center(child: _isSaving
        ? const Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _C.brand, strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Guardando...', style: TextStyle(color: _C.t2, fontSize: 15, fontWeight: FontWeight.w600)),
          ])
        : const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Guardar cambios', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.1)),
          ])),
    ),
  );

  Widget _logoutBtn() => GestureDetector(
    onTap: _logout,
    child: Container(height: 56,
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(_C.r20),
        border: Border.all(color: _C.red.withValues(alpha: 0.3))),
      child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.logout_rounded, color: _C.red, size: 20),
        SizedBox(width: 8),
        Text('Cerrar sesion', style: TextStyle(color: _C.red, fontSize: 15, fontWeight: FontWeight.w600)),
      ])),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  final String name, email;
  final String? avatar;
  const _ProfileHeader({required this.name, required this.email, this.avatar});

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;
    return Container(
      margin: const EdgeInsets.fromLTRB(_C.s16, _C.s20, _C.s16, 0),
      padding: const EdgeInsets.all(_C.s20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF06231B), Color(0xFF041510)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(_C.r20),
        border: Border.all(color: const Color(0x3300C472)),
        boxShadow: const [BoxShadow(color: Color(0x1200C472), blurRadius: 24, spreadRadius: -4, offset: Offset(0, 6))],
      ),
      child: Row(children: [
        Container(width: 66, height: 66,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _C.brand, width: 2.5), color: const Color(0xFF06231B)),
          child: ClipOval(child: avatar != null
            ? Image.network(avatar!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _fallback(firstName))
            : _fallback(firstName))),
        const SizedBox(width: _C.s16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: _C.t1, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(email, style: const TextStyle(color: _C.t2, fontSize: 12), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _C.brandGlow, borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_outlined, color: _C.brand, size: 11),
              SizedBox(width: 4),
              Text('Cuenta activa', style: TextStyle(color: _C.brand, fontSize: 10, fontWeight: FontWeight.w600)),
            ])),
        ])),
      ]),
    );
  }

  Widget _fallback(String first) => Center(child: Text(first.isNotEmpty ? first[0].toUpperCase() : 'U',
      style: const TextStyle(color: _C.brand, fontSize: 24, fontWeight: FontWeight.w700)));
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  const _Section({required this.icon, required this.iconColor, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(_C.r8)),
          child: Icon(icon, color: iconColor, size: 14)),
        const SizedBox(width: _C.s8),
        Text(title, style: const TextStyle(color: _C.t1, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1)),
      ]),
      const SizedBox(height: _C.s12),
      Container(decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(_C.r20), border: Border.all(color: _C.border)),
        child: child),
    ]);
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBox({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(width: 32, height: 32,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(_C.r8)),
    child: Icon(icon, color: color, size: 16));
}

class _SDivider extends StatelessWidget {
  const _SDivider();
  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: _C.border, indent: 16, endIndent: 16);
}

class _LogoutDialog extends StatelessWidget {
  final VoidCallback onConfirm, onCancel;
  const _LogoutDialog({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _C.surfaceHi,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_C.r20), side: const BorderSide(color: _C.border)),
      title: const Text('Cerrar sesion', style: TextStyle(color: _C.t1, fontWeight: FontWeight.w700, fontSize: 17)),
      content: const Text('Tu sesion se cerrara. Deberas iniciar sesion nuevamente para continuar.',
          style: TextStyle(color: _C.t2, fontSize: 14, height: 1.5)),
      actions: [
        TextButton(onPressed: onCancel, child: const Text('Cancelar', style: TextStyle(color: _C.t2, fontWeight: FontWeight.w500))),
        TextButton(onPressed: onConfirm, child: const Text('Cerrar sesion', style: TextStyle(color: _C.red, fontWeight: FontWeight.w600))),
      ],
    );
  }
}
