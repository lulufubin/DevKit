# Logo 与亮暗主题

界面接入仓库 `logo/` 下的亮色、暗色 SVG；关于页可覆盖系统主题并记住选择；Windows / macOS / Linux 系统图标换成同一套品牌图。不引入窗口管理插件，不在运行时更换 exe 资源图标。

## 目标

- 工作台同时提供亮色、暗色 Material 3 主题。
- 默认跟随操作系统；用户可在「关于」固定为亮色或暗色，重启后仍有效。
- 侧栏顶部和「关于」页展示 logo，随当前界面亮度切换文件。
- 安装器、exe、任务栏、Linux 窗口使用从亮色 logo 生成的静态系统图标。

## 非目标

- 不按主题实时更换 Windows 窗口 / 文件图标。
- 不新增独立「外观」页或设置文件。
- 不改工具页业务逻辑，也不发新版本号（打包仍按现有流程）。

## 资源

| 用途 | 文件 |
| --- | --- |
| 亮色界面 | `logo/devkit-logo-light.svg`（白底黑标） |
| 暗色界面 | `logo/devkit-logo-dark.svg`（黑底白标） |
| Windows 图标 | `windows/runner/resources/app_icon.ico`（由亮色 SVG 生成，含 16/32/48/256） |
| macOS 图标 | `macos/Runner/Assets.xcassets/AppIcon.appiconset/`（由亮色 SVG 导出对应 png） |
| Linux 窗口图标 | `linux/runner/resources/app_icon.png`（512，由亮色 SVG 导出） |
| Linux 桌面图标 | `linux/hicolor/{16x16,32x32,48x48,256x256,512x512}/apps/devkit.png` |
| Linux 桌面项 | `linux/devkit.desktop`（`Icon=devkit`） |

`pubspec.yaml` 增加：

```yaml
flutter:
  assets:
    - logo/devkit-logo-light.svg
    - logo/devkit-logo-dark.svg
```

依赖：`flutter_svg` 显示 SVG；`shared_preferences` 记住主题。不新增 `window_manager`。

图标用 `scripts/generate-icons.ps1` 调用 `cargo run -p devkit-icon-gen`，从亮色 SVG 用 `resvg` 渲染。生成结果检入仓库，日常开发不强制跑脚本。步骤补进 `docs/development.md`。不依赖 ImageMagick。

## 主题

根上放一个 `ThemeController`（`ChangeNotifier`）：启动时读偏好，`mode` 变化时 `notifyListeners`。`DevKitApp` 用 `ListenableBuilder` 把它写进 `MaterialApp.themeMode`，并提供成对的 `theme` / `darkTheme`。关于页通过构造参数拿到同一个控制器。`themeMode` 为下面三者之一：

| 存储值 | `ThemeMode` | 界面 |
| --- | --- | --- |
| `system`（缺省） | `ThemeMode.system` | 跟操作系统 |
| `light` | `ThemeMode.light` | 固定亮色 |
| `dark` | `ThemeMode.dark` | 固定暗色 |

- 偏好键：`theme_mode`。
- 非法值、读失败、插件不可用：视为 `system`，不弹错误。
- 写失败：界面立刻按新选择切换，但重启可能回到旧值；不单独提示。
- 种子色保持 `#1565C0`，暗色用 `ColorScheme.fromSeed(..., brightness: Brightness.dark)`。

关于页增加分段控件，文案为「跟随系统」「亮色」「暗色」。点选后立刻变主题并写入偏好。

## 界面 logo

抽取小组件（例如 `DevKitLogo`）：

- 根据 `Theme.of(context).brightness` 选文件：`Brightness.light` → light SVG，`Brightness.dark` → dark SVG。
- 侧栏：`NavigationRail.leading`，边长约 40。
- 关于页：标题行左侧，边长约 72，仍显示「DevKit」与版本说明。

当前亮度只由 Flutter `Theme` 决定，不单独读操作系统。

## 系统图标

- 覆盖现有 `app_icon.ico`；`installer/devkit.iss` 的 `SetupIconFile` 已指向该文件，不必改路径。
- 同步替换 macOS `app_icon_*.png`，避免以后打 macOS 包仍是默认 Flutter 图标。
- Linux：CMake 把 `app_icon.png` 装进 bundle 的 `data/`；`my_application.cc` 用该文件设置 GTK 窗口图标。`devkit.desktop` 与 hicolor png 检入仓库，供打包/桌面环境使用。不改 `pack.sh` 的目录结构。

## 数据流

1. 启动：读 `theme_mode` → 得到 `ThemeMode` → `MaterialApp`。
2. 用户改关于页分段：更新内存中的 mode → 重建 `MaterialApp` → 异步写入偏好。
3. 主题重建后，logo 组件按新 `brightness` 换 SVG。

## 测试

- 存储层：`system` / `light` / `dark` 读写；非法字符串回退 `system`。
- logo 选择：给定 `Brightness` 得到对应 asset 路径。
- 组件：泵一发带 `ThemeMode.dark` 的应用，侧栏或关于页能找到暗色 logo 资源；亮色同理。
- 不比对 ICO 像素，不测真实 `SharedPreferences` 插件通道（用内存假实现）。

现有 `workbench shows tool navigation` 须在接入后仍通过。

## 风险

- Windows 任务栏图标在资源替换后，已安装用户可能看到旧图标缓存，需重装或清图标缓存；文档里一句即可。
- 无 `magick` 时不能本地重生成 ICO；以检入文件为准。
