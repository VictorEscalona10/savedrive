import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safedrive/core/services/test_mode_controller.dart';
import 'package:safedrive/data/models/user_model.dart';
import 'package:safedrive/data/repositories/auth_repository.dart';
import 'package:safedrive/data/repositories/user_repository.dart';
import 'package:safedrive/presentation/components/buttons/danger_button.dart';
import 'package:safedrive/presentation/screens/profile/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient _fakeClient() => SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository() : super(client: _fakeClient());

  @override
  Future<UserModel?> getCurrentUserProfile() async => const UserModel(
        id: 'test-user-id',
        email: 'conductor@safedrive.test',
        fullName: 'Conductor Demo',
      );
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(client: _fakeClient());

  var signOutCalled = false;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  final controller = TestModeController.instance;

  setUp(() {
    controller.disable();
  });

  tearDown(() {
    controller.disable();
  });

  testWidgets(
      'ProfileScreen _logout desactiva el modo de prueba y llama a signOut (RF-2)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    controller.enable();
    expect(controller.enabled, isTrue);

    final fakeUserRepo = _FakeUserRepository();
    final fakeAuthRepo = _FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          userRepository: fakeUserRepo,
          authRepository: fakeAuthRepo,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final logoutFinder = find.byType(DangerButton);
    expect(logoutFinder, findsOneWidget);

    await tester.tap(logoutFinder);
    await tester.pumpAndSettle();

    // Confirmar en el diálogo de confirmación
    final confirmBtn = find.text('Cerrar sesión');
    expect(confirmBtn, findsWidgets);
    await tester.tap(confirmBtn.last);
    await tester.pumpAndSettle();

    expect(fakeAuthRepo.signOutCalled, isTrue);
    expect(controller.enabled, isFalse);
    expect(controller.isActive.value, isFalse);
  });
}
