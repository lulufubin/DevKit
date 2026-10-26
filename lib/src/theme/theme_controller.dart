import 'package:flutter/material.dart';

import 'theme_mode_codec.dart';
import 'theme_store.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({ThemeStore? store, this._mode = ThemeMode.system})
      : _store = store ?? PrefsThemeStore();

  final ThemeStore _store;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    _mode = parseThemeMode(await _store.read());
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    await _store.write(encodeThemeMode(mode));
  }
}
