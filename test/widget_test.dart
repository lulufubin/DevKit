import 'package:devkit/src/app.dart';
import 'package:devkit/src/theme/theme_controller.dart';
import 'package:devkit/src/theme/theme_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('workbench shows tool navigation', (tester) async {
    await tester.pumpWidget(const DevKitApp());
    expect(find.text('JSON 格式化'), findsWidgets);
    expect(find.text('加解密'), findsOneWidget);
    expect(find.text('HAR'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
  });

  testWidgets('about page can lock dark theme and show dark logo', (tester) async {
    final theme = ThemeController(store: MemoryThemeStore());
    await tester.pumpWidget(DevKitApp(theme: theme));
    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('暗色'));
    await tester.pumpAndSettle();
    expect(theme.mode, ThemeMode.dark);
    expect(find.byKey(const ValueKey('logo/devkit-logo-dark.svg')), findsWidgets);
  });
}
