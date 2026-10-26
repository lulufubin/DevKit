import 'package:shared_preferences/shared_preferences.dart';

import 'theme_mode_codec.dart';

abstract class ThemeStore {
  Future<String?> read();
  Future<void> write(String value);
}

class MemoryThemeStore implements ThemeStore {
  MemoryThemeStore([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String next) async {
    value = next;
  }
}

class PrefsThemeStore implements ThemeStore {
  static const key = themeModePrefsKey;

  @override
  Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }
}
