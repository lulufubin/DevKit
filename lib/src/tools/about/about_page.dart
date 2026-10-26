import 'dart:io';

import 'package:devkit/src/theme/theme_controller.dart';
import 'package:devkit/src/update/github_releases.dart';
import 'package:devkit/src/widgets/devkit_logo.dart';
import 'package:devkit/src/widgets/tool_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, required this.theme, this.releases});

  final ThemeController theme;
  final GithubReleases? releases;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with ToolFeedback {
  late final GithubReleases _releases = widget.releases ?? GithubReleases();
  String _version = '…';
  UpdateInfo? _update;
  String? _status;
  bool _busy = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  void dispose() {
    if (widget.releases == null) {
      _releases.close();
    }
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() => _version = info.version);
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _status = '正在检查…';
    });
    try {
      final info = await PackageInfo.fromPlatform();
      final latest = await _releases.fetchLatest(currentVersion: info.version);
      if (!mounted) {
        return;
      }
      setState(() {
        _update = latest;
        _status = latest == null ? '已是最新版本' : '发现新版本 ${latest.version}';
      });
    } catch (error) {
      reportError(error);
      if (mounted) {
        setState(() => _status = '检查失败');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _downloadAndInstall() async {
    final update = _update;
    if (update == null) {
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
      _status = '正在下载安装器…';
    });
    try {
      final file = await _releases.downloadInstaller(
        update,
        onProgress: (received, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            _progress = total == null || total == 0 ? null : received / total;
          });
        },
      );
      if (!mounted) {
        return;
      }
      await Process.start(file.path, const [], runInShell: true);
      reportMessage('已启动安装向导');
    } catch (error) {
      reportError(error);
      if (mounted) {
        setState(() => _status = '下载或启动失败');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '关于',
      child: ListView(
        children: [
          Row(
            children: [
              const DevKitLogo(size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DevKit', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('当前版本 $_version'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('JSON、加解密、HAR 工作台。密钥只在本次会话使用。'),
          const SizedBox(height: 20),
          Text('外观', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
              ButtonSegment(value: ThemeMode.light, label: Text('亮色')),
              ButtonSegment(value: ThemeMode.dark, label: Text('暗色')),
            ],
            selected: {widget.theme.mode},
            onSelectionChanged: (next) {
              widget.theme.setMode(next.single);
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: _busy ? null : _check, child: const Text('检查更新')),
              if (_update != null)
                FilledButton.tonal(
                  onPressed: _busy ? null : _downloadAndInstall,
                  child: Text('下载并安装 ${_update!.version}'),
                ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!),
          ],
          if (_progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress),
          ],
        ],
      ),
    );
  }
}
