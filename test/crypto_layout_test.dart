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
      version: '0.2.2',
      buildNumber: '5',
      buildSignature: '',
    );
  });

  Future<void> openCrypto(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DevKitApp());
    await tester.tap(find.text('加解密'));
    await tester.pumpAndSettle();
  }

  int expandingFields(WidgetTester tester) {
    return tester.widgetList<TextField>(find.byType(TextField)).where((field) => field.expands).length;
  }

  testWidgets('编解码页输入输出拉满剩余高度', (tester) async {
    await openCrypto(tester);
    expect(find.text('编解码'), findsWidgets);
    expect(find.widgetWithText(FilledButton, '编码'), findsOneWidget);
    expect(expandingFields(tester), 2);
  });

  testWidgets('RSA 页密钥占较小高度，输入输出仍拉满', (tester) async {
    await openCrypto(tester);
    await tester.tap(find.text('RSA'));
    await tester.pumpAndSettle();
    expect(find.text('生成 2048 位密钥对'), findsOneWidget);
    expect(find.text('明文 / 密文 / 待签消息'), findsOneWidget);
    expect(expandingFields(tester), 4);
  });
}
