$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
cargo run -p devkit-icon-gen
if ($LASTEXITCODE -ne 0) {
    throw "devkit-icon-gen failed"
}
Write-Host "Icons generated from logo/devkit-logo-light.svg"
