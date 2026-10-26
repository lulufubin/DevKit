# Logo 与亮暗主题 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 工作台支持系统默认并可覆盖的亮/暗主题，界面随亮度切换 logo，Windows / macOS / Linux 系统图标换成亮色品牌图。

**Architecture:** 纯函数编解码 `theme_mode`；`ThemeController` + 可注入 `ThemeStore` 驱动 `MaterialApp.themeMode`；`DevKitLogo` 只读 `Theme.brightness`。系统图标由 `devkit-icon-gen` 从 `logo/devkit-logo-light.svg` 生成并检入。

**Tech Stack:** Flutter Material 3、`flutter_svg`、`shared_preferences`、Rust `resvg` / `ico`。

## Global Constraints

- 界面文案、注释、文档用中文。
- 偏好键必须是 `theme_mode`；合法值只有 `system` / `light` / `dark`。
- 种子色 `#1565C0`；暗色 `ColorScheme.fromSeed(..., brightness: Brightness.dark)`。
- 亮色 logo：`logo/devkit-logo-light.svg`；暗色：`logo/devkit-logo-dark.svg`。
- 不引入 `window_manager`；不按主题更换 exe / 窗口资源图标。
- 不改工具页业务；不改 `pubspec.yaml` 版本号。
- 不提交密钥；用户未要求时不要 `git commit`。
- 用户未要求时跳过每个任务末尾的 Commit 步骤。

---

## File map

- Create: `lib/src/theme/theme_mode_codec.dart` — `parseThemeMode` / `encodeThemeMode`
- Create: `lib/src/theme/theme_store.dart` — `ThemeStore`、`MemoryThemeStore`、`PrefsThemeStore`
- Create: `lib/src/theme/theme_controller.dart` — `ThemeController`
- Create: `lib/src/widgets/devkit_logo.dart` — `logoAssetFor`、`DevKitLogo`
- Create: `test/theme_mode_test.dart`
- Create: `test/theme_controller_test.dart`
- Create: `test/logo_asset_test.dart`
- Create: `test/logo_widget_test.dart`
- Create: `crates/icon-gen/` — 生成 ico / png
- Create: `scripts/generate-icons.ps1`
- Create: `linux/runner/resources/app_icon.png`
- Create: `linux/hicolor/*/apps/devkit.png`
- Create: `linux/devkit.desktop`
- Modify: `lib/main.dart`、`lib/src/app.dart`、`lib/src/tools/about/about_page.dart`
- Modify: `pubspec.yaml`（依赖与 assets）
- Modify: `Cargo.toml`（workspace member）
- Modify: `linux/CMakeLists.txt`、`linux/runner/my_application.cc`
- Modify: `windows/runner/resources/app_icon.ico`
- Modify: `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png`
- Modify: `docs/development.md`、`docs/packaging.md`
- Modify: `test/widget_test.dart`

---

### Task 1: 主题模式编解码

**Files:**
- Create: `lib/src/theme/theme_mode_codec.dart`
- Test: `test/theme_mode_test.dart`

**Interfaces:**
- Consumes: `package:flutter/material.dart` 的 `ThemeMode`
- Produces: `ThemeMode parseThemeMode(String? raw)`；`String encodeThemeMode(ThemeMode mode)`

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme_mode_test.dart`

Expected: FAIL，找不到 `theme_mode_codec.dart`

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';

ThemeMode parseThemeMode(String? raw) {
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String encodeThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme_mode_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

跳过（用户未要求提交）。

---

### Task 2: ThemeController 与可注入存储

**Files:**
- Create: `lib/src/theme/theme_store.dart`
- Create: `lib/src/theme/theme_controller.dart`
- Test: `test/theme_controller_test.dart`

**Interfaces:**
- Consumes: `parseThemeMode`、`encodeThemeMode`
- Produces:
  - `abstract class ThemeStore { Future<String?> read(); Future<void> write(String value); }`
  - `class MemoryThemeStore implements ThemeStore { MemoryThemeStore([this.value]); String? value; }`
  - `class PrefsThemeStore implements ThemeStore`（键 `theme_mode`；读失败返回 `null`；写失败吞掉）
  - `class ThemeController extends ChangeNotifier { ThemeController({ThemeStore? store, ThemeMode mode = ThemeMode.system}); ThemeMode get mode; Future<void> load(); Future<void> setMode(ThemeMode mode); }`

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme_controller_test.dart`

Expected: FAIL，找不到 `theme_controller.dart`

- [ ] **Step 3: Write minimal implementation**

`theme_store.dart`：

```dart
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
```

在 `theme_mode_codec.dart` 增加 `const themeModePrefsKey = 'theme_mode';`

`theme_controller.dart`：

