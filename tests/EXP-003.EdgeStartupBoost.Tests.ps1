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
                return [pscustomobject]@{ Manufacturer='HP'; Model='HP ZBook Firefly 14 G8' }
            }
            Mock Test-Path { $true }
            Mock Get-Item {
                param($LiteralPath)
                if ($LiteralPath -like '*msedge.exe') {
                    return [pscustomobject]@{ VersionInfo=[pscustomobject]@{ ProductVersion='152.0.1000.1' } }
                }
                $key = New-Object psobject
                $key | Add-Member ScriptMethod GetValue { param($name,$default,$options) $default }
                $key | Add-Member ScriptMethod GetValueKind { param($name) [Microsoft.Win32.RegistryValueKind]::DWord }
                return $key
            }
        }

        It 'supports HP Windows 11 with Edge 88 or later' {
            (Get-Exp003Support).Supported | Should -BeTrue
        }

        It 'rejects a non-HP system' {
            Mock Get-CimInstance {
                param($ClassName)
                if ($ClassName -eq 'Win32_OperatingSystem') { return [pscustomobject]@{ Caption='Microsoft Windows 11 Pro'; BuildNumber='26100' } }
                return [pscustomobject]@{ Manufacturer='Other'; Model='Workstation' }
            }
            (Get-Exp003Support).Supported | Should -BeFalse
        }

        It 'dry run preserves the Startup folder and disables visible launch' {
            Mock Get-Exp003State {
                [pscustomobject]@{
                    StartupBoost=[pscustomobject]@{ Exists=$false; Value=$null }
                    VisibleLaunchAtStartup=[pscustomobject]@{ Exists=$false; Value=$null }
                    EdgeProcesses=@()
                }
            }
            $result = Invoke-Exp003DryRun -StartupBoost Enable
            $result.WouldChange | Should -BeTrue
            $result.PreservesStartupFolder | Should -BeTrue
            $result.VisibleLaunchAtWindowsStartupDisabled | Should -BeTrue
        }

        It 'is idempotent when desired policies already match' {
            Mock Get-Exp003State {
                [pscustomobject]@{
                    StartupBoost=[pscustomobject]@{ Exists=$true; Value=1 }
                    VisibleLaunchAtStartup=[pscustomobject]@{ Exists=$true; Value=0 }
                    EdgeProcesses=@()
                }
            }
            (Invoke-Exp003DryRun -StartupBoost Enable).WouldChange | Should -BeFalse
        }

        It 'verifies both startup boost and visible-startup suppression' {
            Mock Get-Exp003State {
                [pscustomobject]@{
                    StartupBoost=[pscustomobject]@{ Exists=$true; Value=1 }
                    VisibleLaunchAtStartup=[pscustomobject]@{ Exists=$true; Value=0 }
                    EdgeProcesses=@()
                }
            }
            (Test-Exp003Configuration -ExpectedStartupBoost 1).Success | Should -BeTrue
        }

        It 'rejects rollback state for another experiment' {
            Mock Get-Content { '{"SchemaVersion":1,"Experiment":"OTHER","State":{}}' }
            { Restore-Exp003State -StatePath 'state.json' -LogPath 'log.jsonl' -Confirm:$false } | Should -Throw '*identity mismatch*'
        }
    }
}
