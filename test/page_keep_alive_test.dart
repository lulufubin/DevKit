import 'package:devkit/src/app.dart';
import 'package:devkit/src/rust/api/json.dart';
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

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DevKitApp());
  }

  Future<void> openTool(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  Future<void> openCryptoTab(WidgetTester tester, String label) async {
    final tab = find.descendant(of: find.byType(TabBar), matching: find.text(label));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  Finder labeledField(String label) {
    return find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == label);
  }

  String fieldText(WidgetTester tester, Finder field) {
    return tester.widget<TextField>(field).controller?.text ?? '';
  }

  Finder compareSwitch() {
    return find.descendant(of: find.widgetWithText(Row, '对比'), matching: find.byType(Switch));
  }

  testWidgets('侧栏切换各工具页后，输入不会被刷新掉', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField).first, '{"keep":1}');
    await tester.tap(find.text('严格'));
    await tester.pump();

    await openTool(tester, 'JSON 对比');
    await tester.enterText(find.byType(TextField).first, '{"left":true}');
    await tester.pump();

    await openTool(tester, '加解密');
    await tester.enterText(find.byType(TextField).first, 'codec-keep');
    await tester.pump();

    await openTool(tester, 'HAR');
    await tester.enterText(labeledField('URL 包含'), 'example.com');
    await tester.pump();

    await openTool(tester, '关于');
    await openTool(tester, 'JSON');
    expect(fieldText(tester, find.byType(TextField).first), '{"keep":1}');
    expect(tester.widget<SegmentedButton<JsonMode>>(find.byType(SegmentedButton<JsonMode>)).selected, {JsonMode.strict});

    await openTool(tester, 'JSON 对比');
    expect(fieldText(tester, find.byType(TextField).first), '{"left":true}');

    await openTool(tester, '加解密');
    expect(fieldText(tester, find.byType(TextField).first), 'codec-keep');

    await openTool(tester, 'HAR');
    expect(fieldText(tester, labeledField('URL 包含')), 'example.com');
  });

  testWidgets('加解密内部标签切换后，各页输入不会被刷新掉', (tester) async {
    await pumpApp(tester);
    await openTool(tester, '加解密');

    await openCryptoTab(tester, '编解码');
    await tester.enterText(find.byType(TextField).first, 'codec-keep');
    await tester.pump();

    await openCryptoTab(tester, '哈希');
    await tester.enterText(find.byType(TextField).first, 'hash-keep');
    await tester.tap(compareSwitch());
    await tester.pump();

    await openCryptoTab(tester, 'AES');
    await tester.enterText(labeledField('密钥'), 'aes-key-keep');
    await tester.enterText(find.byType(TextField).at(1), 'aes-plain-keep');
    await tester.pump();

    await openCryptoTab(tester, 'HMAC');
    await tester.enterText(labeledField('密钥'), 'hmac-key-keep');
    await tester.enterText(find.byType(TextField).at(1), 'hmac-msg-keep');
    await tester.pump();

    await openCryptoTab(tester, 'RSA');
    await tester.enterText(find.byType(TextField).first, 'rsa-pub-keep');
    await tester.pump();

    await openCryptoTab(tester, '国密');
    await tester.enterText(find.byType(TextField).first, 'sm-keep');
    await tester.pump();

    await openTool(tester, 'JSON');
    await openTool(tester, '加解密');

    await openCryptoTab(tester, '编解码');
    expect(fieldText(tester, find.byType(TextField).first), 'codec-keep');

    await openCryptoTab(tester, '哈希');
    expect(fieldText(tester, find.byType(TextField).first), 'hash-keep');
    expect(tester.widget<Switch>(compareSwitch()).value, isTrue);

    await openCryptoTab(tester, 'AES');
    expect(fieldText(tester, find.byType(TextField).first), 'aes-key-keep');
    expect(fieldText(tester, find.byType(TextField).at(1)), 'aes-plain-keep');

    await openCryptoTab(tester, 'HMAC');
    expect(fieldText(tester, find.byType(TextField).first), 'hmac-key-keep');
    expect(fieldText(tester, find.byType(TextField).at(1)), 'hmac-msg-keep');

    await openCryptoTab(tester, 'RSA');
    expect(fieldText(tester, find.byType(TextField).first), 'rsa-pub-keep');

    await openCryptoTab(tester, '国密');
    expect(fieldText(tester, find.byType(TextField).first), 'sm-keep');
  });
}
