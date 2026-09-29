import 'package:latlong2/latlong.dart';

abstract final class MapConfig {
  /// URL de tiles estándar 100% libre de OpenStreetMap (Sin API Key ni restricciones)
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// User agent requerido para consumir tiles OSM de forma legal y segura
  static const String userAgentPackageName = 'com.safedrive.app';

  /// Ubicación por defecto si el GPS aún no tiene fix
  static const LatLng defaultLocation = LatLng(10.4806, -66.9036);
  static const double defaultZoom = 16.5;
}
