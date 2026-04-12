# Packer build wrapper for openclaw-k3s on Hyper-V (Windows)
#
# Usage:
#   .\build.ps1 -SshPublicKey "ssh-ed25519 AAAA..." [-SshPrivateKeyFile "C:\...\id_ed25519"] [-SwitchName "Default Switch"]
#
# Prerequisites:
#   - Packer 1.10.0+  (https://www.packer.io/downloads)
#   - Hyper-V enabled (runs as Administrator)
#   - Internet access to download the Ubuntu ISO (or set -IsoUrl to a local path)
#
# Output:
#   A pre-installed VHDX at .\output-openclaw-k3s\<vm_name>\Virtual Hard Disks\
#   Use Deploy-OpenClawK3sVm.ps1 to create and start the final VM from this VHDX.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SshPublicKey,

    [string]$SshPrivateKeyFile = "$env:USERPROFILE\.ssh\id_ed25519",

    [string]$SwitchName = "Default Switch",

    [string]$IsoUrl = "",

    [string]$IsoChecksum = "",

    [string]$OutputDirectory = "$PSScriptRoot\output-openclaw-k3s"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --------------------------------------------------------------------------
# Generate http/user-data from template
# --------------------------------------------------------------------------
$tmplPath   = Join-Path $PSScriptRoot "http\user-data.tmpl"
$targetPath = Join-Path $PSScriptRoot "http\user-data"

if (-not (Test-Path $tmplPath)) {
    throw "Template not found: $tmplPath"
}

$content = Get-Content $tmplPath -Raw
$content = $content -replace '__SSH_PUBLIC_KEY__', $SshPublicKey
Set-Content -Path $targetPath -Value $content -Encoding UTF8 -NoNewline

Write-Host "Generated: $targetPath"

# --------------------------------------------------------------------------
# Build packer arguments
# --------------------------------------------------------------------------
$packerArgs = @(
    "build",
    "-var", "ssh_private_key_file=$SshPrivateKeyFile",
    "-var", "switch_name=$SwitchName",
    "-var", "output_directory=$OutputDirectory"
)

if ($IsoUrl -ne "") {
    $packerArgs += "-var", "iso_url=$IsoUrl"
}
if ($IsoChecksum -ne "") {
    $packerArgs += "-var", "iso_checksum=$IsoChecksum"
}

$packerArgs += "$PSScriptRoot\openclaw-k3s.pkr.hcl"

# --------------------------------------------------------------------------
# Run Packer (must be run as Administrator for Hyper-V)
# --------------------------------------------------------------------------
Write-Host "Running: packer $packerArgs"
packer @packerArgs

if ($LASTEXITCODE -ne 0) {
    throw "Packer build failed (exit code $LASTEXITCODE)."
}

Write-Host ""
Write-Host "Build complete. VHDX is in: $OutputDirectory"
Write-Host "Next: run infra\hyperv\Deploy-OpenClawK3sVm.ps1 to create and start the VM."
