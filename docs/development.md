# 开发说明

远程：`https://github.com/lulufubin/DevKit.git`，默认分支 `main`。

## 目录

- Flutter 应用在仓库根目录
- FRB crate：`rust/`
- 共享逻辑：`crates/core`
- CLI：`crates/cli`（二进制名 `devkit`）
- Windows 安装脚本：`installer/devkit.iss`

## 依赖

- Rust stable（`cargo`）
- Flutter 3.47+，并已启用桌面
- 改 Rust API 时需要 `flutter_rust_bridge_codegen` 2.13

本机 Flutter 在 `D:\Tools\flutter`。

`flutter build windows` / `flutter run -d windows` 需要 Visual Studio 的「使用 C++ 的桌面开发」工作负载（MSVC、CMake、Windows 10 SDK）。

## 常用命令

```powershell
$env:PATH = "D:\Tools\flutter\bin;$env:PATH"
flutter_rust_bridge_codegen generate
cargo test -p devkit-core
flutter analyze
flutter test
flutter run -d windows
```

GitHub Actions 的 `CI` 工作流会在 PR 和 `main` 上跑同一套测试，通过后才会自动合并并打包。

本机没有 Developer Mode 时，先运行 `scripts/windows-plugin-junctions.ps1` 再 `flutter pub get` / `flutter run`。

改完 `rust/src/api/` 必须重新 generate。跨 crate 类型要在 api 模块里重新定义，不要 `pub use` 到 FRB。

## 图标

亮色、暗色 SVG 在 `logo/`。改 `logo/devkit-logo-light.svg` 后重新生成系统图标：

```powershell
.\scripts\generate-icons.ps1
```

脚本调用 `cargo run -p devkit-icon-gen`，写出 Windows `app_icon.ico`、macOS `app_icon_*.png`、Linux 窗口图标和 hicolor png。生成结果检入仓库。

## CLI（age）

```bash
cargo run -p devkit-cli -- encrypt --input secret.bin --output secret.bin.age
cargo run -p devkit-cli -- decrypt --input secret.bin.age --output secret.bin
```

省略 `--passphrase` 会交互提示。脚本里传入口令会出现在进程列表中。

## 加解密库对比

哈希 / AES / HMAC 页的「对比」开关默认关闭。打开后同一输入分别走 Rust（进程内）、Python 助手（Nuitka + `cryptography`）、Node 助手（便携 `node.exe` + `crypto-js`）。

助手查找顺序：

1. `devkit.exe` 同级的 `helpers/crypto-python` 与 `helpers/crypto-node`
2. 仓库 `helpers/dist/`（本地先跑打包脚本）

找不到时该列提示「未找到助手，请先按文档打包」（Windows）或「当前安装包未带 Python / Node 助手」。不使用本机 PATH 上的 `python` / `node`。

```powershell
.\scripts\pack-helpers.ps1
.\scripts\test-helpers.ps1
```

源码自测用 `uv` 管 Python（`helpers/crypto-python/pyproject.toml`），用 `pnpm` 管 Node（`helpers/crypto-node`）。不要直接调用系统 `python` / `pip` / `npm`。密钥只经 stdin，不要写进日志。

## 约定

- 注释、文档、界面文案用中文；界面字体为 `fonts/` 下的思源黑体 CN
- 不要提交密钥、HAR cookie、`.dart_tool/`、`build/`、`target/`
- 用户未要求时不要 `git commit` 或 `git push`
