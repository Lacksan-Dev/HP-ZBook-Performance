BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\experiments\EXP-006\StartupRegistrationCleanup.psm1'
    Import-Module $modulePath -Force
}

Describe 'EXP-006 startup target classification' {
    It 'targets Microsoft Teams registrations' {
        Test-TargetStartupRegistration -Identity 'com.squirrel.Teams.Teams C:\Users\user\AppData\Local\Microsoft\Teams\Update.exe --processStart Teams.exe' | Should -BeTrue
    }

    It 'targets Microsoft 365 and Office registrations' {
        Test-TargetStartupRegistration -Identity 'Microsoft Office Hub C:\Program Files\Microsoft Office\OfficeHub.exe' | Should -BeTrue
    }

    It 'preserves Tailscale even if surrounding text contains Office' {
        Test-TargetStartupRegistration -Identity 'Tailscale Office VPN C:\Program Files\Tailscale\tailscale-ipn.exe' | Should -BeFalse
    }

    It 'preserves Remote Desktop' {
        Test-ProtectedStartupRegistration -Identity 'Remote Desktop C:\Program Files\Remote Desktop\msrdcw.exe' | Should -BeTrue
    }

    It 'preserves Omnissa' {
        Test-ProtectedStartupRegistration -Identity 'Omnissa Horizon Client' | Should -BeTrue
    }

    It 'ignores unrelated applications' {
        Test-TargetStartupRegistration -Identity 'OneDrive C:\Program Files\Microsoft OneDrive\OneDrive.exe' | Should -BeFalse
    }
}

Describe 'EXP-006 state and logging behavior' {
    It 'creates a versioned state payload with no targets' {
        $root = Join-Path $TestDrive 'state'
        $statePath = Join-Path $root 'state.json'
        $payload = Save-StartupRegistrationState -Inventory @() -StatePath $statePath
        $payload.SchemaVersion | Should -Be 1
        Test-Path $statePath | Should -BeTrue
    }

    It 'writes JSONL during dry run' {
        Mock Get-StartupRegistrationInventory {
            [pscustomobject]@{
                Type='Registry'; Location='HKCU:\Software\Test'; Name='Teams';
                Value='Teams.exe'; Identity='Teams Teams.exe'; Protected=$false; Target=$true
            }
        }
        $logPath = Join-Path $TestDrive 'dryrun.jsonl'
        $statePath = Join-Path $TestDrive 'state.json'
        $result = @(Invoke-StartupRegistrationCleanup -Mode DryRun -StatePath $statePath -LogPath $logPath)
        $result.Count | Should -Be 1
        Test-Path $logPath | Should -BeTrue
        (Get-Content $logPath | Select-Object -First 1 | ConvertFrom-Json).Action | Should -Be 'DryRun'
    }
}
