import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:safedrive/core/constants/map_config.dart';

class LocationTelemetry {
  final LatLng position;
  final double speedKmh;
  final double heading;
  final double accuracy;
  final DateTime timestamp;

  const LocationTelemetry({
    required this.position,
    required this.speedKmh,
    required this.heading,
    required this.accuracy,
    required this.timestamp,
  });

  static LocationTelemetry fallback() {
    return LocationTelemetry(
      position: MapConfig.defaultLocation,
      speedKmh: 0.0,
      heading: 0.0,
      accuracy: 0.0,
      timestamp: DateTime.now(),
    );
  }
}

class LocationService {
  static final LocationService instance = LocationService._internal();
  LocationService._internal();

  StreamSubscription<Position>? _positionSubscription;
  final _telemetryController = StreamController<LocationTelemetry>.broadcast();

  Stream<LocationTelemetry> get telemetryStream => _telemetryController.stream;

  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Servicios de ubicación deshabilitados');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<LocationTelemetry> getCurrentTelemetry() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return LocationTelemetry.fallback();

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      final speedKmh = (pos.speed.clamp(0.0, 300.0)) * 3.6; // m/s a km/h
      return LocationTelemetry(
        position: LatLng(pos.latitude, pos.longitude),
        speedKmh: speedKmh,
        heading: pos.heading,
        accuracy: pos.accuracy,
        timestamp: pos.timestamp,
      );
    } catch (e) {
      debugPrint('Aviso al obtener ubicación actual: $e');
      return LocationTelemetry.fallback();
    }
  }

  void startTracking({ValueChanged<LocationTelemetry>? onUpdate}) {
    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2, // Actualizar cada 2 metros
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (pos) {
        final speedKmh = (pos.speed.clamp(0.0, 300.0)) * 3.6;
        final telemetry = LocationTelemetry(
          position: LatLng(pos.latitude, pos.longitude),
          speedKmh: speedKmh,
          heading: pos.heading,
          accuracy: pos.accuracy,
          timestamp: pos.timestamp,
        );
        _telemetryController.add(telemetry);
        onUpdate?.call(telemetry);
      },
      onError: (e) {
        debugPrint('Error en stream de GPS: $e');
      },
    );
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
