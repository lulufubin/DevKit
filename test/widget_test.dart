import 'package:devkit/src/app.dart';
import 'package:devkit/src/theme/theme_controller.dart';
import 'package:devkit/src/theme/theme_store.dart';
import 'package:devkit/src/update/github_releases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubReleases extends GithubReleases {
  _StubReleases() : super(client: IOClient());

  @override
  Future<UpdateInfo?> fetchLatest({required String currentVersion}) async {
    return const UpdateInfo(
      tag: 'v9.9.9',
      version: '9.9.9',
      installerUrl: 'https://example/devkit-desktop-windows-amd64.exe',
      notes: '',
    );
  }
}

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

  testWidgets('workbench shows tool navigation without page header titles', (tester) async {
    await tester.pumpWidget(const DevKitApp());
    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('JSON 压缩'), findsNothing);
    expect(find.text('宽容'), findsNothing);
    expect(find.text('严格'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(find.text('格式化'), findsOneWidget);
    expect(find.text('压缩'), findsOneWidget);
    expect(find.text('加解密'), findsOneWidget);
    expect(find.text('HAR'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('HAR 分析'), findsNothing);
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

  testWidgets('about update action survives switching tools', (tester) async {
    final theme = ThemeController(store: MemoryThemeStore());
    await tester.pumpWidget(DevKitApp(theme: theme, releases: _StubReleases()));
    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.textContaining('下载并安装'), findsOneWidget);

    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();
    expect(find.textContaining('下载并安装'), findsNothing);

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();
    expect(find.textContaining('下载并安装'), findsOneWidget);
  });

  testWidgets('json editor clears text on the same page', (tester) async {
    await tester.pumpWidget(const DevKitApp());
    final field = find.byType(TextField).first;
    await tester.enterText(field, '{"a":1}');
    await tester.pump();
    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(tester.widget<TextField>(field).controller?.text, isEmpty);
  });
}
