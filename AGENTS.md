# AGENTS.md

Greenfield DevKit. Stack is Flutter desktop + Rust core (flutter_rust_bridge) + a Rust CLI that shares `crates/core`.

## First slice

Streaming age encrypt/decrypt for large files. Do not add JSON compare, HAR, or extra crypto tools until that slice is shipped.

- Core: `crates/core` — path-based streaming APIs only
- CLI: `crates/cli` binary name `devkit`
- Desktop: Flutter app at repo root, Rust FFI crate in `rust/`
- Pack: `scripts/pack.ps1` / `scripts/pack.sh`
- CI/release: `.github/workflows/`

## Commands

```
cargo test --workspace
cargo run -p devkit-cli -- encrypt --input IN --output OUT
flutter pub get
flutter run -d windows
flutter_rust_bridge_codegen generate
.\scripts\pack.ps1
```

After changing `rust/src/api/`, run `flutter_rust_bridge_codegen generate`.

## Notes

- Do not load whole files into memory.
- Do not touch `invoice-tool-api` or other repos on this machine.
- GUI copy is Chinese; CLI flags and README are English.
