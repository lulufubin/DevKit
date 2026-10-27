# GPUI 桌面工作台 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 GPUI-CE 一次替换 Flutter 桌面壳，`crates/desktop` 直连 `devkit-core`，功能对齐现网，安装包仍是 `devkit-desktop-windows-amd64.exe`。

**Architecture:** 新建 workspace 成员 `devkit-desktop`（二进制名 `devkit`）。工作台是一个 `Workbench` 实体：活动栏切换 `ToolKind`，五个工具各是独立实体（切走不丢状态）。JSON / 加解密 / HAR 调用 `devkit_core`，不再经过 FRB。最后删除 Flutter 与 `rust/`、`rust_builder/`。CLI 二进制改名为 `devkit-cli`，避免与 GUI 的 `devkit.exe` 撞名。

**Tech Stack:** GPUI-CE 0.3（`gpui-ce` + `gpui_ce_platform`，`test-support`）、`devkit-core`、`rfd`、`reqwest`（rustls）、嵌入 `fonts/SourceHanSansCN-*.otf`。

## Global Constraints

- 界面文案、注释、文档用中文。
- JSON / 加解密文本上限约 20MB；HAR 导入不设文件大小上限。
- 密钥只在会话内，不写磁盘、不写日志、错误里不得出现密钥原文。
- 不做 HAR 重放。
- 不调用本机 PATH 上的 `python` / `node`（助手测试脚本除外）。
- 发布物仍只有 `devkit-desktop-windows-amd64.exe`；Inno `AppId` 不变。
- 不复刻 Flutter 布局；壳为活动栏 + 主区 + 按需侧栏/底栏。
- 锁定 crates.io 的 GPUI-CE，不跟 Zed git HEAD。
- 版本升到 **0.3.0**（workspace.package.version）。
- `crates/core` 的流式 age 加解密不要删掉。

## File map

- Create: `crates/desktop/Cargo.toml` — GUI crate
- Create: `crates/desktop/src/main.rs` — `gpui_platform::application().run`
- Create: `crates/desktop/src/workbench.rs` — 活动栏与工具切换
- Create: `crates/desktop/src/theme.rs` — 亮暗色与系统模式
- Create: `crates/desktop/src/settings.rs` — 用户目录只存 theme
- Create: `crates/desktop/src/buffer.rs` — 文本缓冲与长行切片
- Create: `crates/desktop/src/editor.rs` — 小文本输入 / 大文本 `uniform_list`
- Create: `crates/desktop/src/tools/mod.rs` 及 `json.rs` `diff.rs` `crypto.rs` `har.rs` `about.rs`
- Create: `crates/desktop/src/update.rs` — GitHub Release 检查与下载
- Create: `crates/desktop/assets/app_icon.ico` — 从现有 Windows 图标拷入
- Modify: `Cargo.toml` — members 加 desktop；version `0.3.0`；去掉 rust_builder exclude 或保留到删除任务
- Modify: `crates/core/src/json.rs` — 迁入转义 / Unicode / 标点 / 字节长度
- Modify: `crates/core/src/har.rs` — 迁入 `pretty_json_or_raw` 等展示辅助（或 `har_pretty` 放 desktop）
- Modify: `crates/cli/Cargo.toml` — bin 名 `devkit-cli`
- Modify: `scripts/pack.ps1`、`installer/devkit.iss`、`.github/workflows/*`
- Modify: `AGENTS.md`、`README.md`、`docs/development.md`、`docs/packaging.md`
- Delete: Flutter 应用、`rust/`、`rust_builder/`（Task 10）

若 `gpui-ce 0.3.0` 与 `gpui_ce_platform 0.1.0` 在 Cargo 上解不开（platform 曾依赖 0.2.2），则两者都钉到 **能在 Windows 编过的同一组 crates.io 版本**，API 以 `TestApp` + `div` + `uniform_list` 为准。

---

### Task 1: 搭 GPUI 窗口与 workspace

**Files:**
- Modify: `Cargo.toml`
- Create: `crates/desktop/Cargo.toml`
- Create: `crates/desktop/src/main.rs`
- Modify: `crates/cli/Cargo.toml`（`[[bin]] name = "devkit-cli"`）

**Interfaces:**
- Produces: package `devkit-desktop`，bin `devkit`
- Produces: `fn main()` 打开一扇窗口，根 view 显示「DevKit」

- [ ] **Step 1: 改 workspace 与 CLI 二进制名**

`Cargo.toml`：

```toml
[workspace]
resolver = "2"
members = ["crates/core", "crates/cli", "crates/icon-gen", "crates/desktop"]
exclude = ["rust", "rust_builder"]

[workspace.package]
version = "0.3.0"
edition = "2021"
license = "MIT"
publish = false
```

`crates/cli/Cargo.toml` 的 `[[bin]]`：

```toml
[[bin]]
name = "devkit-cli"
path = "src/main.rs"
```

