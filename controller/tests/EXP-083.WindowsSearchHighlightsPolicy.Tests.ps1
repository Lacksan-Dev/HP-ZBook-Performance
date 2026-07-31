$providerPath=Join-Path $PSScriptRoot '..\providers\WindowsSearchHighlightsPolicy.ps1'
Describe 'EXP-083 Windows Search highlights policy provider contract' {
  BeforeAll {$text=Get-Content -LiteralPath $providerPath -Raw;$tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$errors)}
  It 'parses as PowerShell' {$errors.Count|Should -Be 0}
  It 'supports the complete reversible lifecycle' {foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match "'$action'"}}
  It 'uses ShouldProcess and terminating failure handling' {$text|Should -Match 'SupportsShouldProcess';$text|Should -Match 'ShouldProcess';$text|Should -Match "ErrorActionPreference='Stop'";$text|Should -Match "Write-Log 'failure'"}
  It 'captures support, management, machine, user, key, type, and value state' {foreach($token in 'Windows 11','Manufacturer','Build','DomainJoined','MdmEnrollments','PolicyManager','ConfigMgr','machine','userSid','KeyExists','ValueExists','Kind','Data'){$text|Should -Match $token}}
  It 'limits mutation to the Search highlights policy value' {$text|Should -Match "valueName='EnableDynamicContentInWSB'";$text|Should -Match "policyPath='HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Windows Search'";$text|Should -Match 'New-ItemProperty';$text|Should -Match 'Remove-ItemProperty';$text|Should -Not -Match 'Set-Service|Stop-Service|Disable-ScheduledTask|Remove-AppxPackage|Uninstall-Package|pnputil|Set-MpPreference|Disable-NetAdapter'}
  It 'includes dry run, idempotence, structured logging, reboot verification, drift refusal, and exact rollback' {foreach($token in 'WouldChange','idempotent','ConvertTo-Json -Compress','VerifyReboot','LastBootUpTime','policy state drifted','Remove empty experiment-created key'){$text|Should -Match $token}}
  It 'refuses managed or preconfigured systems' {$text|Should -Match 'Enterprise-management signals';$text|Should -Match 'Existing Search highlights policy'}
}
