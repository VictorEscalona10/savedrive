class UserSettingsModel {
  final String userId;
  final int? selectedAlarmTypeId;
  final bool autoTriggerEnabled;
  final int alarmToleranceSeconds;
  final double? baselineEar;
  final double? baselineHeadAngle;
  final DateTime? updatedAt;

  const UserSettingsModel({
    required this.userId,
    this.selectedAlarmTypeId,
    this.autoTriggerEnabled = true,
    this.alarmToleranceSeconds = 3,
    this.baselineEar,
    this.baselineHeadAngle,
    this.updatedAt,
  });

  factory UserSettingsModel.fromMap(Map<String, dynamic> map) {
    return UserSettingsModel(
      userId: map['user_id'] as String,
      selectedAlarmTypeId: map['selected_alarm_type_id'] != null
          ? (map['selected_alarm_type_id'] as num).toInt()
          : null,
      autoTriggerEnabled: map['auto_trigger_enabled'] as bool? ?? true,
      alarmToleranceSeconds: map['alarm_tolerance_seconds'] != null
          ? (map['alarm_tolerance_seconds'] as num).toInt()
          : 3,
      baselineEar: map['baseline_ear'] != null
          ? (map['baseline_ear'] as num).toDouble()
          : null,
      baselineHeadAngle: map['baseline_head_angle'] != null
          ? (map['baseline_head_angle'] as num).toDouble()
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'selected_alarm_type_id': selectedAlarmTypeId,
      'auto_trigger_enabled': autoTriggerEnabled,
      'alarm_tolerance_seconds': alarmToleranceSeconds,
      'baseline_ear': baselineEar,
      'baseline_head_angle': baselineHeadAngle,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  UserSettingsModel copyWith({
    int? selectedAlarmTypeId,
    bool? autoTriggerEnabled,
    int? alarmToleranceSeconds,
    double? baselineEar,
    double? baselineHeadAngle,
  }) {
    return UserSettingsModel(
      userId: userId,
      selectedAlarmTypeId: selectedAlarmTypeId ?? this.selectedAlarmTypeId,
      autoTriggerEnabled: autoTriggerEnabled ?? this.autoTriggerEnabled,
      alarmToleranceSeconds: alarmToleranceSeconds ?? this.alarmToleranceSeconds,
      baselineEar: baselineEar ?? this.baselineEar,
      baselineHeadAngle: baselineHeadAngle ?? this.baselineHeadAngle,
      updatedAt: DateTime.now(),
    );
  }
}