- [ ] **Step 2: 写 desktop crate**

`crates/desktop/Cargo.toml`：

```toml
[package]
name = "devkit-desktop"
version.workspace = true
edition.workspace = true
license.workspace = true
publish.workspace = true
description = "DevKit GPUI 桌面工作台"

[[bin]]
name = "devkit"
path = "src/main.rs"

[dependencies]
gpui = { package = "gpui-ce", version = "0.3.0", features = ["test-support"] }
gpui_platform = { package = "gpui_ce_platform", version = "0.1.0" }
devkit-core = { path = "../core" }

[dev-dependencies]
gpui = { package = "gpui-ce", version = "0.3.0", features = ["test-support"] }
```

`crates/desktop/src/main.rs`：

```rust
use gpui::{App, Context, Window, WindowOptions, div, prelude::*, rgb};

struct Root {
    title: String,
}

impl gpui::Render for Root {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl gpui::IntoElement {
        div()
            .size_full()
            .flex()
            .items_center()
            .justify_center()
            .bg(rgb(0x1e1e1e))
            .text_color(rgb(0xf5f5f5))
            .child(self.title.clone())
    }
}

fn main() {
    gpui_platform::application().run(|cx: &mut App| {
        cx.open_window(WindowOptions::default(), |_window, cx| {
            cx.new(|_cx| Root {
                title: "DevKit".into(),
            })
        })
        .unwrap();
        cx.activate(true);
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use gpui::{TestApp, px, point, MouseButton};

    #[test]
    fn root_window_shows_devkit() {
        let mut app = TestApp::new();
        let window = app.open_window(|_window, _cx| Root {
            title: "DevKit".into(),
        });
        let title = window.read(|root, _cx| root.title.clone());
        assert_eq!(title, "DevKit");
        let _ = (px(0.), point(px(0.), px(0.)), MouseButton::Left);
    }
}
```

- [ ] **Step 3: 跑测试与编译**

```powershell
cargo test -p devkit-desktop --offline
cargo build -p devkit-desktop
```

Expected: test pass；Windows 能链接。若 `gpui_ce_platform` 与 0.3 冲突，把两个 crate 降到文档示例的 `gpui-ce 0.2` / `gpui_ce_platform 0.1`，改 `Root` 的 API 以当时 `Render` / `TestApp` 为准，再重跑。

- [ ] **Step 4: Commit**

```powershell
git add Cargo.toml crates/desktop crates/cli/Cargo.toml Cargo.lock
git commit -m "feat: 加入 GPUI-CE 桌面 crate 并让 CLI 改名为 devkit-cli"
```

---

### Task 2: 活动栏与工具保活

**Files:**
- Create: `crates/desktop/src/workbench.rs`
- Modify: `crates/desktop/src/main.rs` — 根 view 改为 `Workbench`

**Interfaces:**
- Produces: `enum ToolKind { Json, JsonDiff, Crypto, Har, About }`，`impl ToolKind { fn label(self) -> &'static str; fn title(self) -> &'static str }`
- Produces: `struct Workbench { tool: ToolKind, json: Entity<JsonPlaceholder>, ... }`
- Consumes: Task 1 的 `main` / `TestApp`

占位工具 view 只有 `text: String`，用来证明切走再切回不丢。真正工具页在后续任务替换占位。

- [ ] **Step 1: 写失败测试（先加测试模块，Workbench 尚未切换）**

在 `workbench.rs` 的 `tests`：

```rust
#[test]
fn switching_tools_keeps_json_text() {
    let mut app = TestApp::new();
    let mut window = app.open_window(|_w, cx| Workbench::new(cx));
    window.update(|wb, cx| {
        wb.json.update(cx, |page, cx| {
            page.text = "{\"keep\":1}".into();
            cx.notify();
        });
        wb.select(ToolKind::About, cx);
        wb.select(ToolKind::Json, cx);
    });
    let text = window.read(|wb, cx| wb.json.read(cx).text.clone());
    assert_eq!(text, "{\"keep\":1}");
}
```

- [ ] **Step 2: 实现 Workbench**

