$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

New-Item -ItemType Directory -Force -Path (Join-Path $Root "dist") | Out-Null

Write-Host "Building CLI (devkit.exe)..."
cargo build --release -p devkit-cli --locked
Copy-Item (Join-Path $Root "target\release\devkit.exe") (Join-Path $Root "dist\devkit.exe") -Force
Write-Host "CLI -> dist\devkit.exe"

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    $candidate = "D:\Tools\flutter\bin\flutter.bat"
    if (Test-Path $candidate) {
        $env:PATH = "D:\Tools\flutter\bin;$env:PATH"
    }
}

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Write-Host "Building Flutter Windows desktop app..."
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Desktop pack skipped. On Windows, enable Developer Mode (start ms-settings:developers) so Flutter can create plugin symlinks. CI builds the desktop zip on GitHub-hosted runners."
    } else {
        $releaseDir = Join-Path $Root "build\windows\x64\runner\Release"
        if (-not (Test-Path $releaseDir)) {
            $releaseDir = Join-Path $Root "build\windows\runner\Release"
        }
        if (Test-Path $releaseDir) {
            $dest = Join-Path $Root "dist\devkit-desktop"
            if (Test-Path $dest) {
                Remove-Item $dest -Recurse -Force
            }
            Copy-Item $releaseDir $dest -Recurse
            Write-Host "Desktop -> dist\devkit-desktop\"
        } else {
            Write-Warning "Flutter Windows build finished but Release folder was not found."
        }
    }
} else {
    Write-Warning "flutter not on PATH; packed CLI only. Install Flutter to pack the desktop app."
}

Write-Host "Done."
