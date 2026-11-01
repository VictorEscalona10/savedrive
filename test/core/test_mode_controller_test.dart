import 'package:flutter_test/flutter_test.dart';
import 'package:safedrive/core/services/test_mode_controller.dart';

void main() {
  final controller = TestModeController.instance;

  setUp(() {
    // El controlador es un singleton: parte siempre de un estado limpio.
    controller.disable();
  });

  tearDown(() {
    // No contaminar el singleton entre tests ni entre archivos de test.
    controller.disable();
  });

  group('estado inicial', () {
    test('arranca desactivado y sin notificaciones previas', () {
      expect(controller.enabled, isFalse);
      expect(controller.isActive.value, isFalse);
    });
  });

  group('enable', () {
    test('activa el modo y avisa una sola vez', () {
      var notificaciones = 0;
      void listener() => notificaciones++;
      controller.isActive.addListener(listener);
      addTearDown(() => controller.isActive.removeListener(listener));

      controller.enable();

      expect(controller.enabled, isTrue);
      expect(controller.isActive.value, isTrue);
      expect(notificaciones, 1);
    });

    test('activar dos veces no vuelve a notificar (idempotente)', () {
      var notificaciones = 0;
      void listener() => notificaciones++;
      controller.isActive.addListener(listener);
      addTearDown(() => controller.isActive.removeListener(listener));

      controller.enable();
      controller.enable();
      controller.enable();

      expect(controller.enabled, isTrue);
      expect(notificaciones, 1);
    });
  });

  group('disable', () {
    test('desactiva el modo y avisa una sola vez', () {
      controller.enable();

      var notificaciones = 0;
      void listener() => notificaciones++;
      controller.isActive.addListener(listener);
      addTearDown(() => controller.isActive.removeListener(listener));

      controller.disable();

      expect(controller.enabled, isFalse);
      expect(controller.isActive.value, isFalse);
      expect(notificaciones, 1);
    });

    test('desactivar sin estar activo no notifica (idempotente)', () {
      var notificaciones = 0;
      void listener() => notificaciones++;
      controller.isActive.addListener(listener);
      addTearDown(() => controller.isActive.removeListener(listener));

      controller.disable();
      controller.disable();

      expect(controller.enabled, isFalse);
      expect(notificaciones, 0);
    });

    test('desactivar dos veces avisa solo la primera vez', () {
      controller.enable();

      var notificaciones = 0;
      void listener() => notificaciones++;
      controller.isActive.addListener(listener);
      addTearDown(() => controller.isActive.removeListener(listener));

      controller.disable();
      controller.disable();

      expect(notificaciones, 1);
    });
  });

  group('eventos de sesión', () {
    test('handleTripFinished deja el modo desactivado y es idempotente', () {
      controller.enable();

      var notificaciones = 0;
      void listener() => notificaciones++;
      controller.isActive.addListener(listener);
      addTearDown(() => controller.isActive.removeListener(listener));

      controller.handleTripFinished();

      expect(controller.enabled, isFalse);
      expect(notificaciones, 1);

      controller.handleTripFinished();

      expect(controller.enabled, isFalse);
      expect(notificaciones, 1);
    });

    test('handleSignOut deja el modo desactivado y es idempotente', () {
      controller.enable();

      var notificaciones = 0;
      void listener() => notificaciones++;
      controller.isActive.addListener(listener);
      addTearDown(() => controller.isActive.removeListener(listener));

      controller.handleSignOut();

      expect(controller.enabled, isFalse);
      expect(notificaciones, 1);

      controller.handleSignOut();

      expect(controller.enabled, isFalse);
      expect(notificaciones, 1);
    });

    test('handleSignOut sin modo activo no notifica', () {
      var notificaciones = 0;
      void listener() => notificaciones++;
      controller.isActive.addListener(listener);
      addTearDown(() => controller.isActive.removeListener(listener));

      controller.handleSignOut();

      expect(controller.enabled, isFalse);
      expect(notificaciones, 0);
    });
  });

  group('suscripción al estado', () {
    test('un listener removido deja de recibir cambios', () {
      var notificaciones = 0;
      void listener() => notificaciones++;
      controller.isActive.addListener(listener);

      controller.enable();
      expect(notificaciones, 1);

      controller.isActive.removeListener(listener);

      controller.disable();
      controller.enable();

      expect(notificaciones, 1);
      expect(controller.enabled, isTrue);
    });

    test('varios listeners reciben una notificación por cambio real', () {
      var primero = 0;
      var segundo = 0;
      void listenerUno() => primero++;
      void listenerDos() => segundo++;
      controller.isActive.addListener(listenerUno);
      controller.isActive.addListener(listenerDos);
      addTearDown(() {
        controller.isActive.removeListener(listenerUno);
        controller.isActive.removeListener(listenerDos);
      });

      controller.enable();
      controller.enable();

      expect(primero, 1);
      expect(segundo, 1);
    });
  });
}