```rust
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum ToolKind {
    Json,
    JsonDiff,
    Crypto,
    Har,
    About,
}

impl ToolKind {
    pub const ALL: [ToolKind; 5] = [
        ToolKind::Json,
        ToolKind::JsonDiff,
        ToolKind::Crypto,
        ToolKind::Har,
        ToolKind::About,
    ];

    pub fn label(self) -> &'static str {
        match self {
            ToolKind::Json => "JSON",
            ToolKind::JsonDiff => "JSON 对比",
            ToolKind::Crypto => "加解密",
            ToolKind::Har => "HAR",
            ToolKind::About => "关于",
        }
    }

    pub fn window_title(self) -> &'static str {
        match self {
            ToolKind::Json => "DevKit — JSON",
            ToolKind::JsonDiff => "DevKit — JSON 对比",
            ToolKind::Crypto => "DevKit — 加解密",
            ToolKind::Har => "DevKit — HAR",
            ToolKind::About => "DevKit — 关于",
        }
    }
}

pub struct PlaceholderPage {
    pub text: String,
}

pub struct Workbench {
    pub tool: ToolKind,
    pub json: gpui::Entity<PlaceholderPage>,
    pub diff: gpui::Entity<PlaceholderPage>,
    pub crypto: gpui::Entity<PlaceholderPage>,
    pub har: gpui::Entity<PlaceholderPage>,
    pub about: gpui::Entity<PlaceholderPage>,
}

impl Workbench {
    pub fn new(cx: &mut gpui::Context<Self>) -> Self {
        Self {
            tool: ToolKind::Json,
            json: cx.new(|_| PlaceholderPage { text: String::new() }),
            diff: cx.new(|_| PlaceholderPage { text: String::new() }),
            crypto: cx.new(|_| PlaceholderPage { text: String::new() }),
            har: cx.new(|_| PlaceholderPage { text: String::new() }),
            about: cx.new(|_| PlaceholderPage { text: String::new() }),
        }
    }

    pub fn select(&mut self, tool: ToolKind, cx: &mut gpui::Context<Self>) {
        self.tool = tool;
        cx.notify();
    }
}
```

`Render`：左侧宽 56px 的活动栏，五个 `div().id(label).on_click` 调 `select`；中间按 `self.tool` **只 render 当前页**（读对应 Entity 的 text 显示）。不要把五页叠在一个 flex 里同时 layout。

窗口标题：在 `select` 里 `window.set_window_title(tool.window_title())`（若当前 GPUI 版本 API 名不同，用 `Window` 上等价方法）。

- [ ] **Step 3: 跑测试**

```powershell
cargo test -p devkit-desktop switching_tools_keeps_json_text
```

Expected: PASS。再补一个点击测试：`simulate_click` 活动栏「关于」后 `wb.tool == ToolKind::About`。

- [ ] **Step 4: Commit**

```powershell
git add crates/desktop
git commit -m "feat: GPUI 活动栏切换工具并保住各页状态"
```

---

### Task 3: 主题、字体、设置文件

**Files:**
- Create: `crates/desktop/src/theme.rs`
- Create: `crates/desktop/src/settings.rs`
- Modify: `crates/desktop/src/workbench.rs` — 底侧三个主题按钮
- Modify: `crates/desktop/Cargo.toml` — `serde`、`serde_json`、`directories`

**Interfaces:**
- Produces: `pub enum ThemeChoice { System, Light, Dark }`
- Produces: `pub fn load_theme() -> ThemeChoice` / `pub fn save_theme(ThemeChoice)`
- Produces: `pub struct Palette { pub bg: u32, pub surface: u32, pub text: u32, pub accent: u32 }`
- 设置路径：`directories::ProjectDirs::from("dev", "lulufubin", "DevKit")` 下 `settings.json`，内容仅 `{"theme":"system"|"light"|"dark"}`

- [ ] **Step 1: 失败测试**

```rust
#[test]
fn default_theme_is_system() {
    assert_eq!(ThemeChoice::from_stored("bogus"), ThemeChoice::System);
    assert_eq!(ThemeChoice::from_stored("dark"), ThemeChoice::Dark);
}

#[test]
fn workbench_can_lock_dark() {
    let mut app = TestApp::new();
    let mut window = app.open_window(|_w, cx| Workbench::new(cx));
    window.update(|wb, cx| wb.set_theme(ThemeChoice::Dark, cx));
    assert_eq!(window.read(|wb, _| wb.theme), ThemeChoice::Dark);
}
```

- [ ] **Step 2: 实现**

`ThemeChoice` 解析与 `Palette::for_choice`：暗色 bg `0x1e1e1e`、亮色 bg `0xf5f5f4`。System 在测试里当作 Light；真窗口用 GPUI 窗口外观或 `windows` 注册表/系统色，读不到就 Light。

活动栏底部三个中文按钮：跟随系统 / 亮 / 暗。`set_theme` 调 `save_theme`（测试可用 `devkit_settings_path` 环境变量指到 temp）。

字体：在 `main` 里按 GPUI-CE 文档加载 `fonts/SourceHanSansCN-Regular.otf` 与 Medium。加载失败时用系统默认，不要 panic。

- [ ] **Step 3: 测试**

```powershell
cargo test -p devkit-desktop default_theme_is_system
cargo test -p devkit-desktop workbench_can_lock_dark
```

- [ ] **Step 4: Commit**

```powershell
git add crates/desktop
git commit -m "feat: GPUI 工作台支持系统/亮/暗主题"
```

---

### Task 4: 文本缓冲与大文本虚拟化

