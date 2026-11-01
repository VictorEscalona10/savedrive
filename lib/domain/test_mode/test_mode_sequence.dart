/// Un disparo de la secuencia del modo de prueba.
///
/// Cada disparo combina sonido de sistema, vibración háptica y destello visual;
/// esta clase solo describe cuándo ocurre, sin depender de la interfaz.
class TestModeCue {
  /// Posición del disparo dentro de la secuencia (0 a 5).
  final int index;

  /// Instante del disparo, en milisegundos desde la entrada a la cabina.
  final int atMs;

  const TestModeCue({required this.index, required this.atMs});
}

/// Lógica pura y determinista de la secuencia del modo de prueba (RF-7, RF-10).
///
/// Es independiente del evaluador de fatiga, de la cámara y de la interfaz:
/// recibe el tiempo transcurrido en milisegundos y responde si toca disparar.
abstract final class TestModeSequence {
  /// Offsets exactos de los seis disparos: t=0, 2, 4, 6, 8 y 10 s.
  static const List<int> cueOffsetsMs = <int>[0, 2000, 4000, 6000, 8000, 10000];

  /// Duración del destello de cada disparo, en milisegundos (±100 ms según RF-10).
  static const int flashDurationMs = 400;

  /// Apertura ocular fija usada en la cabina durante el modo de prueba (RF-6).
  static const double fixedEar = 0.75;

  /// Ángulo de cabeza fijo en grados usado durante el modo de prueba (RF-6).
  static const double fixedHeadAngleDeg = 0.0;

  /// Devuelve el disparo programado exactamente en [elapsedMs].
  ///
  /// Retorna `null` si [elapsedMs] es negativo o no coincide exactamente con
  /// uno de los offsets de [cueOffsetsMs]; no hay disparos posteriores a 10 s.
  static TestModeCue? cueAt(int elapsedMs) {
    final index = cueOffsetsMs.indexOf(elapsedMs);
    if (index < 0) {
      return null;
    }
    return TestModeCue(index: index, atMs: elapsedMs);
  }

  /// Indica si la secuencia ya terminó, es decir, si [elapsedMs] supera 10 s.
  static bool isFinished(int elapsedMs) => elapsedMs > 10000;
}
