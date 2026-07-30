BeforeAll {
  $scriptPath=Join-Path $PSScriptRoot '..\Invoke-SetPointStartupCalibration.ps1'
  $text=Get-Content -LiteralPath $scriptPath -Raw
  $tokens=$null;$errors=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)
}
Describe 'EXP-081 SetPoint startup calibration contract' {
  It 'parses without PowerShell syntax errors' { $errors.Count | Should -Be 0 }
  It 'supports the complete action contract' {
    foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$a'" }
  }
  It 'uses ShouldProcess and terminating failures' {
    $text | Should -Match 'SupportsShouldProcess'
    $text | Should -Match '\$ErrorActionPreference=''Stop'''
    $text | Should -Match '\$PSCmdlet\.ShouldProcess'
  }
  It 'captures exact registry identity and unexpanded data' {
    foreach($term in 'Path','Name','Kind','Data','DoNotExpandEnvironmentNames','PublisherSubject','Executable','userSid','machine'){ $text | Should -Match $term }
  }
  It 'limits mutation to an approved Run value' {
    $text | Should -Match 'Remove-ItemProperty'
    $text | Should -Match 'New-ItemProperty'
    $text | Should -Not -Match 'Remove-AppxPackage|pnputil|sc\.exe delete|Remove-Service|Uninstall-Package|Disable-NetAdapter'
  }
  It 'requires HP Windows 11 and refuses enterprise management' {
    $text | Should -Match 'Windows 11'
    $text | Should -Match 'HP\|Hewlett-Packard'
    $text | Should -Match 'Enterprise-management signals are present'
  }
  It 'verifies Logitech publisher and exact SetPoint executable identity' {
    $text | Should -Match 'Get-AuthenticodeSignature'
    $text | Should -Match 'Logitech\|Logi'
    $text | Should -Match 'SetPoint\(II\)\?'
  }
  It 'protects remote access and Windows safety components' {
    foreach($term in 'omnissa','windows app','remote desktop','tailscale','defender','credential','bitlocker','windows update','recovery'){ $text.ToLowerInvariant() | Should -Match [regex]::Escape($term) }
  }
  It 'provides idempotence reboot verification structured logging and rollback verification' {
    $text | Should -Match 'idempotent'
    $text | Should -Match 'verify-reboot'
    $text | Should -Match 'ConvertTo-Json -Compress'
    $text | Should -Match 'Test-Restored'
    $text | Should -Match 'Rollback refused because the registry value already exists'
  }
}