```dart
import 'package:flutter/material.dart';

import 'theme_mode_codec.dart';
import 'theme_store.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({ThemeStore? store, ThemeMode mode = ThemeMode.system})
      : _store = store ?? PrefsThemeStore(),
        _mode = mode;

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
```

`pubspec.yaml` 的 `dependencies` 增加 `shared_preferences: ^2.5.3`，然后 `flutter pub get`。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme_controller_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

跳过。

---

### Task 3: Logo 资源路径与组件

**Files:**
- Create: `lib/src/widgets/devkit_logo.dart`
- Test: `test/logo_asset_test.dart`
- Test: `test/logo_widget_test.dart`
- Modify: `pubspec.yaml`（`flutter_svg` + assets）

**Interfaces:**
- Consumes: `Theme.of(context).brightness`
- Produces: `String logoAssetFor(Brightness brightness)`；`class DevKitLogo extends StatelessWidget { const DevKitLogo({super.key, required this.size}); final double size; }`，内部 `SvgPicture.asset` 的 `key` 为 `ValueKey(asset)`

- [ ] **Step 1: Write the failing tests**

`test/logo_asset_test.dart`：

```dart
import 'package:devkit/src/widgets/devkit_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('picks logo asset from brightness', () {
    expect(logoAssetFor(Brightness.light), 'logo/devkit-logo-light.svg');
    expect(logoAssetFor(Brightness.dark), 'logo/devkit-logo-dark.svg');
  });
}
```

`test/logo_widget_test.dart`：

```dart
import 'package:devkit/src/widgets/devkit_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders dark logo when theme is dark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(body: DevKitLogo(size: 40)),
      ),
    );
    expect(find.byKey(const ValueKey('logo/devkit-logo-dark.svg')), findsOneWidget);
  });

  testWidgets('renders light logo when theme is light', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: Scaffold(body: DevKitLogo(size: 40)),
      ),
    );
    expect(find.byKey(const ValueKey('logo/devkit-logo-light.svg')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/logo_asset_test.dart test/logo_widget_test.dart`

Expected: FAIL，找不到 `devkit_logo.dart`

- [ ] **Step 3: Write minimal implementation**

`pubspec.yaml`：

```yaml
  flutter_svg: ^2.2.3
```

```yaml
flutter:
  uses-material-design: true
  assets:
    - logo/devkit-logo-light.svg
    - logo/devkit-logo-dark.svg
```

`devkit_logo.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

String logoAssetFor(Brightness brightness) {
  return brightness == Brightness.dark
      ? 'logo/devkit-logo-dark.svg'
      : 'logo/devkit-logo-light.svg';
}

class DevKitLogo extends StatelessWidget {
  const DevKitLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = logoAssetFor(Theme.of(context).brightness);
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      key: ValueKey(asset),
    );
  }
}
```

然后 `flutter pub get`。

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/logo_asset_test.dart test/logo_widget_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

跳过。

---

### Task 4: 接入 MaterialApp、侧栏、关于页

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/src/app.dart`
- Modify: `lib/src/tools/about/about_page.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `ThemeController`、`DevKitLogo`
- Produces: `DevKitApp({ThemeController? theme, GithubReleases? releases})`；`WorkbenchShell` / `AboutPage` 接收同一个 `ThemeController`；关于页分段文案「跟随系统」「亮色」「暗色」

- [ ] **Step 1: Write the failing widget coverage in `test/widget_test.dart`**

在现有测试前加 `setUpAll`（`SharedPreferences.setMockInitialValues({})`），并追加：

```dart
  testWidgets('about page can lock dark theme and show dark logo', (tester) async {
    final theme = ThemeController(store: MemoryThemeStore());
    await tester.pumpWidget(DevKitApp(theme: theme));
    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('暗色'));
    await tester.pumpAndSettle();
    expect(theme.mode, ThemeMode.dark);
    expect(find.byKey(const ValueKey('logo/devkit-logo-dark.svg')), findsWidgets);
  });
```

需要的 import：`theme_controller.dart`、`theme_store.dart`、`shared_preferences`。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`

Expected: FAIL（`DevKitApp` 还没有 `theme` 参数，或没有「暗色」按钮）

- [ ] **Step 3: Write minimal implementation**

`main.dart`：

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final theme = ThemeController();
  await theme.load();
  runApp(DevKitApp(theme: theme));
}
```

`DevKitApp` 改为接收 `theme` / `releases`。若 `theme == null`，内部 `ThemeController()` 并在 `initState` 里 `load()`。`build` 用 `ListenableBuilder`：

```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
  useMaterial3: true,
),
darkTheme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1565C0),
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
),
themeMode: controller.mode,
```

`NavigationRail.leading`：

```dart
leading: const Padding(
  padding: EdgeInsets.only(bottom: 8),
  child: DevKitLogo(size: 40),
),
```

