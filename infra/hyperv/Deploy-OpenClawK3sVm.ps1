# Deploy a pre-built openclaw-k3s VHDX as a new Hyper-V VM.
#
# Usage:
#   .\Deploy-OpenClawK3sVm.ps1 -VhdxSourcePath "C:\packer\output-openclaw-k3s\...\disk.vhdx" [-Start]
#
# The VhdxSourcePath is produced by infra\packer\build.ps1.
# Run as Administrator (required for Hyper-V cmdlets).

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$VhdxSourcePath,

    [string]$Name = "openclaw-k3s",
    [string]$SwitchName = "Default Switch",
    [string]$VmPath = "C:\Hyper-V\openclaw-k3s",
    [string]$VhdPath = "C:\Hyper-V\openclaw-k3s\openclaw-k3s.vhdx",
    [UInt64]$MemoryStartupBytes = 8GB,
    [int]$ProcessorCount = 4,
    [switch]$Start
)

$modulePath = Join-Path $PSScriptRoot "OpenClawK3sVmDeploy.psm1"
Import-Module $modulePath -Force

Deploy-OpenClawK3sVm @PSBoundParameters