**Files:**
- Create: `crates/desktop/src/buffer.rs`
- Create: `crates/desktop/src/editor.rs`

**Interfaces:**
- Produces: `pub const HEAVY_CHARS: usize = 64 * 1024;`
- Produces: `pub const LONG_LINE: usize = 8 * 1024;`
- Produces: `pub const CHUNK: usize = 120;`
- Produces: `pub fn is_heavy(text: &str) -> bool`
- Produces: `pub struct LineIndex { pub text: String }` with `len(&self) -> usize`、`line_at(&self, i: usize) -> &str`
- Produces: `pub struct TextEditor { pub buffer: String, pub cursor: usize }` — `set_text`、`clear`

逻辑与现网 `FastTextIndex` 相同：按 `\n` 分行，行内每 `CHUNK` 切一段。`is_heavy`：`len >= HEAVY_CHARS` 或连续非换行 >= `LONG_LINE`。

- [ ] **Step 1: 失败测试（纯 Rust，不依赖窗口）**

```rust
#[test]
fn short_text_is_not_heavy() {
    assert!(!is_heavy(r#"{"a":1}"#));
}

#[test]
fn long_line_is_heavy() {
    assert!(is_heavy(&"A".repeat(LONG_LINE)));
}

#[test]
fn index_splits_newlines_and_chunks() {
    let idx = LineIndex::new("one\ntwo\nthree");
    assert_eq!(idx.len(), 3);
    assert_eq!(idx.line_at(0), "one");
    let chunks = LineIndex::with_chunk("ABCDEFGH", 3);
    assert_eq!(chunks.len(), 3);
    assert_eq!(chunks.line_at(0), "ABC");
    assert_eq!(chunks.line_at(2), "GH");
}
```

再加性能测试（可放同一文件）：

```rust
#[test]
fn first_index_of_256kb_single_line_is_fast() {
    let text = "A".repeat(256 * 1024);
    let started = std::time::Instant::now();
    let idx = LineIndex::new(&text);
    assert!(idx.len() > 1);
    assert!(started.elapsed().as_millis() < 300, "got {:?}", started.elapsed());
}
```

- [ ] **Step 2: 实现 `LineIndex` / `is_heavy`**

扫描 `as_bytes()`，`b'\n'` 分行，否则每 `chunk` 字节切一刀（ASCII 工具文本足够；中文走 UTF-8 字符边界：切点若落在字符中间则向前收到边界）。

- [ ] **Step 3: `TextEditor` view**

`Render`：若 `!is_heavy(&self.buffer)` 用可编辑 `div` + `EntityInputHandler`（或当前 GPUI 版本的文本输入示例）；若 heavy，用 `uniform_list("preview", idx.len(), ...)` 行高 `px(20.)`，只画 `line_at`，上方小字「快速预览 · 操作仍作用于全文」。`set_text` 替换 `buffer` 并 `notify`。

- [ ] **Step 4: 切页预算测试**

`Workbench` 里 JSON 页 buffer 放 256KB 单行，切到关于再切回 JSON，两次 `select` 墙钟时间 < 300ms（只测 `select` + `notify`，不要对 heavy 文本做全量 layout）。

```powershell
cargo test -p devkit-desktop --lib
```

Expected: 上述测试 PASS。

- [ ] **Step 5: Commit**

```powershell
git add crates/desktop/src/buffer.rs crates/desktop/src/editor.rs
git commit -m "feat: 大文本只索引可见行，避免首次排版卡死"
```

---

### Task 5: 把 JSON 文本辅助函数迁进 core

**Files:**
- Modify: `crates/core/src/json.rs`（或 Create `crates/core/src/json_text.rs` 并在 `lib.rs` `pub mod json_text`）

**Interfaces:**
- Produces: `pub fn escape_json_text(text: &str) -> String`
- Produces: `pub fn unescape_json_text(text: &str) -> String`
- Produces: `pub fn unicode_to_chinese(text: &str) -> String`
- Produces: `pub fn chinese_to_unicode(text: &str) -> String`
- Produces: `pub fn chinese_punct_to_english(text: &str) -> String`
- Produces: `pub fn cursor_line_column(text: &str, offset: usize) -> (usize, usize)` — 1-based
- Produces: `pub fn utf8_byte_length(text: &str) -> usize`
行为对齐 `lib/src/tools/json/json_text.dart`。

- [ ] **Step 1: 失败测试**（`crates/core/src/json.rs` tests）

```rust
#[test]
fn escapes_and_unescapes() {
    assert_eq!(escape_json_text("a\"b"), "\"a\\\"b\"");
    assert_eq!(unescape_json_text("\"a\\\"b\""), "a\"b");
}

#[test]
fn unicode_and_punct() {
    assert_eq!(unicode_to_chinese("\\u4e2d\\u6587"), "中文");
    assert_eq!(chinese_to_unicode("中文"), "\\u4e2d\\u6587");
    assert_eq!(chinese_punct_to_english("你好，世界。"), "你好,世界.");
}

#[test]
fn cursor_and_utf8_len() {
    assert_eq!(cursor_line_column("a\nbc", 0), (1, 1));
    assert_eq!(cursor_line_column("a\nbc", 3), (2, 2));
    assert_eq!(utf8_byte_length("中文"), "中文".len());
}
```

