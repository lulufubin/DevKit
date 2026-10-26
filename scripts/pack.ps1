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

function Get-InnoCompiler {
    foreach ($candidate in @(
            (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
            (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
        )) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }
    return $null
}

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Write-Host "Building Flutter Windows desktop app..."
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Desktop pack skipped. Need Developer Mode or C++ desktop workload. CI builds the installer."
    } else {
        $releaseDir = Join-Path $Root "build\windows\x64\runner\Release"
        if (-not (Test-Path $releaseDir)) {
            $releaseDir = Join-Path $Root "build\windows\runner\Release"
        }
        if (-not (Test-Path $releaseDir)) {
            Write-Warning "Flutter Windows build finished but Release folder was not found."
        } else {
            $iscc = Get-InnoCompiler
            if ($iscc) {
                $version = "0.2.0"
                $pubspec = Get-Content (Join-Path $Root "pubspec.yaml") -Raw
                if ($pubspec -match '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
                    $version = $Matches[1]
                }
                $out = Join-Path $Root "dist"
                & $iscc "/DMyAppVersion=$version" "/DSourcePath=$releaseDir" "/DOutputDir=$out" (Join-Path $Root "installer\devkit.iss")
                if ($LASTEXITCODE -ne 0) {
                    throw "ISCC failed"
                }
                Write-Host "Installer -> dist\devkit-desktop-windows-amd64.exe"
            } else {
                $dest = Join-Path $Root "dist\devkit-desktop"
                if (Test-Path $dest) {
                    Remove-Item $dest -Recurse -Force
                }
                Copy-Item $releaseDir $dest -Recurse
                Write-Warning "Inno Setup 6 not found; copied desktop folder to dist\devkit-desktop\. Install Inno Setup to build the exe installer."
            }
        }
    }
} else {
    Write-Warning "flutter not on PATH; packed CLI only. Install Flutter to pack the desktop app."
}

Write-Host "Done."
