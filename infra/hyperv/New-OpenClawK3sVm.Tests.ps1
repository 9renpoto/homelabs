$scriptPath = Join-Path $PSScriptRoot "New-OpenClawK3sVm.ps1"

Describe "New-OpenClawK3sVm.ps1" {
    BeforeEach {
        Mock Get-VM { $null }
        Mock Test-Path { $true }
        Mock Split-Path { "C:\Hyper-V\disks" }
        Mock New-Item { }
        Mock New-VHD { }
        Mock New-VM { }
        Mock Set-VMProcessor { }
        Mock Set-VM { }
        Mock Set-VMMemory { }
        Mock Add-VMDvdDrive { "dvd-drive" }
        Mock Get-VMHardDiskDrive { "hard-drive" }
        Mock Set-VMFirmware { }
        Mock Write-Host { }
    }

    It "throws when the VM already exists" {
        Mock Get-VM { @{ Name = "openclaw-k3s" } }

        {
            & $scriptPath -IsoPath "C:\isos\ubuntu.iso"
        } | Should -Throw "VM 'openclaw-k3s' already exists."

        Should -Invoke Test-Path -Times 0
        Should -Invoke New-VM -Times 0
    }

    It "throws when the ISO path does not exist" {
        Mock Test-Path { $false }

        {
            & $scriptPath -IsoPath "C:\isos\missing.iso"
        } | Should -Throw "ISO not found: C:\isos\missing.iso"

        Should -Invoke New-VHD -Times 0
        Should -Invoke New-VM -Times 0
    }

    It "creates and configures a new VM with the requested settings" {
        $params = @{
            IsoPath            = "C:\isos\ubuntu.iso"
            Name               = "unit-vm"
            SwitchName         = "External Switch"
            VmPath             = "C:\Hyper-V\vms\unit-vm"
            VhdPath            = "D:\Hyper-V\disks\unit-vm.vhdx"
            VhdSizeBytes       = 120GB
            MemoryStartupBytes = 12GB
            ProcessorCount     = 6
        }

        Mock Split-Path { "D:\Hyper-V\disks" }

        & $scriptPath @params

        Should -Invoke New-Item -Times 1 -ParameterFilter {
            $ItemType -eq "Directory" -and $Path -eq "C:\Hyper-V\vms\unit-vm" -and $Force
        }
        Should -Invoke New-Item -Times 1 -ParameterFilter {
            $ItemType -eq "Directory" -and $Path -eq "D:\Hyper-V\disks" -and $Force
        }
        Should -Invoke New-VHD -Times 1 -ParameterFilter {
            $Path -eq "D:\Hyper-V\disks\unit-vm.vhdx" -and $Dynamic -and $SizeBytes -eq 128849018880
        }
        Should -Invoke New-VM -Times 1 -ParameterFilter {
            $Name -eq "unit-vm" -and
            $Generation -eq 2 -and
            $Path -eq "C:\Hyper-V\vms\unit-vm" -and
            $MemoryStartupBytes -eq 12884901888 -and
            $VHDPath -eq "D:\Hyper-V\disks\unit-vm.vhdx" -and
            $SwitchName -eq "External Switch"
        }
        Should -Invoke Set-VMProcessor -Times 1 -ParameterFilter {
            $VMName -eq "unit-vm" -and $Count -eq 6
        }
        Should -Invoke Set-VM -Times 1 -ParameterFilter {
            $Name -eq "unit-vm" -and $AutomaticCheckpointsEnabled -eq $false
        }
        Should -Invoke Set-VM -Times 1 -ParameterFilter {
            $Name -eq "unit-vm" -and $CheckpointType -eq "Disabled"
        }
        Should -Invoke Set-VMMemory -Times 1 -ParameterFilter {
            $VMName -eq "unit-vm" -and
            $DynamicMemoryEnabled -and
            $MinimumBytes -eq 4294967296 -and
            $StartupBytes -eq 12884901888 -and
            $MaximumBytes -eq 17179869184
        }
        Should -Invoke Add-VMDvdDrive -Times 1 -ParameterFilter {
            $VMName -eq "unit-vm" -and $Path -eq "C:\isos\ubuntu.iso"
        }
        Should -Invoke Get-VMHardDiskDrive -Times 1 -ParameterFilter {
            $VMName -eq "unit-vm"
        }
        Should -Invoke Set-VMFirmware -Times 1 -ParameterFilter {
            $VMName -eq "unit-vm" -and
            $EnableSecureBoot -eq "On" -and
            $SecureBootTemplate -eq "MicrosoftUEFICertificateAuthority" -and
            $FirstBootDevice -eq "dvd-drive"
        }
        Should -Invoke Set-VMFirmware -Times 1 -ParameterFilter {
            $VMName -eq "unit-vm" -and
            $BootOrder.Count -eq 2 -and
            $BootOrder[0] -eq "dvd-drive" -and
            $BootOrder[1] -eq "hard-drive"
        }
        Should -Invoke Write-Host -Times 5
    }
}
