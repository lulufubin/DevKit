$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$win = Join-Path $root "windows\flutter\ephemeral\.plugin_symlinks"
$linux = Join-Path $root "linux\flutter\ephemeral\.plugin_symlinks"
New-Item -ItemType Directory -Force -Path $win, $linux | Out-Null

$plugins = @{
    rust_lib_devkit = (Join-Path $root "rust_builder")
}

$deps = Join-Path $root ".flutter-plugins-dependencies"
if (Test-Path $deps) {
    $json = Get-Content -Raw -Path $deps | ConvertFrom-Json
    foreach ($plugin in @($json.plugins.windows)) {
        $plugins[$plugin.name] = $plugin.path.TrimEnd('\')
    }
}

foreach ($dir in @($win, $linux)) {
    foreach ($name in $plugins.Keys) {
        $link = Join-Path $dir $name
        $target = $plugins[$name]
        if (Test-Path $link) {
            cmd /c rmdir "$link" | Out-Null
        }
        cmd /c mklink /J "$link" "$target" | Out-Null
    }
}
Write-Host "Created plugin junctions for: $($plugins.Keys -join ', ')"
