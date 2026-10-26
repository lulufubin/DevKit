$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

New-Item -ItemType Directory -Force -Path (Join-Path $Root "dist") | Out-Null

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

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "flutter not on PATH. Desktop installer is the only pack output."
}

Write-Host "Packing Python / Node helpers..."
& (Join-Path $Root "scripts\pack-helpers.ps1")

Write-Host "Building Flutter Windows desktop app..."
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    throw "Desktop pack failed. Need Developer Mode or C++ desktop workload. CI builds the installer."
}

$releaseDir = Join-Path $Root "build\windows\x64\runner\Release"
if (-not (Test-Path $releaseDir)) {
    $releaseDir = Join-Path $Root "build\windows\runner\Release"
}
if (-not (Test-Path $releaseDir)) {
    throw "Flutter Windows build finished but Release folder was not found."
}

$helpersDest = Join-Path $releaseDir "helpers"
New-Item -ItemType Directory -Force -Path $helpersDest | Out-Null
Copy-Item (Join-Path $Root "helpers\dist\crypto-python") (Join-Path $helpersDest "crypto-python") -Recurse -Force
Copy-Item (Join-Path $Root "helpers\dist\crypto-node") (Join-Path $helpersDest "crypto-node") -Recurse -Force

$iscc = Get-InnoCompiler
if (-not $iscc) {
    throw "Inno Setup 6 not found. Install it to build dist\devkit-desktop-windows-amd64.exe"
}

$version = "0.2.1"
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
Write-Host "Done."
