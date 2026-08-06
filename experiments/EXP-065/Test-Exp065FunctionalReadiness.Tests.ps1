Describe 'EXP-065 functional readiness verifier contract' {
  BeforeAll {
    $scriptPath=Join-Path $PSScriptRoot 'Test-Exp065FunctionalReadiness.ps1'
    $text=Get-Content -LiteralPath $scriptPath -Raw
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)
    foreach($name in @('Test-OwnedProcessCleanupProof','Test-AppLaunchProof')){
      $functionAst=$ast.Find({param($node)$node-is[Management.Automation.Language.FunctionDefinitionAst]-and$node.Name-eq$name},$true)
      Invoke-Expression $functionAst.Extent.Text
    }
  }
  It 'parses under Windows PowerShell syntax' {@($errors).Count|Should -Be 0}
  It 'binds the exact HP app package service and Store identity' {
    $text|Should -Match "PackageName='AD2F1837.HPSystemInformation'"
    $text|Should -Match "ServiceName='HPSysInfoCap'"
    $text|Should -Match "StoreId='9MTKLT3PWWN1'"
    $text|Should -Match 'HP System Information\.exe'
    $text|Should -Match 'Get-AuthenticodeSignature'
    $text|Should -Match 'executableHash'
    $text|Should -Match 'signerThumbprint'
    $text|Should -Match 'GetNameInfo\(\[Security\.Cryptography\.X509Certificates\.X509NameType\]::SimpleName,\$false\)'
    $text|Should -Match "signerName-in@\('HP Inc\.',"
    $text|Should -Not -Match "SignerCertificate\.Subject-match'\(\?i\)HP"
    $text|Should -Match 'Test-HpExecutableIdentity'
  }
  It 'launches only the installed HP application and observes demand start' {
    $text|Should -Match 'IApplicationActivationManager'
    $text|Should -Match 'ActivateApplication'
    $text|Should -Match 'CLSCTX_LOCAL_SERVER'
    $text|Should -Match '45BA127D-10A8-46EA-8AB7-56EA9078943C'
    $text|Should -Match '\$activation=Invoke-AumidActivation'
    $text|Should -Not -Match 'shell:AppsFolder|Start-Process explorer\.exe'
    $text|Should -Match 'demandStartObserved'
    $text|Should -Match "serviceBefore.Status-eq'Stopped'"
    $text|Should -Match "serviceAfter-eq'Running'"
    $text|Should -Not -Match 'Start-Service|Stop-Service|Set-Service|sc\.exe config'
  }
  It 'compiles the process-scoped activation interop without activating an app' {
    $source=[regex]::Match($text,"Add-Type -Language CSharp -TypeDefinition @'\r?\n(?<source>[\s\S]+?)\r?\n'@").Groups['source'].Value
    $source|Should -Not -BeNullOrEmpty
    if(-not('Lacksan.PortfolioValidation.ApplicationActivation'-as[type])){Add-Type -Language CSharp -TypeDefinition $source}
    ('Lacksan.PortfolioValidation.ApplicationActivation'-as[type])|Should -Not -BeNullOrEmpty
  }
  It 'proves the activation-returned sustained-live exact process without requiring a classic window owner' {
    $text|Should -Match 'activationReturnedProcess'
    $text|Should -Match 'activationOwnedNewProcess'
    $text|Should -Match 'newProcessObserved'
    $text|Should -Match 'livePolls-ge4'
    $text|Should -Match 'createdProcessCleanupSucceeded'
    $text|Should -Match 'Test-AppLaunchProof \$app \$Phase'
    $text|Should -Not -Match '\$app\.appProcessLive-and\[bool\]\$app\.appWindowPresent'
    $text|Should -Match '\$windowPresent-and\$process\.Responding'
  }
  It 'accepts four live polls with no classic window but rejects weak launch observations' {
    $proof=[pscustomobject]@{activationReturnedProcess=$true;activationOwnedNewProcess=$true;newProcessObserved=$true;appProcessLive=$true;stableLivePolls=4;createdProcessCleanupSucceeded=$true;noPostActivationExactProcesses=$true;appWindowPresent=$false;windowResponding=$false}
    Test-AppLaunchProof $proof 'Baseline'|Should -BeTrue
    foreach($property in @('activationReturnedProcess','activationOwnedNewProcess','newProcessObserved','appProcessLive','createdProcessCleanupSucceeded','noPostActivationExactProcesses')){$copy=$proof.PSObject.Copy();$copy.$property=$false;Test-AppLaunchProof $copy 'Baseline'|Should -BeFalse}
    $short=$proof.PSObject.Copy();$short.stableLivePolls=3;Test-AppLaunchProof $short 'Treatment'|Should -BeFalse
  }
  It 'holds one native process handle from strict post-request binding through termination' {
    $source=[regex]::Match($text,"Add-Type -Language CSharp -TypeDefinition @'\r?\n(?<source>[\s\S]+?)\r?\n'@").Groups['source'].Value
    $source|Should -Match 'OwnedApplicationProcess'
    $source|Should -Match '_creationFileTime < launchRequestedFileTime'
    $source|Should -Not -Match 'AddSeconds\(-1\)'
    $source|Should -Match 'GetCreationFileTime\(_handle'
    $source|Should -Match 'GetImagePath\(_handle'
    $source|Should -Match 'if \(!VerifyIdentity\(\)\) return new ProcessCleanupResult\(false, false\);[\s\S]+TerminateProcess\(_handle'
    $source|Should -Match 'WaitForSingleObject\(_handle'
  }
  It 'requires native-handle cleanup and rejects any late exact replacement' {
    Test-OwnedProcessCleanupProof $true 0|Should -BeTrue
    Test-OwnedProcessCleanupProof $false 0|Should -BeFalse
    Test-OwnedProcessCleanupProof $true 1|Should -BeFalse
  }
  It 'never terminates by PID and does not kill concurrent exact instances' {
    $body=[regex]::Match($text,'function Invoke-HpApp\(\$Identity\)\{(?<body>[\s\S]+?)\r?\n\}').Groups['body'].Value
    $body|Should -Match 'if\(\$before\.Count-gt0\)\{throw ''A pre-existing exact HP System Information process prevents causal launch verification\.''\}'
    $body|Should -Match '\$activation\.Cleanup\(5000\)'
    $body|Should -Not -Match 'Stop-Process|CloseMainWindow|WaitForExit'
    $body|Should -Match '\$exactProcessCount=@\(Get-ExactHpProcessRows \$Identity\)\.Count'
    $body|Should -Match 'Test-HpExecutableIdentity \$Identity'
    $result=[regex]::Match($text,'\[pscustomobject\]\[ordered\]@\{\s*schemaVersion=1;experiment=''EXP-065'';phase=\$Phase;(?<body>[\s\S]+)\}\s*$').Groups['body'].Value
    $result|Should -Not -Match '\bpid\s*=|processId\s*='
  }
  It 'rechecks all protected scopes after app cleanup before reporting readiness' {
    $text|Should -Match '\$protectedBefore=Get-ProtectedSnapshot[\s\S]+\$app=Invoke-HpApp \$identity[\s\S]+\$protected=Get-ProtectedSnapshot'
    $text|Should -Match '\$scopeHashesBefore\[\$name\]-eq\[string\]\$scopeHashes\[\$name\]'
    $text|Should -Match '\$protectedBefore\.device\.driverInventoryHash-eq\[string\]\$protected\.device\.driverInventoryHash'
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
    $text|Should -Match 'appProcessLive=\$false'
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
    $text|Should -Not -Match 'GetWindowText|UIAutomation|Clipboard|ProductNumber|SerialNumber'
    $text|Should -Match 'does not prove that model, serial, warranty, BIOS, or other system-information fields were visibly rendered or correct'
    $text|Should -Match 'Application content, serial numbers, customer data, paths, and process identifiers are not recorded'
  }
}
