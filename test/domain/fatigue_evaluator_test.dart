import 'package:flutter_test/flutter_test.dart';
import 'package:safedrive/domain/monitoring/fatigue_evaluator.dart';

void main() {
  group('FatigueEvaluator - Lógica pura y modo de prueba', () {
    test('Con ignoreSpeedLimit=false y velocidad < 10 km/h, silencia alertas a pesar de ojos cerrados', () {
      final evaluator = FatigueEvaluator(
        baselineEar: 0.75,
        baselineHeadAngle: 0.0,
        alarmToleranceSeconds: 1,
        ignoreSpeedLimit: false,
      );

      final result = evaluator.evaluate(
        currentEar: 0.2, // Caída fuerte > 35%
        currentHeadAngleY: 0.0,
        currentSpeedKmh: 0.0,
        isFaceDetected: true,
      );

      expect(result.isSilencedByTraffic, isTrue);
      expect(result.state, equals(MonitoringState.normal));
    });

    test('Con ignoreSpeedLimit=true y velocidad 0.0 km/h, NO silencia por tráfico', () {
      final evaluator = FatigueEvaluator(
        baselineEar: 0.75,
        baselineHeadAngle: 0.0,
        alarmToleranceSeconds: 1,
        ignoreSpeedLimit: true,
      );

      final result = evaluator.evaluate(
        currentEar: 0.2,
        currentHeadAngleY: 0.0,
        currentSpeedKmh: 0.0,
        isFaceDetected: true,
      );

      expect(result.isSilencedByTraffic, isFalse);
      expect(result.isDrowsy, isTrue);
      expect(result.state, equals(MonitoringState.gracePeriod));
    });

    test('isFaceDetected=false se evalúa como pérdida de atención y genera alerta tras la tolerancia', () async {
      final evaluator = FatigueEvaluator(
        baselineEar: 0.75,
        baselineHeadAngle: 0.0,
        alarmToleranceSeconds: 1,
        ignoreSpeedLimit: true,
      );

      // Primer frame sin rostro: entra en ventana de gracia (1 s)
      final r1 = evaluator.evaluate(
        currentEar: 0.0,
        currentHeadAngleY: 0.0,
        currentSpeedKmh: 0.0,
        isFaceDetected: false,
      );
      expect(r1.state, equals(MonitoringState.gracePeriod));
      expect(r1.isDistracted, isTrue);

      // Esperar que transcurra más de 1 segundo
      await Future.delayed(const Duration(milliseconds: 1100));

      // Segundo frame sin rostro: pasa a alertWarning con mensaje '¡ROSTRO NO DETECTADO!'
      final r2 = evaluator.evaluate(
        currentEar: 0.0,
        currentHeadAngleY: 0.0,
        currentSpeedKmh: 0.0,
        isFaceDetected: false,
      );
      expect(r2.state, equals(MonitoringState.alertWarning));
      expect(r2.statusMessage, equals('¡ROSTRO NO DETECTADO!'));
    });

    test('Ojos cerrados con ignoreSpeedLimit=true dispara alertWarning tras 1 segundo con mensaje de somnolencia', () async {
      final evaluator = FatigueEvaluator(
        baselineEar: 0.75,
        baselineHeadAngle: 0.0,
        alarmToleranceSeconds: 1,
        ignoreSpeedLimit: true,
      );

      final r1 = evaluator.evaluate(
        currentEar: 0.2, // Caída relativa > 35%
        currentHeadAngleY: 0.0,
        currentSpeedKmh: 0.0,
        isFaceDetected: true,
      );
      expect(r1.state, equals(MonitoringState.gracePeriod));
      expect(r1.isDrowsy, isTrue);

      await Future.delayed(const Duration(milliseconds: 1100));

      final r2 = evaluator.evaluate(
        currentEar: 0.2,
        currentHeadAngleY: 0.0,
        currentSpeedKmh: 0.0,
        isFaceDetected: true,
      );
      expect(r2.state, equals(MonitoringState.alertWarning));
      expect(r2.statusMessage, equals('¡ALERTA DE SOMNOLENCIA!'));
    });

    test('Cabeza desviada dispara alertWarning con mensaje de atención al frente', () async {
      final evaluator = FatigueEvaluator(
        baselineEar: 0.75,
        baselineHeadAngle: 0.0,
        alarmToleranceSeconds: 1,
        ignoreSpeedLimit: true,
      );

      evaluator.evaluate(
        currentEar: 0.75,
        currentHeadAngleY: 25.0, // Desviación > 20°
        currentSpeedKmh: 0.0,
        isFaceDetected: true,
      );

      await Future.delayed(const Duration(milliseconds: 1100));

      final r2 = evaluator.evaluate(
        currentEar: 0.75,
        currentHeadAngleY: 25.0,
        currentSpeedKmh: 0.0,
        isFaceDetected: true,
      );
      expect(r2.state, equals(MonitoringState.alertWarning));
      expect(r2.statusMessage, equals('¡ATENCIÓN AL FRENTE!'));
    });

    test('Recuperar atención resetea inmediatamente a MonitoringState.normal', () async {
      final evaluator = FatigueEvaluator(
        baselineEar: 0.75,
        baselineHeadAngle: 0.0,
        alarmToleranceSeconds: 1,
        ignoreSpeedLimit: true,
      );

      evaluator.evaluate(
        currentEar: 0.2,
        currentHeadAngleY: 0.0,
        currentSpeedKmh: 0.0,
        isFaceDetected: true,
      );

      await Future.delayed(const Duration(milliseconds: 1100));

      final rAlert = evaluator.evaluate(
        currentEar: 0.2,
        currentHeadAngleY: 0.0,
        currentSpeedKmh: 0.0,
        isFaceDetected: true,
      );
      expect(rAlert.state, equals(MonitoringState.alertWarning));

      // Recupera atención: ojos abiertos y rostro centrado
      final rNormal = evaluator.evaluate(
        currentEar: 0.75,
        currentHeadAngleY: 0.0,
        currentSpeedKmh: 0.0,
        isFaceDetected: true,
      );
      expect(rNormal.state, equals(MonitoringState.normal));
      expect(rNormal.isDrowsy, isFalse);
      expect(rNormal.isDistracted, isFalse);
      expect(rNormal.statusMessage, equals('Atención al camino'));
    });
  });
}

