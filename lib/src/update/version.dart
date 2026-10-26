/// GitHub Release 资源。
class GithubAsset {
  const GithubAsset({required this.name, required this.url});

  final String name;
  final String url;
}

/// 去掉标签前的 `v` / `V`。
String normalizeSemver(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
    return trimmed.substring(1);
  }
  return trimmed;
}

List<int> _parts(String version) {
  return normalizeSemver(version)
      .split('.')
      .map((part) => int.tryParse(part.split(RegExp(r'[^0-9]')).first) ?? 0)
      .toList();
}

/// 比较两个 semver。大于 0 表示 [left] 更新。
int compareSemver(String left, String right) {
  final a = _parts(left);
  final b = _parts(right);
  final len = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < len; i++) {
    final av = i < a.length ? a[i] : 0;
    final bv = i < b.length ? b[i] : 0;
    if (av != bv) {
      return av.compareTo(bv);
    }
  }
  return 0;
}

bool isNewerRelease({required String current, required String latest}) {
  return compareSemver(latest, current) > 0;
}

const desktopInstallerAssetName = 'devkit-desktop-windows-amd64.exe';

GithubAsset? findDesktopInstaller(Iterable<GithubAsset> assets) {
  for (final asset in assets) {
    if (asset.name == desktopInstallerAssetName) {
      return asset;
    }
  }
  return null;
}
