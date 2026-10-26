# 加解密库对比（Rust / Python / crypto-js）

哈希、AES、HMAC 页增加可选「对比」。打开后同一输入分别用 Rust（进程内）、Python（`cryptography` + 标准库）、Node（`crypto-js`）计算，并排看出是否一致。本机不必安装 Python 或 Node：两个助手各自独立打包，打进 Windows 图形安装包。

## 目标

- 现有哈希 / AES / HMAC 页各有「对比」开关，默认关闭；关闭时界面与现在一致。
- 打开后输出变成三列：Rust、Python、crypto-js，并标「一致 / 不一致 / 不支持」。
- Python 用 Nuitka 打成独立目录；Node 打成独立目录（便携 `node.exe` + `crypto-js`）。用户无感知，也不单独提供命令行安装包。
- 说清 crypto-js 和 Python 对不上的常见原因：AES-CBC、口令派生（OpenSSL `Salted__`）、密钥按字符串还是按字节。

## 非目标

- 不把 Python / Node 助手作为 Release 里单独下载的 CLI。
- 第一期不打 macOS / Linux 助手；这两端打开对比时提示「当前安装包未带 Python / Node 助手」。
- 不对比 RSA、国密 SM2 / SM4；SM3 在 Python 标准库和 crypto-js 中标「不支持」。
- 不调用本机 PATH 上的 `python` / `node`。
- 不把密钥写磁盘、写日志；助手 stdin/stdout 用完即弃。
- 不做 HAR 重放，不改文本 20MB 上限。

## 界面

三页共用同一套对比条，默认关。

打开后：

- 原单列输出换成三列等宽输出（Rust | Python | crypto-js），仍占满剩余高度。
- 每列标题旁显示该列状态：成功且与 Rust 相同为「一致」；成功但不同为「不一致」；该库无此算法为「不支持」；进程失败为错误原文。
- AES 页在对比开启时额外出现：
  - 模式：`GCM`（现有 AES-256-GCM）或 `CBC`（crypto-js 常用 AES-256-CBC + PKCS7）。
  - 密钥：`原始密钥` 或 `口令派生`。
- 哈希 / HMAC 的算法与编码控件保持现有；对比只是多跑两列。
- 输入、打开文件仍可用；三列输出各自带「复制」。

关闭对比后回到单列 Rust 输出，不丢输入内容。

## 算法与对齐规则

同一套用户输入（明文、密钥、编码）送给三端。比较的是**规范化后的输出字节**（哈希 / HMAC 用小写 Hex；AES 用页面上的输出编码）。

| 操作 | Rust | Python | crypto-js |
| --- | --- | --- | --- |
| MD5 / SHA-1 / SHA-256 | 现有 `hash_text` | `hashlib` | `CryptoJS.MD5` / `SHA1` / `SHA256` |
| SM3 | 现有 | 不支持 | 不支持 |
| HMAC-SHA256 | 现有 | `hmac` + `hashlib.sha256` | `CryptoJS.HmacSHA256` |
| AES-256-GCM + 原始密钥 | 现有（nonce 前置 12 字节） | `cryptography.hazmat` AESGCM，同样 nonce 前置 | 不支持 |
| AES-256-CBC + 原始密钥 | 新增（IV 前置 16 字节，PKCS7） | `Cipher(AES, CBC)` + PKCS7，IV 前置 | `CryptoJS.AES` + 已解析的 key/iv |
| 口令派生 | 三端都用 OpenSSL EVP_BytesToKey（MD5、1 次迭代）+ 8 字节 salt，密文为 `Salted__` + salt + ciphertext 的 Base64，与 `CryptoJS.AES.encrypt(msg, password)` 默认一致 | 同左 | 默认行为 |

口令派生只用于 CBC。选 GCM 时密钥方式锁定为「原始密钥」，不能选口令派生。

AES-GCM 加密时 nonce 仍随机；对比时 **Rust 先算，把 nonce/IV/salt 传给另外两端**，否则随机数不同会永远「不一致」。解密则三端各自解同一段密文。

哈希 / HMAC 在相同编码下三列应一致。AES 在「CBC + 原始密钥 + 同一 IV」或「CBC + 口令派生 + 同一 salt」下三列应一致。对不上时，列下用一两句中文说明（例如 crypto-js 把密钥当 UTF-8 口令，Python 当 Hex 原始密钥）。

## 助手进程

工作台不内嵌解释器。Rust（FRB）负责调度：