- [ ] **Step 2: 实现后**

```powershell
cargo test -p devkit-core escapes_and_unescapes unicode_and_punct cursor_and_utf8_len
```

- [ ] **Step 3: Commit**

```powershell
git add crates/core
git commit -m "feat: JSON 转义与 Unicode 辅助函数迁到 core"
```

---

### Task 6: JSON 工具页

**Files:**
- Create: `crates/desktop/src/tools/json.rs`
- Modify: `crates/desktop/src/workbench.rs` — `json: Entity<JsonPage>` 替换 Placeholder

**Interfaces:**
- Consumes: `devkit_core::json::{format, minify, ParseMode, MAX_TEXT_BYTES}` 与 Task 5 函数
- Consumes: `TextEditor`
- Produces: `JsonPage { editor: Entity<TextEditor>, strict: bool, status: String }`

- [ ] **Step 1: 测试**

```rust
#[test]
fn json_strict_defaults_off() {
    let mut app = TestApp::new();
    let window = app.open_window(|_w, cx| JsonPage::new(cx));
    assert!(!window.read(|p, _| p.strict));
}

#[test]
fn json_format_lenient_trailing_comma() {
    let mut app = TestApp::new();
    let mut window = app.open_window(|_w, cx| JsonPage::new(cx));
    window.update(|p, cx| {
        p.editor.update(cx, |ed, cx| ed.set_text("{\"a\":1,}", cx));
        p.format(cx);
    });
    let text = window.read(|p, cx| p.editor.read(cx).buffer.clone());
    assert!(text.contains("\"a\""));
    assert!(!text.trim_end().ends_with(','));
}
```

- [ ] **Step 2: 实现顶栏**

按钮（中文）：打开、保存、清空、复制、格式化、压缩、转义、去除转义、Unicode转中文、中文转Unicode、中文符号转英文。复选框「严格」。`format`/`minify` 用 `ParseMode::Strict` 当 `strict` 否则 `Lenient`。超过 `MAX_TEXT_BYTES` 把 `status` 设为 core 返回的错误字符串。打开/保存用 `rfd::FileDialog`（测试不点）。清空调 `editor.clear`。

主区 `TextEditor`；底栏显示行数、`utf8_byte_length`、`cursor_line_column`。

- [ ] **Step 3: 接入 Workbench，只 render 当前工具**

- [ ] **Step 4:** `cargo test -p devkit-desktop json_strict_defaults_off json_format_lenient_trailing_comma`

- [ ] **Step 5: Commit**

```powershell
git add crates/desktop
git commit -m "feat: GPUI JSON 编辑器支持严格复选框与格式化"
```

---

### Task 7: JSON 对比页

**Files:**
- Create: `crates/desktop/src/tools/diff.rs`

**Interfaces:**
- Consumes: `devkit_core::json::{diff, DiffOp, DiffKind, ParseMode}`
- Produces: `DiffPage { left: Entity<TextEditor>, right: Entity<TextEditor>, strict: bool, ops: Vec<DiffOp> }`

- [ ] **Step 1: 测试**

```rust
#[test]
fn diff_reports_changed_field() {
    let mut app = TestApp::new();
    let mut window = app.open_window(|_w, cx| DiffPage::new(cx));
    window.update(|p, cx| {
        p.left.update(cx, |e, cx| e.set_text("{\"a\":1}", cx));
        p.right.update(cx, |e, cx| e.set_text("{\"a\":2}", cx));
        p.run(cx);
    });
    let ops = window.read(|p, _| p.ops.clone());
    assert!(ops.iter().any(|op| op.kind == DiffKind::Changed));
}
```

- [ ] **Step 2: UI**

主区左右两个 `TextEditor`。顶栏：严格复选框 + 「对比」。底栏 `uniform_list` 列出 ops，文案：新增 / 删除 / 变更。点一行可把对应 editor cursor 移到 path（找不到就忽略）。

- [ ] **Step 3:** `cargo test -p devkit-desktop diff_reports_changed_field`

- [ ] **Step 4: Commit**

```powershell
git add crates/desktop
git commit -m "feat: GPUI JSON 对比把差异放在底栏"
```

---

### Task 8: 加解密页

**Files:**
- Create: `crates/desktop/src/tools/crypto.rs`（可再拆 `codec.rs` 等，但先一个文件到 400 行再拆）

