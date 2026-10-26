import 'dart:io';

import 'package:devkit/src/theme/theme_controller.dart';
import 'package:devkit/src/tools/about/about_page.dart';
import 'package:devkit/src/tools/crypto/crypto_page.dart';
import 'package:devkit/src/tools/har/har_page.dart';
import 'package:devkit/src/tools/json/diff_page.dart';
import 'package:devkit/src/tools/json/json_page.dart';
import 'package:devkit/src/update/github_releases.dart';
import 'package:devkit/src/widgets/devkit_logo.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _seed = Color(0xFF1565C0);
const sourceHanSansFamily = 'SourceHanSans';

ThemeData _appTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
    useMaterial3: true,
    fontFamily: sourceHanSansFamily,
  );
}

class DevKitApp extends StatefulWidget {
  const DevKitApp({super.key, this.theme, this.releases});

  final ThemeController? theme;
  final GithubReleases? releases;

  @override
  State<DevKitApp> createState() => _DevKitAppState();
}

class _DevKitAppState extends State<DevKitApp> {
  late final ThemeController _theme = widget.theme ?? ThemeController();
  late final bool _ownsTheme = widget.theme == null;

  @override
  void initState() {
    super.initState();
    if (_ownsTheme) {
      _theme.load();
    }
  }

  @override
  void dispose() {
    if (_ownsTheme) {
      _theme.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _theme,
      builder: (context, _) {
        return MaterialApp(
          title: 'DevKit',
          debugShowCheckedModeBanner: false,
          theme: _appTheme(Brightness.light),
          darkTheme: _appTheme(Brightness.dark),
          themeMode: _theme.mode,
          home: WorkbenchShell(theme: _theme, releases: widget.releases),
        );
      },
    );
  }
}

enum ToolKind { json, jsonDiff, crypto, har, about }

class WorkbenchShell extends StatefulWidget {
  const WorkbenchShell({super.key, required this.theme, this.releases});

  final ThemeController theme;
  final GithubReleases? releases;

  @override
  State<WorkbenchShell> createState() => _WorkbenchShellState();
}

class _WorkbenchShellState extends State<WorkbenchShell> {
  ToolKind _tool = ToolKind.json;
  late final List<Widget> _pages = [
    const JsonPage(),
    const JsonDiffPage(),
    const CryptoPage(),
    const HarPage(),
    AboutPage(theme: widget.theme, releases: widget.releases),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _silentUpdateCheck();
    });
  }

  Future<void> _silentUpdateCheck() async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      return;
    }
    final owned = widget.releases == null;
    final releases = widget.releases ?? GithubReleases();
    try {
      final info = await PackageInfo.fromPlatform();
      final latest = await releases.fetchLatest(currentVersion: info.version);
      if (!mounted || latest == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发现新版本 ${latest.version}，可在「关于」中更新')),
      );
    } catch (_) {
      // 启动检查失败时不打扰用户。
    } finally {
      if (owned) {
        releases.close();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tool.index,
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: DevKitLogo(size: 40),
            ),
            onDestinationSelected: (index) {
              setState(() => _tool = ToolKind.values[index]);
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.data_object_outlined),
                selectedIcon: Icon(Icons.data_object),
                label: Text('JSON'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.difference_outlined),
                selectedIcon: Icon(Icons.difference),
                label: Text('JSON 对比'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.lock_outline),
                selectedIcon: Icon(Icons.lock),
                label: Text('加解密'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.http_outlined),
                selectedIcon: Icon(Icons.http),
                label: Text('HAR'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.info_outline),
                selectedIcon: Icon(Icons.info),
                label: Text('关于'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _tool.index,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }
}
