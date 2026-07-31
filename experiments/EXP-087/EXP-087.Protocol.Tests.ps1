$protocol = Join-Path $PSScriptRoot 'README.md'

Describe 'EXP-087 protocol contract' {
    BeforeAll { $text = Get-Content -LiteralPath $protocol -Raw }

    It 'remains Experimental and evidence-gated' {
        $text | Should -Match 'Release state: Experimental'
        $text | Should -Match 'Evidence state: needs-evidence'
        $text | Should -Match 'Never assign Stable automatically|Stable assignment: prohibited'
    }

    It 'defines the complete reversible lifecycle' {
        foreach($token in 'support detection','State artifact','Dry run','Application transaction','Immediate verification','Reboot-persistence verification','Exact rollback') {
            $text | Should -Match [regex]::Escape($token)
        }
    }

    It 'requires one bounded service configuration transaction' {
        $text | Should -Match 'one service configuration transaction'
        $text | Should -Match 'Change only the exact service startup configuration to Manual'
        $text | Should -Match 'Do not stop or restart the service during application'
        $text | Should -Match 'Rollback changes no second service'
    }

    It 'requires identity, state, publisher, hash, dependency, listener, and management capture' {
        foreach($token in 'service name','startup mode','delayed-start','running state','SHA-256','Authenticode','signer thumbprint','dependencies','dependent services','listeners','management indicators') {
            $text | Should -Match [regex]::Escape($token)
        }
    }

    It 'requires dry run, WhatIf, logging, idempotence, and terminating failures' {
        foreach($token in '-WhatIf','zero service','structured JSONL','idempotently','Terminate on any partial or unverifiable result') {
            $text | Should -Match [regex]::Escape($token)
        }
    }

    It 'preserves protected Windows and remote-access scope' {
        foreach($token in 'Defender','Firewall','BitLocker','Credential Guard','VBS','Windows Update','recovery','enterprise-management','device-critical','Omnissa','Windows App','Remote Desktop','Tailscale') {
            $text | Should -Match [regex]::Escape($token)
        }
    }

    It 'preserves failed and inconclusive evidence without fabricated measurements' {
        $text | Should -Match 'Preserve every raw run'
        $text | Should -Match 'Missing measurements remain `needs-evidence`'
        $text | Should -Match 'Inconclusive or Rejected evidence'
    }

    It 'requires exact drift-aware rollback and verification' {
        foreach($token in 'Refuse when the current service configuration differs','Restore the captured startup mode','Restore the captured running state','Verify the restored configuration','Log the complete rollback transaction') {
            $text | Should -Match [regex]::Escape($token)
        }
    }

    It 'excludes sensitive data from logs' {
        foreach($token in 'serial numbers','tenant identifiers','credentials','tokens','mailbox data','browser data','certificate private material') {
            $text | Should -Match [regex]::Escape($token)
        }
    }
}
