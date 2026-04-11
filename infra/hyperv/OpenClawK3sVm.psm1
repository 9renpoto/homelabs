function Get-OpenClawHyperVVm {
    param(
        [string]$Name
    )

    Get-VM -Name $Name -ErrorAction SilentlyContinue
}

function New-OpenClawHyperVVhd {
    param(
        [string]$Path,
        [UInt64]$SizeBytes
    )

    New-VHD -Path $Path -Dynamic -SizeBytes $SizeBytes | Out-Null
}

function New-OpenClawHyperVVm {
    param(
        [string]$Name,
        [string]$Path,
        [UInt64]$MemoryStartupBytes,
        [string]$VhdPath,
        [string]$SwitchName
    )

    New-VM `
        -Name $Name `
        -Generation 2 `
        -Path $Path `
        -MemoryStartupBytes $MemoryStartupBytes `
        -VHDPath $VhdPath `
        -SwitchName $SwitchName | Out-Null
}

function Set-OpenClawHyperVProcessor {
    param(
        [string]$VmName,
        [int]$Count
    )

    Set-VMProcessor -VMName $VmName -Count $Count
}

function Disable-OpenClawHyperVCheckpoints {
    param(
        [string]$Name
    )

    Set-VM -Name $Name -AutomaticCheckpointsEnabled $false
    Set-VM -Name $Name -CheckpointType Disabled
}

function Set-OpenClawHyperVMemory {
    param(
        [string]$VmName,
        [UInt64]$StartupBytes
    )

    Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $true -MinimumBytes 4GB -StartupBytes $StartupBytes -MaximumBytes 16GB
}

function Add-OpenClawHyperVDvdDrive {
    param(
        [string]$VmName,
        [string]$Path
    )

    Add-VMDvdDrive -VMName $VmName -Path $Path
}

function Get-OpenClawHyperVHardDiskDrive {
    param(
        [string]$VmName
    )

    Get-VMHardDiskDrive -VMName $VmName
}

function Set-OpenClawHyperVSecureBoot {
    param(
        [string]$VmName,
        [object]$FirstBootDevice
    )

    Set-VMFirmware `
        -VMName $VmName `
        -EnableSecureBoot On `
        -SecureBootTemplate "MicrosoftUEFICertificateAuthority" `
        -FirstBootDevice $FirstBootDevice
}

function Set-OpenClawHyperVBootOrder {
    param(
        [string]$VmName,
        [object[]]$BootOrder
    )

    Set-VMFirmware -VMName $VmName -BootOrder $BootOrder
}

function New-OpenClawK3sVm {
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

    if (Get-OpenClawHyperVVm -Name $Name) {
        throw "VM '$Name' already exists."
    }

    if (-not (Test-Path -LiteralPath $IsoPath)) {
        throw "ISO not found: $IsoPath"
    }

    $vmDirectory = Split-Path -Parent $VhdPath
    New-Item -ItemType Directory -Path $VmPath -Force | Out-Null
    New-Item -ItemType Directory -Path $vmDirectory -Force | Out-Null

    New-OpenClawHyperVVhd -Path $VhdPath -SizeBytes $VhdSizeBytes
    New-OpenClawHyperVVm -Name $Name -Path $VmPath -MemoryStartupBytes $MemoryStartupBytes -VhdPath $VhdPath -SwitchName $SwitchName
    Set-OpenClawHyperVProcessor -VmName $Name -Count $ProcessorCount
    Disable-OpenClawHyperVCheckpoints -Name $Name
    Set-OpenClawHyperVMemory -VmName $Name -StartupBytes $MemoryStartupBytes

    $dvdDrive = Add-OpenClawHyperVDvdDrive -VmName $Name -Path $IsoPath
    $hardDiskDrive = Get-OpenClawHyperVHardDiskDrive -VmName $Name

    Set-OpenClawHyperVSecureBoot -VmName $Name -FirstBootDevice $dvdDrive
    Set-OpenClawHyperVBootOrder -VmName $Name -BootOrder @($dvdDrive, $hardDiskDrive)

    Write-Host "Created VM '$Name'."
    Write-Host "Next steps:"
    Write-Host "  1. Boot the VM and complete Ubuntu installation with cloud-init/autoinstall seed data."
    Write-Host "  2. Clone the repository in the guest."
    Write-Host "  3. Run infra/k8s/bootstrap-openclaw-vm.sh in the guest."
}

Export-ModuleMember -Function New-OpenClawK3sVm
