$modulePath = Join-Path $PSScriptRoot "OpenClawK3sVm.psm1"

Import-Module $modulePath -Force

InModuleScope OpenClawK3sVm {
    Describe "New-OpenClawK3sVm" {
        BeforeEach {
            Mock Get-OpenClawHyperVVm { $null }
            Mock Test-Path { $true }
            Mock Split-Path { "C:\Hyper-V\disks" }
            Mock New-Item { }
            Mock New-OpenClawHyperVVhd { }
            Mock New-OpenClawHyperVVm { }
            Mock Set-OpenClawHyperVProcessor { }
            Mock Disable-OpenClawHyperVCheckpoints { }
            Mock Set-OpenClawHyperVMemory { }
            Mock Add-OpenClawHyperVDvdDrive { "dvd-drive" }
            Mock Get-OpenClawHyperVHardDiskDrive { "hard-drive" }
            Mock Set-OpenClawHyperVSecureBoot { }
            Mock Set-OpenClawHyperVBootOrder { }
            Mock Write-Host { }
        }

        It "throws when the VM already exists" {
            Mock Get-OpenClawHyperVVm { @{ Name = "openclaw-k3s" } }

            {
                New-OpenClawK3sVm -IsoPath "C:\isos\ubuntu.iso"
            } | Should -Throw "VM 'openclaw-k3s' already exists."

            Should -Invoke Test-Path -Times 0
            Should -Invoke New-OpenClawHyperVVm -Times 0
        }

        It "throws when the ISO path does not exist" {
            Mock Test-Path { $false }

            {
                New-OpenClawK3sVm -IsoPath "C:\isos\missing.iso"
            } | Should -Throw "ISO not found: C:\isos\missing.iso"

            Should -Invoke New-OpenClawHyperVVhd -Times 0
            Should -Invoke New-OpenClawHyperVVm -Times 0
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

            New-OpenClawK3sVm @params

            Should -Invoke New-Item -Times 1 -ParameterFilter {
                $ItemType -eq "Directory" -and $Path -eq "C:\Hyper-V\vms\unit-vm" -and $Force
            }
            Should -Invoke New-Item -Times 1 -ParameterFilter {
                $ItemType -eq "Directory" -and $Path -eq "D:\Hyper-V\disks" -and $Force
            }
            Should -Invoke New-OpenClawHyperVVhd -Times 1 -ParameterFilter {
                $Path -eq "D:\Hyper-V\disks\unit-vm.vhdx" -and $SizeBytes -eq 128849018880
            }
            Should -Invoke New-OpenClawHyperVVm -Times 1 -ParameterFilter {
                $Name -eq "unit-vm" -and
                $Path -eq "C:\Hyper-V\vms\unit-vm" -and
                $MemoryStartupBytes -eq 12884901888 -and
                $VhdPath -eq "D:\Hyper-V\disks\unit-vm.vhdx" -and
                $SwitchName -eq "External Switch"
            }
            Should -Invoke Set-OpenClawHyperVProcessor -Times 1 -ParameterFilter {
                $VmName -eq "unit-vm" -and $Count -eq 6
            }
            Should -Invoke Disable-OpenClawHyperVCheckpoints -Times 1 -ParameterFilter {
                $Name -eq "unit-vm"
            }
            Should -Invoke Set-OpenClawHyperVMemory -Times 1 -ParameterFilter {
                $VmName -eq "unit-vm" -and $StartupBytes -eq 12884901888
            }
            Should -Invoke Add-OpenClawHyperVDvdDrive -Times 1 -ParameterFilter {
                $VmName -eq "unit-vm" -and $Path -eq "C:\isos\ubuntu.iso"
            }
            Should -Invoke Get-OpenClawHyperVHardDiskDrive -Times 1 -ParameterFilter {
                $VmName -eq "unit-vm"
            }
            Should -Invoke Set-OpenClawHyperVSecureBoot -Times 1 -ParameterFilter {
                $VmName -eq "unit-vm" -and $FirstBootDevice -eq "dvd-drive"
            }
            Should -Invoke Set-OpenClawHyperVBootOrder -Times 1 -ParameterFilter {
                $VmName -eq "unit-vm" -and
                $BootOrder.Count -eq 2 -and
                $BootOrder[0] -eq "dvd-drive" -and
                $BootOrder[1] -eq "hard-drive"
            }
            Should -Invoke Write-Host -Times 5
        }
    }
}
