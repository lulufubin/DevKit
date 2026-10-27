import 'package:devkit/src/app.dart';
import 'package:devkit/src/widgets/io_pane.dart';
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
      version: '0.2.2',
      buildNumber: '5',
      buildSignature: '',
    );
  });

  testWidgets('HAR 页导入不按 20MB 文本上限拦截', (tester) async {
    await tester.pumpWidget(const DevKitApp());
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('HAR')));
    await tester.pumpAndSettle();
    expect(find.text('导入 HAR'), findsOneWidget);
    expect(maxTextBytes, 20 * 1024 * 1024);
    expect(find.textContaining('20MB'), findsNothing);
  });
}
