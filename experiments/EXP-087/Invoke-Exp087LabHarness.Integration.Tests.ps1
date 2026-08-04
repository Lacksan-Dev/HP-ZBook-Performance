Describe 'EXP-087 continuation integration guard' {
 BeforeAll {
  $sut=Join-Path $PSScriptRoot 'Invoke-Exp087LabHarness.ps1'
  $text=Get-Content -LiteralPath $sut -Raw
  $tokens=$null;$errors=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($sut,[ref]$tokens,[ref]$errors)
 }
 It 'parses without PowerShell syntax errors' {$errors.Count|Should -Be 0}
 It 'keeps automatic reboot as explicit opt-in across continuation' {
  $text|Should -Match '\[switch\]\$AllowAutomaticReboot'
  $text|Should -Match 'if\(\$AllowAutomaticReboot\)\{\$arg\+=''-AllowAutomaticReboot''\}'
  $text|Should -Match 'Restart-Computer -Force'
 }
 It 'makes the scheduled continuation noninteractive without passing Confirm through powershell file arguments' {
  $text|Should -Match '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File'
  $text|Should -Match '-Action Continue -Unattended'
  $text|Should -Not -Match '-Action Continue[^\r\n]*-Confirm'
 }
 It 'retains provider dry-run verification and exact rollback lifecycle' {
  $text|Should -Match "Provider 'DryRun'"
  $text|Should -Match "Provider 'Apply'.*Provider 'Verify'"
  $text|Should -Match "Provider 'VerifyReboot'"
  $text|Should -Match "Provider 'Rollback'"
 }
 It 'contains no direct service startup mutation in the harness' {
  $text|Should -Not -Match 'Set-Service'
  $text|Should -Not -Match 'sc\.exe\s+config'
 }
}
