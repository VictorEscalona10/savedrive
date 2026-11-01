import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safedrive/core/theme/app_colors.dart';
import 'package:safedrive/domain/test_mode/test_mode_sequence.dart';

/// Ejecuta la secuencia de alerta del modo de prueba sobre la cabina
/// (RF-7, RF-9, RF-10).
///
/// Programa un temporizador por cada offset de [TestModeSequence.cueOffsetsMs]
/// y, en cada disparo, emite sonido de sistema, vibración háptica y un destello
/// rojo incondicional de [TestModeSequence.flashDurationMs]. No detecta audio ni
/// depende de la cámara: cuando la app pasa a segundo plano, o el widget se
/// desmonta, cancela todos los temporizadores de forma definitiva.
class TestModeAlertDriver extends StatefulWidget {
  /// Indica si la secuencia debe ejecutarse mientras este widget esté montado.
  final bool active;

  /// Contenido sobre el que se dibuja el destello (normalmente la cabina).
  final Widget child;

  /// Se invoca en cada disparo con su índice (0 a 5).
  final ValueChanged<int>? onCue;

  /// Se invoca con `true` al arrancar la secuencia y con `false` al terminar,
  /// al cancelarla o al desmontar el widget.
  final ValueChanged<bool>? onRunningChanged;

  const TestModeAlertDriver({
    super.key,
    required this.active,
    required this.child,
    this.onCue,
    this.onRunningChanged,
  });

  @override
  State<TestModeAlertDriver> createState() => _TestModeAlertDriverState();
}

class _TestModeAlertDriverState extends State<TestModeAlertDriver>
    with WidgetsBindingObserver {
  /// Clave del destello, usada por los tests y por la validación manual.
  static const Key flashKey = Key('test-mode-flash');

  /// Rojo de la paleta al 40 % sobre la cabina: sin texto encima, legible en
  /// tema claro y oscuro.
  static final Color _flashColor = AppColors.red.withValues(alpha: 0.4);

  /// Todos los temporizadores vivos (disparos, fin de destello y fin de
  /// secuencia) para poder cancelarlos juntos.
  final List<Timer> _timers = <Timer>[];

  bool _flashVisible = false;
  bool _running = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) {
      _startSequence();
    }
  }

  @override
  void didUpdateWidget(covariant TestModeAlertDriver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _cancelSequence();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // RF-9: la secuencia se cancela de forma definitiva y no se reanuda
        // al volver a `resumed`.
        _cancelSequence();
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    _cancelTimers();
    _flashVisible = false;
    WidgetsBinding.instance.removeObserver(this);
    _setRunning(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (_flashVisible)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(key: flashKey, color: _flashColor),
            ),
          ),
      ],
    );
  }

  /// Programa un temporizador por offset y avisa del arranque al terminar el
  /// primer frame, para que quien escuche pueda reconstruirse sin `setState`
  /// durante el build.
  void _startSequence() {
    _cancelled = false;
    for (int index = 0; index < TestModeSequence.cueOffsetsMs.length; index++) {
      final int cueIndex = index;
      _timers.add(
        Timer(
          Duration(milliseconds: TestModeSequence.cueOffsetsMs[index]),
          () => _fireCue(cueIndex),
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _cancelled) {
        return;
      }
      _setRunning(true);
    });
  }

  void _fireCue(int index) {
    if (_cancelled || !mounted) {
      return;
    }
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    setState(() => _flashVisible = true);
    _timers.add(
      Timer(
        Duration(milliseconds: TestModeSequence.flashDurationMs),
        _hideFlash,
      ),
    );
    if (index == TestModeSequence.cueOffsetsMs.length - 1) {
      _timers.add(
        Timer(
          Duration(milliseconds: TestModeSequence.flashDurationMs),
          () => _setRunning(false),
        ),
      );
    }
    widget.onCue?.call(index);
  }

  void _hideFlash() {
    if (_cancelled || !mounted || !_flashVisible) {
      return;
    }
    setState(() => _flashVisible = false);
  }

  /// Cancela la secuencia para siempre: apaga el destello, descarta los
  /// temporizadores y avisa de que ya no está en marcha.
  void _cancelSequence() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    _cancelTimers();
    if (_flashVisible && mounted) {
      setState(() => _flashVisible = false);
    }
    _setRunning(false);
  }

  void _cancelTimers() {
    for (final Timer timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// Notifica el estado de marcha una sola vez por transición.
  void _setRunning(bool value) {
    if (_running == value) {
      return;
    }
    _running = value;
    widget.onRunningChanged?.call(value);
  }
}
