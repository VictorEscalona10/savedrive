import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safedrive/core/services/test_mode_controller.dart';
import 'package:safedrive/data/models/alarm_type_model.dart';
import 'package:safedrive/data/models/emergency_contact_model.dart';
import 'package:safedrive/data/models/user_settings_model.dart';
import 'package:safedrive/data/repositories/alarm_type_repository.dart';
import 'package:safedrive/data/repositories/auth_repository.dart';
import 'package:safedrive/data/repositories/emergency_contact_repository.dart';
import 'package:safedrive/data/repositories/settings_repository.dart';
import 'package:safedrive/presentation/screens/settings/settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente ficticio: solo satisface el constructor de los repositorios reales.
/// No se inicializa Supabase y ninguna llamada sale a la red porque todos los
/// métodos usados por la pantalla están sobrescritos en los fakes. Se desactiva
/// el refresco automático de tokens para no dejar timers pendientes en el test.
SupabaseClient _fakeClient() => SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository({SupabaseClient? client})
      : super(client: client ?? _fakeClient());

  final List<UserSettingsModel> saveCalls = [];

  @override
  Future<UserSettingsModel?> getUserSettings() async => null;

  @override
  Future<void> saveUserSettings(UserSettingsModel settings) async {
    saveCalls.add(settings);
  }
}

class _FakeAlarmTypeRepository extends AlarmTypeRepository {
  _FakeAlarmTypeRepository({SupabaseClient? client})
      : super(client: client ?? _fakeClient());

  @override
  Future<List<AlarmTypeModel>> getAlarmTypes() async => const [];
}

class _FakeEmergencyContactRepository extends EmergencyContactRepository {
  _FakeEmergencyContactRepository({SupabaseClient? client})
      : super(client: client ?? _fakeClient());

  @override
  Future<EmergencyContactModel?> getPrimaryContact() async => null;
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({SupabaseClient? client})
      : super(client: client ?? _fakeClient());

  @override
  User? get currentUser => null;
}

class _Harness {
  final SupabaseClient client = _fakeClient();
  late final _FakeSettingsRepository settings =
      _FakeSettingsRepository(client: client);
  late final _FakeAlarmTypeRepository alarms =
      _FakeAlarmTypeRepository(client: client);
  late final _FakeEmergencyContactRepository contacts =
      _FakeEmergencyContactRepository(client: client);
  late final _FakeAuthRepository auth = _FakeAuthRepository(client: client);

  SettingsScreen build() => SettingsScreen(
        settingsRepository: settings,
        alarmTypeRepository: alarms,
        emergencyContactRepository: contacts,
        authRepository: auth,
      );

  Widget app() => MaterialApp(home: build());
}

const _switchKey = Key('test-mode-switch');

Switch _switchWidget(WidgetTester tester) =>
    tester.widget<Switch>(find.byKey(_switchKey));

void main() {
  setUp(() {
    TestModeController.instance.disable();
  });

  testWidgets('el interruptor de Modo de prueba existe y arranca apagado', (
    tester,
  ) async {
    final harness = _Harness();

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(find.byKey(_switchKey), findsOneWidget);
    expect(find.text('Modo de prueba'), findsOneWidget);
    expect(_switchWidget(tester).value, isFalse);
    expect(TestModeController.instance.enabled, isFalse);
  });

  testWidgets('activar el interruptor no llama a saveUserSettings', (
    tester,
  ) async {
    final harness = _Harness();

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(_switchKey));
    await tester.tap(find.byKey(_switchKey));
    await tester.pump();

    expect(TestModeController.instance.enabled, isTrue);
    expect(_switchWidget(tester).value, isTrue);
    expect(harness.settings.saveCalls, isEmpty);
  });

  testWidgets('un segundo toque desactiva el modo', (tester) async {
    final harness = _Harness();

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(_switchKey));
    await tester.tap(find.byKey(_switchKey));
    await tester.pump();
    expect(TestModeController.instance.enabled, isTrue);

    await tester.tap(find.byKey(_switchKey));
    await tester.pump();

    expect(TestModeController.instance.enabled, isFalse);
    expect(_switchWidget(tester).value, isFalse);
    expect(harness.settings.saveCalls, isEmpty);
  });

  testWidgets('«Guardar Ajustes» no escribe el modo ni lo desactiva', (
    tester,
  ) async {
    final harness = _Harness();

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(_switchKey));
    await tester.tap(find.byKey(_switchKey));
    await tester.pump();
    expect(TestModeController.instance.enabled, isTrue);

    await tester.ensureVisible(find.text('Guardar Ajustes'));
    await tester.tap(find.text('Guardar Ajustes'));
    await tester.pump();

    // Sin sesión activa el guardado ni siquiera llega al repositorio.
    expect(harness.settings.saveCalls, isEmpty);
    expect(TestModeController.instance.enabled, isTrue);

    // Deja expirar el SnackBar para no dejar timers pendientes.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('el modo sobrevive a desmontar y volver a montar Ajustes', (
    tester,
  ) async {
    final harness = _Harness();

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(_switchKey));
    await tester.tap(find.byKey(_switchKey));
    await tester.pump();
    expect(_switchWidget(tester).value, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(find.byKey(_switchKey), findsOneWidget);
    expect(_switchWidget(tester).value, isTrue);
    expect(TestModeController.instance.enabled, isTrue);
    expect(harness.settings.saveCalls, isEmpty);
  });
}
