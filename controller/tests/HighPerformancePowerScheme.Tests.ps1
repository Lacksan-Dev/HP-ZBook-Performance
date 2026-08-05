$path=Join-Path $PSScriptRoot '..\providers\HighPerformancePowerScheme.ps1';$text=Get-Content $path -Raw
Describe 'EXP-086 HighPerformancePowerScheme contract' {
 It 'declares complete reversible actions' {$text|Should -Match "Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback"}
 It 'supports WhatIf and ShouldProcess' {$text|Should -Match 'SupportsShouldProcess';$text|Should -Match 'WhatIfPreference';$text|Should -Match 'ShouldProcess'}
 It 'uses only existing scheme activation' {$text|Should -Match 'powercfg /setactive';$text|Should -Not -Match '/duplicatescheme|/import|/delete'}
 It 'uses canonical High performance GUID' {$text|Should -Match '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'}
 It 'requires HP Windows 11 elevation AC and unmanaged ownership' {$text|Should -Match 'Windows 11 required';$text|Should -Match 'HP platform required';$text|Should -Match 'Elevation required';$text|Should -Match 'AC power required';$text|Should -Match 'Enterprise management ownership detected'}
 It 'captures and restores exact original GUID' {$text|Should -Match 'original=\$s.Original';$text|Should -Match "Restore captured original power scheme"}
 It 'has structured logging and needs-evidence' {$text|Should -Match 'ConvertTo-Json -Compress';$text|Should -Match "evidenceStatus='needs-evidence'"}
 It 'checks reboot persistence and protected drift' {$text|Should -Match 'capturedBootUtc';$text|Should -Match 'Protected configuration drift detected'}
 It 'remains Experimental' {$text|Should -Not -Match "Stable"}
}
