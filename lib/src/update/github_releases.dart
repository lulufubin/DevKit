import 'dart:convert';
import 'dart:io';

import 'package:devkit/src/update/version.dart';
import 'package:http/io_client.dart';

const githubLatestReleaseUrl = 'https://api.github.com/repos/lulufubin/DevKit/releases/latest';

class UpdateInfo {
  const UpdateInfo({
    required this.tag,
    required this.version,
    required this.installerUrl,
    required this.notes,
  });

  final String tag;
  final String version;
  final String installerUrl;
  final String notes;
}

class GithubReleases {
  GithubReleases({IOClient? client, this.latestUrl = githubLatestReleaseUrl})
    : _client = client ?? IOClient(HttpClient()..findProxy = HttpClient.findProxyFromEnvironment);

  final IOClient _client;
  final String latestUrl;

  Future<UpdateInfo?> fetchLatest({required String currentVersion}) async {
    final response = await _client.get(
      Uri.parse(latestUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'DevKit',
      },
    );
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('检查更新失败：HTTP ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    if (json is! Map) {
      throw const FormatException('GitHub 返回的不是对象');
    }
    final tag = json['tag_name']?.toString() ?? '';
    final assets = <GithubAsset>[];
    final rawAssets = json['assets'];
    if (rawAssets is List) {
      for (final item in rawAssets) {
        if (item is Map) {
          final name = item['name']?.toString() ?? '';
          final url = item['browser_download_url']?.toString() ?? '';
          if (name.isNotEmpty && url.isNotEmpty) {
            assets.add(GithubAsset(name: name, url: url));
          }
        }
      }
    }
    final installer = findDesktopInstaller(assets);
    if (installer == null || !isNewerRelease(current: currentVersion, latest: tag)) {
      return null;
    }
    return UpdateInfo(
      tag: tag,
      version: normalizeSemver(tag),
      installerUrl: installer.url,
      notes: json['body']?.toString() ?? '',
    );
  }

  Future<File> downloadInstaller(
    UpdateInfo info, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final client = HttpClient()..findProxy = HttpClient.findProxyFromEnvironment;
    try {
      final request = await client.getUrl(Uri.parse(info.installerUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'DevKit');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('下载安装器失败：HTTP ${response.statusCode}');
      }
      final dest = File('${Directory.systemTemp.path}${Platform.pathSeparator}$desktopInstallerAssetName');
      final sink = dest.openWrite();
      var received = 0;
      final total = response.contentLength < 0 ? null : response.contentLength;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      return dest;
    } finally {
      client.close();
    }
  }

  void close() {
    _client.close();
  }
}