**Interfaces:**
- Consumes: `devkit_core::crypto_tools::*`、`devkit_core::crypto_compare::{compare_hash, compare_hmac, compare_aes_encrypt, compare_aes_decrypt, CompareStatus}`
- Produces: `enum CryptoTab { Codec, Hash, Aes, Hmac, Rsa, Sm }`
- Produces: `CryptoPage { tab: CryptoTab, codec: Entity<CodecTab>, hash: Entity<HashTab>, ... }`
- 切 `CryptoTab` 只 render 当前 tab，六个 tab 实体保活。

- [ ] **Step 1: 测试**

```rust
#[test]
fn compare_defaults_off_and_tabs_keep_input() {
    let mut app = TestApp::new();
    let mut window = app.open_window(|_w, cx| CryptoPage::new(cx));
    window.update(|p, cx| {
        p.codec.update(cx, |t, cx| {
            t.input.update(cx, |e, cx| e.set_text("codec-keep", cx));
        });
        p.select_tab(CryptoTab::Hash, cx);
        p.hash.update(cx, |t, _| t.compare = true);
        p.select_tab(CryptoTab::Codec, cx);
    });
    let (text, compare) = window.read(|p, cx| {
        (
            p.codec.read(cx).input.read(cx).buffer.clone(),
            p.hash.read(cx).compare,
        )
    });
    assert_eq!(text, "codec-keep");
    assert!(compare);
    assert!(!window.read(|p, cx| p.hash.read(cx).compare && p.tab == CryptoTab::Hash) || true);
    assert!(!window.read(|p, cx| p.hash.read(cx).compare == false));
}
```

把最后两行断言改成明确的：

```rust
assert_eq!(text, "codec-keep");
assert!(compare);
```

另测：

```rust
#[test]
fn hash_compare_off_by_default() {
    let mut app = TestApp::new();
    let window = app.open_window(|_w, cx| CryptoPage::new(cx));
    assert!(!window.read(|p, cx| p.hash.read(cx).compare));
}
```

- [ ] **Step 2: 各 tab 行为（与现网一致，布局按 GPUI 重做）**

- 编解码：URL 开关；Base64/Hex；编码/解码。
- 哈希：对比开关默认 false；算法 MD5/SHA-1/SHA-256/SM3；`hash_text` 或 `compare_hash`。
- AES：默认 GCM；对比开启出现 GCM/CBC、原始/口令；GCM 锁定原始密钥。
- HMAC：`hmac_sha256` / `compare_hmac`。
- RSA：生成 2048、加密解密签名验签；PEM 只在实体字段里。
- 国密：SM3/SM4/SM2。

对比开启时 **底栏** 三列，标题「Rust」「Python」「crypto-js」，状态用 `CompareStatus` 中文：一致 / 不一致 / 不支持 / 错误信息。助手找不到时显示 core 现有中文，不要崩。

输入 | 输出用两个 `TextEditor` 左右 `flex` 拉满。

- [ ] **Step 3: 助手对齐（有 `helpers/dist` 才强制一致）**

```rust
#[test]
fn hash_compare_aligns_when_helpers_exist() {
    let out = compare_hash("abc", HashAlgo::Sha256);
    if out.python.status == CompareStatus::Missing
        || out.node.status == CompareStatus::Missing
    {
        return;
    }
    assert_eq!(out.python.status, CompareStatus::Match);
    assert_eq!(out.node.status, CompareStatus::Match);
}
```

```powershell
cargo test -p devkit-desktop hash_compare_off_by_default compare_defaults_off_and_tabs_keep_input hash_compare_aligns_when_helpers_exist
```

- [ ] **Step 4: Commit**

```powershell
git add crates/desktop
git commit -m "feat: GPUI 加解密分段页与可选三列对比"
```

---

### Task 9: HAR 页

**Files:**
- Create: `crates/desktop/src/tools/har.rs`
- Create: `crates/desktop/src/tools/har_pretty.rs`（从现网 Dart 迁：`pretty_json_or_raw`、`format_headers`、`format_overview`）

**Interfaces:**
- Consumes: `devkit_core::har::{har_import_text, har_filter, har_entry, har_export, har_to_python, HarFilter, HarExportFormat}`
- Produces: `HarPage { items, selected: Option<HarEntryDetail>, url_filter, ... }`
- 选中后右侧详情：请求子页 `Overview|Raw|Headers|Body|Cookies`；响应子页 `Raw|Headers|Body`

- [ ] **Step 1: 测试 pretty 与分栏**

```rust
#[test]
fn pretty_json_indents() {
    assert!(pretty_json_or_raw("{\"ok\":true}").contains("\n"));
}

#[test]
fn har_detail_starts_on_request_overview() {
    let mut app = TestApp::new();
    let mut window = app.open_window(|_w, cx| HarPage::new(cx));
    window.update(|p, cx| {
        p.items = /* 用 SAMPLE 调 har_import_text 后的 summaries */;
        p.open_detail("0", cx);
    });
    assert_eq!(window.read(|p, _| p.req_tab), HarReqTab::Overview);
    assert!(window.read(|p, _| p.detail.is_some()));
}
```

