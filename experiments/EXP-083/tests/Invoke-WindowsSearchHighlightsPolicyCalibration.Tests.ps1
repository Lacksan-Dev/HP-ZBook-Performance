BeforeAll {
  $scriptPath=Join-Path $PSScriptRoot '..\Invoke-WindowsSearchHighlightsPolicyCalibration.ps1'
  $text=Get-Content -LiteralPath $scriptPath -Raw
  $tokens=$null;$errors=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)
}
Describe 'EXP-083 Windows Search highlights policy contract' {
  It 'parses without PowerShell syntax errors' { $errors.Count | Should -Be 0 }
  It 'supports the complete action contract' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$a'" } }
  It 'uses ShouldProcess and terminating failures' { $text | Should -Match 'SupportsShouldProcess';$text | Should -Match '\$ErrorActionPreference=''Stop''';$text | Should -Match '\$PSCmdlet\.ShouldProcess' }
  It 'targets only the documented Search highlights policy' { $text | Should -Match 'EnableDynamicContentInWSB';$text | Should -Match '\$script:TargetValue=0';$text | Should -Match 'Windows Search' }
  It 'captures exact original key value type and data' { foreach($term in 'KeyExists','ValueExists','Kind','Value','DoNotExpandEnvironmentNames','machine','policyPath','valueName'){ $text | Should -Match $term } }
  It 'requires supported Windows 11 elevation and refuses enterprise management' { $text | Should -Match 'Windows 11';$text | Should -Match 'Elevation is required';$text | Should -Match 'Enterprise-management signals are present' }
  It 'limits mutation to one registry policy value' { $text | Should -Match 'New-ItemProperty';$text | Should -Match 'Remove-ItemProperty';$text | Should -Not -Match 'Stop-Service|Set-Service|Remove-AppxPackage|pnputil|Disable-NetAdapter|New-NetFirewallRule|Set-DnsClient' }
  It 'provides verification idempotence persistence logging and exact rollback' { foreach($term in 'Assert-AppliedIdentity','idempotent','verify-reboot','ConvertTo-Json -Compress','Test-Restored','Restore exact Windows Search highlights policy state'){ $text | Should -Match $term } }
  It 'preserves protected components by contract' { foreach($term in 'omnissa','windows app','remote desktop','tailscale','defender','firewall','bitlocker','windows update','recovery','credential','accessibility'){ $text.ToLowerInvariant() | Should -Match [regex]::Escape($term) } }
}
