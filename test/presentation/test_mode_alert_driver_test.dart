import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safedrive/presentation/components/test_mode/test_mode_alert_driver.dart';

/// Clave del destello incondicional de cada disparo (RF-10).
const Key _flashKey = Key('test-mode-flash');

/// Monta el driver igual que lo hará la cabina, sin cámara ni servicios.
Widget _buildDriver({
  bool active = true,
  ValueChanged<int>? onCue,
  ValueChanged<bool>? onRunningChanged,
}) {
  return MaterialApp(
    home: TestModeAlertDriver(
      active: active,
      onCue: onCue,
      onRunningChanged: onRunningChanged,
      child: const SizedBox.expand(),
    ),
  );
}

/// Avanza el reloj falso hasta t=10.5 s con pasos de un segundo.
///
/// El primer `pump` sin duración consume el disparo de t=0 s.
Future<void> _advanceToSequenceEnd(WidgetTester tester) async {
  await tester.pump(Duration.zero);
  for (int second = 0; second < 10; second++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('dispara exactamente en 0, 2, 4, 6, 8 y 10 s', (tester) async {
    final cues = <int>[];

    await tester.pumpWidget(_buildDriver(onCue: cues.add));
    await _advanceToSequenceEnd(tester);

    expect(cues, <int>[0, 1, 2, 3, 4, 5]);
  });

  testWidgets('no dispara ningún cue después de 10.5 s', (tester) async {
    final cues = <int>[];

    await tester.pumpWidget(_buildDriver(onCue: cues.add));
    await _advanceToSequenceEnd(tester);
    expect(cues.length, 6);

    await tester.pump(const Duration(seconds: 3));

    expect(cues.length, 6);
    expect(cues, <int>[0, 1, 2, 3, 4, 5]);
  });

  testWidgets('el destello se muestra en el cue y dura 400 ms', (tester) async {
    await tester.pumpWidget(_buildDriver());

    await tester.pump(Duration.zero);
    expect(find.byKey(_flashKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(_flashKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(_flashKey), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('onRunningChanged avisa del arranque y del final', (
    tester,
  ) async {
    final running = <bool>[];

    await tester.pumpWidget(_buildDriver(onRunningChanged: running.add));
    await tester.pump(Duration.zero);
    expect(running, <bool>[true]);

    await tester.pump(const Duration(seconds: 10));
    expect(running, <bool>[true]);

    await tester.pump(const Duration(milliseconds: 500));
    expect(running, <bool>[true, false]);

    await tester.pumpWidget(const SizedBox());
    expect(running, <bool>[true, false]);
  });

  testWidgets('paused cancela la secuencia de forma definitiva', (tester) async {
    final cues = <int>[];
    final running = <bool>[];

    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    await tester.pumpWidget(
      _buildDriver(onCue: cues.add, onRunningChanged: running.add),
    );
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(seconds: 2));
    expect(cues, <int>[0, 1]);
    expect(find.byKey(_flashKey), findsOneWidget);
    expect(running, <bool>[true]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(running, <bool>[true, false]);

    await tester.pump(const Duration(seconds: 12));
    expect(cues, <int>[0, 1]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.byKey(_flashKey), findsNothing);

    await tester.pump(const Duration(seconds: 12));

    expect(cues, <int>[0, 1]);
    expect(running, <bool>[true, false]);

    await tester.pumpWidget(const SizedBox());
    expect(running, <bool>[true, false]);
  });

  testWidgets('con active false no dispara nada', (tester) async {
    final cues = <int>[];
    final running = <bool>[];

    await tester.pumpWidget(
      _buildDriver(active: false, onCue: cues.add, onRunningChanged: running.add),
    );
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(seconds: 12));

    expect(cues, isEmpty);
    expect(running, isEmpty);
    expect(find.byKey(_flashKey), findsNothing);
  });

  testWidgets('desmontar a mitad de secuencia no deja timers pendientes', (
    tester,
  ) async {
    final cues = <int>[];
    final running = <bool>[];

    await tester.pumpWidget(
      _buildDriver(onCue: cues.add, onRunningChanged: running.add),
    );
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(seconds: 2));
    expect(cues, <int>[0, 1]);

    await tester.pumpWidget(const SizedBox());
    expect(running, <bool>[true, false]);

    await tester.pump(const Duration(seconds: 12));

    expect(cues, <int>[0, 1]);
    expect(tester.takeException(), isNull);
  });
}
