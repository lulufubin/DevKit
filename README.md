# DevKit

Local-first developer toolkit. First slice: **streaming age encrypt/decrypt** for large files.

- **Core:** Rust crate (`crates/core`) streams files and never loads them whole into memory.
- **CLI:** `devkit` binary shares that crate.
- **Desktop:** Flutter Windows/Linux/macOS UI talks to the same core through flutter_rust_bridge.

JSON compare, HAR analysis, and other tools are intentionally not in this slice.

## Prerequisites

- Rust stable (`cargo`)
- Flutter 3.47+ with desktop enabled (`flutter config --enable-windows-desktop`)
- `flutter_rust_bridge_codegen` 2.13 (`cargo install flutter_rust_bridge_codegen`) — only needed when changing Rust APIs

On this Windows machine Flutter is at `D:\Tools\flutter`.

## Run locally

### CLI

```bash
cargo run -p devkit-cli -- encrypt --input secret.bin --output secret.bin.age
cargo run -p devkit-cli -- decrypt --input secret.bin.age --output secret.bin
```

Omit `--passphrase` to be prompted. Passing `--passphrase` is for scripts; it shows up in process lists.

```bash
cargo test --workspace
```

### Desktop

Windows desktop builds need **Developer Mode** so Flutter can create plugin
symlinks (`start ms-settings:developers`). Without it, `flutter run` /
`flutter build windows` fail with error 1314. After enabling it:

```bash
flutter pub get
flutter run -d windows
```

If Developer Mode is off, `.\scripts\windows-plugin-junctions.ps1` can create
directory junctions for `rust_lib_devkit` after `flutter pub get`. GitHub
Actions Windows runners can create symlinks, so CI packs the desktop zip.

If you change `rust/src/api/`, regenerate bindings:

```bash
flutter_rust_bridge_codegen generate
```

Type an input path, output path, and passphrase, then **加密** or **解密**.

## Pack

Local pack (Windows):

```powershell
.\scripts\pack.ps1
```

Writes:

- `dist/devkit.exe` — CLI
- `dist/devkit-desktop/` — Flutter Windows release folder (if `flutter` is on PATH)

Unix CLI (and Flutter if present):

```bash
./scripts/pack.sh
```

### GitHub Actions

- `CI` runs `cargo test --workspace` (Ubuntu + Windows) and `flutter analyze` / `flutter test`.
- `Release` builds CLI binaries for Windows/Linux/macOS and a Windows desktop zip.
- Push a tag `v0.1.0` to publish those artifacts on the GitHub Release.

```bash
git tag v0.1.0
git push origin v0.1.0
```
