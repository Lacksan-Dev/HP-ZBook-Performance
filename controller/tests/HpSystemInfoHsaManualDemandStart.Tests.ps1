$provider=Join-Path $PSScriptRoot '..\providers\HpSystemInfoHsaManualDemandStart.ps1'
Describe 'EXP-065 HP System Info HSA manual demand-start provider contract' {
 BeforeAll {$text=Get-Content -LiteralPath $provider -Raw}
 It 'parses as PowerShell' {$tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors)|Out-Null;@($errors).Count|Should -Be 0}
 It 'implements the full reversible lifecycle' {foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match "'$a'"}}
 It 'targets exactly HPSysInfoCap and Manual startup only' {$text|Should -Match "ServiceName='HPSysInfoCap'";$text|Should -Match 'SysInfoCap\.exe';$text|Should -Match 'Set-Service -Name \$ServiceName -StartupType Manual';$text|Should -Not -Match 'Get-Service \*|Set-Service .+\*'}
 It 'requires HP Windows 11 elevation signed HP executable and safe dependencies' {foreach($t in 'Windows 11 required','HP platform required','elevation required','Get-AuthenticodeSignature','Get-FileHash','ValidHp','dependency-sensitive service refused','driver-backed service refused'){$text|Should -Match ([regex]::Escape($t))}}
 It 'requires exact display and executable identity' {$text|Should -Match 'HP System Info HSA Service';$text|Should -Match 'display identity mismatch';$text|Should -Match 'executable identity mismatch'}
 It 'captures exact startup delayed running and executable identity' {foreach($t in 'StartMode','DelayedAutoStart','State=','PathName','StartName','Dependencies','Dependents','Sha256','Thumbprint','capturedBootTime'){$text|Should -Match $t}}
 It 'refuses management and holds protected security update and remote access state' {foreach($t in 'enterprise management ownership detected','CcmExec','Enrollments','OMADM','WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'){$text|Should -Match $t}}
 It 'supports dry run WhatIf structured logging idempotence and failure retention' {foreach($t in 'SupportsShouldProcess','DryRun','WhatIfPreference','ConvertTo-Json -Compress','idempotent',"Log 'failure' 'failure'",'ErrorActionPreference'){$text|Should -Match ([regex]::Escape($t))}}
 It 'preserves running state during treatment and requires a later boot' {$text|Should -Match 'PreserveRunningState';$text|Should -Match 'after.State-ne\$running';$text|Should -Match 'A later boot is required'}
 It 'implements drift-safe exact rollback including delayed-auto-start and running state' {foreach($t in 'Rollback collision','delayed-auto-start drift','RegistryValueKind','Start-Service','Stop-Service','Exact rollback verification failed','restoredExactOriginal'){$text|Should -Match $t}}
 It 'contains no package driver device firmware security or broad service mutation commands' {$text|Should -Not -Match 'Disable-PnpDevice|pnputil|Remove-AppxPackage|Uninstall-Package|Remove-Package|bcdedit|sc\.exe\s+delete|Set-MpPreference|Disable-WindowsOptionalFeature|Get-Service \*'}
 It 'retains physical evidence as pending and avoids release promotion' {$text|Should -Match 'needs-evidence';$text|Should -Not -Match 'status:stable|Stable='}
}