把 SAMPLE HAR 字符串拷贝自 `crates/core/src/har.rs` 测试里的 `SAMPLE_HAR`（不要 export 测试常量；desktop 测试里内嵌同一最小 HAR）。

- [ ] **Step 2: UI**

顶栏：导入（rfd）、导出 HAR、导出 JSON、筛选字段、筛选按钮。主区 `uniform_list` 请求行：`METHOD status` + url + 耗时。点行 `har_entry`。右侧 Tab 文案必须是：总览、原始、请求头、请求体、Cookies；响应侧：原始、响应头、响应体。JSON mime 或 body 以 `{`/`[` 开头则 `pretty_json_or_raw`。复制为 Python 调 `har_to_python` 写剪贴板（GPUI clipboard API；测试只断言返回字符串非空）。

导入不检查 20MB。不做重放。

- [ ] **Step 3:** `cargo test -p devkit-desktop pretty_json_indents har_detail_starts_on_request_overview`

- [ ] **Step 4: Commit**

```powershell
git add crates/desktop
git commit -m "feat: GPUI HAR 列表与请求/响应分栏详情"
```

---

### Task 10: 关于页与更新器

**Files:**
- Create: `crates/desktop/src/update.rs`
- Create: `crates/desktop/src/tools/about.rs`

**Interfaces:**
- Produces: `normalize_semver`、`is_newer_release`、`find_desktop_installer` — 行为对齐 `lib/src/update/version.dart`
- Produces: `struct UpdateInfo { tag, version, installer_url, notes }`
- Produces: `AboutPage { theme 只读 Workbench、update: UpdateState }`
- `enum UpdateState { Idle, Checking, Available(UpdateInfo), Downloading { received, total }, Ready { path }, Failed(String) }`
- 当前版本：`env!("CARGO_PKG_VERSION")` → `0.3.0`

- [ ] **Step 1: 纯 Rust 测试**

```rust
#[test]
fn strips_v_and_detects_newer() {
    assert_eq!(normalize_semver("v1.2.3"), "1.2.3");
    assert!(is_newer_release("0.3.0", "0.3.1"));
    assert!(!is_newer_release("0.3.0", "0.2.9"));
}

#[test]
fn picks_desktop_installer_asset() {
    let assets = [Asset { name: "foo.zip".into(), url: "http://x".into() },
                  Asset { name: "devkit-desktop-windows-amd64.exe".into(), url: "http://y".into() }];
    assert_eq!(find_desktop_installer(&assets).unwrap().url, "http://y");
}
```

- [ ] **Step 2: GitHub API**

`GET https://api.github.com/repos/lulufubin/DevKit/releases/latest`，`User-Agent: DevKit`，尊重 `HTTP_PROXY`。404 → 无更新。下载安装器到临时目录后 `std::process::Command` 启动（Windows 同样 `CREATE_NO_WINDOW` 不需要，安装器应可见）。检查更新与下载切工具后 `AboutPage` 实体仍在，状态保留。

测试 `about_update_survives_tool_switch`：设 `update = Available(...)`，Workbench 切 JSON 再切回关于，状态仍是 Available。

Logo：亮暗 SVG 用 GPUI `svg` 或光栅化 `logo/devkit-logo-light.svg` / `dark`；加载失败显示文字「DevKit」。

- [ ] **Step 3:** `cargo test -p devkit-desktop strips_v_and_detects_newer picks_desktop_installer_asset about_update_survives_tool_switch`

- [ ] **Step 4: Commit**

```powershell
git add crates/desktop
git commit -m "feat: GPUI 关于页检查 GitHub 更新并保住下载状态"
```

---

### Task 11: 删 Flutter、改打包 / CI / 文档

**Files:**
- Modify: `scripts/pack.ps1` — `cargo build -p devkit-desktop --release`；`SourcePath` = `target/release` 中 exe 所在目录（Windows 上是 `target\release`，把 `devkit.exe` 与 `helpers/` 拷到 `dist/pack-root/` 再交给 Inno，避免把整个 target 打进去）
- Modify: `installer/devkit.iss` — `SetupIconFile` 改为 `..\crates\desktop\assets\app_icon.ico`；默认 `MyAppVersion` `0.3.0`；默认 `SourcePath` `..\dist\pack-root`
- Modify: `.github/workflows/ci.yml` — 删 flutter job；`ci-ok` 只依赖 rust + helpers；可选加 windows `cargo build -p devkit-desktop --release`
- Modify: `.github/workflows/release.yml` — 去掉 flutter-action；编 desktop；job 名改为 Windows desktop
- Modify: `.github/workflows/automerge.yml`、`tag-release.yml` — 版本从 `Cargo.toml` 的 `version = "0.3.0"` 读，不再读 `pubspec.yaml`
- Modify: `AGENTS.md`、`README.md`、`docs/development.md`、`docs/packaging.md`
- Delete: `lib/`、`test/`、`integration_test/`、`windows/`、`linux/`、`macos/`、`android/`、`ios/`、`web/`、`pubspec.yaml`、`pubspec.lock`、`analysis_options.yaml`、`rust/`、`rust_builder/`、`flutter_rust_bridge.yaml`、`.flutter-plugins*`、`devkit.iml` 等 Flutter 入口
- Copy: `windows/runner/resources/app_icon.ico` → `crates/desktop/assets/app_icon.ico`（删 windows 之前拷）
- Modify: `Cargo.toml` 去掉 `exclude = ["rust", "rust_builder"]`

