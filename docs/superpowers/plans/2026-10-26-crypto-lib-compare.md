# 加解密库对比 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 哈希 / AES / HMAC 页可选三列对比（Rust、Nuitka Python、crypto-js），Windows 安装包内置助手，本机不用装 Python / Node。

**Architecture:** `crates/core` 增加 AES-CBC、OpenSSL 口令派生和 `compare_*`。Rust 先算并固定 nonce/IV/salt，再经 JSON 行协议问两个长驻助手。Dart 只加对比开关和三列输出。

**Tech Stack:** Rust `aes`/`cbc`、`cryptography` + Nuitka、Node + `crypto-js`、FRB 2.13、Flutter。

## Global Constraints

- 界面文案、注释、文档用中文。
- 密钥只在会话 / stdin，不写盘、不写日志、错误里不得出现密钥原文。
- 文本约 20MB 上限不变。
- 不调用本机 PATH 上的 `python` / `node`（测试除外）。
- 发布物仍只有 `devkit-desktop-windows-amd64.exe`。
- 跨 crate 类型在 `rust/src/api/` 重定义，改完后 `flutter_rust_bridge_codegen generate`。
- 第一期助手只打进 Windows；其它平台提示未带助手。
- 不对比 RSA / SM2 / SM4；SM3 两助手标不支持。

## File map

- Create: `crates/core/src/crypto_compare.rs` — 对比调度、助手客户端、路径查找
- Create: `helpers/crypto-python/main.py` — Python 助手
- Create: `helpers/crypto-python/pyproject.toml`、`uv.lock`
- Create: `helpers/crypto-node/index.js` — crypto-js 助手
- Create: `helpers/crypto-node/package.json`
- Create: `helpers/vectors.json` — 固定对齐向量
- Create: `scripts/pack-helpers.ps1`
- Create: `scripts/test-helpers.ps1`
- Create: `test/crypto_compare_test.dart`
- Modify: `crates/core/src/crypto_tools.rs` — AES-CBC、EVP_BytesToKey
- Modify: `crates/core/src/lib.rs`、`crates/core/Cargo.toml`
- Modify: `rust/src/api/crypto_tools.rs` — FRB 类型与 `compare_*`
- Modify: `lib/src/tools/crypto/crypto_page.dart`
- Modify: `lib/src/widgets/io_pane.dart` — 三列输出
- Modify: `scripts/pack.ps1`、`.github/workflows/release.yml`、`.github/workflows/ci.yml`
- Modify: `docs/development.md`、`docs/packaging.md`、`README.md`、`.gitignore`

---

### Task 1: Rust AES-CBC 与口令派生

**Files:**
- Modify: `crates/core/Cargo.toml`
- Modify: `crates/core/src/crypto_tools.rs`
- Test: `crates/core/src/crypto_tools.rs` 的 `tests` 模块

**Interfaces:**
- Produces: `aes256_cbc_encrypt(key, key_encoding, plaintext, plaintext_encoding, output_encoding, iv: Option<&[u8]>) -> Result<String, String>`（输出 IV 前置 16 字节）
- Produces: `aes256_cbc_decrypt(...)`
- Produces: `aes256_cbc_passphrase_encrypt(password, plaintext, plaintext_encoding, salt: Option<&[u8]>) -> Result<String, String>`（Base64 的 `Salted__`+salt+ct）
- Produces: `aes256_cbc_passphrase_decrypt(password, salted_b64) -> Result<String, String>`
- Produces: `evp_bytes_to_key(password, salt, key_len=32, iv_len=16)`

依赖：`aes = "0.8"`、`cbc = "0.1"`。

- [ ] 先写失败测试：固定 key/iv 的 CBC 往返；固定 salt 的 EVP 与 OpenSSL 格式
- [ ] 实现后 `cargo test -p devkit-core` 通过

### Task 2: Python / Node 助手

**Files:**
- Create: `helpers/crypto-python/main.py`
- Create: `helpers/crypto-python/pyproject.toml`、`uv.lock`（`cryptography`）
- Create: `helpers/crypto-node/index.js`
- Create: `helpers/crypto-node/package.json`（`crypto-js`）
- Create: `helpers/vectors.json`
- Create: `scripts/test-helpers.ps1`

