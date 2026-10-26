#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p dist

echo "Building CLI..."
cargo build --release -p devkit-cli --locked
cp "$ROOT/target/release/devkit" "$ROOT/dist/devkit"
echo "CLI -> dist/devkit"

pack_desktop() {
  if ! command -v flutter >/dev/null 2>&1; then
    echo "flutter not on PATH; packed CLI only."
    return 0
  fi
  case "$(uname -s)" in
    Darwin)
      echo "Building Flutter macOS app..."
      if flutter build macos --release; then
        local src="build/macos/Build/Products/Release"
        if [[ -d "$src" ]]; then
          rm -rf dist/devkit-desktop
          mkdir -p dist/devkit-desktop
          cp -R "$src"/*.app dist/devkit-desktop/ 2>/dev/null || cp -R "$src"/. dist/devkit-desktop/
          echo "Desktop -> dist/devkit-desktop/"
        fi
      else
        echo "warning: desktop pack skipped (flutter build macos failed)"
      fi
      ;;
    Linux)
      echo "Building Flutter Linux app..."
      if flutter build linux --release; then
        local src=""
        if [[ -d build/linux/x64/release/bundle ]]; then
          src="build/linux/x64/release/bundle"
        elif [[ -d build/linux/arm64/release/bundle ]]; then
          src="build/linux/arm64/release/bundle"
        fi
        if [[ -n "$src" ]]; then
          rm -rf dist/devkit-desktop
          cp -a "$src" dist/devkit-desktop
          echo "Desktop -> dist/devkit-desktop/"
        else
          echo "warning: Flutter Linux build finished but bundle folder was not found."
        fi
      else
        echo "warning: desktop pack skipped (flutter build linux failed)"
      fi
      ;;
    *)
      echo "No desktop pack for $(uname -s); packed CLI only."
      ;;
  esac
}

pack_desktop
echo "Done."
