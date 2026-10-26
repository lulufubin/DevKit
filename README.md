# DevKit

跨平台桌面工作台：Flutter 做界面，Rust 做计算。支持 Windows / macOS / Linux。

## 第一期工具

- JSON 格式化、压缩、结构对比
- 编解码、哈希、AES-256-GCM、HMAC、RSA、国密 SM2 / SM3 / SM4
- HAR 导入、筛选、详情、导出，以及复制为 Python `requests`
- 另有流式 age 文件加解密（`crates/core` + CLI），不把整文件读进内存

密钥只在本次会话使用，不写磁盘。不做 HAR 重放。

## 目录

- Flutter 应用在仓库根目录
- FRB crate：`rust/`
- 共享逻辑：`crates/core`
- CLI：`crates/cli`（二进制名 `devkit`）

## 依赖

- Rust stable（`cargo`）
- Flutter 3.47+，并已启用桌面
- 改 Rust API 时需要 `flutter_rust_bridge_codegen` 2.13

本机 Flutter 在 `D:\Tools\flutter`。

## 本地运行

```powershell
$env:PATH = "D:\Tools\flutter\bin;$env:PATH"
flutter_rust_bridge_codegen generate
cargo test -p devkit-core
flutter analyze
flutter test
flutter run -d windows
```

Windows 没有 Developer Mode 时，先运行：

```powershell
.\scripts\windows-plugin-junctions.ps1
```

再 `flutter pub get` / `flutter run` / `flutter build windows`。

### CLI（age）

```bash
cargo run -p devkit-cli -- encrypt --input secret.bin --output secret.bin.age
cargo run -p devkit-cli -- decrypt --input secret.bin.age --output secret.bin
```

省略 `--passphrase` 会交互提示。脚本里传入口令会出现在进程列表中。

GitHub Release 里：

- `devkit-desktop-windows-amd64.zip`：桌面工作台。解压后运行 `devkit.exe`
- `devkit-cli-windows-amd64.exe`：命令行加解密，需在终端里带 `encrypt` / `decrypt` 使用。单独双击不是图形界面

## 约定

- 注释、文档、界面文案用中文
- 不要提交密钥、HAR cookie、`.dart_tool/`、`build/`、`target/`
- 用户未要求时不要 `git commit` 或 `git push`
