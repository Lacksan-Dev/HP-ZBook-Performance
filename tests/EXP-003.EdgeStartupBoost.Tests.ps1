BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\experiments\EXP-003\EdgeStartupBoost.psm1'
    Import-Module $modulePath -Force
}

Describe 'EXP-003 Edge Startup Boost calibration' {
    InModuleScope EdgeStartupBoost {
        BeforeEach {
            Mock Get-CimInstance {
                param($ClassName)
                if ($ClassName -eq 'Win32_OperatingSystem') { return [pscustomobject]@{ Caption='Microsoft Windows 11 Pro'; BuildNumber='26100' } }
                [pscustomobject]@{ Manufacturer='HP'; Model='HP ZBook Firefly 14 G8' }
            }
            Mock Test-Path { $true }
            Mock Get-Item {
                param($LiteralPath)
                if ($LiteralPath -like '*msedge.exe') { return [pscustomobject]@{ VersionInfo=[pscustomobject]@{ ProductVersion='152.0.1000.1' } } }
                $key=New-Object psobject
                $key | Add-Member ScriptMethod GetValue { param($name,$default,$options) $default }
                $key | Add-Member ScriptMethod GetValueKind { param($name) [Microsoft.Win32.RegistryValueKind]::DWord }
                $key
            }
        }

        It 'supports HP Windows 11 with Edge 88 or later and no mandatory override' {
            (Get-Exp003Support).Supported | Should -BeTrue
        }

        It 'rejects a non-HP system' {
            Mock Get-CimInstance {
                param($ClassName)
                if ($ClassName -eq 'Win32_OperatingSystem') { return [pscustomobject]@{ Caption='Microsoft Windows 11 Pro'; BuildNumber='26100' } }
                [pscustomobject]@{ Manufacturer='Other'; Model='Workstation' }
            }
            (Get-Exp003Support).Supported | Should -BeFalse
        }

        It 'refuses to override a mandatory enterprise policy' {
            Mock Get-RegistryValueState { [pscustomobject]@{ Exists=$true; Value=1 } }
            (Get-Exp003Support).Supported | Should -BeFalse
            (Get-Exp003Support).Reason | Should -Match 'Mandatory enterprise'
        }

        It 'dry run preserves mandatory policy and Startup folder' {
            Mock Get-Exp003State {
                [pscustomobject]@{ MandatoryPolicy=[pscustomobject]@{Exists=$false}; RecommendedPolicy=[pscustomobject]@{Exists=$false;Value=$null}; EdgeProcesses=@() }
            }
            $result=Invoke-Exp003DryRun -StartupBoost Enable
            $result.WouldChange | Should -BeTrue
            $result.PreservesMandatoryPolicy | Should -BeTrue
            $result.PreservesStartupFolder | Should -BeTrue
        }

        It 'is idempotent when recommended policy already matches' {
            Mock Get-Exp003State {
                [pscustomobject]@{ MandatoryPolicy=[pscustomobject]@{Exists=$false}; RecommendedPolicy=[pscustomobject]@{Exists=$true;Value=1}; EdgeProcesses=@() }
            }
            (Invoke-Exp003DryRun -StartupBoost Enable).WouldChange | Should -BeFalse
        }

        It 'verifies recommended policy with mandatory policy clear' {
            Mock Get-Exp003State {
                [pscustomobject]@{ MandatoryPolicy=[pscustomobject]@{Exists=$false}; RecommendedPolicy=[pscustomobject]@{Exists=$true;Value=1}; EdgeProcesses=@() }
            }
            (Test-Exp003Configuration -ExpectedStartupBoost 1).Success | Should -BeTrue
        }

        It 'rejects rollback state for another experiment' {
            Mock Get-Content { '{"SchemaVersion":1,"Experiment":"OTHER","State":{}}' }
            { Restore-Exp003State -StatePath 'state.json' -LogPath 'log.jsonl' -Confirm:$false } | Should -Throw '*identity mismatch*'
        }
    }
}
