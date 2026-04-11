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

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (Get-VM -Name $Name -ErrorAction SilentlyContinue) {
    throw "VM '$Name' already exists."
}

if (-not (Test-Path -LiteralPath $IsoPath)) {
    throw "ISO not found: $IsoPath"
}

$vmDirectory = Split-Path -Parent $VhdPath
New-Item -ItemType Directory -Path $VmPath -Force | Out-Null
New-Item -ItemType Directory -Path $vmDirectory -Force | Out-Null

New-VHD -Path $VhdPath -Dynamic -SizeBytes $VhdSizeBytes | Out-Null

New-VM `
    -Name $Name `
    -Generation 2 `
    -Path $VmPath `
    -MemoryStartupBytes $MemoryStartupBytes `
    -VHDPath $VhdPath `
    -SwitchName $SwitchName | Out-Null

Set-VMProcessor -VMName $Name -Count $ProcessorCount
Set-VM -Name $Name -AutomaticCheckpointsEnabled $false
Set-VM -Name $Name -CheckpointType Disabled
Set-VMMemory -VMName $Name -DynamicMemoryEnabled $true -MinimumBytes 4GB -StartupBytes $MemoryStartupBytes -MaximumBytes 16GB

$dvdDrive = Add-VMDvdDrive -VMName $Name -Path $IsoPath
$hardDiskDrive = Get-VMHardDiskDrive -VMName $Name

Set-VMFirmware `
    -VMName $Name `
    -EnableSecureBoot On `
    -SecureBootTemplate "MicrosoftUEFICertificateAuthority" `
    -FirstBootDevice $dvdDrive

Set-VMFirmware -VMName $Name -BootOrder $dvdDrive, $hardDiskDrive

Write-Host "Created VM '$Name'."
Write-Host "Next steps:"
Write-Host "  1. Boot the VM and complete Ubuntu installation with cloud-init/autoinstall seed data."
Write-Host "  2. Clone the repository in the guest."
Write-Host "  3. Run infra/k8s/bootstrap-openclaw-vm.sh in the guest."
