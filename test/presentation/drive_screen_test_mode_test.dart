import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safedrive/core/services/test_mode_controller.dart';
import 'package:safedrive/presentation/screens/camera/drive_screen.dart';

/// Clave del destello incondicional de cada disparo (RF-10).
const Key _flashKey = Key('test-mode-flash');

/// Texto exacto del panel durante la secuencia de prueba (RF-8).
const String _testAlertMessage = '¡ALERTA DE SOMNOLENCIA! (MODO PRUEBA)';

/// Cabina en modo prueba sin cámara, sin Supabase y sin GPS.
Widget _testModeApp() => const MaterialApp(
  home: DriveScreen(isTestMode: true, enableTelemetry: false, showMap: false),
);

/// Monta la cabina y consume el primer frame (arranque del driver) y el
/// disparo de t=0.
///
/// No usa `pumpAndSettle`: `_pulseCtrl` se repite indefinidamente y el
/// destello se programa con temporizadores que nunca se asientan.
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

  testWidgets('muestra insignia, EAR fijo y panel en alerta con destello', (
    tester,
  ) async {
    await _pumpCockpit(tester);

    expect(find.text('MODO PRUEBA'), findsOneWidget);
    expect(find.text('EAR: 75%'), findsOneWidget);
    expect(find.text(_testAlertMessage), findsOneWidget);
    expect(find.byKey(_flashKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('el destello desaparece a los 400 ms', (tester) async {
    await _pumpCockpit(tester);
    expect(find.byKey(_flashKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(_flashKey), findsNothing);
    // Sigue dentro de la secuencia, así que el panel continúa en alerta.
    expect(find.text(_testAlertMessage), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('al terminar la secuencia el panel deja de estar forzado', (
    tester,
  ) async {
    await _pumpCockpit(tester);
    expect(find.text(_testAlertMessage), findsOneWidget);

    for (int second = 0; second < 10; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(_testAlertMessage), findsNothing);
    expect(tester.takeException(), isNull);

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

  testWidgets('sin modo prueba no hay insignia ni destello y el EAR usa el '
      'baseline', (tester) async {
    // Sin `isTestMode` no se instancia nada de Supabase ni se arranca el GPS.
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
