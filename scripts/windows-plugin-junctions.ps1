$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root "rust_builder"
$win = Join-Path $root "windows\flutter\ephemeral\.plugin_symlinks"
$linux = Join-Path $root "linux\flutter\ephemeral\.plugin_symlinks"
New-Item -ItemType Directory -Force -Path $win, $linux | Out-Null
foreach ($dir in @($win, $linux)) {
    $link = Join-Path $dir "rust_lib_devkit"
    if (Test-Path $link) {
        cmd /c rmdir "$link" | Out-Null
    }
    cmd /c mklink /J "$link" "$target" | Out-Null
}
Write-Host "Created plugin junctions -> $target"
