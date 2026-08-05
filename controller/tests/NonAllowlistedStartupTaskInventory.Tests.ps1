Describe 'EXP-135 issue 305 NonAllowlistedStartupTaskInventory research contract' {
 BeforeAll{
  $script:probe=Join-Path $PSScriptRoot '..\research\NonAllowlistedStartupTaskInventory.ps1'
  $script:decision=Join-Path $PSScriptRoot '..\..\experiments\EXP-135\research-decision.md'
  $script:text=Get-Content -LiteralPath $script:probe -Raw
  $script:research=Get-Content -LiteralPath $script:decision -Raw
 }
 It 'parses as valid PowerShell'{[scriptblock]::Create($script:text)|Should -Not -BeNullOrEmpty}
 It 'declares the exact Experimental research identity'{foreach($t in 'EXP-135','issue=305','NonAllowlistedStartupTaskInventory','nonallowlisted-startuptask-inventory'){$script:text|Should -Match [regex]::Escape($t)};$script:text|Should -Not -Match 'status:stable|stage:stable'}
 It 'offers read-only Check Capture and explicit DryRun actions'{$script:text|Should -Match "ValidateSet\('Check','Capture','DryRun'\)";foreach($t in 'Apply','Rollback','Disable\(','RequestEnableAsync','StartupApproved','Set-ItemProperty','Remove-ItemProperty','Register-ScheduledTask','Disable-ScheduledTask','Enable-ScheduledTask','Remove-AppxPackage'){$script:text|Should -Not -Match $t}}
 It 'makes DryRun explicit structured and zero mutation' {foreach($t in "'DryRun'","'dry-run'","zeroMutation=\$true","plannedMutation=\$null",'nextGate'){$script:text|Should -Match $t}}
 It 'captures Windows HP management and protected scope'{foreach($t in 'Windows 11','Hewlett-Packard','DomainJoined','MdmEnrollments','PolicyManager','ConfigMgr','Intune','WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','omnissa','windowsapp'){$script:text|Should -Match $t}}
 It 'captures package manifest StartupTask and executable identity'{foreach($t in 'Get-AppxPackageManifest','windows.startupTask','TaskId','DisplayName','ExecutableLeaf','ExecutablePathHash','EntryPoint','ManifestEnabled','PackageFamilyName','PackageFullNameHash','Version','Publisher','Sha256','FileVersion','SignatureStatus','Thumbprint'){$script:text|Should -Match [regex]::Escape($t)}}
 It 'classifies protected servicing and already-focused product identities'{foreach($t in 'ProtectedIdentity','ServicingIdentity','SpecificExperimentIdentity','microsoft.*(office|365|teams)','logitech|logi','driver','firmware','credential','accessibility','recovery'){$script:text|Should -Match $t}}
 It 'requires measured physical selection evidence'{foreach($t in 'RuntimeState=''needs-physical-probe''','First120SecondAttribution=''needs-evidence''','selectionStatus=''needs-evidence''','measured-cost'){$script:text|Should -Match [regex]::Escape($t)}}
 It 'captures related startup mechanisms without mutation'{foreach($t in 'CurrentVersion\\Run','CurrentVersion\\RunOnce','GetFolderPath','ScheduledTasks','StartupFolders','relatedStartup'){$script:text|Should -Match $t}}
 It 'hashes local path identity and emits structured failure evidence'{foreach($t in 'Get-PathHash','PackageFullNameHash','InstallLocationHash','statePathHash','schemaVersion','timestampUtc','machine','userSid','ConvertTo-Json -Compress','refusalReason','failureDetail','State overwrite refused'){$script:text|Should -Match [regex]::Escape($t)}}
 It 'keeps mutation gated on physical supported API proof'{$script:text|Should -Match 'mutationSupported=\$false';$script:text|Should -Match 'Physical runtime-state, measured-cost, supported Disable\(\), and exact supported RequestEnableAsync\(\) restoration proof'}
 It 'documents exact restore and performance acceptance gates'{foreach($t in 'StartupTask.Disable\(\)','StartupTask.RequestEnableAsync\(\)','DisabledByUser','DisabledByPolicy','EnabledByPolicy','highest reproducible first-120-second startup cost','five matched baseline','needs-evidence'){$script:research|Should -Match $t}}
 It 'documents preserved protected scope'{foreach($t in 'Omnissa','Windows App','Remote Desktop','Tailscale','Windows security','Windows Update','recovery','enterprise management','device-critical drivers'){$script:research|Should -Match [regex]::Escape($t)}}
}
