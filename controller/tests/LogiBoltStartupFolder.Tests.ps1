Describe 'EXP-121 LogiBoltStartupFolder provider contract' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\providers\LogiBoltStartupFolder.ps1'
        $source = Get-Content -LiteralPath $scriptPath -Raw
    }

    It 'supports the complete reversible lifecycle' {
        foreach ($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') {
            $source | Should -Match "'$action'"
        }
    }

    It 'uses ShouldProcess and WhatIf' {
        $source | Should -Match 'SupportsShouldProcess=\$true'
        $source | Should -Match '\$PSCmdlet\.ShouldProcess'
        $source | Should -Match '\$WhatIfPreference'
    }

    It 'limits candidates to approved Startup folders and signed Logi Bolt executables' {
        $source | Should -Match 'SpecialFolder\]::Startup'
        $source | Should -Match 'SpecialFolder\]::CommonStartup'
        $source | Should -Match 'LogiBolt'
        $source | Should -Match 'logi-bolt'
        $source | Should -Match 'Get-AuthenticodeSignature'
        $source | Should -Match 'ValidPublisher'
        $source | Should -Match 'Logitech\|Logi'
    }

    It 'captures byte exact restoration material and surrounding startup state' {
        foreach ($token in 'BytesBase64','Sha256','CreationTimeUtc','LastWriteTimeUtc','Attributes','Sddl','TargetPath','WorkingDirectory','IconLocation','AppUserModelId') {
            $source | Should -Match $token
        }
        $source | Should -Match 'Get-RelatedBoltStartupState'
        $source | Should -Match 'relatedBoltStartupHash'
        $source | Should -Match 'Get-BoltDeviceSnapshot'
        $source | Should -Match 'boltDeviceHash'
    }

    It 'refuses servicing device pairing management and protected identities' {
        $source | Should -Match 'update\|updater\|servic'
        $source | Should -Match 'firmware\|driver\|dfu\|pair\|pairing'
        $source | Should -Match 'omnissa'
        $source | Should -Match 'windows app'
        $source | Should -Match 'remote desktop'
        $source | Should -Match 'tailscale'
        $source | Should -Match 'Enterprise-management ownership detected'
    }

    It 'implements structured logging idempotence failure retention and later boot verification' {
        $source | Should -Match 'ConvertTo-Json -Compress'
        $source | Should -Match "'idempotent'"
        $source | Should -Match "Write-Log 'failure' 'fail'"
        $source | Should -Match 'A later boot is required'
    }

    It 'refuses target startup protected device known-folder and rollback drift' {
        $source | Should -Match 'Logi Bolt target identity drift detected'
        $source | Should -Match 'Related Logi Bolt startup state drift detected'
        $source | Should -Match 'Protected-scope drift detected'
        $source | Should -Match 'Logitech device-state drift detected'
        $source | Should -Match 'Known-folder path drift detected'
        $source | Should -Match 'Rollback destination collision detected'
        $source | Should -Match 'Exact rollback verification failed'
    }

    It 'keeps mutation bounded to one Startup registration' {
        $source | Should -Match 'Remove-Item -LiteralPath'
        $source | Should -Match 'WriteAllBytes'
        $source | Should -Not -Match 'Remove-AppxPackage'
        $source | Should -Not -Match 'Uninstall-Package'
        $source | Should -Not -Match 'pnputil\s+/delete-driver'
        $source | Should -Not -Match 'Disable-PnpDevice'
        $source | Should -Not -Match 'Stop-Service'
        $source | Should -Not -Match 'Set-Service'
        $source | Should -Not -Match 'Set-MpPreference'
    }
}
