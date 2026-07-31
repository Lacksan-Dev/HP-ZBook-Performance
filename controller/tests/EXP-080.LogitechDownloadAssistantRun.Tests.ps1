$provider = Join-Path $PSScriptRoot '..\providers\LogitechDownloadAssistantRun.ps1'

Describe 'EXP-080 Logitech Download Assistant provider contract' {
    BeforeAll {
        $text = Get-Content -LiteralPath $provider -Raw
        $tokens = $null
        $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($provider, [ref]$tokens, [ref]$errors) | Out-Null
    }

    It 'exists and parses without PowerShell errors' {
        Test-Path -LiteralPath $provider | Should -BeTrue
        $errors.Count | Should -Be 0
    }

    It 'uses strict terminating behavior' {
        $text | Should -Match 'Set-StrictMode -Version Latest'
        $text | Should -Match "ErrorActionPreference = 'Stop'"
        $text | Should -Match "'failure' 'fail'"
    }

    It 'supports the complete reversible lifecycle' {
        foreach ($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') {
            $text | Should -Match "'$action'"
        }
    }

    It 'supports dry run WhatIf and ShouldProcess' {
        $text | Should -Match 'SupportsShouldProcess'
        $text | Should -Match 'ShouldProcess'
        $text | Should -Match "'DryRun'"
    }

    It 'binds state to schema experiment provider machine and user' {
        foreach ($token in 'schemaVersion','EXP-080','logitech-download-assistant-run','machine','userSid','capturedBootTime') {
            $text | Should -Match [regex]::Escape($token)
        }
    }

    It 'covers all approved Run locations and registry views' {
        foreach ($token in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','WOW6432Node','Registry32') {
            $text | Should -Match [regex]::Escape($token)
        }
    }

    It 'captures exact registry ACL executable and signer identity' {
        foreach ($token in 'DoNotExpandEnvironmentNames','GetValueKind','Get-Acl','KeyOwner','KeySddl','ExecutableHash','ExecutableVersion','ProductName','CompanyName','PublisherThumbprint','Get-AuthenticodeSignature') {
            $text | Should -Match [regex]::Escape($token)
        }
    }

    It 'requires one exact candidate' {
        $text | Should -Match 'Assert-OneCandidate'
        $text | Should -Match 'Multiple eligible Logitech Download Assistant registrations'
        $text | Should -Match 'Logitech Download Assistant\|Logi Download Assistant\|LogiLDA'
        $text | Should -Match 'LogitechDownloadAssistant\|LogiDownloadAssistant\|LogiLDA\|LDA'
    }

    It 'refuses management and enforced startup policy ownership' {
        foreach ($token in 'DomainJoined','MdmEnrollments','PolicyManager','ConfigMgr','StartupPolicy','Enterprise-management or enforced startup-policy') {
            $text | Should -Match [regex]::Escape($token)
        }
    }

    It 'refuses interpreters installers services tasks drivers firmware pairing and protected identities' {
        foreach ($token in 'powershell','pwsh','cmd','rundll32','msiexec','regsvr32','schtasks','sc','install','uninstall','repair','firmware','pair','driver','pnputil','devcon','omnissa','windows app','remote desktop','tailscale') {
            $text.ToLowerInvariant() | Should -Match [regex]::Escape($token)
        }
    }

    It 'captures and verifies protected scope without mutation' {
        foreach ($token in 'Get-ProtectedSnapshot','protectedScopeHash','WinDefend','mpssvc','wuauserv','BITS','Tailscale') {
            $text | Should -Match [regex]::Escape($token)
        }
    }

    It 'provides structured JSONL logging and bounded failure records' {
        $text | Should -Match 'ConvertTo-Json -Compress'
        $text | Should -Match 'timestampUtc'
        $text | Should -Match 'statePath'
        $text | Should -Match 'Exception.GetType'
    }

    It 'implements idempotence drift refusal and reboot persistence' {
        foreach ($token in 'idempotent','Captured-state drift','Protected-scope drift','publisher drift','hash drift','A later boot is required','VerifyReboot') {
            $text | Should -Match [regex]::Escape($token)
        }
    }

    It 'implements exact rollback and overwrite refusal' {
        $text | Should -Match 'already exists'
        $text | Should -Match 'DoNotExpandEnvironmentNames'
        $text | Should -Match 'RegistryValueKind'
        $text | Should -Match 'Test-Restored'
        $text | Should -Match '\.SetValue\('
    }

    It 'limits mutation to one Run value and exact restoration' {
        $text | Should -Match 'Remove-ItemProperty'
        @($text | Select-String -Pattern 'Remove-Service|Stop-Service|Set-Service|Disable-ScheduledTask|Unregister-ScheduledTask|Remove-AppxPackage|Uninstall-Package|pnputil|devcon|bcdedit|reagentc|Set-NetAdapter|Disable-NetAdapter|Set-MpPreference' -AllMatches).Matches.Count | Should -Be 0
    }
}
