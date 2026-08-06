Describe 'EXP-065 functional readiness verifier contract' {
  BeforeAll {
    $scriptPath=Join-Path $PSScriptRoot 'Test-Exp065FunctionalReadiness.ps1'
    $text=Get-Content -LiteralPath $scriptPath -Raw
    $tokens=$null;$errors=$null
    [Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)|Out-Null
  }
  It 'parses under Windows PowerShell syntax' {@($errors).Count|Should -Be 0}
  It 'binds the exact HP app package service and Store identity' {
    $text|Should -Match "PackageName='AD2F1837.HPSystemInformation'"
    $text|Should -Match "ServiceName='HPSysInfoCap'"
    $text|Should -Match "StoreId='9MTKLT3PWWN1'"
    $text|Should -Match 'HP System Information\.exe'
  }
  It 'launches only the installed HP application and observes demand start' {
    $text|Should -Match 'shell:AppsFolder'
    $text|Should -Match 'demandStartObserved'
    $text|Should -Match "serviceBefore.Status-eq'Stopped'"
    $text|Should -Match "serviceAfter-eq'Running'"
    $text|Should -Not -Match 'Start-Service|Stop-Service|Set-Service|sc\.exe config'
  }
  It 'keeps the post-rollback readiness check read-only so exact rollback remains final' {
    $body=[regex]::Match($text,'function Invoke-HpApp\(\$Identity\)\{(?<body>[\s\S]+?)\r?\n\}').Groups['body'].Value
    $body.IndexOf("if(`$Phase-eq'Rollback')")|Should -BeLessThan $body.IndexOf('ShouldProcess')
    $body|Should -Match 'launchAttempted=\$false'
    $text|Should -Match 'post-rollback check is read-only'
  }
  It 'keeps WhatIf free of app launch and reference-state writes' {
    $text|Should -Match 'ShouldProcess'
    $text|Should -Match 'if\(-not\$WhatIfPreference\)\{Write-JsonFile'
    $text|Should -Match 'wouldLaunch=\$true'
    $text|Should -Match 'appProcessResponding=\$false'
  }
  It 'uses read-only Store discovery and never installs an update' {
    $text|Should -Match 'winget\.exe'
    $text|Should -Match 'list --id \$StoreId --source msstore'
    $text|Should -Match 'installationAttempted=\$false'
    $body=[regex]::Match($text,'function Test-UpdateDiscovery\(\$Identity\)\{(?<body>[\s\S]+?)\r?\n\}').Groups['body'].Value
    $body|Should -Not -Match '\b(?:install|upgrade)\b|Add-AppxPackage|Remove-AppxPackage|Reset-AppxPackage'
  }
  It 'records only aggregate protected and device readiness' {
    foreach($token in @('WinDefend','mpssvc','wuauserv','edgeupdate','edgeupdatem','CryptSvc','KeyIso','VaultSvc','TermService','Tailscale','Get-NetFirewallProfile','Win32_DeviceGuard','Get-BitLockerVolume','Get-NetAdapter','Get-PnpDevice','reagentc.exe','Get-ManagementHealth','Get-CredentialHealth','driverInventoryHash','scopeResults')){$text|Should -Match ([regex]::Escape($token))}
    $result=[regex]::Match($text,'\[pscustomobject\]\[ordered\]@\{\s*schemaVersion=1;experiment=''EXP-065'';phase=\$Phase;(?<body>[\s\S]+)\}\s*$').Groups['body'].Value
    $result|Should -Not -Match '\bpid\s*=|processId\s*=|userSid\s*=|computer\s*=|serial\s*=|InstallLocation\s*=|PathName\s*='
  }
  It 'does not read or persist HP application content' {
    $text|Should -Not -Match 'GetWindowText|UIAutomation|Clipboard|ProductNumber|SerialNumber|Warranty'
    $text|Should -Match 'Application content, serial numbers, customer data, paths, and process identifiers are not recorded'
  }
}
