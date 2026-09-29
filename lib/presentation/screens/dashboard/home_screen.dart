import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safedrive/core/theme/theme_service.dart';
import 'package:safedrive/core/constants/map_config.dart';
import 'package:safedrive/core/services/location_service.dart';
import 'package:safedrive/core/services/snackbar_service.dart';
import 'package:safedrive/data/models/user_model.dart';
import 'package:safedrive/data/models/user_settings_model.dart';
import 'package:safedrive/data/repositories/user_repository.dart';
import 'package:safedrive/data/repositories/settings_repository.dart';
import 'package:safedrive/presentation/components/cards/app_card.dart';
import 'package:safedrive/presentation/components/cards/app_section.dart';
import 'package:safedrive/presentation/components/cards/stat_tile.dart';
import 'package:safedrive/presentation/components/common/user_avatar.dart';
import 'package:safedrive/presentation/components/common/theme_toggle_button.dart';
import 'package:safedrive/presentation/components/maps/free_drive_map_widget.dart';
import 'package:safedrive/presentation/screens/camera/calibration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _userRepo = UserRepository();
  final _settingsRepo = SettingsRepository();
  final _locationService = LocationService.instance;

  UserModel? _user;
  UserSettingsModel? _settings;
  bool _isLoading = true;

  LatLng _currentLocation = MapConfig.defaultLocation;
  double _currentSpeedKmh = 0.0;
  double _currentHeading = 0.0;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final List<Map<String, dynamic>> _quickTips = const [
    {
      'icon': Icons.remove_red_eye_outlined,
      'color': AppColors.brand,
      'title': 'Descanso visual 20-20-20',
      'body': 'Parpadea con frecuencia y mira a lo lejos para relajar la vista.',
    },
    {
      'icon': Icons.local_cafe_outlined,
      'color': AppColors.orange,
      'title': 'Pausa cada 2 horas',
      'body': 'Hacer una pausa breve recupera tus reflejos y concentración.',
    },
    {
      'icon': Icons.air_outlined,
      'color': AppColors.cyan,
      'title': 'Ventilación en cabina',
      'body': 'Mantén aire fresco circulando para evitar la fatiga por somnolencia.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadData();
    _startLocation();
  }

  Future<void> _loadData() async {
    try {
      final user = await _userRepo.getCurrentUserProfile();
      final settings = await _settingsRepo.getUserSettings();

      if (mounted) {
        setState(() {
          _user = user;
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos del dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startLocation() {
    _locationService.startTracking(
      onUpdate: (telemetry) {
        if (!mounted) return;
        setState(() {
          _currentLocation = telemetry.position;
          _currentSpeedKmh = telemetry.speedKmh;
          _currentHeading = telemetry.heading;
        });
      },
    );
  }

  Future<void> _iniciarViaje() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      SnackBarService.showError(
        context,
        'Permiso de cámara requerido para monitoreo activo.',
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
          pageBuilder: (context, anim, secAnim) =>
              CalibrationScreen(frontCamera: front),
          transitionsBuilder: (context, anim, secAnim, child) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 320),
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      SnackBarService.showError(context, 'Error al iniciar cámara: $e');
    }
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Buenos días';
    if (h >= 12 && h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String get _displayName {
    if (_user?.fullName != null && _user!.fullName!.isNotEmpty) {
      return _user!.fullName!.split(' ').first;
    }
    return _user?.email.split('@').first ?? 'Conductor';
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
                          const SizedBox(height: 14),
                          _buildHeroActionCard(isDark),
                          const SizedBox(height: 24),
                          _buildTelemetryStats(isDark),
                          const SizedBox(height: 28),
                          _buildMapPreviewSection(isDark),
                          const SizedBox(height: 28),
                          _buildActiveSensors(isDark),
                          const SizedBox(height: 28),
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

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          UserAvatar(
            name: _displayName,
            size: 50,
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
                    color: AppColors.t2(isDark),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _displayName,
                  style: TextStyle(
                    color: AppColors.t1(isDark),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const ThemeToggleButton(),
        ],
      ),
    );
  }

  Widget _buildHeroActionCard(bool isDark) {
    return AppCard(
      onTap: _iniciarViaje,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      gradient: isDark
          ? const LinearGradient(
              colors: [Color(0xFF131D2E), Color(0xFF0F1622)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brand, AppColors.brandDim],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4000C472),
                  blurRadius: 18,
                  spreadRadius: -2,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Iniciar Monitoreo',
                  style: TextStyle(
                    color: AppColors.t1(isDark),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Calibración Fantasma & Cámara Frontal',
                  style: TextStyle(
                    color: AppColors.t2(isDark),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.cardSecondary(isDark),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border(isDark)),
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.brand,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryStats(bool isDark) {
    final tolerance = _settings?.alarmToleranceSeconds ?? 3;
    final hasBaseline = _settings?.baselineEar != null;
    final autoTrigger = _settings?.autoTriggerEnabled ?? true;

    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: 'Cero Relativo',
            value: _isLoading ? '-' : (hasBaseline ? 'Calibrado' : 'Pendiente'),
            icon: Icons.face_retouching_natural_rounded,
            color: hasBaseline ? AppColors.brand : AppColors.orange,
            subtext: hasBaseline ? 'EAR Guardado' : 'Iniciar Viaje',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatTile(
            label: 'Tolerancia',
            value: '${tolerance}s',
            icon: Icons.timer_outlined,
            color: AppColors.blue,
            subtext: 'Tiempo Gracia',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatTile(
            label: 'Auto-Start',
            value: autoTrigger ? 'Activo' : 'Manual',
            icon: Icons.speed_rounded,
            color: autoTrigger ? AppColors.cyan : AppColors.t3(isDark),
            subtext: '> 20 km/h',
          ),
        ),
      ],
    );
  }

  Widget _buildMapPreviewSection(bool isDark) {
    return AppSection(
      icon: Icons.map_rounded,
      iconColor: AppColors.brand,
      title: 'Free-Drive Map (Tiempo Real)',
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 200,
        child: FreeDriveMapWidget(
          currentPosition: _currentLocation,
          currentSpeedKmh: _currentSpeedKmh,
          currentHeading: _currentHeading,
          initialZoom: 15.5,
        ),
      ),
    );
  }

  Widget _buildActiveSensors(bool isDark) {
    return AppSection(
      icon: Icons.sensors_rounded,
      iconColor: AppColors.brand,
      title: 'Monitoreo y Protocolo SafeDrive',
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _buildSensorRow(
            icon: Icons.remove_red_eye_rounded,
            title: 'Detección Ocular (EAR Anti-Bias)',
            desc: 'Apertura relativa contra el Cero Relativo del conductor',
            color: AppColors.brand,
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              color: AppColors.border(isDark).withValues(alpha: 0.6),
              height: 1,
            ),
          ),
          _buildSensorRow(
            icon: Icons.screen_rotation_rounded,
            title: 'Filtro de Postura (-15° a +15°)',
            desc: 'Acepta solo frames frontales y detecta distracciones',
            color: AppColors.blue,
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              color: AppColors.border(isDark).withValues(alpha: 0.6),
              height: 1,
            ),
          ),
          _buildSensorRow(
            icon: Icons.traffic_rounded,
            title: 'Silenciador de Semáforo (<10 km/h)',
            desc: 'Atenúa alarmas en paradas de tráfico para evitar falsos positivos',
            color: AppColors.cyan,
            isDark: isDark,
          ),
        ],
      ),
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.t1(isDark),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: TextStyle(
                  color: AppColors.t2(isDark),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyTips(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consejos de Seguridad Vial',
          style: TextStyle(
            color: AppColors.t1(isDark),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _quickTips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final tip = _quickTips[i];
              final icon = tip['icon'] as IconData;
              final color = tip['color'] as Color;
              final title = tip['title'] as String;
              final body = tip['body'] as String;

              return Container(
                width: 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card(isDark),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.border(isDark),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? const Color(0x18000000) : const Color(0x08000000),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: AppColors.t1(isDark),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(
                        body,
                        style: TextStyle(
                          color: AppColors.t2(isDark),
                          fontSize: 13,
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
