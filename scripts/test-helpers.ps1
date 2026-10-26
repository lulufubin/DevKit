$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Invoke-JsonHelper {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][string]$Exe,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)]$Request
    )
    $line = ($Request | ConvertTo-Json -Compress)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Exe
    foreach ($arg in $Arguments) {
        [void]$psi.ArgumentList.Add($arg)
    }
    $psi.WorkingDirectory = $Root
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.StandardInput.WriteLine($line)
    $proc.StandardInput.Close()
    if (-not $proc.WaitForExit(30000)) {
        $proc.Kill()
        throw "$File helper timed out"
    }
    $out = $proc.StandardOutput.ReadLine()
    if (-not $out) {
        throw "$File helper empty stdout: $($proc.StandardError.ReadToEnd())"
    }
    return $out | ConvertFrom-Json
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "Need uv to run Python helper tests. Install: https://docs.astral.sh/uv/"
}
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    throw "Need node on PATH to run helper source tests"
}

$pyProject = Join-Path $Root "helpers\crypto-python"
Write-Host "uv sync Python helper..."
uv sync --project $pyProject
if ($LASTEXITCODE -ne 0) { throw "uv sync failed" }

$pyArgs = @("run", "--project", $pyProject, "python", (Join-Path $pyProject "main.py"))
$jsArgs = @(Join-Path $Root "helpers\crypto-node\index.js")

$sha = Invoke-JsonHelper -File python -Exe "uv" -Arguments $pyArgs -Request @{ id = "1"; op = "hash"; alg = "sha256"; data = "abc"; encoding = "utf8" }
if ($sha.output -ne "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") {
    throw "python sha256 mismatch: $($sha.output)"
}
$shaJs = Invoke-JsonHelper -File node -Exe $node.Source -Arguments $jsArgs -Request @{ id = "1"; op = "hash"; alg = "sha256"; data = "abc"; encoding = "utf8" }
if ($shaJs.output -ne $sha.output) { throw "node sha256 mismatch" }

$sm3 = Invoke-JsonHelper -File python -Exe "uv" -Arguments $pyArgs -Request @{ id = "2"; op = "hash"; alg = "sm3"; data = "abc"; encoding = "utf8" }
if (-not $sm3.unsupported) { throw "python should reject SM3" }
$sm3Js = Invoke-JsonHelper -File node -Exe $node.Source -Arguments $jsArgs -Request @{ id = "2"; op = "hash"; alg = "sm3"; data = "abc"; encoding = "utf8" }
if (-not $sm3Js.unsupported) { throw "crypto-js should reject SM3" }

$hmac = @{
    id = "3"; op = "hmac"; alg = "sha256"; key = "key"; keyEncoding = "utf8"
    data = "The quick brown fox jumps over the lazy dog"; encoding = "utf8"
}
$h1 = Invoke-JsonHelper -File python -Exe "uv" -Arguments $pyArgs -Request $hmac
$h2 = Invoke-JsonHelper -File node -Exe $node.Source -Arguments $jsArgs -Request $hmac
if ($h1.output -ne "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8") { throw "python hmac mismatch" }
if ($h1.output -ne $h2.output) { throw "hmac python/node mismatch" }

$enc = @{
    id = "4"; op = "encrypt"; alg = "aes-256-cbc"; key = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
    keyEncoding = "hex"; data = "hello DevKit"; encoding = "utf8"; outputEncoding = "hex"
    keyMode = "raw"; ivHex = "000102030405060708090a0b0c0d0e0f"
}
$c1 = Invoke-JsonHelper -File python -Exe "uv" -Arguments $pyArgs -Request $enc
$c2 = Invoke-JsonHelper -File node -Exe $node.Source -Arguments $jsArgs -Request $enc
if ($c1.output -ne $c2.output) { throw "CBC python/node mismatch: $($c1.output) vs $($c2.output)" }
if (-not $c1.output.StartsWith("000102030405060708090a0b0c0d0e0f")) { throw "CBC missing IV prefix" }

$pass = @{
    id = "5"; op = "encrypt"; alg = "aes-256-cbc"; key = "secret"; keyEncoding = "utf8"
    data = "hello DevKit"; encoding = "utf8"; outputEncoding = "base64"
    keyMode = "passphrase"; saltHex = "0102030405060708"
}
$p1 = Invoke-JsonHelper -File python -Exe "uv" -Arguments $pyArgs -Request $pass
$p2 = Invoke-JsonHelper -File node -Exe $node.Source -Arguments $jsArgs -Request $pass
if ($p1.output -ne $p2.output) { throw "passphrase python/node mismatch" }

Write-Host "Helper source tests passed."
