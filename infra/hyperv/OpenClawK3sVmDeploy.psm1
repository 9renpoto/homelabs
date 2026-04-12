function Get-OpenClawDeployVm {
    param(
        [string]$Name
    )

    Get-VM -Name $Name -ErrorAction SilentlyContinue
}

function Copy-OpenClawVhdx {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
}

function New-OpenClawDeployVm {
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
        -VHDPath $VhdPath `
        -MemoryStartupBytes $MemoryStartupBytes `
        -SwitchName $SwitchName | Out-Null
}

function Set-OpenClawDeployProcessor {
    param(
        [string]$VmName,
        [int]$Count
    )

    Set-VMProcessor -VMName $VmName -Count $Count
}

function Disable-OpenClawDeployCheckpoints {
    param(
        [string]$Name
    )

    Set-VM -Name $Name -AutomaticCheckpointsEnabled $false
    Set-VM -Name $Name -CheckpointType Disabled
}

function Set-OpenClawDeployMemory {
    param(
        [string]$VmName,
        [UInt64]$StartupBytes
    )

    Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $true -MinimumBytes 4GB -StartupBytes $StartupBytes -MaximumBytes 16GB
}

function Set-OpenClawDeploySecureBoot {
    param(
        [string]$VmName
    )

    $hdd = Get-VMHardDiskDrive -VMName $VmName
    Set-VMFirmware `
        -VMName $VmName `
        -EnableSecureBoot On `
        -SecureBootTemplate "MicrosoftUEFICertificateAuthority" `
        -FirstBootDevice $hdd
}

function Start-OpenClawDeployVm {
    param(
        [string]$Name
    )

    Start-VM -Name $Name
}

function Deploy-OpenClawK3sVm {
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

    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    if (Get-OpenClawDeployVm -Name $Name) {
        throw "VM '$Name' already exists."
    }

    if (-not (Test-Path -LiteralPath $VhdxSourcePath)) {
        throw "VHDX not found: $VhdxSourcePath"
    }

    $vmDirectory = Split-Path -Parent $VhdPath
    New-Item -ItemType Directory -Path $VmPath -Force | Out-Null
    New-Item -ItemType Directory -Path $vmDirectory -Force | Out-Null

    Write-Host "Copying VHDX from Packer output..."
    Copy-OpenClawVhdx -SourcePath $VhdxSourcePath -DestinationPath $VhdPath

    New-OpenClawDeployVm -Name $Name -Path $VmPath -MemoryStartupBytes $MemoryStartupBytes -VhdPath $VhdPath -SwitchName $SwitchName
    Set-OpenClawDeployProcessor -VmName $Name -Count $ProcessorCount
    Disable-OpenClawDeployCheckpoints -Name $Name
    Set-OpenClawDeployMemory -VmName $Name -StartupBytes $MemoryStartupBytes
    Set-OpenClawDeploySecureBoot -VmName $Name

    Write-Host "Created VM '$Name' from: $VhdxSourcePath"

    if ($Start) {
        Start-OpenClawDeployVm -Name $Name
        Write-Host "VM '$Name' started."
    }

    Write-Host "Next steps:"
    Write-Host "  1. SSH into the VM: ssh openclaw@<vm-ip>"
    Write-Host "  2. Clone the repository in the guest."
    Write-Host "  3. Run infra/k8s/bootstrap-openclaw-vm.sh in the guest."
}

Export-ModuleMember -Function Deploy-OpenClawK3sVm, Start-OpenClawDeployVm
