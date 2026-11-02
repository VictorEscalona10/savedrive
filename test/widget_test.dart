import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safedrive/presentation/components/test_mode/test_mode_badge.dart';
import 'package:safedrive/presentation/screens/auth/widgets/register_dots_indicator.dart';

void main() {
  testWidgets('TestModeBadge smoke test renderiza el texto MODO PRUEBA (RF-3, RF-11)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TestModeBadge(),
        ),
      ),
    );

    expect(find.text('MODO PRUEBA'), findsOneWidget);
    expect(find.byIcon(Icons.science_rounded), findsOneWidget);
  });

  testWidgets('RegisterDotsIndicator renderiza la cantidad correcta de puntos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RegisterDotsIndicator(
            currentIndex: 1,
            totalSteps: 5,
          ),
        ),
      ),
    );

    expect(find.byType(RegisterDotsIndicator), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(5));
  });
}
