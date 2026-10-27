# 桌面壳从 Flutter 换成 GPUI

一次替换：删掉 Flutter / FRB，新建 GPUI-CE 工作台，直接调用 `devkit-core`。功能与现网对齐（JSON、加解密对比、HAR 分栏详情、关于与更新、Windows 安装包），界面按编辑器式重做，不复刻 Flutter 布局。

## 目标

- 用户打开的仍是 `devkit-desktop-windows-amd64.exe`，覆盖安装（同一 Inno `AppId`）。
- 五个入口都在：JSON、JSON 对比、加解密、HAR、关于。
- 计算仍在 `crates/core`：JSON 严格/宽容、加解密、三库对比助手、HAR 导入不设大小上限、流式 age 保留给 CLI。
- 界面用 GPUI-CE，编辑器式：窄活动栏 + 主区 + 按需侧栏/底栏。
- 中文文案、思源黑体、系统亮暗可覆盖、密钥只在会话内。
- 版本升到 **0.3.0**，changelog 写明换壳。

## 非目标

- 不保留 Flutter、Dart、FRB、`lib/`、`rust/`、`rust_builder/` 双栈。
- 不把 Zed 编辑器源码当 git 依赖。
- 不做 HAR 重放，不把密钥写磁盘或日志。
- 第一期仍只发 Windows 图形安装包；macOS / Linux 可 `cargo run`，不新增正式包。
- 不把 Python / Node 助手改成 PATH 依赖；查找顺序与现网一致。
- 不要求像素级复刻现有 Flutter 页面。

## 决策

| 项 | 选择 |
| --- | --- |
| 节奏 | 一次换完，不留 Flutter |
| 功能 | 全量对齐 |
| 外观 | 重设计 |
| 壳 | 编辑器式（活动栏 + 主区 + 按需面板） |
| UI 框架 | GPUI-CE 0.3（`gpui-ce` + `gpui_ce_platform`） |
| 接线 | `crates/desktop` 直接调 `devkit-core` |
| 发布 | 现有 Inno 安装器，exe 改为 cargo Release |

## 架构

```
crates/desktop   GPUI 窗口、工具页、主题、更新
crates/core      JSON / 加解密 / HAR / age（不变）
crates/cli       流式 age 命令行（不变）
helpers/         Python Nuitka + 便携 Node（不变）
installer/       Inno，SourcePath 改为 desktop Release 输出
```

`crates/desktop` 是 workspace 成员，二进制名 `devkit`，产物 `devkit.exe`。不再经过 `flutter_rust_bridge`。类型就用 `devkit_core` 的结构，不要为 FRB 再抄一份。

桌面侧额外依赖：`rfd`（文件框）、`reqwest` 或现有 HTTP 客户端（GitHub 更新）、嵌入思源黑体。主题写入用户配置目录一个小 JSON（只存 `theme: system|light|dark`），不存密钥、不存编辑器内容。

助手路径（相对 `devkit.exe`）：

1. `helpers/crypto-python/` 与 `helpers/crypto-node/`
2. 开发态仓库 `helpers/dist/`、`helpers/`

Windows 启动子进程继续 `CREATE_NO_WINDOW`。

## 壳

单窗口，无大标题条。窗口标题 `DevKit — JSON` 这类。

1. **左侧活动栏（窄）**  
   JSON、JSON 对比、加解密、HAR、关于。单击切换工作区，再点不关闭。当前项高亮。底侧：主题 跟随系统 / 亮 / 暗。

2. **中间主区**  
   只渲染当前工具。切工具时 State 保存在内存（输入、HAR 列表、对比开关、关于页更新按钮）。关应用才清。

3. **按需面板**  
   - HAR 选中一条 → **右侧**详情。  
   - 加解密打开对比 → **底栏**三列。  
   - JSON 对比的差异列表 → **底栏**。

切页只布局当前工具；离开的工具用实体保活，后台大文本不参与排版。超过约 64KB 或单行超过约 8KB 的编辑器只画可见行；格式化 / 复制 / 保存仍作用于全文。

## 工具页

### JSON