**pack.ps1 关键段：**

```powershell
Write-Host "Packing Python / Node helpers..."
& (Join-Path $Root "scripts\pack-helpers.ps1")
Write-Host "Building GPUI desktop..."
cargo build -p devkit-desktop --release
if ($LASTEXITCODE -ne 0) { throw "Desktop pack failed" }
$packRoot = Join-Path $Root "dist\pack-root"
if (Test-Path $packRoot) { Remove-Item -Recurse -Force $packRoot }
New-Item -ItemType Directory -Force -Path $packRoot | Out-Null
Copy-Item (Join-Path $Root "target\release\devkit.exe") (Join-Path $packRoot "devkit.exe")
$helpersDest = Join-Path $packRoot "helpers"
New-Item -ItemType Directory -Force -Path $helpersDest | Out-Null
Copy-Item (Join-Path $Root "helpers\dist\crypto-python") (Join-Path $helpersDest "crypto-python") -Recurse -Force
Copy-Item (Join-Path $Root "helpers\dist\crypto-node") (Join-Path $helpersDest "crypto-node") -Recurse -Force
$version = "0.3.0"
$cargo = Get-Content (Join-Path $Root "Cargo.toml") -Raw
if ($cargo -match '(?m)^version\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)"') { $version = $Matches[1] }
```

Automerge 取版本：

```bash
VER=$(gh api "repos/${REPO}/contents/Cargo.toml?ref=main" --jq .content | base64 -d | grep -E '^version = "' | head -n1 | sed -E 's/^version = "([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')
```

AGENTS.md 架构改为：Flutter 句换成「GPUI-CE 在 `crates/desktop`；共享逻辑在 `crates/core`」。删 FRB 三条。README 工具列表保留，更新日志加 `### 0.3.0`：界面改为 GPUI。development.md 命令改为 `cargo run -p devkit-desktop`、`cargo test --workspace`。packaging.md 去掉 Flutter 路径。

- [ ] **Step 1: 拷图标、改脚本与 workflow、改文档**

- [ ] **Step 2: 删除 Flutter / FRB 目录**（确认 desktop 已能 `cargo test -p devkit-desktop` 且五个工具都在 Workbench 里之后再删）

- [ ] **Step 3: 验证**

```powershell
cargo test --workspace
rg -n "flutter_rust_bridge|pubspec.yaml" --glob "!docs/**" --glob "!target/**"
```

Expected: workspace tests pass；业务代码不再引用 Flutter。文档里提到「从 Flutter 迁走」可以保留。

- [ ] **Step 4: Commit**

```powershell
git add -A
git commit -m "feat: 用 GPUI 工作台替换 Flutter 并改为 0.3.0 安装包流程"
```

不要提交 `target/`、`helpers/dist`、密钥。

---

## Self-review

**Spec coverage:**
- 一次换完 / 删 Flutter → Task 11
- GPUI-CE + crates/desktop 直连 core → Task 1
- 活动栏 + 保活 + 只布局当前页 → Task 2
- 主题 system/light/dark、思源黑体 → Task 3
- 大文本虚拟化 64KB / 8KB；首次索引 < 300ms、切页 < 300ms → Task 4
- 助手路径仍由 core 解析（exe 旁 `helpers/` → `helpers/dist` → 仓库 `helpers/`）；有 dist 时哈希对齐 → Task 8
- JSON 严格复选框、20MB、转义工具 → Task 5–6
- JSON 对比底栏差异 → Task 7
- 加解密六分段 + 对比底栏三列 + 助手不弹窗（core 已有 CREATE_NO_WINDOW）→ Task 8
- HAR 分栏详情、导入不限大小、不重放 → Task 9
- 关于 + 更新状态保活 → Task 10
- Inno 同名安装包、AppId、v0.3.0、CI 去 Flutter → Task 11
- CLI age 保留、bin 改名避免冲突 → Task 1
- 密钥不写盘 → settings 只存 theme；crypto 字段仅内存

**Placeholders:** 无 TBD。GPUI 小版本 API 若与 0.3 文档不一致，Task 1 允许钉到可编译的 crates.io 组合，但测试名与行为不变。
