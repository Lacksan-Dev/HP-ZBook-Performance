$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp024LabHarness.ps1'
Describe 'EXP-024 lab harness contract' {
  $text=Get-Content -LiteralPath $scriptPath -Raw
  It 'implements the reboot-aware lifecycle' {foreach($name in 'Start','Continue','Status','Summarize','Stop'){$text|Should Match "'$name'"}}
  It 'uses the existing reversible controller' {$text|Should Match 'Invoke-Exp024HpTouchpoint.ps1';$text|Should Match "Invoke-Controller 'Apply'";$text|Should Match "Invoke-Controller 'Rollback'";$text|Should Match "Invoke-Controller 'VerifyReboot'"}
  It 'requires a clean reboot and rejects duplicate collection' {$text|Should Match 'A clean reboot is required before collecting this trial';$text|Should Match 'This boot was already collected';$text|Should Match 'preparedBootUtc';$text|Should Match 'lastCollectedBootUtc'}
  It 'alternates baseline and treatment trials' {$text|Should Match "phase='Baseline'";$text|Should Match "'Treatment'";$text|Should Match 'totalRuns=\(\$RunsPerArm\*2\)'}
  It 'collects structured resource evidence' {foreach($name in 'PercentProcessorTime','DiskBytesPersec','BytesTotalPersec','readTransferBytes','writeTransferBytes','tcpConnections','collectorCpuDeltaMs'){$text|Should Match $name}}
  It 'records a desktop readiness proxy and protected remote access state' {$text|Should Match 'bootToExplorerStartMs';$text|Should Match 'explorerResponding';foreach($name in 'Tailscale','TermService','msrdc','windowsapp','omnissa','horizon'){$text|Should Match $name}}
  It 'calculates medians and dispersion without inventing results' {$text|Should Match 'Get-Median';$text|Should Match 'Get-Mad';$text|Should Match 'summary.json';$text|Should Match 'No run evidence found'}
  It 'guards automatic reboot behind an explicit switch' {$text|Should Match 'AllowAutomaticReboot';$text|Should Match 'Restart-Computer -Force'}
  It 'uses a reversible logon scheduled task without autologon changes' {$text|Should Match 'New-ScheduledTaskTrigger -AtLogOn';$text|Should Match 'Register-ScheduledTask';$text|Should Match 'Unregister-ScheduledTask';$text|Should Not Match 'AutoAdminLogon';$text|Should Not Match 'DefaultPassword';$text|Should Not Match 'Winlogon\\DefaultUserName'}
  It 'supports dry-run planning before mutation' {$text|Should Match 'SupportsShouldProcess';$text|Should Match '\$WhatIfPreference';$text|Should Match 'WhatIf';$text|Should Match 'ShouldProcess'}
  It 'performs exact service rollback on completion and stop' {$text|Should Match "Invoke-Controller 'Rollback' \$Dir";$text|Should Match "rollback='verified'"}
}
