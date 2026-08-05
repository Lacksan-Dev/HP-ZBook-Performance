$providerPath=Join-Path $PSScriptRoot '..\providers\EdgeStartupBoostEnabledPolicy.ps1'
Describe 'EXP-079 Edge Startup Boost enabled provider contract' {
    BeforeAll { $content=Get-Content -LiteralPath $providerPath -Raw }
    It 'parses as PowerShell' { { [scriptblock]::Create($content) } | Should -Not -Throw }
    It 'supports the complete reversible action contract' { foreach($action in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')) { $content | Should -Match "'$action'" } }
    It 'targets one recommended policy value and value 1' { $content | Should -Match 'StartupBoostEnabled'; $content | Should -Match "targetValue=1"; $content | Should -Match 'Edge\\Recommended' }
    It 'requires HP Windows 11, elevation, Edge 88, and enterprise refusal' { $content | Should -Match 'Windows 11'; $content | Should -Match 'Hewlett-Packard'; $content | Should -Match 'Major-ge88'; $content | Should -Match 'Elevation is required'; $content | Should -Match 'Enterprise management detected' }
    It 'refuses existing mandatory or recommended policy ownership' { $content | Should -Match 'mandatory.*recommended Startup Boost policy detected' }
    It 'captures state and refuses identity or policy drift' { $content | Should -Match 'State identity validation failed'; $content | Should -Match 'policy drifted' }
    It 'provides dry run, ShouldProcess, idempotence, verification, JSONL logging, and exact rollback' { $content | Should -Match 'SupportsShouldProcess'; $content | Should -Match 'WouldChange'; $content | Should -Match 'MutationCount=0'; $content | Should -Match 'ConvertTo-Json -Compress'; $content | Should -Match 'restoredExactOriginal' }
    It 'does not mutate protected scopes' { $content | Should -Not -Match 'Set-MpPreference|Disable-WindowsOptionalFeature|Remove-AppxPackage|sc.exe|Set-Service|Stop-Service|Disable-NetAdapter|pnputil|bcdedit' }
}