主区一块编辑器。顶栏：打开、保存、清空、复制；格式化、压缩、转义、去转义、Unicode 与中文、中英标点。严格为复选框，默认不勾（宽容，允许尾逗号）。底栏：行数、UTF-8 大小、光标行列。文本上限约 20MB。

### JSON 对比

主区左右编辑器。顶栏：严格复选框 + 对比。差异在底栏列出（新增 / 删除 / 变更），点一条可聚焦对应侧。模式与 JSON 页同一套严格/宽容。

### 加解密

主区内顶部分段：编解码、哈希、AES、HMAC、RSA、国密。每种输入 | 输出左右拉满。哈希 / AES / HMAC 有对比开关，默认关；打开后底栏三列 Rust / Python / crypto-js，算法与对齐规则仍按现有 spec（GCM nonce 前置、CBC IV 前置、口令 `Salted__`、SM3 助手不支持）。RSA / 国密密钥仅会话内。切分段不丢输入。

### HAR

主区筛选列表：URL 包含、方法、状态、最大耗时、导入、导出 HAR/JSON、复制为 Python。点一条，右侧：

- 请求：总览、原始、请求头、请求体、Cookies  
- 响应：原始、响应头、响应体  

JSON 体自动缩进；非 JSON 保持原文。导入不设文件大小上限。不做重放。

### 关于

主区：亮/暗 logo、版本、检查更新、下载并安装。更新流程仍是 GitHub Releases + 同名安装器。切走再切回，下载状态还在。

## 删除清单

删除（或停止维护并移出仓库）：

- `lib/`、`test/`（Dart）、`integration_test/`
- `windows/`、`linux/`、`macos/`、`android/`、`ios/`、`web/`（若有）
- `pubspec.yaml`、`pubspec.lock`、`analysis_options.yaml`
- `rust/`、`rust_builder/`、`flutter_rust_bridge.yaml`
- Flutter 专用脚本与 CI 的 `flutter analyze / test` job

保留：`crates/`、`helpers/`、`installer/`、`logo/`、`fonts/`、`docs/`、`scripts/pack-helpers.ps1`、`scripts/test-helpers.ps1`。`scripts/pack.ps1` 改为 cargo 编 desktop。

## 打包与 CI

- 版本以 workspace / `crates/desktop` 的 `0.3.0` 为准，Automerge 打 `v0.3.0`。不再读 `pubspec.yaml`。
- CI：`cargo test --workspace --locked`、Windows 助手源码测试、Windows `cargo build -p devkit-desktop --release`。
- Release：pack-helpers → 编 desktop → 复制 helpers 到 exe 旁 → ISCC 打 `devkit-desktop-windows-amd64.exe`。
- 本机：`cargo run -p devkit-desktop`。需要 VS「使用 C++ 的桌面开发」（MSVC + Windows SDK），不再需要 Flutter 或 Developer Mode 符号链接。

## 测试

- `crates/core` 现有测试保持。
- `crates/desktop`：GPUI `test-support` 测活动栏切换保活、JSON 严格复选框默认关、HAR 详情分栏标题、对比开关默认关。
- 大文本：256KB 单行首次布局与切页不得卡死（预算与现网测试同级：首次 < 300ms、切页 < 300ms）。
- 助手对比：有 `helpers/dist` 时跑一轮哈希对齐；没有则列报缺失，不崩。

## 风险

- GPUI 文本控件不如 Flutter 成熟，大 HAR/JSON 必须虚拟化，否则会卡。
- GPUI-CE 仍 pre-1.0，锁定 crates.io 版本，不跟 Zed git HEAD。
- 一次删除 Flutter 的 PR 很大；按「能运行的工作台 + 安装包脚本」一整块交付，不拆成双 UI 并存。

## 验收

1. `cargo run -p devkit-desktop` 在 Windows 打开工作台，五个入口可切换且不丢输入。
2. JSON 宽容/严格、加解密对比、HAR 大文件与分栏详情、关于更新，行为与现网一致（外观可以不同）。
3. `scripts/pack.ps1` 产出同名 Inno 安装器，内含 helpers。
4. 仓库内搜不到 Flutter 应用入口；文档与 AGENTS.md 改为「GPUI 做界面，Rust 做计算」。
