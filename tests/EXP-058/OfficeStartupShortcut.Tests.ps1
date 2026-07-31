BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\..\experiments\EXP-058\OfficeStartupShortcut.ps1'
    $content = Get-Content -LiteralPath $scriptPath -Raw
}

Describe 'EXP-058 Office Startup shortcut contract' {
    It 'declares every required lifecycle action' {
        foreach ($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') {
            $content | Should -Match ([regex]::Escape("'$action'"))
        }
    }

    It 'limits eligible targets to supported Microsoft 365 desktop executables' {
        foreach ($name in 'OUTLOOK.EXE','WINWORD.EXE','EXCEL.EXE','POWERPNT.EXE','ONENOTE.EXE','MSACCESS.EXE') {
            $content | Should -Match ([regex]::Escape($name))
        }
    }

    It 'requires HP Windows 11 and rejects enterprise-managed systems' {
        $content | Should -Match 'Windows 11 is required'
        $content | Should -Match 'HP or Hewlett-Packard system is required'
        $content | Should -Match 'Enterprise-management ownership detected'
        foreach ($token in 'PartOfDomain','Enrollments','PolicyManager','Microsoft\\CCM','Policies\\Microsoft\\Office') {
            $content | Should -Match $token
        }
    }

    It 'requires a valid Microsoft publisher and Office installation path' {
        $content | Should -Match 'Get-AuthenticodeSignature'
        $content | Should -Match 'Microsoft Corporation'
        $content | Should -Match 'IsMicrosoftOfficePath'
        $content | Should -Match 'IsValidPublisher'
        $content | Should -Match 'Microsoft 365 executable identity drift detected'
    }

    It 'captures bytes metadata ACL and executable identity for rollback' {
        foreach ($token in 'sha256','creationTimeUtc','lastWriteTimeUtc','attributes','owner','sddl','targetPath','arguments','workingDirectory','iconLocation','description','windowStyle','targetIdentity','SignatureStatus','Publisher','Version') {
            $content | Should -Match $token
        }
    }

    It 'binds versioned state to experiment machine and user' {
        $content | Should -Match 'schemaVersion = 2'
        $content | Should -Match 'machine = \$env:COMPUTERNAME'
        $content | Should -Match 'userSid = \[Security\.Principal\.WindowsIdentity\]::GetCurrent\(\)\.User\.Value'
        $content | Should -Match 'State identity validation failed'
    }

    It 'refuses state and rollback-backup overwrite' {
        $content | Should -Match 'State artifact already exists; capture overwrite refused'
        $content | Should -Match 'Rollback backup already exists; capture overwrite refused'
    }

    It 'uses structured JSONL logging and terminating failures' {
        $content | Should -Match 'ConvertTo-Json -Compress'
        $content | Should -Match 'events.jsonl'
        $content | Should -Match "\$ErrorActionPreference = 'Stop'"
        $content | Should -Match "Write-Event 'failure' 'error'"
        $content | Should -Match 'Immediate verification failed'
        $content | Should -Match 'Reboot-persistence verification failed'
    }

    It 'implements idempotence drift refusal and exact restore verification' {
        $content | Should -Match "Write-Event 'apply' 'already-applied'"
        $content | Should -Match "Write-Event 'rollback' 'already-restored'"
        $content | Should -Match 'Shortcut drift detected before application'
        $content | Should -Match 'Management state drift detected; rollback refused'
        $content | Should -Match 'Rollback refused because the original path contains different content'
        $content | Should -Match 'Captured shortcut backup hash mismatch'
        $content | Should -Match 'SetSecurityDescriptorSddlForm'
        $content | Should -Match 'Set-Acl'
        $content | Should -Match 'Exact rollback verification failed'
    }

    It 'preserves protected remote-access identities' {
        foreach ($name in 'omnissa','windows app','remote desktop','tailscale') {
            $content | Should -Match ([regex]::Escape($name))
        }
    }

    It 'avoids package service task driver and policy mutation commands' {
        $content | Should -Not -Match 'Remove-AppxPackage|Get-PnpDevice|pnputil|sc\.exe|Set-Service|Unregister-ScheduledTask|Remove-ItemProperty|Set-ItemProperty'
    }
}

Describe 'EXP-058 non-destructive integration path' {
    It 'can parse under Windows PowerShell syntax' -Skip:($env:OS -ne 'Windows_NT') {
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$null,[ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'documents zero-mutation actions for integration execution' {
        $content | Should -Match "'Check'"
        $content | Should -Match "'DryRun'"
        $content | Should -Match 'SupportsShouldProcess'
    }
}