1. 进程内算 Rust 列。
2. 启动（或复用）两个长驻助手，stdin/stdout 一行一个 JSON。
3. 汇总三列返回 Dart。

助手路径（安装后，相对 `devkit.exe`）：

- `helpers/crypto-python/devkit-crypto-python.exe`
- `helpers/crypto-node/node.exe` + 同目录 `index.js`（工作台直接拉起该 `node.exe`，参数为 `index.js`）

开发态从仓库 `helpers/` 产物目录找；找不到则该列报「未找到助手，请先按文档打包」。

请求示例：

```json
{"id":"1","op":"hash","alg":"sha256","data":"...","encoding":"utf8"}
{"id":"2","op":"hmac","alg":"sha256","key":"...","keyEncoding":"utf8","data":"...","encoding":"utf8"}
{"id":"3","op":"encrypt","alg":"aes-256-cbc","key":"...","keyEncoding":"utf8","data":"...","encoding":"utf8","outputEncoding":"base64","keyMode":"passphrase","saltHex":"..."}
{"id":"4","op":"encrypt","alg":"aes-256-gcm","key":"...","keyEncoding":"hex","data":"...","encoding":"utf8","outputEncoding":"base64","keyMode":"raw","nonceHex":"..."}
```

成功：`{"id":"1","ok":true,"output":"..."}`。失败：`{"id":"1","ok":false,"error":"..."}`（错误里不得出现密钥原文）。不支持：`{"id":"1","ok":false,"unsupported":true,"error":"crypto-js 不支持 AES-GCM"}`。

超时、超过约 20MB、助手退出，均记为该列失败，不影响另外两列。密钥只在会话内，不写助手旁路文件。

## 打包

对外发布物仍只有 `devkit-desktop-windows-amd64.exe`。Inno 把 `helpers/crypto-python/` 与 `helpers/crypto-node/` 一并拷进安装目录。

**Python（Nuitka）**

- 源码：`helpers/crypto-python/`（入口脚本 + `requirements.txt`：`cryptography`、`nuitka`）。
- CI / `scripts/pack-helpers.ps1` 用 Nuitka `--standalone`（不用 onefile，避免每次对比都解压）。
- 产物：`helpers/dist/crypto-python/`，主程序名 `devkit-crypto-python.exe`。
- Windows runner 已有 MSVC，供 Nuitka 编译。

**Node（crypto-js）**

- 源码：`helpers/crypto-node/`（入口脚本 + `package.json` 依赖 `crypto-js`）。
- 打包：下载官方 Windows x64 `node.exe`，与 `node_modules`、入口脚本放进 `helpers/dist/crypto-node/`。不依赖本机全局 npm 包。
- 启动：同目录启动脚本调用该 `node.exe`，不读 PATH。

Release 工作流在 `flutter build windows` 之后、Inno 之前跑 `pack-helpers.ps1`，把两个目录复制到 Flutter Release 目录。本地 `scripts/pack.ps1` 同样先打助手。

助手是安装包内部文件，不出现在 Release 资源列表里当独立下载项。

## 数据流

1. 用户打开对比并点计算 / 加密。
2. Dart 把输入交给 FRB：`cryptoCompare(...)`。
3. `crates/core` 算 Rust 结果；若需要 IV/nonce/salt，先生成再写入请求。
4. 向 Python、Node 助手各发一行 JSON，等两份应答。
5. 规范化输出后比较，返回三列文本与状态。
6. 界面渲染；密钥不落盘。

## 测试

- `crates/core`：CBC 原始密钥、口令派生（固定 salt）三端对齐的单元测试；GCM 仅 Rust/Python 对齐；SM3 两助手 `unsupported`。
- 助手自测：同一固定向量，Nuitka 产物与 `crypto-js` 脚本输出与 Rust 一致。
- Flutter：对比开关默认关；打开后能看到三列标题「Rust」「Python」「crypto-js」。不在 widget 测试里真起助手（用假实现）。
- CI：Windows 打出两个助手并跑助手自测；Ubuntu CI 只测 Rust 对齐逻辑与 Dart 界面，不要求 Nuitka。

## 风险

- 安装包大约再大几十 MB（Nuitka standalone + 便携 Node）。
- Nuitka 编译 `cryptography` 较慢，Release 任务要加长超时。
- 杀毒软件可能拦新打的助手 exe；文档一句说明即可。
- 助手路径在 `flutter run` 与安装后不同，查找顺序必须写进 `docs/development.md`。
