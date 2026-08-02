$provider=Join-Path $PSScriptRoot '..\providers\EdgeSetSleepingTabsTimeout.ps1'
$source=Get-Content -LiteralPath $provider -Raw
Describe 'EXP-073 Edge sleeping-tabs timeout provider contract' {
    It 'targets only the documented recommended SleepingTabsTimeout treatment' {
        $source | Should -Match "EXP-073"
        $source | Should -Match "SleepingTabsTimeout"
        $source | Should -Match "Recommended"
        $source | Should -Match "Treatment=900"
    }
    It 'supports the complete reversible action surface' {
        foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$source|Should -Match "'$action'"}
        $source | Should -Match 'SupportsShouldProcess'
        $source | Should -Match 'ShouldProcess'
    }
    It 'captures support identity and refuses unsafe ownership or drift' {
        foreach($token in 'Windows 11 required','HP platform required','elevation required','enterprise management ownership','mandatory SleepingTabsTimeout','Sleeping Tabs is explicitly disabled','Edge identity drift','management drift','startup-folder drift'){$source|Should -Match ([regex]::Escape($token))}
        $source | Should -Match 'Get-AuthenticodeSignature'
        $source | Should -Match 'Get-FileHash'
    }
    It 'preserves physical evidence requirements and structured failure logging' {
        $source | Should -Match 'needsEvidence'
        $source | Should -Match 'ConvertTo-Json'
        $source | Should -Match "'failed'"
        $source | Should -Match 'LastBootUpTime'
    }
    It 'contains exact rollback and collision refusal' {
        $source | Should -Match 'rollback collision or policy drift'
        $source | Should -Match 'Rollback exact-state mismatch'
        $source | Should -Match 'RegistryValueKind'
    }
    It 'avoids broad destructive operations' {
        $source | Should -Not -Match 'Uninstall-Package|Remove-AppxPackage|Disable-WindowsOptionalFeature|pnputil.+/delete-driver|sc\.exe\s+delete|bcdedit'
    }
}
