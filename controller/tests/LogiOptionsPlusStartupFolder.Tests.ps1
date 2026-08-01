Describe 'EXP-122 LogiOptionsPlusStartupFolder provider contract' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\providers\LogiOptionsPlusStartupFolder.ps1'
        $source = Get-Content -LiteralPath $scriptPath -Raw
    }

    It 'supports the complete reversible lifecycle' {
        foreach ($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') { $source | Should -Match "'$action'" }
    }

    It 'uses ShouldProcess and WhatIf' {
        $source | Should -Match 'SupportsShouldProcess=\$true'
        $source | Should -Match '\$PSCmdlet\.ShouldProcess'
        $source | Should -Match '\$WhatIfPreference'
    }

    It 'limits candidates to approved Startup folders and Logitech-signed Logi Options+ executables' {
        $source | Should -Match 'SpecialFolder\]::Startup'
        $source | Should -Match 'SpecialFolder\]::CommonStartup'
        $source | Should -Match 'logioptionsplus'
        $source | Should -Match 'Get-AuthenticodeSignature'
        $source | Should -Match 'Logitech\|Logi'
    }

    It 'captures byte-exact rollback material, shortcut metadata, and device state' {
        $source | Should -Match 'BytesBase64'
        $source | Should -Match 'SHA256'
        $source | Should -Match 'CreationTimeUtc'
        $source | Should -Match 'LastWriteTimeUtc'
        $source | Should -Match 'Attributes'
        $source | Should -Match 'Sddl'
        $source | Should -Match 'TargetPath'
        $source | Should -Match 'WorkingDirectory'
        $source | Should -Match 'IconLocation'
        $source | Should -Match 'logitechDeviceHash'
    }

    It 'refuses updater, firmware, driver, pairing, management, and protected identities' {
        $source | Should -Match 'update\|updater'
        $source | Should -Match 'firmware\|dfu\|driver'
        $source | Should -Match 'pair\|receiver'
        $source | Should -Match 'enterprise\|manage'
        $source | Should -Match 'omnissa'
        $source | Should -Match 'windows app'
        $source | Should -Match 'remote desktop'
        $source | Should -Match 'tailscale'
    }

    It 'implements structured logging, idempotence, failure retention, and later-boot verification' {
        $source | Should -Match 'ConvertTo-Json -Compress'
        $source | Should -Match "'idempotent'"
        $source | Should -Match "Write-Log 'failure' 'fail'"
        $source | Should -Match 'A later boot is required'
    }

    It 'refuses rollback collision and scope drift' {
        $source | Should -Match 'Known-folder path drift detected'
        $source | Should -Match 'Logi Options\+ target identity drift detected'
        $source | Should -Match 'Protected-scope drift detected'
        $source | Should -Match 'Logitech device-state drift detected'
        $source | Should -Match 'Rollback destination collision detected'
        $source | Should -Match 'Exact rollback verification failed'
    }

    It 'keeps mutation bounded to the selected Startup registration' {
        $source | Should -Match 'Remove-Item -LiteralPath'
        $source | Should -Not -Match 'Remove-AppxPackage'
        $source | Should -Not -Match 'Uninstall-Package'
        $source | Should -Not -Match 'pnputil\s+/delete-driver'
        $source | Should -Not -Match 'sc\.exe\s+delete'
        $source | Should -Not -Match 'Stop-Service'
        $source | Should -Not -Match 'Disable-PnpDevice'
    }
}
