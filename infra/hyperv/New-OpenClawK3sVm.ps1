[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$IsoPath,

    [string]$Name = "openclaw-k3s",
    [string]$SwitchName = "Default Switch",
    [string]$VmPath = "C:\Hyper-V\openclaw-k3s",
    [string]$VhdPath = "C:\Hyper-V\openclaw-k3s\openclaw-k3s.vhdx",
    [UInt64]$VhdSizeBytes = 80GB,
    [UInt64]$MemoryStartupBytes = 8GB,
    [int]$ProcessorCount = 4
)

$modulePath = Join-Path $PSScriptRoot "OpenClawK3sVm.psm1"
Import-Module $modulePath -Force

New-OpenClawK3sVm @PSBoundParameters
