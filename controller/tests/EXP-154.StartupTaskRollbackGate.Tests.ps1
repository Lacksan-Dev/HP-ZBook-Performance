Describe 'EXP-154 packaged StartupTask rollback gate contract' {
 BeforeAll {
  $script:decisionPath=Join-Path $PSScriptRoot '..\..\experiments\EXP-154\research-decision.md'
  $script:text=Get-Content -LiteralPath $script:decisionPath -Raw
 }
 It 'uses the current experiment and issue identity' {
  Test-Path -LiteralPath $script:decisionPath | Should -BeTrue
  $script:text | Should -Match 'EXP-154 / issue #353'
  $script:text | Should -Not -Match 'EXP-145'
 }
 It 'gates production mutation on exact supported API restoration proof' {
  foreach($token in @('Windows.ApplicationModel.StartupTask','StartupTask.Disable()','StartupTask.RequestEnableAsync()','initially `Enabled`','returns exactly to `Enabled`','Only after exact restore is demonstrated')){
   $script:text | Should -Match ([regex]::Escape($token))
  }
 }
 It 'requires the complete reversible lifecycle after the physical gate passes' {
  foreach($action in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')){
   $script:text | Should -Match ([regex]::Escape($action))
  }
  foreach($token in @('ShouldProcess','-WhatIf','structured JSONL','idempotent','terminating failure','drift refusal','post-rollback equality verification')){
   $script:text | Should -Match ([regex]::Escape($token))
  }
 }
 It 'preserves protected Windows device management and remote-access scope' {
  foreach($token in @('Windows security','Windows Update','recovery','enterprise management','device-critical drivers','Omnissa','Windows App','Remote Desktop','Tailscale')){
   $script:text | Should -Match ([regex]::Escape($token))
  }
 }
 It 'keeps unexecuted physical work as Experimental needs-evidence' {
  $script:text | Should -Match 'needs-evidence'
  $script:text | Should -Match 'Release state remains Experimental'
  $script:text | Should -Match 'Stable remains unassigned'
  foreach($token in @('five matched baseline','five matched treatment','medians plus dispersion','instrumentation overhead')){
   $script:text | Should -Match ([regex]::Escape($token))
  }
 }
 It 'keeps machine and user identity in machine-local raw evidence' {
  $script:text | Should -Match 'machine identity, user SID.*machine-local raw evidence only'
  $script:text | Should -Match 'raw machine/user identity remains machine-local'
 }
}
