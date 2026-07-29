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

    It 'captures byte hash and shortcut metadata for rollback' {
        foreach ($token in 'sha256','creationTimeUtc','lastWriteTimeUtc','attributes','targetPath','arguments','workingDirectory','iconLocation','description','windowStyle') {
            $content | Should -Match $token
        }
    }

    It 'uses structured JSONL logging and terminating failures' {
        $content | Should -Match 'ConvertTo-Json -Compress'
        $content | Should -Match 'events.jsonl'
        $content | Should -Match "\$ErrorActionPreference = 'Stop'"
        $content | Should -Match "Write-Event 'failure' 'error'"
    }

    It 'implements drift refusal and exact restore verification' {
        $content | Should -Match 'Shortcut drift detected before application'
        $content | Should -Match 'Rollback refused because the original path contains different content'
        $content | Should -Match 'Captured shortcut backup hash mismatch'
        $content | Should -Match 'Exact rollback verification failed'
    }

    It 'preserves protected remote-access identities' {
        foreach ($name in 'omnissa','windows app','remote desktop','tailscale') {
            $content | Should -Match ([regex]::Escape($name))
        }
    }

    It 'avoids package, service, task, driver, and policy mutation commands' {
        $content | Should -Not -Match 'Remove-AppxPackage|Get-PnpDevice|pnputil|sc\.exe|Set-Service|Unregister-ScheduledTask|Remove-ItemProperty|Set-ItemProperty'
    }
}

Describe 'EXP-058 non-destructive integration path' {
    It 'can parse under Windows PowerShell syntax' -Skip:($env:OS -ne 'Windows_NT') {
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$null,[ref]$errors)
        $errors.Count | Should -Be 0
    }
}
