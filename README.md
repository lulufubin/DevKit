# DevKit

跨平台桌面工作台：Flutter 做界面，Rust 做计算。支持 Windows / macOS / Linux。

密钥只在本次会话使用，不写磁盘。不做 HAR 重放。

## 工具

- **JSON**：同一编辑器里格式化 / 压缩 / 转义，支持严格与宽容（尾逗号如 `{},`）解析；另有结构对比
- **加解密**：Base64 / URL / Hex、MD5 / SHA-1 / SHA-256、AES-256-GCM、HMAC-SHA256、RSA、国密 SM2 / SM3 / SM4
- **HAR**：导入、筛选、详情、导出，以及复制为 Python `requests`

开发说明见 [docs/development.md](docs/development.md)，安装与发布见 [docs/packaging.md](docs/packaging.md)。

## 更新日志

### 0.2.1

- 加解密各页输入输出左右并排，占满剩余高度
- 发布物只保留图形界面安装包 `devkit-desktop-windows-amd64.exe`，不再附带命令行二进制

### 0.2.0

- Windows 桌面改为安装向导 `devkit-desktop-windows-amd64.exe`，无需再解压 zip
- 工作台「关于」页可检查 GitHub 更新并下载安装器
- README 只保留工具说明与更新日志，其余文档移到 `docs/`

### 0.1.1

- 区分命令行产物与桌面工作台；无参数启动 CLI 时说明用法并等待关闭

### 0.1.0

- 第一期工作台：JSON、加解密、HAR、流式 age
