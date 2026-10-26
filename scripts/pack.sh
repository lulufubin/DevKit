#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p dist

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not on PATH; desktop pack is the only release output." >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    echo "Building Flutter macOS app..."
    flutter build macos --release
    src="build/macos/Build/Products/Release"
    if [[ ! -d "$src" ]]; then
      echo "macOS Release folder not found." >&2
      exit 1
    fi
    rm -rf dist/devkit-desktop
    mkdir -p dist/devkit-desktop
    cp -R "$src"/*.app dist/devkit-desktop/ 2>/dev/null || cp -R "$src"/. dist/devkit-desktop/
    echo "Desktop -> dist/devkit-desktop/"
    ;;
  Linux)
    echo "Building Flutter Linux app..."
    flutter build linux --release
    src=""
    if [[ -d build/linux/x64/release/bundle ]]; then
      src="build/linux/x64/release/bundle"
    elif [[ -d build/linux/arm64/release/bundle ]]; then
      src="build/linux/arm64/release/bundle"
    fi
    if [[ -z "$src" ]]; then
      echo "Linux bundle folder not found." >&2
      exit 1
    fi
    rm -rf dist/devkit-desktop
    cp -a "$src" dist/devkit-desktop
    echo "Desktop -> dist/devkit-desktop/"
    ;;
  *)
    echo "Use scripts/pack.ps1 on Windows to build the installer exe." >&2
    exit 1
    ;;
esac

echo "Done."
