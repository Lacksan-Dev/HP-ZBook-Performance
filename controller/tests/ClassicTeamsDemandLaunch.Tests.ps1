BeforeAll {
    $providerPath = Join-Path $PSScriptRoot '..\providers\ClassicTeamsDemandLaunch.ps1'
    $source = Get-Content -LiteralPath $providerPath -Raw
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$parseErrors) | Out-Null
}

Describe 'ClassicTeamsDemandLaunch provider contract' {
    It 'parses without PowerShell syntax errors' {
        $parseErrors | Should -BeNullOrEmpty
    }

    It 'exposes the full reversible lifecycle' {
        foreach ($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') {
            $source | Should -Match "'$action'"
        }
    }

    It 'uses an exact current-user classic Teams Run boundary' {
        $source | Should -Match [regex]::Escape("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run")
        $source | Should -Match [regex]::Escape('com.squirrel.Teams.Teams')
        $source | Should -Match [regex]::Escape('--processStart')
        $source | Should -Match [regex]::Escape('Teams.exe')
        $source | Should -Match [regex]::Escape('--system-initiated')
        $source | Should -Match [regex]::Escape('ms-teams\.exe')
    }

    It 'requires HP Windows 11 and refuses management ownership' {
        $source | Should -Match 'Windows 11'
        $source | Should -Match 'Hewlett-Packard'
        foreach ($signal in 'DomainJoined','MdmEnrollments','PolicyManager','ConfigMgr','RunPolicy') {
            $source | Should -Match $signal
        }
        $source | Should -Match 'mutation is refused'
    }

    It 'captures exact registry and binary identity state' {
        foreach ($term in 'DoNotExpandEnvironmentNames','GetValueKind','KeyOwner','KeySddl','Sha256','FileVersion','SignatureStatus','PublisherThumbprint','capturedBootTime','userSid','protectedScopeHash') {
            $source | Should -Match $term
        }
        $source | Should -Match 'State artifact already exists; overwrite refused'
    }

    It 'validates signed Microsoft classic Teams binaries' {
        $source | Should -Match 'Get-AuthenticodeSignature'
        $source | Should -Match 'Microsoft Corporation'
        $source | Should -Match 'ValidMicrosoftPublisher'
        $source | Should -Match 'binary identity drift detected'
    }

    It 'supports dry run WhatIf ShouldProcess and idempotence' {
        foreach ($term in 'SupportsShouldProcess','WhatIfPreference','ShouldProcess','dry-run','idempotent') {
            $source | Should -Match $term
        }
    }

    It 'performs immediate and observed-reboot verification' {
        $source | Should -Match 'Immediate removal verification failed'
        $source | Should -Match 'A later boot is required'
        $source | Should -Match 'Reboot-persistence verification failed'
    }

    It 'writes structured JSONL and preserves failure evidence' {
        $source | Should -Match 'ConvertTo-Json -Compress'
        $source | Should -Match 'Add-Content'
        $source | Should -Match "'failure' 'fail'"
        $source | Should -Match 'statePath'
    }

    It 'limits mutation to one exact Run value and exact rollback' {
        $source | Should -Match 'Remove-ItemProperty -LiteralPath'
        $source | Should -Match 'mutationCount = 1'
        $source | Should -Match 'Rollback overwrite refused'
        $source | Should -Match 'SetValue'
        $source | Should -Match 'Exact rollback verification failed'
        $source | Should -Not -Match 'Remove-AppxPackage|Get-PnpDevice|Disable-PnpDevice|pnputil|sc\.exe|Set-Service|Disable-ScheduledTask|Remove-ScheduledTask'
    }

    It 'names protected remote access and Windows safety scopes' {
        foreach ($term in 'omnissa','windows app','remote desktop','tailscale','WinDefend','wuauserv','BITS','MSTeams') {
            $source | Should -Match $term
        }
    }
}
