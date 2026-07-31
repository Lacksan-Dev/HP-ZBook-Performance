$protocol = Join-Path $PSScriptRoot 'README.md'

Describe 'EXP-087 protocol integration guard' -Tag 'WindowsIntegration' {
    It 'defines zero mutation for every pre-application path' {
        $text = Get-Content -LiteralPath $protocol -Raw
        foreach($action in 'Check','Capture','DryRun','Apply -WhatIf') {
            $text | Should -Match [regex]::Escape($action)
        }
        foreach($scope in 'service','registry','task','process','listener','file','package','device','driver','security','update','recovery','management','network','protected-application') {
            $text | Should -Match [regex]::Escape($scope)
        }
        $text | Should -Match 'Mutation count must remain zero'
    }

    It 'requires refusal-case integration coverage' {
        $text = Get-Content -LiteralPath $protocol -Raw
        foreach($case in 'product is absent','ambiguous service identity','domain-joined or MDM-managed','dependencies or dependents','invalid publisher identity','active HP support workflow') {
            $text | Should -Match [regex]::Escape($case)
        }
    }
}
