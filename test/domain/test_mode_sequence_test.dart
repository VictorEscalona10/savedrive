import 'package:flutter_test/flutter_test.dart';
import 'package:safedrive/domain/test_mode/test_mode_sequence.dart';

void main() {
  group('TestModeSequence.cueAt', () {
    test('devuelve el disparo correspondiente en cada offset programado', () {
      const esperados = <int, int>{
        0: 0,
        2000: 1,
        4000: 2,
        6000: 3,
        8000: 4,
        10000: 5,
      };

      esperados.forEach((ms, indice) {
        final cue = TestModeSequence.cueAt(ms);

        expect(cue, isNotNull, reason: '$ms ms debería generar un disparo');
        expect(cue!.index, indice, reason: 'índice incorrecto en $ms ms');
        expect(cue.atMs, ms, reason: 'atMs incorrecto en $ms ms');
      });
    });

    test('devuelve null en milisegundos que no son offsets exactos', () {
      const intermedios = <int>[
        1,
        1999,
        2001,
        2300,
        3999,
        4001,
        5000,
        9999,
        10001,
        12000,
      ];

      for (final ms in intermedios) {
        expect(
          TestModeSequence.cueAt(ms),
          isNull,
          reason: '$ms ms no es un offset programado',
        );
      }
    });

    test('devuelve null con milisegundos negativos', () {
      for (final ms in <int>[-1, -2000]) {
        expect(
          TestModeSequence.cueAt(ms),
          isNull,
          reason: '$ms ms es negativo y no debe disparar',
        );
      }
    });
  });

  group('TestModeSequence.cueOffsetsMs', () {
    test('contiene exactamente seis offsets en orden ascendente', () {
      expect(TestModeSequence.cueOffsetsMs, hasLength(6));
      expect(
        TestModeSequence.cueOffsetsMs,
        <int>[0, 2000, 4000, 6000, 8000, 10000],
      );
    });

    test('el índice de cada disparo coincide con su posición en la lista', () {
      for (var i = 0; i < TestModeSequence.cueOffsetsMs.length; i++) {
        final cue = TestModeSequence.cueAt(TestModeSequence.cueOffsetsMs[i]);

        expect(cue, isNotNull, reason: 'falta el disparo de la posición $i');
        expect(cue!.index, i);
        expect(cue.atMs, TestModeSequence.cueOffsetsMs[i]);
      }
    });
  });

  group('TestModeSequence constantes', () {
    test('el destello dura 400 ms', () {
      expect(TestModeSequence.flashDurationMs, 400);
    });

    test('la apertura ocular fija es 0.75', () {
      expect(TestModeSequence.fixedEar, 0.75);
    });

    test('el ángulo de cabeza fijo es 0.0', () {
      expect(TestModeSequence.fixedHeadAngleDeg, 0.0);
    });
  });

  group('TestModeSequence.isFinished', () {
    test('no ha terminado en t=10 s ni antes', () {
      expect(TestModeSequence.isFinished(10000), isFalse);
      expect(TestModeSequence.isFinished(9999), isFalse);
      expect(TestModeSequence.isFinished(0), isFalse);
      expect(TestModeSequence.isFinished(-1), isFalse);
    });

    test('ha terminado después de t=10 s', () {
      expect(TestModeSequence.isFinished(10001), isTrue);
      expect(TestModeSequence.isFinished(12000), isTrue);
    });
  });
}
