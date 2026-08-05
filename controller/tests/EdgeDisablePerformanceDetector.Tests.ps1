Describe 'EXP-141 Edge Performance Detector provider contract' {
 BeforeAll{$script:providerPath=Join-Path $PSScriptRoot '..\providers\EdgeDisablePerformanceDetector.ps1';$script:text=Get-Content -LiteralPath $script:providerPath -Raw}
 It 'parses as PowerShell'{$tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($script:providerPath,[ref]$tokens,[ref]$errors);@($errors).Count|Should -Be 0}
 It 'retains Experimental identity and evidence status'{$script:text|Should -Match 'EXP-141';$script:text|Should -Match 'needs-evidence';$script:text|Should -Not -Match 'status:stable|Stable='}
 It 'implements the full reversible lifecycle'{foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$script:text|Should -Match "'$a'"}}
 It 'uses one recommended Edge policy only'{$script:text|Should -Match 'PerformanceDetectorEnabled';$script:text|Should -Match 'Recommended';$script:text|Should -Match "PropertyType DWord -Value 0"}
 It 'requires HP Windows 11 elevation Edge 107 and unmanaged ownership'{foreach($x in 'Windows 11 required','HP platform required','Elevation required','Edge 107+','Enterprise management ownership detected'){$script:text|Should -Match ([regex]::Escape($x))}}
 It 'requires controlled non-MSA detector-eligible profile evidence'{foreach($x in '.lacksan-edge-performance-detector.json','microsoftAccountSignedIn','detectorEligible','Controlled non-MSA profile fixture'){$script:text|Should -Match ([regex]::Escape($x))}}
 It 'captures exact Edge and held-policy identity'{foreach($x in 'Sha256','Thumbprint','ExtensionsPerformanceDetectorEnabled','StartupBoostEnabled','BackgroundModeEnabled','SleepingTabsEnabled','EfficiencyModeEnabled','NetworkPredictionOptions'){$script:text|Should -Match $x}}
 It 'provides dry run WhatIf structured logging idempotence and failure retention'{foreach($x in 'DryRun','WhatIfPreference','ConvertTo-Json -Compress','Add-Content','idempotent','catch'){$script:text|Should -Match $x}}
 It 'requires later boot persistence and exact rollback'{$script:text|Should -Match 'A later boot is required';$script:text|Should -Match 'Reboot persistence failed';$script:text|Should -Match 'Exact rollback verification failed';$script:text|Should -Match 'Rollback collision detected'}
 It 'preserves protected services and Edge Update'{foreach($x in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale','edgeupdate','edgeupdatem'){$script:text|Should -Match $x}}
 It 'contains no package driver service task profile or security mutation primitives'{$script:text|Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Disable-PnpDevice|Remove-PnpDevice|pnputil|Set-MpPreference|Set-NetFirewall|Disable-ScheduledTask|Stop-Service|sc\.exe\s+config'}
}
