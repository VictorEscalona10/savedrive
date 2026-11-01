import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:safedrive/core/constants/map_config.dart';
import 'package:safedrive/core/theme/theme_service.dart';

class FreeDriveMapWidget extends StatefulWidget {
  final LatLng currentPosition;
  final double currentSpeedKmh;
  final double currentHeading;
  final bool showSpeedBadge;
  final bool isInteractive;
  final double initialZoom;
  final VoidCallback? onRecenter;

  const FreeDriveMapWidget({
    super.key,
    required this.currentPosition,
    this.currentSpeedKmh = 0.0,
    this.currentHeading = 0.0,
    this.showSpeedBadge = true,
    this.isInteractive = true,
    this.initialZoom = MapConfig.defaultZoom,
    this.onRecenter,
  });

  @override
  State<FreeDriveMapWidget> createState() => _FreeDriveMapWidgetState();
}

class _FreeDriveMapWidgetState extends State<FreeDriveMapWidget> {
  late final MapController _mapController;
  bool _isFollowingUser = true;

  // Filtro de matriz de color para transformar OpenStreetMap en Dark Mode Obsidian
  static const ColorFilter _darkColorFilter = ColorFilter.matrix(<double>[
    -0.85, 0, 0, 0, 255,
    0, -0.85, 0, 0, 255,
    0, 0, -0.85, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant FreeDriveMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition) {
      // Si la ubicación cambió desde la posición por defecto a una posición real,
      // forzar recentrado automático la primera vez
      final wasDefault = oldWidget.currentPosition == MapConfig.defaultLocation;
      final isNowReal = widget.currentPosition != MapConfig.defaultLocation;

      if (wasDefault && isNowReal) {
        _isFollowingUser = true;
      }

      if (_isFollowingUser) {
        _mapController.move(widget.currentPosition, _mapController.camera.zoom);
      }
    }
  }

  void _recenter() {
    HapticFeedback.selectionClick();
    setState(() => _isFollowingUser = true);
    _mapController.move(widget.currentPosition, MapConfig.defaultZoom);
    widget.onRecenter?.call();
  }

  bool get _isDefaultLocation =>
      widget.currentPosition.latitude == MapConfig.defaultLocation.latitude &&
      widget.currentPosition.longitude == MapConfig.defaultLocation.longitude;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.currentPosition,
                  initialZoom: widget.initialZoom,
                  interactionOptions: InteractionOptions(
                    flags: widget.isInteractive
                        ? InteractiveFlag.all
                        : InteractiveFlag.none,
                  ),
                  onPositionChanged: (camera, hasGesture) {
                    // Si el usuario arrastró o hizo zoom manualmente en el mapa,
                    // pausamos el auto-seguimiento para permitirle explorar libremente
                    if (hasGesture && _isFollowingUser) {
                      setState(() => _isFollowingUser = false);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: MapConfig.osmTileUrl,
                    userAgentPackageName: MapConfig.userAgentPackageName,
                    maxZoom: 19,
                    tileBuilder: (context, tileWidget, tile) {
                      if (isDark) {
                        return ColorFiltered(
                          colorFilter: _darkColorFilter,
                          child: tileWidget,
                        );
                      }
                      return tileWidget;
                    },
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.currentPosition,
                        width: 50,
                        height: 50,
                        child: Transform.rotate(
                          angle: (widget.currentHeading * (3.141592653589793 / 180)),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Halo pulsante de radio
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.brand.withValues(alpha: 0.25),
                                ),
                              ),
                              // Punto de posición con aguja de rumbo
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.brand,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x6600C472),
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.navigation_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Badge de Velocidad en Tiempo Real
              if (widget.showSpeedBadge)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card(isDark).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.border(isDark),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0x33000000)
                              : const Color(0x14000000),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.speed_rounded,
                          color: AppColors.brand,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.currentSpeedKmh.toInt()}',
                          style: TextStyle(
                            color: AppColors.t1(isDark),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'km/h',
                          style: TextStyle(
                            color: AppColors.t2(isDark),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Píldora de búsqueda de señal GPS si aún no hay fix
              if (_isDefaultLocation)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.card(isDark).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border(isDark)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Buscando GPS...',
                          style: TextStyle(
                            color: AppColors.t2(isDark),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Botón de Recentrado y Modo Auto-Follow
              if (widget.isInteractive)
                Positioned(
                  bottom: 14,
                  right: 14,
                  child: Material(
                    color: Colors.transparent,
                    child: _isFollowingUser
                        ? InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _recenter,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.card(isDark).withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.brand.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.brand.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                color: AppColors.brand,
                                size: 18,
                              ),
                            ),
                          )
                        : InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _recenter,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.brand.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.my_location_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Recentrar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
