import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camera/camera.dart';
import 'package:safedrive/presentation/screens/camera/calibration_screen.dart';

class _C {
  static const bg = Color(0xFF0A0D12);
  static const surface = Color(0xFF141920);
  static const brand = Color(0xFF00C472);
  static const brandDim = Color(0xFF009558);
  static const brandGlow = Color(0x2200C472);
  static const blue = Color(0xFF3D8EFF);
  static const orange = Color(0xFFFF9F3D);
  static const red = Color(0xFFFF5252);
  static const t1 = Color(0xFFECF0F5);
  static const t2 = Color(0xFF8693A4);
  static const border = Color(0xFF1E2736);
  static const r8 = 8.0;
  static const r12 = 12.0;
  static const r16 = 16.0;
  static const r20 = 20.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
}

class _Tip {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Tip(this.icon, this.color, this.title, this.body);
}

const _kTips = <_Tip>[
  _Tip(
    Icons.coffee_outlined,
    _C.orange,
    'Toma descansos',
    'Detente cada 2 h. La fatiga reduce reflejos hasta un 50 %.',
  ),
  _Tip(
    Icons.phone_iphone_outlined,
    _C.red,
    'Evita el telefono',
    'El movil cuadruplica el riesgo de accidente.',
  ),
  _Tip(
    Icons.air_outlined,
    _C.blue,
    'Ventila el auto',
    'El CO2 acumulado provoca somnolencia en minutos.',
  ),
  _Tip(
    Icons.remove_red_eye_outlined,
    _C.brand,
    'Descansa los ojos',
    'Regla 20-20-20: mira lejos 20 s cada 20 min.',
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _supa = Supabase.instance.client;
  String _nombre = 'Usuario';
  String? _avatarUrl;
  bool _loadingStats = true;
  int _trips = 0, _alerts = 0, _score = 0;

  late AnimationController _fadeCtrl, _pulseCtrl;
  late Animation<double> _fadeAnim, _pulseScale;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _pulseScale = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fadeCtrl.forward();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
      return;
    }

    final meta = user.userMetadata;
    final fallback = user.email?.split('@').first ?? 'Usuario';
    final initialName =
        (meta?['full_name'] as String?) ??
        (meta?['name'] as String?) ??
        fallback;
    final initialAvatar =
        (meta?['avatar_url'] as String?) ?? (meta?['picture'] as String?);

    if (mounted) {
      setState(() {
        _nombre = initialName;
        _avatarUrl = initialAvatar;
      });
    }

    String fullName = initialName;
    try {
      final row = await _supa.from('users').select().eq('id', user.id).single();
      final dbName = row['full_name'] as String?;
      if (dbName != null && dbName.isNotEmpty) {
        fullName = dbName;
      }
    } catch (e) {
      debugPrint('No se pudo cargar el perfil de la base de datos: $e');
    }

    int trips = 0;
    int alerts = 0;
    int score = 100;
    try {
      final rows =
          await _supa.from('trips').select().eq('user_id', user.id) as List;
      trips = rows.length;
      for (final r in rows) {
        alerts += ((r['alert_count'] ?? 0) as num).toInt();
      }
      if (trips > 0) {
        score = (100 - (alerts / trips * 10).clamp(0.0, 100.0)).round();
      }
    } catch (e) {
      debugPrint('No se pudieron cargar viajes: $e');
    }

    if (mounted) {
      setState(() {
        _nombre = fullName;
        _trips = trips;
        _alerts = alerts;
        _score = score;
        _loadingStats = false;
      });
    }
  }

  Future<void> _iniciarViaje() async {
    HapticFeedback.mediumImpact();
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CalibrationScreen(frontCamera: front),
          transitionsBuilder: (context, anim, secondaryAnim, child) =>
              FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error camara: $e'), backgroundColor: _C.red),
      );
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos dias';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String get _firstName => _nombre.split(' ').first;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 88.0;
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _headerSlide,
                  child: _header(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: _C.s16),
                sliver: SliverToBoxAdapter(child: _statusCard()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_C.s16, _C.s16, _C.s16, 0),
                sliver: SliverToBoxAdapter(child: _stats()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_C.s16, _C.s24, _C.s16, 0),
                sliver: SliverToBoxAdapter(child: _detection()),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: _C.s24),
                sliver: SliverToBoxAdapter(child: _tips()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_C.s16, _C.s24, _C.s16, 0),
                sliver: SliverToBoxAdapter(child: _startBtn()),
              ),
              SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_C.s20, _C.s20, _C.s20, _C.s16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => HapticFeedback.selectionClick(),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _C.brand, width: 2),
                color: _C.surface,
              ),
              child: ClipOval(
                child: _avatarUrl != null
                    ? Image.network(
                        _avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _fallback(),
                      )
                    : _fallback(),
              ),
            ),
          ),
          const SizedBox(width: _C.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: const TextStyle(
                    color: _C.t2,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _firstName,
                  style: const TextStyle(
                    color: _C.t1,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Material(
            color: _C.surface,
            borderRadius: BorderRadius.circular(_C.r12),
            child: InkWell(
              borderRadius: BorderRadius.circular(_C.r12),
              onTap: () => HapticFeedback.selectionClick(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.notifications_none_outlined,
                  color: _C.t2,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() => Center(
    child: Text(
      _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'U',
      style: const TextStyle(
        color: _C.brand,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _statusCard() => Container(
    padding: const EdgeInsets.all(_C.s20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF06231B), Color(0xFF041510)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(_C.r20),
      border: Border.all(color: const Color(0x3300C472)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1500C472),
          blurRadius: 32,
          spreadRadius: -4,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        ScaleTransition(
          scale: _pulseScale,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.brandGlow,
              border: Border.all(color: const Color(0x5900C472), width: 1.5),
            ),
            child: const Icon(Icons.shield_outlined, color: _C.brand, size: 26),
          ),
        ),
        const SizedBox(width: _C.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.brandGlow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'SISTEMA LISTO',
                  style: TextStyle(
                    color: _C.brand,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'SafeDrive activo',
                style: TextStyle(
                  color: _C.t1,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'IA de monitoreo lista para protegerte',
                style: TextStyle(color: _C.t2, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _stats() {
    final v = _loadingStats ? '-' : null;
    return Row(
      children: [
        _StatCard(
          icon: Icons.route_outlined,
          color: _C.blue,
          label: 'Viajes',
          value: v ?? '$_trips',
        ),
        const SizedBox(width: _C.s8),
        _StatCard(
          icon: Icons.warning_amber_outlined,
          color: _C.orange,
          label: 'Alertas',
          value: v ?? '$_alerts',
        ),
        const SizedBox(width: _C.s8),
        _StatCard(
          icon: Icons.star_border_rounded,
          color: _C.brand,
          label: 'Score',
          value: v ?? '$_score',
        ),
      ],
    );
  }

  Widget _detection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionTitle('Monitoreo en tiempo real'),
      const SizedBox(height: _C.s12),
      _DetCard(
        icon: Icons.remove_red_eye_outlined,
        color: _C.red,
        title: 'Deteccion de somnolencia',
        sub: 'Analiza el EAR de tus ojos en cada fotograma.',
      ),
      const SizedBox(height: _C.s8),
      _DetCard(
        icon: Icons.face_outlined,
        color: _C.orange,
        title: 'Inclinacion de cabeza',
        sub: 'Detecta cabeceo por angulo Euler (headEulerAngleX).',
      ),
      const SizedBox(height: _C.s8),
      _DetCard(
        icon: Icons.visibility_off_outlined,
        color: _C.blue,
        title: 'Distraccion visual',
        sub: 'Monitoreo continuo aunque uses lentes de sol.',
      ),
    ],
  );

  Widget _tips() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: _C.s16),
        child: _SectionTitle('Tips de seguridad'),
      ),
      const SizedBox(height: _C.s12),
      SizedBox(
        height: 148,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: _C.s16),
          physics: const BouncingScrollPhysics(),
          itemCount: _kTips.length,
          separatorBuilder: (context, index) => const SizedBox(width: _C.s8),
          itemBuilder: (context, i) => _TipCard(tip: _kTips[i]),
        ),
      ),
    ],
  );

  Widget _startBtn() => GestureDetector(
    onTap: _iniciarViaje,
    child: Container(
      height: 62,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.brand, _C.brandDim],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_C.r20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4800C472),
            blurRadius: 28,
            spreadRadius: -6,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: _C.s20),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: _C.s12),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Iniciar viaje',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Calibracion facial requerida',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: _C.s20),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _C.t1,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
  );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(_C.r16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(_C.r8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _C.t1,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _C.t2, fontSize: 11)),
        ],
      ),
    ),
  );
}

class _DetCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, sub;
  const _DetCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(_C.s16),
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(_C.r16),
      border: Border.all(color: _C.border),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(_C.r12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: _C.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _C.t1,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(sub, style: const TextStyle(color: _C.t2, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: _C.s8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _C.brandGlow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Activo',
            style: TextStyle(
              color: _C.brand,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TipCard extends StatelessWidget {
  final _Tip tip;
  const _TipCard({required this.tip});
  @override
  Widget build(BuildContext context) => Container(
    width: 178,
    padding: const EdgeInsets.all(_C.s16),
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(_C.r16),
      border: Border.all(color: _C.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tip.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(_C.r8),
          ),
          child: Icon(tip.icon, color: tip.color, size: 18),
        ),
        const SizedBox(height: _C.s8),
        Text(
          tip.title,
          style: const TextStyle(
            color: _C.t1,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Text(
            tip.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _C.t2, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    ),
  );
}
