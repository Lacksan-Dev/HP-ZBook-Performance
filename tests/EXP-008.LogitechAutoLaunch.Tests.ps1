BeforeAll {
    Import-Module "$PSScriptRoot/../experiments/EXP-008/LogitechAutoLaunch.psm1" -Force
}

Describe 'EXP-008 candidate classification' {
    It 'accepts Logi Options Plus user-space launchers' {
        Test-Exp008Candidate -Name 'Logi Options+' -Command 'C:\Program Files\LogiOptionsPlus\logioptionsplus_agent.exe --background' | Should -BeTrue
    }

    It 'accepts G Hub updater registrations' {
        Test-Exp008Candidate -Name 'LGHUB Updater' -Command 'C:\Program Files\LGHUB\lghub_updater.exe' | Should -BeTrue
    }

    It 'rejects protected remote-access registrations' {
        Test-Exp008Candidate -Name 'Tailscale' -Command 'C:\Program Files\Tailscale\tailscale-ipn.exe' | Should -BeFalse
    }

    It 'rejects Logitech driver-only identities' {
        Test-Exp008Candidate -Name 'Logitech HID Driver' -Command 'C:\Windows\System32\drivers\logi_hid.sys' | Should -BeFalse
    }

    It 'rejects unrelated applications' {
        Test-Exp008Candidate -Name 'OneDrive' -Command 'C:\Program Files\Microsoft OneDrive\OneDrive.exe /background' | Should -BeFalse
    }
}

Describe 'EXP-008 module contract' {
    It 'exports the required engineering functions' {
        $required = @(
            'Test-Exp008Support','Get-Exp008Inventory','Save-Exp008State',
            'Invoke-Exp008Apply','Test-Exp008Applied','Invoke-Exp008Rollback','Test-Exp008Rollback'
        )
        foreach ($name in $required) { Get-Command $name -ErrorAction Stop | Should -Not -BeNullOrEmpty }
    }

    It 'uses ShouldProcess for application' {
        (Get-Command Invoke-Exp008Apply).CmdletBinding | Should -BeTrue
    }
}
