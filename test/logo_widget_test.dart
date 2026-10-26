import 'package:devkit/src/widgets/devkit_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders dark logo when theme is dark', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(body: DevKitLogo(size: 40)),
      ),
    );
    expect(find.byKey(const ValueKey('logo/devkit-logo-dark.svg')), findsOneWidget);
  });

  testWidgets('renders light logo when theme is light', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: const Scaffold(body: DevKitLogo(size: 40)),
      ),
    );
    expect(find.byKey(const ValueKey('logo/devkit-logo-light.svg')), findsOneWidget);
  });
}
