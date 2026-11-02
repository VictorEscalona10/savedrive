package com.example.safedrive

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "safedrive/alert"
    private var toneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            toneGenerator = ToneGenerator(AudioManager.STREAM_ALARM, 100)
        } catch (_: Exception) {
            try {
                toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
            } catch (_: Exception) {}
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "playAlarmCue" -> {
                    try {
                        toneGenerator?.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 400)
                    } catch (_: Exception) {
                        try {
                            toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP2, 400)
                        } catch (_: Exception) {}
                    }

                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                            vibratorManager?.defaultVibrator?.vibrate(
                                VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator?.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator?.vibrate(400)
                            }
                        }
                    } catch (_: Exception) {}

                    result.success(true)
                }
                "stopAlarm" -> {
                    try {
                        toneGenerator?.stopTone()
                    } catch (_: Exception) {}
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                            vibratorManager?.defaultVibrator?.cancel()
                        } else {
                            @Suppress("DEPRECATION")
                            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                            vibrator?.cancel()
                        }
                    } catch (_: Exception) {}
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
