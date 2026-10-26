# 安装与发布

## 用户怎么装

1. 打开 [Releases](https://github.com/lulufubin/DevKit/releases)
2. 下载 `devkit-desktop-windows-amd64.exe`
3. 双击安装向导：欢迎 → 选择目录 → 快捷方式 → 安装 → 完成（可立即运行）
4. 之后从开始菜单打开 DevKit

命令行加解密是另一套文件：`devkit-cli-windows-amd64.exe`，需在终端里使用 `encrypt` / `decrypt`。

## 软件内更新

工作台「关于」页可以检查 GitHub 最新 Release。有新版本时启动时也会提示，但不会自动下载。点更新后下载同名安装器并启动向导，覆盖安装（同一 `AppId`）。

需要访问 `api.github.com`。若本机走代理，设置 `HTTP_PROXY` / `HTTPS_PROXY`（例如 `http://127.0.0.1:10808`）。

## 本地打包

```powershell
.\scripts\pack.ps1
```

有 Flutter 且本机装了 [Inno Setup 6](https://jrsoftware.org/isinfo.php) 时，会生成 `dist/devkit-desktop-windows-amd64.exe`。否则只打 CLI，或仅复制桌面 Release 目录。

```powershell
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" /DMyAppVersion=0.2.0 /DSourcePath=build\windows\x64\runner\Release installer\devkit.iss
```

## GitHub 测试、合并、打包

1. 向 `main` 开 PR 后，`CI` 会跑 Rust 工作区测试、CLI 加解密往返、FRB crate 检查，以及 `flutter analyze` / `flutter test`。
2. `CI passed` 通过后，`Automerge` 自动把 PR 合进 `main`。
3. `main` 上的 CI 通过后，`Tag release` 若还没有 `v` + `pubspec.yaml` 版本号的标签，会打上该标签，并显式调度 `Release`（Actions 默认 token 推送的 tag 不会自动触发其他 workflow）。
4. `Release` 打 CLI 与 Windows 安装器，并发布到 GitHub Release。

手动补打：`git tag v0.2.0 && git push origin v0.2.0`。

## GitHub Release

推送标签 `v*`（例如 `v0.2.0`）会跑 `.github/workflows/release.yml`：

- 编译 CLI（Windows / Linux / macOS）
- `flutter build windows` 后用 Inno Setup 打安装器
- 上传到 GitHub Release

`pubspec.yaml` 的版本号必须与标签去掉 `v` 后一致，软件内更新才比较得准。
