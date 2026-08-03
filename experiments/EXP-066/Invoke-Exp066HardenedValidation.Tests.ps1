Describe 'EXP-066 hardened validation entrypoint' {
 $path=Join-Path $PSScriptRoot 'Invoke-Exp066HardenedValidation.ps1'
 $text=Get-Content $path -Raw
 It 'binds the reboot harness to the hardened Manual demand-start provider' {
  $text|Should -Match 'Invoke-Exp066LabHarness\.ps1'
  $text|Should -Match 'HpNetworkHsaManualDemandStart\.ps1'
  $text|Should -Match 'ControllerPath=\$provider'
 }
 It 'preserves matched-run and sampling controls' {
  $text|Should -Match '\[int\]\$RunsPerArm=5'
  $text|Should -Match '\[int\]\$SampleSeconds=120'
  $text|Should -Match 'AllowAutomaticReboot'
 }
 It 'preserves dry-run propagation' {$text|Should -Match '\$WhatIfPreference';$text|Should -Match '\$args\.WhatIf=\$true'}
}