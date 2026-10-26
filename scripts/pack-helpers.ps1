$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "Need uv to pack the Python helper. Install: https://docs.astral.sh/uv/"
}

$pyProject = Join-Path $Root "helpers\crypto-python"
$dist = Join-Path $Root "helpers\dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

Write-Host "uv sync Python helper (cryptography + Nuitka)..."
uv sync --project $pyProject --group pack
if ($LASTEXITCODE -ne 0) { throw "uv sync failed" }

$work = Join-Path $dist "nuitka-work"
$pyOut = Join-Path $dist "crypto-python"
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
if (Test-Path $pyOut) { Remove-Item -Recurse -Force $pyOut }

Write-Host "Nuitka standalone via uv..."
uv run --project $pyProject --group pack python -m nuitka --standalone --windows-console-mode=disable --assume-yes-for-downloads --output-filename=devkit-crypto-python.exe --output-dir=$work (Join-Path $pyProject "main.py")
if ($LASTEXITCODE -ne 0) { throw "Nuitka failed" }
$built = Get-ChildItem $work -Directory -Filter "*.dist" | Select-Object -First 1
if (-not $built) { throw "Nuitka dist folder not found" }
Move-Item $built.FullName $pyOut

$nodeDir = Join-Path $Root "helpers\crypto-node"
Write-Host "pnpm install crypto-js..."
if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    throw "Need pnpm to pack the Node helper. Install: https://pnpm.io/installation"
}
Push-Location $nodeDir
pnpm install --prod
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "pnpm install failed" }
Pop-Location

$nodeVer = "v22.21.0"
$zipName = "node-$nodeVer-win-x64.zip"
$zipUrl = "https://nodejs.org/dist/$nodeVer/$zipName"
$zipPath = Join-Path $dist $zipName
Write-Host "Downloading $zipUrl"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
$extract = Join-Path $dist "node-extract"
if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
Expand-Archive -Path $zipPath -DestinationPath $extract
$nodeExe = Get-ChildItem $extract -Recurse -Filter node.exe | Select-Object -First 1
if (-not $nodeExe) { throw "node.exe not in official zip" }

$jsOut = Join-Path $dist "crypto-node"
if (Test-Path $jsOut) { Remove-Item -Recurse -Force $jsOut }
New-Item -ItemType Directory -Force -Path $jsOut | Out-Null
Copy-Item $nodeExe.FullName (Join-Path $jsOut "node.exe")
Copy-Item (Join-Path $nodeDir "index.js") (Join-Path $jsOut "index.js")
Copy-Item (Join-Path $nodeDir "package.json") (Join-Path $jsOut "package.json")
Copy-Item (Join-Path $nodeDir "node_modules") (Join-Path $jsOut "node_modules") -Recurse

Write-Host "Helpers -> helpers\dist\crypto-python and helpers\dist\crypto-node"
