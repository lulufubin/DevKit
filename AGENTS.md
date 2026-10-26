# AGENTS.md

DevKit 是跨平台桌面工作台（Windows / macOS / Linux）：Flutter 做界面，Rust 做计算。

远程：`https://github.com/lulufubin/DevKit.git`，默认分支 `main`。

产品说明与更新日志见 [README.md](README.md)。开发命令与环境见 [docs/development.md](docs/development.md)。安装包与 Release 见 [docs/packaging.md](docs/packaging.md)。

## 架构要点

- Flutter 在仓库根目录；FRB crate 在 `rust/`；共享逻辑在 `crates/core`。
- 给 Dart 的 API 写在 `rust/src/api/`。跨 crate 类型必须在 api 模块里重新定义，不要 `pub use` 到 FRB。
- 生成代码在 `lib/src/rust/` 与 `rust/src/frb_generated.*`，不要手改。
- 文本类工具上限约 20MB。密钥只在会话内使用，不写磁盘、不写日志。不做 HAR 重放。
- `crates/core` 的流式 age 加解密不要删掉。

## 约定

- 注释、文档、界面文案用中文。
- 不要提交密钥、HAR cookie、`.dart_tool/`、`build/`、`target/`。
- 用户未要求时不要 `git commit` 或 `git push`。

## 改动汇报

每次改动结束时说明：改了什么、是否验证（命令与结果）、是否本地提交。
