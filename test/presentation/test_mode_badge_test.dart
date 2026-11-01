import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safedrive/presentation/components/test_mode/test_mode_badge.dart';

void main() {
  testWidgets('muestra el texto MODO PRUEBA con su icono', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TestModeBadge())),
    );

    expect(find.text('MODO PRUEBA'), findsOneWidget);
    expect(find.byIcon(Icons.science_rounded), findsOneWidget);
  });

  testWidgets('se describe como modo de prueba activo para lectores', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TestModeBadge())),
    );

    expect(find.bySemanticsLabel('Modo de prueba activo'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('la variante compacta renderiza y ocupa menos que la normal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TestModeBadge())),
    );
    final normal = tester.getSize(find.byType(TestModeBadge));
    expect(find.text('MODO PRUEBA'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TestModeBadge(compact: true))),
    );
    final compacta = tester.getSize(find.byType(TestModeBadge));
    expect(find.text('MODO PRUEBA'), findsOneWidget);

    expect(compacta.height, lessThan(normal.height));
    expect(compacta.width, lessThan(normal.width));
  });
}