把 `controller` 传给 `WorkbenchShell` 与 `AboutPage`。

关于页标题行：

```dart
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
```

分段控件：

```dart
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
```

`AboutPage` 增加必填 `ThemeController theme`。测试里的 `AboutPage(releases: ...)` 也要带上。

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widget_test.dart test/theme_mode_test.dart test/theme_controller_test.dart test/logo_asset_test.dart test/logo_widget_test.dart`

Expected: 全部 PASS。再跑 `flutter analyze`（无 issue）。

- [ ] **Step 5: Commit**

跳过。

---

### Task 5: 系统图标（Windows / macOS / Linux）

**Files:**
- Create: `crates/icon-gen/Cargo.toml`
- Create: `crates/icon-gen/src/main.rs`
- Create: `scripts/generate-icons.ps1`
- Create: `linux/devkit.desktop`
- Modify: `Cargo.toml`（`members` 加入 `crates/icon-gen`）
- Modify: `linux/CMakeLists.txt`、`linux/runner/my_application.cc`
- Generate: `windows/runner/resources/app_icon.ico`
- Generate: `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{16,32,64,128,256,512,1024}.png`
- Generate: `linux/runner/resources/app_icon.png`（512）
- Generate: `linux/hicolor/{16x16,32x32,48x48,256x256,512x512}/apps/devkit.png`
- Modify: `docs/development.md`、`docs/packaging.md`

**Interfaces:**
- Consumes: `logo/devkit-logo-light.svg`
- Produces: 上述检入的 ico/png；GTK 从 bundle `data/app_icon.png` 设窗口图标

- [ ] **Step 1: Add `devkit-icon-gen` and generate files**

`crates/icon-gen/Cargo.toml`：

```toml
[package]
name = "devkit-icon-gen"
version.workspace = true
edition.workspace = true
license.workspace = true
publish = false

[dependencies]
ico = "0.4"
resvg = "0.45"
tiny-skia = "0.11"
```

`main.rs` 从仓库根读取 `logo/devkit-logo-light.svg`，按边长渲染正方形 pixmap，写出：

- ICO 帧：16、32、48、256 → `windows/runner/resources/app_icon.ico`
- macOS png：16、32、64、128、256、512、1024
- Linux：`linux/runner/resources/app_icon.png` = 512；hicolor 16/32/48/256/512

渲染时 `fit_to = FitTo::Size(n, n)`（或等价 API），背景按 SVG 自身白底，不要再垫一层。

`scripts/generate-icons.ps1`：

```powershell
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
cargo run -p devkit-icon-gen --locked
```

第一次若无 lock 变更则可不加 `--locked`，生成后再 `cargo generate-lockfile` 如有新 crate。

`linux/devkit.desktop`：

```
[Desktop Entry]
Type=Application
Name=DevKit
Comment=JSON、加解密、HAR 工作台
Exec=devkit
Icon=devkit
Terminal=false
Categories=Development;Utility;
StartupWMClass=com.lulufubin.devkit
```

`linux/CMakeLists.txt` 在安装 ICU 附近增加：

```cmake
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/runner/resources/app_icon.png"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)
```

`my_application.cc` 在 `gtk_window_set_default_size` 之后：

```c
{
  g_autoptr(GError) icon_error = nullptr;
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  g_autofree gchar* dir = exe != nullptr ? g_path_get_dirname(exe) : g_strdup(".");
  g_autofree gchar* icon = g_build_filename(dir, "data", "app_icon.png", nullptr);
  if (!gtk_window_set_icon_from_file(window, icon, &icon_error)) {
    g_warning("Failed to set window icon: %s",
              icon_error != nullptr ? icon_error->message : "unknown");
  }
}
```

- [ ] **Step 2: Run generator**

Run: `cargo run -p devkit-icon-gen`

Expected: 退出 0，上述 png/ico 存在且非空。

- [ ] **Step 3: Docs**

`docs/development.md` 增加「图标」一节：改 `logo/devkit-logo-light.svg` 后运行 `.\scripts\generate-icons.ps1`。

`docs/packaging.md` 加一句：替换系统图标后，已安装的 Windows 用户可能看到旧任务栏图标，重装或清图标缓存即可。

- [ ] **Step 4: Verify Dart tests still pass**

Run: `flutter test`

Expected: PASS

- [ ] **Step 5: Commit**

跳过。

---

## Self-review

1. Spec coverage：主题编解码、控制器、logo 切换、关于页覆盖、三套系统图标、文档、测试均有对应任务。Linux 已纳入 Task 5。
2. 无 TBD / “类似 Task N”。
3. 名称一致：`theme_mode`、`parseThemeMode`、`ThemeController.setMode`、`logoAssetFor`、`DevKitLogo`。
