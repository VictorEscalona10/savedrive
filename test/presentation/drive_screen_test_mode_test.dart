import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safedrive/core/services/test_mode_controller.dart';
import 'package:safedrive/presentation/screens/camera/drive_screen.dart';

/// Clave del destello incondicional de cada disparo (RF-8, RF-10).
const Key _flashKey = Key('test-mode-flash');

/// Cabina en modo prueba sin cámara física, sin Supabase y sin GPS.
Widget _testModeApp() => const MaterialApp(
  home: DriveScreen(isTestMode: true, enableTelemetry: false, showMap: false),
);

/// Monta la cabina y consume el frame inicial.
Future<void> _pumpCockpit(WidgetTester tester) async {
  await tester.pumpWidget(_testModeApp());
  await tester.pump();
  await tester.pump(Duration.zero);
}

void main() {
  setUp(() {
    TestModeController.instance.disable();
    addTearDown(TestModeController.instance.disable);
  });

  testWidgets('muestra insignia MODO PRUEBA, chip EAR inicial y estado normal', (
    tester,
  ) async {
    await _pumpCockpit(tester);

    expect(find.text('MODO PRUEBA'), findsOneWidget);
    expect(find.text('EAR: 75%'), findsOneWidget);
    expect(find.text('Atención al camino'), findsOneWidget);
    expect(find.byKey(_flashKey), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('ojos cerrados por 1 s activa alarma con mensaje de somnolencia y destello', (
    tester,
  ) async {
    await _pumpCockpit(tester);

    final dynamic state = tester.state(find.byType(DriveScreen));
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);

    // Frame 1: Cierre de ojos (EAR 0.2 < 0.75 baseline)
    state.simulateAttentionUpdateForTesting(
      ear: 0.2,
      headAngleY: 0.0,
      isFaceDetected: true,
      currentTime: t0,
    );
    await tester.pump();
    expect(find.text('EAR: 20%'), findsOneWidget);
    expect(find.byKey(_flashKey), findsNothing);

    // Frame 2: Cierre persistente tras tolerancia de 1 segundo
    final t1 = t0.add(const Duration(milliseconds: 1100));
    state.simulateAttentionUpdateForTesting(
      ear: 0.2,
      headAngleY: 0.0,
      isFaceDetected: true,
      currentTime: t1,
    );
    await tester.pump();

    expect(find.text('¡ALERTA DE SOMNOLENCIA!'), findsOneWidget);
    expect(find.byKey(_flashKey), findsOneWidget);

    // Restaurar atención para limpiar timers
    state.simulateAttentionUpdateForTesting(
      ear: 0.75,
      headAngleY: 0.0,
      isFaceDetected: true,
      currentTime: t1.add(const Duration(seconds: 1)),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('rostro ausente por 1 s activa alarma ¡ROSTRO NO DETECTADO!', (
    tester,
  ) async {
    await _pumpCockpit(tester);

    final dynamic state = tester.state(find.byType(DriveScreen));
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);

    // Frame 1: Rostro ausente
    state.simulateAttentionUpdateForTesting(
      ear: 0.0,
      headAngleY: 0.0,
      isFaceDetected: false,
      currentTime: t0,
    );
    await tester.pump();
    expect(find.byKey(_flashKey), findsNothing);

    // Frame 2: Rostro sigue ausente tras tolerancia
    final t1 = t0.add(const Duration(milliseconds: 1100));
    state.simulateAttentionUpdateForTesting(
      ear: 0.0,
      headAngleY: 0.0,
      isFaceDetected: false,
      currentTime: t1,
    );
    await tester.pump();

    expect(find.text('¡ROSTRO NO DETECTADO!'), findsOneWidget);
    expect(find.byKey(_flashKey), findsOneWidget);

    // Recuperar atención: rostro centrado y ojos abiertos
    state.simulateAttentionUpdateForTesting(
      ear: 0.75,
      headAngleY: 0.0,
      isFaceDetected: true,
      currentTime: t1.add(const Duration(seconds: 1)),
    );
    await tester.pump();

    expect(find.text('Atención al camino'), findsOneWidget);
    expect(find.byKey(_flashKey), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('el destello visual dura 400 ms', (tester) async {
    await _pumpCockpit(tester);

    final dynamic state = tester.state(find.byType(DriveScreen));
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);

    state.simulateAttentionUpdateForTesting(
      ear: 0.2,
      headAngleY: 0.0,
      isFaceDetected: true,
      currentTime: t0,
    );
    state.simulateAttentionUpdateForTesting(
      ear: 0.2,
      headAngleY: 0.0,
      isFaceDetected: true,
      currentTime: t0.add(const Duration(milliseconds: 1100)),
    );
    await tester.pump();
    expect(find.byKey(_flashKey), findsOneWidget);

    // A los 450 ms el destello debe haberse apagado
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(_flashKey), findsNothing);

    // Detener alarma
    state.simulateAttentionUpdateForTesting(
      ear: 0.75,
      headAngleY: 0.0,
      isFaceDetected: true,
      currentTime: t0.add(const Duration(seconds: 2)),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('finalizar el viaje borra el modo de prueba', (tester) async {
    TestModeController.instance.enable();
    await _pumpCockpit(tester);
    expect(TestModeController.instance.enabled, isTrue);

    await tester.tap(find.text('Finalizar Viaje'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Finalizar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(TestModeController.instance.enabled, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('sin modo prueba no hay insignia ni destello y el EAR usa el baseline', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DriveScreen(enableTelemetry: false, showMap: false),
      ),
    );
    await tester.pump();

    expect(find.text('MODO PRUEBA'), findsNothing);
    expect(find.text('EAR: 75%'), findsOneWidget);
    expect(find.byKey(_flashKey), findsNothing);
    expect(TestModeController.instance.enabled, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
