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

  Future<int> timeMs(Future<void> Function() action) async {
    final watch = Stopwatch()..start();
    await action();
    return watch.elapsedMilliseconds;
  }

  String multiline(int kb) {
    final line = 'A' * 80;
    return List.filled((kb * 1024 / 81).ceil(), line).join('\n');
  }

  Future<void> fillFirstField(WidgetTester tester, String text) async {
    tester.widget<TextField>(find.byType(TextField).first).controller!.text = text;
    await tester.pump();
  }

  testWidgets('1MB 多行文本下，侧栏和加解密标签切换保持流畅', (tester) async {
    await pumpApp(tester);
    await fillFirstField(tester, multiline(1024));

    expect(await timeMs(() => openTool(tester, '关于')), lessThan(300));
    expect(await timeMs(() => openTool(tester, 'JSON')), lessThan(300));
    expect(await timeMs(() => openTool(tester, '加解密')), lessThan(300));

    await fillFirstField(tester, multiline(1024));
    expect(await timeMs(() => openCryptoTab(tester, '哈希')), lessThan(300));
    expect(await timeMs(() => openCryptoTab(tester, '编解码')), lessThan(300));
    expect(fieldText(tester, find.byType(TextField).first).length, greaterThan(1000 * 1024));
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('256KB 单行压缩文本下，切到关于后再缩放窗口不应被隐藏页拖死', (tester) async {
    await pumpApp(tester);
    await fillFirstField(tester, 'A' * (256 * 1024));
    expect(await timeMs(() => openTool(tester, '关于')), lessThan(300));

    final resize = await timeMs(() async {
      await tester.binding.setSurfaceSize(const Size(1100, 700));
      await tester.pumpAndSettle();
    });
    expect(resize, lessThan(400), reason: '隐藏页的大文本不应参与当前页的布局');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

String fieldText(WidgetTester tester, Finder field) {
  return tester.widget<TextField>(field).controller?.text ?? '';
}
