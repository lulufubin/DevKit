import 'package:devkit/src/theme/theme_mode_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses stored theme mode and falls back to system', () {
    expect(parseThemeMode('system'), ThemeMode.system);
    expect(parseThemeMode('light'), ThemeMode.light);
    expect(parseThemeMode('dark'), ThemeMode.dark);
    expect(parseThemeMode(null), ThemeMode.system);
    expect(parseThemeMode('nope'), ThemeMode.system);
  });

  test('encodes theme mode for prefs', () {
    expect(encodeThemeMode(ThemeMode.system), 'system');
    expect(encodeThemeMode(ThemeMode.light), 'light');
    expect(encodeThemeMode(ThemeMode.dark), 'dark');
  });
}
