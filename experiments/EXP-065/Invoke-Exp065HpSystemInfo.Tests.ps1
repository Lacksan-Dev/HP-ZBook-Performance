Describe 'EXP-065 HP System Info controller contract' {
  BeforeAll {
    $scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp065HpSystemInfo.ps1'
    $text=Get-Content -LiteralPath $scriptPath -Raw
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)
    $trustFunction=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-ExecutableTrustMode'},$true)
    Invoke-Expression $trustFunction.Extent.Text
    $utcFunction=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'ConvertTo-UtcDateTime'},$true)
    Invoke-Expression $utcFunction.Extent.Text
  }
  It 'supports ShouldProcess and explicit lifecycle actions' {
    $text | Should -Match 'SupportsShouldProcess=\$true'
    $text | Should -Match "'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'"
    $text | Should -Match '\$WhatIfPreference'
    $text | Should -Match 'ShouldProcess'
  }
  It 'targets only HPSysInfoCap' {$text | Should -Match "\$ServiceName='HPSysInfoCap'"}
  It 'requires Windows 11, HP platform identity, elevation, and unmanaged ownership' {
    $text | Should -Match 'Windows 11 required'
    $text | Should -Match 'HP platform required'
    $text | Should -Match 'elevation required'
    $text | Should -Match 'enterprise management ownership detected'
  }
  It 'requires SysInfoCap and a narrow HP vendor or DriverStore trust identity' {
    $text | Should -Match 'SysInfoCap\\\.exe'
    $text | Should -Match 'Get-AuthenticodeSignature'
    $text | Should -Match 'HP Inc\|Hewlett-Packard'
    $text | Should -Match 'Get-FileHash'
    $text | Should -Match 'hpcustomcapcomp\\\.inf_'
    $text | Should -Match 'Microsoft Windows Hardware Compatibility Publisher'
    $text | Should -Match 'ExecutableCompanyName'
    $text | Should -Match 'ExecutableProductName'
    $text | Should -Match 'ExecutableOriginalFilename'
    $text | Should -Match 'hp-driverstore-hardware-publisher'
    $text | Should -Match 'service executable trust identity refused'
  }
  It 'accepts the exact HP DriverStore package with HP metadata and the Windows hardware publisher' {
    $mode=Get-ExecutableTrustMode -Executable 'C:\Windows\System32\DriverStore\FileRepository\hpcustomcapcomp.inf_amd64_deadbeef\x64\SysInfoCap.exe' -SignatureValid $true -SignatureSubject 'CN=Microsoft Windows Hardware Compatibility Publisher, O=Microsoft Corporation' -Company 'HP Inc.' -Product 'SysInfoCap' -OriginalFilename 'SysInfoCap.exe' -WindowsRoot 'C:\Windows'
    $mode | Should -Be 'hp-driverstore-hardware-publisher'
  }
  It 'keeps the legacy direct HP publisher identity supported' {
    $mode=Get-ExecutableTrustMode -Executable 'C:\Program Files\HP\SysInfoCap\SysInfoCap.exe' -SignatureValid $true -SignatureSubject 'CN=HP Inc., O=HP Inc.' -Company 'HP Inc.' -Product 'SysInfoCap' -OriginalFilename 'SysInfoCap.exe' -WindowsRoot 'C:\Windows'
    $mode | Should -Be 'direct-hp-publisher'
  }
  It 'refuses generic Microsoft-signed DriverStore executables and metadata drift' {
    Get-ExecutableTrustMode -Executable 'C:\Windows\System32\DriverStore\FileRepository\other.inf_amd64_deadbeef\x64\SysInfoCap.exe' -SignatureValid $true -SignatureSubject 'CN=Microsoft Windows Hardware Compatibility Publisher, O=Microsoft Corporation' -Company 'HP Inc.' -Product 'SysInfoCap' -OriginalFilename 'SysInfoCap.exe' -WindowsRoot 'C:\Windows' | Should -BeNullOrEmpty
    Get-ExecutableTrustMode -Executable 'C:\Windows\System32\DriverStore\FileRepository\hpcustomcapcomp.inf_amd64_deadbeef\x64\SysInfoCap.exe' -SignatureValid $true -SignatureSubject 'CN=Microsoft Windows Hardware Compatibility Publisher, O=Microsoft Corporation' -Company 'Other Vendor' -Product 'SysInfoCap' -OriginalFilename 'SysInfoCap.exe' -WindowsRoot 'C:\Windows' | Should -BeNullOrEmpty
    Get-ExecutableTrustMode -Executable 'C:\Windows\System32\DriverStore\FileRepository\hpcustomcapcomp.inf_amd64_deadbeef\x64\SysInfoCap.exe' -SignatureValid $false -SignatureSubject 'CN=Microsoft Windows Hardware Compatibility Publisher, O=Microsoft Corporation' -Company 'HP Inc.' -Product 'SysInfoCap' -OriginalFilename 'SysInfoCap.exe' -WindowsRoot 'C:\Windows' | Should -BeNullOrEmpty
  }
  It 'captures exact delayed-start registry existence type and data' {
    $text | Should -Match 'Get-RegistryValueState'
    $text | Should -Match 'RegistryValueOptions.*DoNotExpandEnvironmentNames'
    $text | Should -Match 'Exists=\$false;Kind=\$null;Data=\$null'
    $text | Should -Match 'Set-RegistryValueState'
  }
  It 'captures dependency, management, protected, boot and machine-bound state' {
    $text | Should -Match 'Dependencies'
    $text | Should -Match 'Dependents'
    $text | Should -Match 'Get-ManagementState'
    $text | Should -Match 'Get-ProtectedState'
    $text | Should -Match 'capturedBootUtc'
    $text | Should -Match 'userSid'
  }
  It 'collects dependency names without WhatIf-sensitive member shorthand' {
    $text | Should -Match 'ServicesDependedOn\|ForEach-Object \{\[string\]\$_\.Name\}'
    $text | Should -Match 'DependentServices\|ForEach-Object \{\[string\]\$_\.Name\}'
    $text | Should -Not -Match 'ForEach-Object Name'
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
    $apply | Should -Not -Match 'Stop-Service|Remove-Item|Disable-PnpDevice|pnputil'
  }
  It 'requires a later boot for persistence verification' {
    $text | Should -Match 'Later boot required for reboot persistence verification'
    $text | Should -Match 'Reboot persistence failed'
  }
  It 'compares reboot timestamps as UTC instants in non-UTC time zones' {
    $zulu=ConvertTo-UtcDateTime '2026-08-04T16:52:37.5000000Z'
    $japan=ConvertTo-UtcDateTime '2026-08-05T01:52:37.5000000+09:00'
    $zulu.Kind | Should -Be ([DateTimeKind]::Utc)
    $zulu.ToString('o') | Should -Be '2026-08-04T16:52:37.5000000Z'
    $japan.Ticks | Should -Be $zulu.Ticks
    $text | Should -Match '\$capturedBoot=ConvertTo-UtcDateTime'
    $text | Should -Match '\$boot -le \$capturedBoot'
    $text | Should -Not -Match '\$boot -le \[datetime\]\$state\.capturedBootUtc'
  }
  It 'provides structured JSONL logging and terminating failure retention' {
    $text | Should -Match 'schemaVersion=1'
    $text | Should -Match 'ConvertTo-Json -Compress'
    $text | Should -Match 'events.jsonl'
    $text | Should -Match 'experiment=\$Experiment'
    $text | Should -Match "Write-Event 'failure' 'failed'"
    $text | Should -Match '\bthrow\b'
  }
  It 'refuses service, dependency, management, and protected-configuration drift while allowing transient runtime state' {
    $text | Should -Match 'Service identity drift detected'
    $text | Should -Match 'Service dependency drift detected'
    $text | Should -Match 'Management state drift detected'
    $text | Should -Match 'Get-ProtectedConfiguration'
    $text | Should -Match 'Protected security, update, or remote-access configuration drift detected'
    $projection=[regex]::Match($text,'function Get-ProtectedConfiguration\(\$Rows\)\{(?<body>.+?)\}\r?\n').Groups['body'].Value
    $projection | Should -Match 'Name='
    $projection | Should -Match 'StartMode='
    $projection | Should -Match 'PathName='
    $projection | Should -Not -Match 'State='
  }
  It 'uses collision-safe exact rollback including absent DelayedAutoStart restoration' {
    $rollback=[regex]::Match($text,"'Rollback' \{(?<body>[\s\S]*?)\r?\n  \}\r?\n\} catch").Groups['body'].Value
    $rollback | Should -Match 'Rollback collision detected'
    $rollback | Should -Match 'Set-RegistryValueState'
    $rollback | Should -Match 'Exact rollback verification failed'
    $rollback | Should -Match "\$o.State -eq 'Running'"
    $rollback | Should -Match "\$o.State -eq 'Stopped'"
  }
  It 'preserves security updates drivers packages and protected remote access' {
    $text | Should -Match 'WinDefend'
    $text | Should -Match 'wuauserv'
    $text | Should -Match 'TermService'
    $text | Should -Match 'Tailscale'
    $text | Should -Not -Match 'Remove-AppxPackage|pnputil|Disable-NetAdapter|Remove-NetAdapter|Set-NetFirewall|Disable-WindowsOptionalFeature'
  }
}
