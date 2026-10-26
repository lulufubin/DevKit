import 'dart:io';

import 'package:devkit/src/tools/about/about_page.dart';
import 'package:devkit/src/tools/crypto/crypto_page.dart';
import 'package:devkit/src/tools/har/har_page.dart';
import 'package:devkit/src/tools/json/diff_page.dart';
import 'package:devkit/src/tools/json/format_page.dart';
import 'package:devkit/src/tools/json/minify_page.dart';
import 'package:devkit/src/update/github_releases.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DevKitApp extends StatelessWidget {
  const DevKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevKit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const WorkbenchShell(),
    );
  }
}

enum ToolKind { jsonFormat, jsonMinify, jsonDiff, crypto, har, about }

class WorkbenchShell extends StatefulWidget {
  const WorkbenchShell({super.key, this.releases});

  final GithubReleases? releases;

  @override
  State<WorkbenchShell> createState() => _WorkbenchShellState();
}

class _WorkbenchShellState extends State<WorkbenchShell> {
  ToolKind _tool = ToolKind.jsonFormat;

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
            onDestinationSelected: (index) {
              setState(() => _tool = ToolKind.values[index]);
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.data_object_outlined),
                selectedIcon: Icon(Icons.data_object),
                label: Text('JSON 格式化'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.compress_outlined),
                selectedIcon: Icon(Icons.compress),
                label: Text('JSON 压缩'),
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
          Expanded(child: _pageFor(_tool)),
        ],
      ),
    );
  }

  Widget _pageFor(ToolKind tool) {
    switch (tool) {
      case ToolKind.jsonFormat:
        return const JsonFormatPage();
      case ToolKind.jsonMinify:
        return const JsonMinifyPage();
      case ToolKind.jsonDiff:
        return const JsonDiffPage();
      case ToolKind.crypto:
        return const CryptoPage();
      case ToolKind.har:
        return const HarPage();
      case ToolKind.about:
        return AboutPage(releases: widget.releases);
    }
  }
}
