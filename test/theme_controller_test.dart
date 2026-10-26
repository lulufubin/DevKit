import 'package:devkit/src/theme/theme_controller.dart';
import 'package:devkit/src/theme/theme_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('load reads store and rejects illegal values', () async {
    final store = MemoryThemeStore('dark');
    final controller = ThemeController(store: store);
    await controller.load();
    expect(controller.mode, ThemeMode.dark);

    store.value = 'nope';
    await controller.load();
    expect(controller.mode, ThemeMode.system);
  });

  test('setMode updates memory then writes encoded value', () async {
    final store = MemoryThemeStore();
    final controller = ThemeController(store: store);
    final notified = <ThemeMode>[];
    controller.addListener(() => notified.add(controller.mode));

    await controller.setMode(ThemeMode.light);
    expect(controller.mode, ThemeMode.light);
    expect(store.value, 'light');
    expect(notified, [ThemeMode.light]);
  });
}
