BeforeAll {
  $scriptPath=Join-Path $PSScriptRoot '..\Invoke-WindowsSearchWebPolicyCalibration.ps1'
  $text=Get-Content -LiteralPath $scriptPath -Raw
  $tokens=$null;$errors=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)
}
Describe 'EXP-082 Windows Search web policy contract' {
  It 'parses without PowerShell syntax errors' { $errors.Count | Should -Be 0 }
  It 'supports the complete action contract' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$a'" } }
  It 'uses ShouldProcess and terminating failures' { $text | Should -Match 'SupportsShouldProcess';$text | Should -Match '\$ErrorActionPreference=''Stop''';$text | Should -Match '\$PSCmdlet\.ShouldProcess' }
  It 'targets only the documented Search policy pair' {
    $text | Should -Match 'Windows Search'
    $text | Should -Match 'DisableWebSearch'
    $text | Should -Match 'ConnectedSearchUseWeb'
    $text | Should -Match "DisableWebSearch=\[ordered\]@\{Kind='DWord';Value=1\}"
    $text | Should -Match "ConnectedSearchUseWeb=\[ordered\]@\{Kind='DWord';Value=0\}"
  }
  It 'captures exact original key and value state' { foreach($term in 'KeyExists','Exists','Kind','Value','DoNotExpandEnvironmentNames','machine','policyPath'){ $text | Should -Match $term } }
  It 'requires supported Windows 11 elevation and refuses enterprise management' { $text | Should -Match 'Windows 11';$text | Should -Match 'Elevation is required';$text | Should -Match 'Enterprise-management signals are present' }
  It 'limits mutation to registry policy values' {
    $text | Should -Match 'New-ItemProperty'
    $text | Should -Match 'Remove-ItemProperty'
    $text | Should -Not -Match 'Stop-Service|Set-Service|Remove-AppxPackage|pnputil|Disable-NetAdapter|New-NetFirewallRule|Set-DnsClient'
  }
  It 'provides atomic verification idempotence persistence logging and exact rollback' {
    $text | Should -Match 'Assert-AppliedIdentity'
    $text | Should -Match 'idempotent'
    $text | Should -Match 'verify-reboot'
    $text | Should -Match 'ConvertTo-Json -Compress'
    $text | Should -Match 'Test-Restored'
    $text | Should -Match 'Restore exact Windows Search policy state'
  }
  It 'preserves protected components by contract' { foreach($term in 'omnissa','windows app','remote desktop','tailscale','defender','firewall','bitlocker','windows update','recovery','credential','accessibility'){ $text.ToLowerInvariant() | Should -Match [regex]::Escape($term) } }
}