**Interfaces:**
- 一行 JSON 请求 / 一行 JSON 应答，字段与 spec 一致
- `op`: `hash` | `hmac` | `encrypt` | `decrypt`
- 不支持返回 `{"ok":false,"unsupported":true,"error":"..."}`

- [ ] 用 `helpers/vectors.json` 对源码脚本跑自测（本机/CI 可用 PATH 上的 python/node）
- [ ] 向量须与 Task 1 Rust 测试同一组固定值

### Task 3: 对比调度与助手进程

**Files:**
- Create: `crates/core/src/crypto_compare.rs`
- Modify: `crates/core/src/lib.rs`

**Interfaces:**
- Produces: `CompareStatus { Match, Differ, Unsupported, Error }`
- Produces: `CompareColumn { label, output, status, message }`
- Produces: `CompareResult { rust, python, node }`
- Produces: `compare_hash` / `compare_hmac` / `compare_aes_encrypt` / `compare_aes_decrypt`
- 查找顺序：可执行文件旁 `helpers/` → 仓库 `helpers/dist/` → 仓库源码脚本仅用于测试 cfg
- 应用运行时不读 PATH 的 python/node
- 加密时 Rust 先算，把 nonce/IV/salt 写入助手请求
- 助手缺失：该列 `Error` + 「未找到助手，请先按文档打包」或非 Windows「当前安装包未带 Python / Node 助手」

- [ ] 无助手时哈希对比：Rust 列成功，两助手列为 Error/说明
- [ ] 有助手时 SHA-256 / HMAC / CBC 三列一致

### Task 4: FRB

**Files:**
- Modify: `rust/src/api/crypto_tools.rs`
- Generate: `lib/src/rust/`、`rust/src/frb_generated.*`

**Interfaces:**
- API 模块重定义 `AesMode { Gcm, Cbc }`、`AesKeyMode { Raw, Passphrase }`、`CompareStatus`、`CompareColumn`、`CompareResult`
- `compare_hash` / `compare_hmac` / `compare_aes_encrypt` / `compare_aes_decrypt`

- [ ] `flutter_rust_bridge_codegen generate`
- [ ] `cargo check --manifest-path rust/Cargo.toml`

### Task 5: 界面

**Files:**
- Modify: `lib/src/tools/crypto/crypto_page.dart`
- Modify: `lib/src/widgets/io_pane.dart`（可选 `IoTriple`）
- Test: `test/crypto_compare_test.dart`

**Interfaces:**
- 哈希 / AES / HMAC：`对比` 开关默认关
- 开：输出为三列 Rust / Python / crypto-js，各带状态与复制
- AES 开对比：模式 GCM/CBC；密钥 原始/口令；GCM 锁定原始密钥
- 关对比：恢复单列，不丢输入；AES 仍走现有 GCM API
- 关对比时计算仍只跑 Rust

- [ ] widget 测试：默认无三列标题；打开对比后出现「Rust」「Python」「crypto-js」

### Task 6: 打包、CI、文档

**Files:**
- Create: `scripts/pack-helpers.ps1`（Nuitka `--standalone`；下载官方 Windows `node.exe`）
- Modify: `scripts/pack.ps1`、`.github/workflows/release.yml`、`.github/workflows/ci.yml`
- Modify: `docs/development.md`、`docs/packaging.md`、`README.md`、`.gitignore`（忽略 `helpers/dist/`、`helpers/crypto-node/node_modules/`）

- [ ] CI Windows 用源码脚本跑 `test-helpers`（不在 PR 里跑完整 Nuitka）
- [ ] Release 在 Inno 前跑 `pack-helpers.ps1` 并拷进 Flutter Release 目录
- [ ] 文档写明助手查找顺序与「杀毒可能拦截」

---

## Spec 覆盖

| spec | 任务 |
| --- | --- |
| 三页对比开关 | 5 |
| 三列状态 | 3、5 |
| AES GCM/CBC、原始/口令 | 1、5 |
| 口令派生 OpenSSL | 1、2 |
| nonce/IV/salt 由 Rust 先定 | 3 |
| SM3 不支持 | 2、3 |
| Nuitka + 便携 Node | 6 |
| 不单独发 CLI | 6 |
| 密钥不落盘 | 2、3 |
| widget 不真起助手 | 5 |
