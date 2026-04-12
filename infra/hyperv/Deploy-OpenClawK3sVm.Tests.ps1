$modulePath = Join-Path $PSScriptRoot "OpenClawK3sVmDeploy.psm1"

Import-Module $modulePath -Force

InModuleScope OpenClawK3sVmDeploy {
    Describe "Deploy-OpenClawK3sVm" {
        BeforeEach {
            Mock Get-OpenClawDeployVm { $null }
            Mock Test-Path { $true }
            Mock Split-Path { "C:\Hyper-V\openclaw-k3s" }
            Mock New-Item { }
            Mock Copy-OpenClawVhdx { }
            Mock New-OpenClawDeployVm { }
            Mock Set-OpenClawDeployProcessor { }
            Mock Disable-OpenClawDeployCheckpoints { }
            Mock Set-OpenClawDeployMemory { }
            Mock Set-OpenClawDeploySecureBoot { }
            Mock Start-OpenClawDeployVm { }
            Mock Write-Host { }
        }

        It "throws when the VM already exists" {
            Mock Get-OpenClawDeployVm { @{ Name = "openclaw-k3s" } }

            {
                Deploy-OpenClawK3sVm -VhdxSourcePath "C:\output\disk.vhdx"
            } | Should -Throw "VM 'openclaw-k3s' already exists."

            Should -Invoke Copy-OpenClawVhdx -Times 0
            Should -Invoke New-OpenClawDeployVm -Times 0
        }

        It "throws when the VHDX source path does not exist" {
            Mock Test-Path { $false }

            {
                Deploy-OpenClawK3sVm -VhdxSourcePath "C:\output\missing.vhdx"
            } | Should -Throw "VHDX not found: C:\output\missing.vhdx"

            Should -Invoke Copy-OpenClawVhdx -Times 0
            Should -Invoke New-OpenClawDeployVm -Times 0
        }

        It "copies VHDX, creates, and configures the VM with defaults" {
            Deploy-OpenClawK3sVm -VhdxSourcePath "C:\output\disk.vhdx"

            Should -Invoke Copy-OpenClawVhdx -Times 1 -ParameterFilter {
                $SourcePath -eq "C:\output\disk.vhdx"
            }
            Should -Invoke New-OpenClawDeployVm -Times 1 -ParameterFilter {
                $Name -eq "openclaw-k3s" -and
                $SwitchName -eq "Default Switch"
            }
            Should -Invoke Set-OpenClawDeployProcessor -Times 1 -ParameterFilter {
                $VmName -eq "openclaw-k3s" -and $Count -eq 4
            }
            Should -Invoke Disable-OpenClawDeployCheckpoints -Times 1
            Should -Invoke Set-OpenClawDeployMemory -Times 1
            Should -Invoke Set-OpenClawDeploySecureBoot -Times 1
            Should -Invoke Start-OpenClawDeployVm -Times 0
        }

        It "starts the VM when -Start is specified" {
            Deploy-OpenClawK3sVm -VhdxSourcePath "C:\output\disk.vhdx" -Start

            Should -Invoke Start-OpenClawDeployVm -Times 1 -ParameterFilter {
                $Name -eq "openclaw-k3s"
            }
        }

        It "creates and configures a VM with custom settings" {
            $params = @{
                VhdxSourcePath     = "D:\packer\disk.vhdx"
                Name               = "custom-vm"
                SwitchName         = "External Switch"
                VmPath             = "C:\Hyper-V\custom-vm"
                VhdPath            = "D:\Hyper-V\custom-vm\custom-vm.vhdx"
                MemoryStartupBytes = [UInt64]12GB
                ProcessorCount     = 6
            }

            Mock Split-Path { "D:\Hyper-V\custom-vm" }

            Deploy-OpenClawK3sVm @params

            Should -Invoke Copy-OpenClawVhdx -Times 1 -ParameterFilter {
                $SourcePath -eq "D:\packer\disk.vhdx" -and
                $DestinationPath -eq "D:\Hyper-V\custom-vm\custom-vm.vhdx"
            }
            Should -Invoke New-OpenClawDeployVm -Times 1 -ParameterFilter {
                $Name -eq "custom-vm" -and
                $Path -eq "C:\Hyper-V\custom-vm" -and
                $MemoryStartupBytes -eq 12884901888 -and
                $VhdPath -eq "D:\Hyper-V\custom-vm\custom-vm.vhdx" -and
                $SwitchName -eq "External Switch"
            }
            Should -Invoke Set-OpenClawDeployProcessor -Times 1 -ParameterFilter {
                $VmName -eq "custom-vm" -and $Count -eq 6
            }
            Should -Invoke Disable-OpenClawDeployCheckpoints -Times 1 -ParameterFilter {
                $Name -eq "custom-vm"
            }
            Should -Invoke Set-OpenClawDeployMemory -Times 1 -ParameterFilter {
                $VmName -eq "custom-vm" -and $StartupBytes -eq 12884901888
            }
            Should -Invoke Set-OpenClawDeploySecureBoot -Times 1 -ParameterFilter {
                $VmName -eq "custom-vm"
            }
        }
    }
}
