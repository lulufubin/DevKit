# AGENTS.md

DevKit 是跨平台桌面工作台（Windows / macOS / Linux）：Flutter 做界面，Rust 做计算。

远程：`https://github.com/lulufubin/DevKit.git`，默认分支 `main`。

## 产品

第一期工作台工具（已落地）：

- JSON 格式化 / 压缩 / 结构对比
- 编解码、哈希、AES-256-GCM、HMAC、RSA、国密 SM2/SM3/SM4
- HAR 导入、筛选、详情、导出，以及复制为 Python `requests`

另外，`crates/core` 还有一套流式 age 文件加解密（路径读写，不把整文件读进内存），供 CLI / 桌面复用。不要删掉它。

## 架构

- Flutter 在仓库根目录；FRB crate 在 `rust/`；共享逻辑在 `crates/core`。
- 给 Dart 的 API 写在 `rust/src/api/`。跨 crate 类型必须在 api 模块里重新定义，不要 `pub use` 到 FRB（否则会变成不透明类型）。
- 生成代码在 `lib/src/rust/` 与 `rust/src/frb_generated.*`，不要手改。
- 文本类工具上限约 20MB。密钥只在会话内使用，不写磁盘、不写日志。不做 HAR 重放。

## 常用命令

```powershell
$env:PATH = "D:\Tools\flutter\bin;$env:PATH"
flutter_rust_bridge_codegen generate
cargo test -p devkit-core
flutter analyze
flutter test
flutter run -d windows
```

本机没有 Developer Mode 时，先运行 `scripts/windows-plugin-junctions.ps1` 再 `flutter pub get` / `flutter run`。

`flutter build windows` / `flutter run -d windows` 需要 Visual Studio 的「使用 C++ 的桌面开发」工作负载（MSVC、CMake、Windows 10 SDK）。只有 VS 安装器、没有这套组件时，Flutter 会报无法找到 toolchain。

改完 `rust/src/api/` 必须重新 generate。

## 约定

- 注释、文档、界面文案用中文。
- 不要提交密钥、HAR cookie、`.dart_tool/`、`build/`、`target/`。
- 用户未要求时不要 `git commit` 或 `git push`。

## 改动汇报

每次改动结束时说明：改了什么、是否验证（命令与结果）、是否本地提交。
