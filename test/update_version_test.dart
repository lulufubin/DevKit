import 'package:devkit/src/update/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strips v prefix and compares semver', () {
    expect(compareSemver('0.2.0', 'v0.1.1'), greaterThan(0));
    expect(compareSemver('v0.1.1', '0.2.0'), lessThan(0));
    expect(compareSemver('0.2.0', 'v0.2.0'), 0);
  });

  test('newer release is detected', () {
    expect(isNewerRelease(current: '0.1.1', latest: 'v0.2.0'), isTrue);
    expect(isNewerRelease(current: '0.2.0', latest: 'v0.2.0'), isFalse);
    expect(isNewerRelease(current: '0.2.0', latest: '0.1.9'), isFalse);
  });

  test('picks desktop installer asset', () {
    const assets = [
      GithubAsset(name: 'notes.txt', url: 'https://example/notes'),
      GithubAsset(name: 'devkit-desktop-windows-amd64.exe', url: 'https://example/setup'),
    ];
    expect(findDesktopInstaller(assets)?.url, 'https://example/setup');
    expect(findDesktopInstaller(const []), isNull);
  });
}
