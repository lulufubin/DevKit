import 'package:devkit/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'DevKit',
      packageName: 'devkit',
      version: '0.2.1',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  Future<void> openHash(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DevKitApp());
    await tester.tap(find.text('加解密'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('哈希'));
    await tester.pumpAndSettle();
  }

  testWidgets('对比开关默认关闭，打开后出现三列标题', (tester) async {
    await openHash(tester);
    expect(find.text('Rust'), findsNothing);
    expect(find.text('Python'), findsNothing);
    expect(find.text('crypto-js'), findsNothing);
    await tester.tap(find.descendant(of: find.widgetWithText(Row, '对比'), matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(find.text('对比'), findsWidgets);
    expect(find.text('Rust'), findsOneWidget);
    expect(find.text('Python'), findsOneWidget);
    expect(find.text('crypto-js'), findsOneWidget);
  });
}
