Describe 'EXP-066 HP Network HSA controller contract' {
  BeforeAll {$script:path=Join-Path $PSScriptRoot 'Invoke-Exp066HpNetwork.ps1';$script:text=Get-Content -LiteralPath $script:path -Raw}
  It 'supports the full reversible lifecycle' {$text|Should -Match 'SupportsShouldProcess=\$true';$text|Should -Match "'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'";$text|Should -Match 'ShouldProcess';$text|Should -Match '\$WhatIfPreference'}
  It 'targets only HPNetworkCap and NetworkCap.exe' {$text|Should -Match "\$ServiceName='HPNetworkCap'";$text|Should -Match 'NetworkCap\\\.exe'}
  It 'requires HP Windows 11 elevation and self-managed ownership' {$text|Should -Match 'Windows 11 required';$text|Should -Match 'HP platform required';$text|Should -Match 'elevation required';$text|Should -Match 'enterprise management ownership detected'}
  It 'captures executable identity and exact delayed start state' {$text|Should -Match 'Get-AuthenticodeSignature';$text|Should -Match 'Get-FileHash';$text|Should -Match 'DoNotExpandEnvironmentNames';$text|Should -Match 'Set-Reg'}
  It 'captures and protects network state' {$text|Should -Match 'Get-NetAdapter';$text|Should -Match 'Get-NetAdapterBinding';$text|Should -Match 'Get-NetIPConfiguration';$text|Should -Match 'Protected network stack drift detected';$text|Should -Match 'Network stack changed during Apply'}
  It 'refuses protected dependencies and OMEN ambiguity' {$text|Should -Match 'Protected dependency refused';$text|Should -Match 'OMEN-dependent state requires physical demand-start evidence before mutation'}
  It 'keeps DryRun mutation free' {$dry=[regex]::Match($text,"'DryRun'\{(?<b>[\s\S]*?)\};'Apply'").Groups['b'].Value;$dry|Should -Match 'MutationCount';$dry|Should -Not -Match 'Set-Service|Set-Reg|Start-Service|Stop-Service'}
  It 'changes only service startup mode on Apply' {$apply=[regex]::Match($text,"'Apply'\{(?<b>[\s\S]*?)\};'Verify'").Groups['b'].Value;$apply|Should -Match "Set-Mode 'Manual'";$apply|Should -Not -Match 'Disable-NetAdapter|Set-NetAdapter|Set-NetIP|Set-DnsClient|Set-NetFirewall|pnputil|Remove-AppxPackage'}
  It 'requires a later boot for persistence verification' {$text|Should -Match 'Later boot required for reboot persistence verification';$text|Should -Match 'Reboot persistence failed'}
  It 'uses structured JSONL and terminating failure retention' {$text|Should -Match 'schemaVersion=1';$text|Should -Match 'events.jsonl';$text|Should -Match "Write-Event 'failure' 'failed'";$text|Should -Match '\bthrow\b'}
  It 'implements collision-safe exact rollback' {$text|Should -Match 'Rollback collision detected';$text|Should -Match 'Exact rollback verification failed';$text|Should -Match "Set-Reg 'DelayedAutoStart'";$text|Should -Match 'Start-Service';$text|Should -Match 'Stop-Service'}
  It 'preserves protected services and remote access' {$text|Should -Match 'WinDefend';$text|Should -Match 'wuauserv';$text|Should -Match 'TermService';$text|Should -Match 'Tailscale'}
}
