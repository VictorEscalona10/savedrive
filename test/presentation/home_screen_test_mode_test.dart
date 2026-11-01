import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safedrive/core/services/test_mode_controller.dart';
import 'package:safedrive/data/models/user_model.dart';
import 'package:safedrive/data/models/user_settings_model.dart';
import 'package:safedrive/data/repositories/settings_repository.dart';
import 'package:safedrive/data/repositories/user_repository.dart';
import 'package:safedrive/presentation/screens/camera/drive_screen.dart';
import 'package:safedrive/presentation/screens/dashboard/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Subtítulo del flujo real (RF-5): debe desaparecer con el modo activo (RF-3).
const String _calibrationSubtitle = 'Calibración Fantasma & Cámara Frontal';

/// Subtítulo de demo mostrado con el modo activo (RF-3).
const String _demoSubtitle = 'Modo de prueba: alerta simulada sin calibración';

/// Texto del chip reutilizable (RF-3).
const String _badgeText = 'MODO PRUEBA';

/// Canal nativo de `permission_handler`; se intercepta para comprobar si el
/// dashboard solicita el permiso de cámara o no (RF-4 / RF-5).
const MethodChannel _permissionsChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

/// Canal nativo de geolocator; solo se referencia en el mensaje del test.
const String _geolocatorChannel = 'flutter.baseflow.com/geolocator';

/// Cliente ficticio: satisface el constructor de los repositorios reales sin
/// inicializar Supabase. Todos los métodos usados por la pantalla están
/// sobrescritos en los fakes. Se desactiva el refresco de tokens para no dejar
/// timers pendientes.
SupabaseClient _fakeClient() => SupabaseClient(
  'https://test.supabase.co',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository({SupabaseClient? client})
    : super(client: client ?? _fakeClient());

  @override
  Future<UserModel?> getCurrentUserProfile() async => null;
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository({SupabaseClient? client})
    : super(client: client ?? _fakeClient());

  @override
  Future<UserSettingsModel?> getUserSettings() async => null;
}

class _Harness {
  final SupabaseClient client = _fakeClient();
  late final _FakeUserRepository user = _FakeUserRepository(client: client);
  late final _FakeSettingsRepository settings =
      _FakeSettingsRepository(client: client);

  /// `enableLocation: false` evita tocar geolocator al montar el dashboard.
  Widget app() => MaterialApp(
    home: HomeScreen(
      userRepository: user,
      settingsRepository: settings,
      enableLocation: false,
    ),
  );
}

/// Monta el dashboard y deja avanzar el fade de entrada. No se usa
/// `pumpAndSettle`: el mapa y las animaciones de la cabina no se asientan.
Future<void> _pumpHome(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(harness.app());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Desmonta el árbol para cancelar animaciones, timers y streams pendientes.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

/// Instala un mock del canal de permisos que registra cada llamada y concede
/// el permiso de cámara (valor 1) para que la rama normal avance hasta
/// `availableCameras()`.
List<MethodCall> _installPermissionMock(WidgetTester tester) {
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(_permissionsChannel, (call) async {
    calls.add(call);
    if (call.method == 'requestPermissions') {
      return <int, int>{1: 1};
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(_permissionsChannel, null),
  );

  return calls;
}

/// Consume las excepciones capturadas por el binding y falla ante cualquiera
/// que no sea la ausencia del plugin de geolocator (el canal nativo no existe
/// en `flutter test`). No se oculta ningún otro error.
void _expectNoUnexpectedException(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception == null) {
    return;
  }
  expect(
    exception,
    isA<MissingPluginException>().having(
      (e) => e.message ?? '',
      'message',
      contains(_geolocatorChannel),
    ),
  );
}

void main() {
  HttpOverrides? previousOverrides;

  setUp(() {
    TestModeController.instance.disable();
    // Las teselas del mapa usan `package:http` sobre `dart:io`: se sustituye el
    // cliente global por uno que responde un PNG transparente de 1×1. Así el
    // mapa no intenta red real y no inunda el test con errores de imagen.
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _FakeHttpOverrides();
  });

  tearDown(() {
    TestModeController.instance.disable();
    HttpOverrides.global = previousOverrides;
  });

  testWidgets('sin modo prueba mantiene el subtítulo de calibración real', (
    tester,
  ) async {
    final harness = _Harness();

    await _pumpHome(tester, harness);

    expect(find.text(_calibrationSubtitle), findsOneWidget);
    expect(find.text(_badgeText), findsNothing);
    expect(find.text(_demoSubtitle), findsNothing);

    await _unmount(tester);
  });

  testWidgets('con modo prueba muestra chip y subtítulo de demo', (
    tester,
  ) async {
    final harness = _Harness();
    TestModeController.instance.enable();

    await _pumpHome(tester, harness);

    expect(find.text(_badgeText), findsOneWidget);
    expect(find.text(_demoSubtitle), findsOneWidget);
    expect(find.text(_calibrationSubtitle), findsNothing);

    await _unmount(tester);
  });

  testWidgets('con modo prueba abre la cabina sin pedir permiso de cámara', (
    tester,
  ) async {
    final harness = _Harness();
    TestModeController.instance.enable();
    final permissionCalls = _installPermissionMock(tester);

    await _pumpHome(tester, harness);
    expect(find.text(_badgeText), findsOneWidget);

    await tester.tap(find.text('Iniciar Monitoreo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DriveScreen), findsOneWidget);
    expect(find.text(_calibrationSubtitle), findsNothing);
    expect(
      permissionCalls,
      isEmpty,
      reason: 'El modo prueba no debe solicitar permisos de cámara (RF-4).',
    );

    _expectNoUnexpectedException(tester);

    await _unmount(tester);
    _expectNoUnexpectedException(tester);
  });

  testWidgets('sin modo prueba pide el permiso de cámara y no abre la cabina', (
    tester,
  ) async {
    final harness = _Harness();
    final permissionCalls = _installPermissionMock(tester);

    await _pumpHome(tester, harness);

    await tester.tap(find.text('Iniciar Monitoreo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      permissionCalls.any((call) => call.method == 'requestPermissions'),
      isTrue,
      reason: 'El flujo normal debe solicitar el permiso de cámara (RF-5).',
    );
    // Sin plugin de cámara en `flutter test`, la rama normal no navega y cae
    // en el SnackBar de error: la calibración solo se abre con cámara real.
    expect(find.byType(DriveScreen), findsNothing);

    await _unmount(tester);
  });
}

/// `HttpClient` falso: cualquier petición devuelve un PNG transparente.
class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest();

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool persistentConnection = true;

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  void add(List<int> data) {}

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse implements HttpClientResponse {
  /// PNG transparente de 1×1 que `dart:ui` puede decodificar sin error.
  static final Uint8List _bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
    'hKmMIQAAAABJRU5ErkJggg==',
  );

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
