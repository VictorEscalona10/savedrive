import 'dart:io';
import 'package:flutter/services.dart';

abstract final class AlertFeedbackService {
  static const MethodChannel _channel = MethodChannel('safedrive/alert');

  static Future<void> playAlert() async {
    // Intenta usar el canal nativo de alarma (ToneGenerator + Vibrator en Android)
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('playAlarmCue');
        return;
      } catch (_) {}
    }
    // Fallback estándar en Flutter
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);
  }

  static Future<void> stopAlert() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stopAlarm');
      } catch (_) {}
    }
  }
}

