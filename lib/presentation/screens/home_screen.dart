import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safedrive/presentation/screens/camera/calibration_screen.dart';
import 'package:safedrive/core/theme/theme_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _supa = Supabase.instance.client;
  String _nombre = 'Conductor';
  String? _avatarUrl;
  bool _loadingStats = true;
  int _trips = 0;
  int _alerts = 0;
  int _score = 100;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final List<Map<String, dynamic>> _quickTips = [
    {
      'icon': Icons.remove_red_eye_outlined,
      'color': AppColors.brand,
      'title': 'Regla 20-20-20',
      'body': 'Parpadea regularmente y mantén la vista relajada en trayectos largos.',
    },
    {
      'icon': Icons.local_cafe_outlined,
      'color': AppColors.orange,
      'title': 'Pausa cada 2 horas',
      'body': 'Hacer paradas cortas restaura tus reflejos hasta en un 40%.',
    },
    {
      'icon': Icons.air_outlined,
      'color': AppColors.cyan,
      'title': 'Buena ventilación',
      'body': 'El aire fresco y una temperatura adecuada previenen la somnolencia.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingStats = false);
      return;
    }

    final meta = user.userMetadata;
    final fallback = user.email?.split('@').first ?? 'Conductor';
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
      debugPrint('No se pudo cargar perfil de users: $e');
    }

    int trips = 0;
    int alerts = 0;
    int score = 100;
    try {
      final rows = await _supa.from('trips').select().eq('user_id', user.id) as List;
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
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permiso de cámara requerido para monitoreo facial.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

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
          pageBuilder: (context, anim, secAnim) => CalibrationScreen(frontCamera: front),
          transitionsBuilder: (context, anim, secAnim, child) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 320),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar cámara: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Buenos días';
    if (h >= 12 && h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String get _firstName => _nombre.split(' ').first;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 92.0;

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(isDark),
          body: SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                color: AppColors.brand,
                backgroundColor: AppColors.card(isDark),
                onRefresh: _loadData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(isDark)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 12),
                          _buildHeroActionCard(isDark),
                          const SizedBox(height: 20),
                          _buildTelemetryStats(isDark),
                          const SizedBox(height: 22),
                          _buildActiveSensors(isDark),
                          const SizedBox(height: 22),
                          _buildSafetyTips(isDark),
                          SizedBox(height: bottomPad),
                        ]),
                      ),
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

  // ---------------------------------------------------------------------------
  // 1. Sleek Header with Theme Switcher
  // ---------------------------------------------------------------------------
  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brand.withValues(alpha: 0.8), width: 1.5),
              color: AppColors.cardSecondary(isDark),
            ),
            child: ClipOval(
              child: _avatarUrl != null
                  ? Image.network(
                      _avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _greeting,
                  style: TextStyle(
                    color: AppColors.t3(isDark),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _firstName,
                  style: TextStyle(
                    color: AppColors.t1(isDark),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Botón selector de Modo Día / Modo Noche
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: ThemeService.toggleTheme,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.card(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border(isDark)),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? const Color(0x1A000000) : const Color(0x0A000000),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                    key: ValueKey<bool>(isDark),
                    color: isDark ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Center(
        child: Text(
          _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: AppColors.brand,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  // ---------------------------------------------------------------------------
  // 2. Hero Action Launcher (Iniciar Viaje)
  // ---------------------------------------------------------------------------
  Widget _buildHeroActionCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight(isDark)),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF131C2A), Color(0xFF0F1521)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x1F000000) : const Color(0x0F000000),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _iniciarViaje,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brand, AppColors.brandDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4000C472),
                        blurRadius: 16,
                        spreadRadius: -2,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Iniciar Viaje',
                        style: TextStyle(
                          color: AppColors.t1(isDark),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Monitoreo y detección en tiempo real',
                        style: TextStyle(
                          color: AppColors.t2(isDark),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.cardSecondary(isDark),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border(isDark)),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.brand,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Telemetry Stats Row
  // ---------------------------------------------------------------------------
  Widget _buildTelemetryStats(bool isDark) {
    final vScore = _loadingStats ? '-' : '$_score%';
    final vTrips = _loadingStats ? '-' : '$_trips';
    final vAlerts = _loadingStats ? '-' : '$_alerts';

    return Row(
      children: [
        _buildStatTile(
          label: 'Score',
          value: vScore,
          icon: Icons.shield_outlined,
          color: AppColors.brand,
          subtext: _score >= 85 ? 'Óptimo' : 'Atención',
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _buildStatTile(
          label: 'Viajes',
          value: vTrips,
          icon: Icons.route_outlined,
          color: AppColors.blue,
          subtext: 'Completados',
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _buildStatTile(
          label: 'Alertas',
          value: vAlerts,
          icon: Icons.notifications_active_outlined,
          color: _alerts == 0 ? AppColors.cyan : AppColors.orange,
          subtext: 'Registradas',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String subtext,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(isDark)),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x14000000) : const Color(0x08000000),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.t3(isDark),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(icon, color: color, size: 15),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: AppColors.t1(isDark),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtext,
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Compact Active Sensors Module
  // ---------------------------------------------------------------------------
  Widget _buildActiveSensors(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SISTEMA DE SEGURIDAD',
          style: TextStyle(
            color: AppColors.t3(isDark),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border(isDark)),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0x14000000) : const Color(0x08000000),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSensorRow(
                icon: Icons.remove_red_eye_outlined,
                title: 'Detección EAR Ocular',
                desc: 'Análisis de parpadeo y microsueños',
                color: AppColors.brand,
                isDark: isDark,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: AppColors.border(isDark).withValues(alpha: 0.5), height: 1),
              ),
              _buildSensorRow(
                icon: Icons.face_retouching_natural_outlined,
                title: 'Postura & Cabeceo',
                desc: 'Ángulo Euler X/Y y cabeceo involuntario',
                color: AppColors.blue,
                isDark: isDark,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: AppColors.border(isDark).withValues(alpha: 0.5), height: 1),
              ),
              _buildSensorRow(
                icon: Icons.warning_amber_rounded,
                title: 'Alerta Sonora & Háptica',
                desc: 'Disparo de advertencia instantánea',
                color: AppColors.cyan,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorRow({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.t1(isDark),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  color: AppColors.t3(isDark),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Minimalist Safety Insights Carousel
  // ---------------------------------------------------------------------------
  Widget _buildSafetyTips(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECOMENDACIONES DE CONDUCCIÓN',
          style: TextStyle(
            color: AppColors.t3(isDark),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _quickTips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final tip = _quickTips[i];
              final icon = tip['icon'] as IconData;
              final color = tip['color'] as Color;
              final title = tip['title'] as String;
              final body = tip['body'] as String;

              return Container(
                width: 230,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(isDark)),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? const Color(0x14000000) : const Color(0x08000000),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: AppColors.t1(isDark),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        body,
                        style: TextStyle(
                          color: AppColors.t2(isDark),
                          fontSize: 11,
                          height: 1.35,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
