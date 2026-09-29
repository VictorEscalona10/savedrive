/// Constantes de la aplicación SafeDrive según CONTEXT.md y esquema Supabase
abstract final class AppConstants {
  // Telemetría
  static const double autoStartSpeedKmh = 20.0;
  static const double trafficLightSilenceSpeedKmh = 10.0;

  // Calibración Fantasma (Ghost Calibration)
  static const int ghostCalibrationFrameQuota = 50;
  static const double maxHeadAngleYDeg = 15.0; // Posture filter: -15° to +15°
  static const double maxHeadAngleXDeg = 15.0;
  static const double maxHeadAngleZDeg = 15.0;
  static const int ghostCalibrationTimeoutSec = 30;

  // Tolerancia y Escalación
  static const int defaultAlarmToleranceSeconds = 3; // Tiempo de gracia
  static const double fatigueDropThresholdPercent = 0.35; // 35% de caída relativa del EAR baseline
  static const double distractionHeadAngleRelativeDeg = 20.0; // Desviación de postura relativa

  // Tablas Supabase
  static const String tableUsers = 'users';
  static const String tableAlarmTypes = 'alarm_types';
  static const String tableUserSettings = 'user_settings';
  static const String tableEmergencyContacts = 'emergency_contacts';
}
