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

## 交付流程

每完成一项可独立交付的改动（功能、修复、约定或文档）后，按顺序做完，并向用户汇报每一步：

1. **自动提交**：`git commit`，说明为什么改。不提交密钥和构建产物。
2. **审查**：跑相关测试与分析，核对实现是否对题。有问题先修再审，不要带病推送。
3. **无问题则自动推送并合并**：推送分支、开 PR，等 CI 通过后合进 `main`（可用仓库 Automerge）。
4. **汇报**：立刻告诉用户改了什么；若是修复，说明修的是什么问题；验证命令与结果；是否已提交、推送、合并（含 PR 链接）。

当次对话另有指示时，以当次指示为准。
