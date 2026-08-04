Describe 'EXP-067 HP Diagnostics HSA controller contract' {
  BeforeAll {
    $script:scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp067HpDiagnostics.ps1'
    $script:text=Get-Content -LiteralPath $script:scriptPath -Raw
  }
  It 'supports ShouldProcess and explicit lifecycle actions' {
    $text | Should -Match 'SupportsShouldProcess=\$true'
    $text | Should -Match "'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'"
    $text | Should -Match '\$WhatIfPreference'
    $text | Should -Match 'ShouldProcess'
  }
  It 'targets only HPDiagsCap' {$text | Should -Match "\$ServiceName='HPDiagsCap'"}
  It 'requires Windows 11 HP elevation and unmanaged ownership' {
    $text | Should -Match 'Windows 11 required'
    $text | Should -Match 'HP platform required'
    $text | Should -Match 'elevation required'
    $text | Should -Match 'enterprise management ownership detected'
  }
  It 'requires DiagsCap and valid HP publisher identity' {
    $text | Should -Match 'DiagsCap\\\.exe'
    $text | Should -Match 'Get-AuthenticodeSignature'
    $text | Should -Match 'HP Inc\|Hewlett-Packard'
    $text | Should -Match 'Get-FileHash'
  }
  It 'captures exact delayed-start registry existence type and data' {
    $text | Should -Match 'Get-RegistryValueState'
    $text | Should -Match 'RegistryValueOptions.*DoNotExpandEnvironmentNames'
    $text | Should -Match 'Exists=\$false;Kind=\$null;Data=\$null'
    $text | Should -Match 'Set-RegistryValueState'
  }
  It 'captures dependency management protected boot and machine-bound state' {
    $text | Should -Match 'Dependencies'
    $text | Should -Match 'Dependents'
    $text | Should -Match 'Get-ManagementState'
    $text | Should -Match 'Get-ProtectedState'
    $text | Should -Match 'capturedBootUtc'
    $text | Should -Match 'userSid'
  }
  It 'detects active diagnostics activity before mutation' {
    $text | Should -Match 'Get-DiagnosticsActivity'
    $text | Should -Match 'active HP diagnostics session detected'
  }
  It 'implements zero-mutation DryRun' {
    $dry=[regex]::Match($text,"'DryRun' \{(?<body>[\s\S]*?)\n    'Apply'").Groups['body'].Value
    $dry | Should -Match 'WouldChange'
    $dry | Should -Match 'MutationCount'
    $dry | Should -Not -Match 'Set-Service|Set-ItemProperty|Remove-ItemProperty|Start-Service|Stop-Service'
  }
  It 'changes only startup mode during Apply and preserves running and delayed-start state' {
    $apply=[regex]::Match($text,"'Apply' \{(?<body>[\s\S]*?)\n    'Verify'").Groups['body'].Value
    $apply | Should -Match "Set-StartupMode 'Manual'"
    $apply | Should -Match 'State -ne \$running'
    $apply | Should -Match 'DelayedAutoStart'
    $apply | Should -Not -Match 'Stop-Service|Remove-AppxPackage|Disable-PnpDevice|pnputil'
  }
  It 'requires a later boot for persistence verification' {
    $text | Should -Match 'Later boot required for reboot persistence verification'
    $text | Should -Match 'Reboot persistence failed'
  }
  It 'provides structured JSONL logging and terminating failure retention' {
    $text | Should -Match 'schemaVersion=1'
    $text | Should -Match 'ConvertTo-Json -Compress'
    $text | Should -Match 'events.jsonl'
    $text | Should -Match 'experiment=\$Experiment'
    $text | Should -Match "Write-Event 'failure' 'failed'"
    $text | Should -Match '\bthrow\b'
  }
  It 'refuses service dependency management and protected-state drift' {
    $text | Should -Match 'Service identity drift detected'
    $text | Should -Match 'Service dependency drift detected'
    $text | Should -Match 'Management state drift detected'
    $text | Should -Match 'Protected security, update, or remote-access state drift detected'
  }
  It 'uses collision-safe exact rollback' {
    foreach($token in 'Rollback collision detected','Set-RegistryValueState','Exact rollback verification failed',"`$o.State -eq 'Running'","`$o.State -eq 'Stopped'"){
      $text | Should -Match ([regex]::Escape($token))
    }
  }
  It 'preserves security updates drivers packages and protected remote access' {
    $text | Should -Match 'WinDefend'
    $text | Should -Match 'wuauserv'
    $text | Should -Match 'TermService'
    $text | Should -Match 'Tailscale'
    $text | Should -Not -Match 'Remove-AppxPackage|pnputil|Disable-NetAdapter|Remove-NetAdapter|Set-NetFirewall|Disable-WindowsOptionalFeature'
  }
}
