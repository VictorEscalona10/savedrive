import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:safedrive/core/constants/map_config.dart';

enum LocationServiceStatus {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

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

  Future<LocationServiceStatus> checkStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Servicios de ubicación deshabilitados');
      return LocationServiceStatus.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationServiceStatus.permissionDenied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationServiceStatus.permissionDeniedForever;
    }

    return LocationServiceStatus.ready;
  }

  Future<bool> checkAndRequestPermission() async {
    final status = await checkStatus();
    return status == LocationServiceStatus.ready;
  }

  Future<LocationTelemetry> getCurrentTelemetry() async {
    try {
      final status = await checkStatus();
      if (status != LocationServiceStatus.ready) {
        return LocationTelemetry.fallback();
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
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

  Future<void> startTracking({
    ValueChanged<LocationTelemetry>? onUpdate,
    ValueChanged<LocationServiceStatus>? onStatusChange,
  }) async {
    _positionSubscription?.cancel();

    final status = await checkStatus();
    onStatusChange?.call(status);

    if (status != LocationServiceStatus.ready) {
      debugPrint('LocationService no listo: $status');
      return;
    }

    // 1. Obtener última posición conocida de inmediato para respuesta instantánea (0ms)
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        final speedKmh = (lastPos.speed.clamp(0.0, 300.0)) * 3.6;
        final telemetry = LocationTelemetry(
          position: LatLng(lastPos.latitude, lastPos.longitude),
          speedKmh: speedKmh,
          heading: lastPos.heading,
          accuracy: lastPos.accuracy,
          timestamp: lastPos.timestamp,
        );
        _telemetryController.add(telemetry);
        onUpdate?.call(telemetry);
      }
    } catch (e) {
      debugPrint('Aviso al obtener lastKnownPosition: $e');
    }

    // 2. Obtener posición actual inicial precisa
    try {
      final curPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final speedKmh = (curPos.speed.clamp(0.0, 300.0)) * 3.6;
      final telemetry = LocationTelemetry(
        position: LatLng(curPos.latitude, curPos.longitude),
        speedKmh: speedKmh,
        heading: curPos.heading,
        accuracy: curPos.accuracy,
        timestamp: curPos.timestamp,
      );
      _telemetryController.add(telemetry);
      onUpdate?.call(telemetry);
    } catch (e) {
      debugPrint('Aviso al obtener posición precisa inicial: $e');
    }

    // 3. Stream continuo en tiempo real
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1, // Actualizar cada 1 metro para seguimiento suave
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

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
