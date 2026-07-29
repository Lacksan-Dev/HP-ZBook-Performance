BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\..\experiments\EXP-064\LogitechSetPointRemoval.ps1'
    $content = Get-Content -LiteralPath $scriptPath -Raw
}

Describe 'EXP-064 Logitech SetPoint removal contract' {
    It 'declares the required actions' {
        foreach ($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') {
            $content | Should -Match ([regex]::Escape("'$action'"))
        }
    }

    It 'supports WhatIf and confirmation' {
        $content | Should -Match 'SupportsShouldProcess\s*=\s*\$true'
        $content | Should -Match '\$PSCmdlet\.ShouldProcess'
    }

    It 'captures exact product and rollback identity' {
        foreach ($field in 'displayName','displayVersion','publisher','productCode','installLocation','uninstallString','quietUninstallString','sha256') {
            $content | Should -Match $field
        }
    }

    It 'requires Windows 11 elevation single-product identity and rollback media' {
        $content | Should -Match 'Windows 11'
        $content | Should -Match 'Elevation is required'
        $content | Should -Match 'Exactly one Logitech-published SetPoint'
        $content | Should -Match 'matching offline installer'
    }

    It 'refuses enterprise management and driver firmware or pairing uninstall commands' {
        $content | Should -Match 'Enterprise-management ownership detected'
        foreach ($token in 'pnputil','remove-driver','devcon','Remove-PnpDevice','Disable-PnpDevice','firmware','pair') {
            $content | Should -Match ([regex]::Escape($token))
        }
    }

    It 'implements structured JSONL logging and terminating failure handling' {
        $content | Should -Match 'ConvertTo-Json -Compress'
        $content | Should -Match 'Add-Content'
        $content | Should -Match '\$ErrorActionPreference\s*=\s*''Stop'''
        $content | Should -Match "Write-Event 'failure' 'error'"
        $content | Should -Match 'throw'
    }

    It 'contains idempotent apply and rollback paths' {
        $content | Should -Match "'already-applied'"
        $content | Should -Match "'already-restored'"
        $content | Should -Match 'State identity validation failed'
        $content | Should -Match 'Installed-product identity drift detected'
        $content | Should -Match 'Rollback installer hash'
    }

    It 'verifies immediate reboot and exact rollback state' {
        $content | Should -Match "'Verify'"
        $content | Should -Match "'VerifyReboot'"
        $content | Should -Match 'Exact-version rollback verification failed'
        $content | Should -Match 'DisplayVersion'
        $content | Should -Match 'PSChildName'
    }

    It 'contains no live device or driver mutation commands' {
        $content | Should -Not -Match '(?im)^\s*(pnputil|devcon|Remove-PnpDevice|Disable-PnpDevice|Update-PnpDevice)\b'
        $content | Should -Not -Match '(?im)^\s*dism(?:\.exe)?\s+.*?/remove-driver'
    }

    It 'names every protected remote-access application in captured state' {
        foreach ($application in 'Omnissa','Windows App','Remote Desktop','Tailscale') {
            $content | Should -Match ([regex]::Escape($application))
        }
    }
}