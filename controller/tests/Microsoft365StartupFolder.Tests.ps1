Describe 'EXP-127 Microsoft365StartupFolder provider contract' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\providers\Microsoft365StartupFolder.ps1'
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

    It 'limits candidates to approved Startup folders and Microsoft-signed Office desktop executables' {
        $source | Should -Match 'SpecialFolder\]::Startup'
        $source | Should -Match 'SpecialFolder\]::CommonStartup'
        foreach ($leaf in 'OUTLOOK','WINWORD','EXCEL','POWERPNT','ONENOTE','MSACCESS') {
            $source | Should -Match $leaf
        }
        $source | Should -Match 'Microsoft Office'
        $source | Should -Match 'Get-AuthenticodeSignature'
        $source | Should -Match 'ValidPublisher'
    }

    It 'captures exact restoration material and Office startup attribution state' {
        $source | Should -Match 'BytesBase64'
        $source | Should -Match 'Sha256'
        $source | Should -Match 'CreationTimeUtc'
        $source | Should -Match 'LastWriteTimeUtc'
        $source | Should -Match 'Attributes'
        $source | Should -Match 'Sddl'
        $source | Should -Match 'TargetPath'
        $source | Should -Match 'WorkingDirectory'
        $source | Should -Match 'IconLocation'
        $source | Should -Match 'AppUserModelId'
        $source | Should -Match 'Get-RelatedOfficeStartupState'
        $source | Should -Match 'relatedOfficeStartupHash'
    }

    It 'refuses servicing, activation, management, and protected identities' {
        $source | Should -Match 'clicktorun'
        $source | Should -Match 'update\|updater\|servic'
        $source | Should -Match 'repair\|activat\|licens\|setup\|install'
        $source | Should -Match 'omnissa'
        $source | Should -Match 'windows app'
        $source | Should -Match 'remote desktop'
        $source | Should -Match 'tailscale'
        $source | Should -Match 'Enterprise-management ownership detected'
    }

    It 'implements structured logging, idempotence, failure retention, and later-boot verification' {
        $source | Should -Match 'ConvertTo-Json -Compress'
        $source | Should -Match "'idempotent'"
        $source | Should -Match "Write-Log 'failure' 'fail'"
        $source | Should -Match 'A later boot is required'
    }

    It 'refuses target, related-startup, protected-scope, known-folder, and rollback drift' {
        $source | Should -Match 'Microsoft 365 target identity drift detected'
        $source | Should -Match 'Related Microsoft 365 startup state drift detected'
        $source | Should -Match 'Protected-scope drift detected'
        $source | Should -Match 'Known-folder path drift detected'
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
        $source | Should -Not -Match 'Set-Service'
    }
}
