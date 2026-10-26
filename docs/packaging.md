# 安装与发布

发布物只有图形界面，不提供命令行安装包。

## 用户怎么装

1. 打开 [Releases](https://github.com/lulufubin/DevKit/releases)
2. 下载 `devkit-desktop-windows-amd64.exe`
3. 双击安装向导：欢迎 → 选择目录 → 快捷方式 → 安装 → 完成（可立即运行）
4. 之后从开始菜单打开 DevKit

替换系统图标后，已安装的 Windows 用户可能仍看到旧任务栏图标，重装或清图标缓存即可。

## 软件内更新

工作台「关于」页可以检查 GitHub 最新 Release。有新版本时启动时也会提示，但不会自动下载。点更新后下载同名安装器并启动向导，覆盖安装（同一 `AppId`）。

需要访问 `api.github.com`。若本机走代理，设置 `HTTP_PROXY` / `HTTPS_PROXY`（例如 `http://127.0.0.1:10808`）。

## 本地打包

```powershell
.\scripts\pack.ps1
```

需要 Flutter 和 [Inno Setup 6](https://jrsoftware.org/isinfo.php)，产出 `dist/devkit-desktop-windows-amd64.exe`。

```powershell
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" /DMyAppVersion=0.2.1 /DSourcePath=build\windows\x64\runner\Release installer\devkit.iss
```

## GitHub 测试、合并、打包

1. 向 `main` 开 PR 后，`CI` 会跑 Rust 测试和 `flutter analyze` / `flutter test`。
2. `CI passed` 通过后，`Automerge` 自动把 PR 合进 `main`。
3. 合并后 `Automerge` 按 `pubspec.yaml` 打标签，并调度 `Release`（Actions 默认 token 合进 `main` 不会再触发 push 工作流）。
4. `Release` 只打 Windows 桌面安装器 `devkit-desktop-windows-amd64.exe`。

`pubspec.yaml` 的版本号必须与标签去掉 `v` 后一致。
