Describe 'EXP-086 HighPerformancePowerScheme contract' {
 BeforeAll {
  $script:path=Join-Path $PSScriptRoot '..\providers\HighPerformancePowerScheme.ps1'
  $script:text=Get-Content $script:path -Raw
 }
 It 'declares complete reversible actions' {$script:text|Should -Match "Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback"}
 It 'supports WhatIf and ShouldProcess' {$script:text|Should -Match 'SupportsShouldProcess';$script:text|Should -Match 'WhatIfPreference';$script:text|Should -Match 'ShouldProcess'}
 It 'uses only existing scheme activation' {$script:text|Should -Match 'powercfg /setactive';$script:text|Should -Not -Match '/duplicatescheme|/import|/delete'}
 It 'uses canonical High performance GUID' {$script:text|Should -Match '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'}
 It 'requires HP Windows 11 elevation AC and unmanaged ownership' {$script:text|Should -Match 'Windows 11 required';$script:text|Should -Match 'HP platform required';$script:text|Should -Match 'Elevation required';$script:text|Should -Match 'AC power required';$script:text|Should -Match 'Enterprise management ownership detected'}
 It 'captures and restores exact original GUID' {$script:text|Should -Match 'original=\$s.Original';$script:text|Should -Match "Restore captured original power scheme"}
 It 'has structured logging and needs-evidence' {$script:text|Should -Match 'ConvertTo-Json -Compress';$script:text|Should -Match "evidenceStatus='needs-evidence'"}
 It 'checks reboot persistence and protected drift' {$script:text|Should -Match 'capturedBootUtc';$script:text|Should -Match 'Protected configuration drift detected'}
 It 'remains Experimental' {$script:text|Should -Not -Match "Stable"}
}
