[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
    [string]$ExtensionId=$env:LACKSAN_EDGE_EXTENSION_ID,
    [string]$StatePath,
    [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-089'
$provider='edge-measured-extension-blocklist'
$policyPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallBlocklist'
$edgePolicyRoot='HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$protectedPattern='(?i)password|credential|authenticator|security|defender|vpn|remote\s*desktop|remote\s*access|omnissa|vmware|tailscale|accessibility'

function Write-StructuredLog([string]$Event,[string]$Result,[object]$Data){
    if([string]::IsNullOrWhiteSpace($LogPath)){return}
    $parent=Split-Path -Parent $LogPath
    if($parent -and !(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;provider=$provider;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 16|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-TextHash([string]$Text){$sha=[Security.Cryptography.SHA256]::Create();try{($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))|ForEach-Object{$_.ToString('x2')})-join''}finally{$sha.Dispose()}}
function Get-EdgePath{@("$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe","$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")|Where-Object{$_ -and (Test-Path -LiteralPath $_ -PathType Leaf)}|Select-Object -First 1}
function Get-ManagementState{
    $cs=Get-CimInstance Win32_ComputerSystem
    $signals=[ordered]@{DomainJoined=[bool]$cs.PartOfDomain;MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count;PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device';ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)}
    [pscustomobject]@{Managed=($signals.DomainJoined -or $signals.MdmEnrollments -gt 0 -or $signals.PolicyManager -or $signals.ConfigMgr);Signals=$signals}
}
function Get-SupportState{
    $os=Get-CimInstance Win32_OperatingSystem;$cs=Get-CimInstance Win32_ComputerSystem;$edge=Get-EdgePath;$v=if($edge){[version](Get-Item -LiteralPath $edge).VersionInfo.ProductVersion}else{$null};$m=Get-ManagementState
    $admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    [pscustomobject]@{Supported=($os.Caption -match 'Windows 11' -and $cs.Manufacturer -match '(?i)^HP$|Hewlett-Packard' -and $edge -and $v.Major -ge 77);Elevated=$admin;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$cs.Manufacturer;Model=$cs.Model;EdgePath=$edge;EdgeVersion=$(if($v){$v.ToString()}else{$null});Managed=$m.Managed;ManagementSignals=$m.Signals}
}
function Assert-ExtensionId{if([string]::IsNullOrWhiteSpace($ExtensionId) -or $ExtensionId -notmatch '^[a-p]{32}$'){throw 'ExtensionId must be one exact 32-character Edge extension ID (a-p only).'}}
function Get-RegistryValues([string]$Path){
    if(!(Test-Path -LiteralPath $Path)){return @()};$k=Get-Item -LiteralPath $Path
    @($k.GetValueNames()|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})
}
function Get-PolicyOwnership{
    $forcelist=Get-RegistryValues "$edgePolicyRoot\ExtensionInstallForcelist"
    $settings=Get-RegistryValues "$edgePolicyRoot\ExtensionSettings"
    $blocklist=Get-RegistryValues $policyPath
    $forceMatch=@($forcelist|Where-Object{$_.Data -match [regex]::Escape($ExtensionId)})
    $settingsMatch=@($settings|Where-Object{($_.Name -eq $ExtensionId) -or ($_.Data -match [regex]::Escape($ExtensionId))})
    $blockMatch=@($blocklist|Where-Object{$_.Data -eq $ExtensionId})
    [pscustomobject]@{ForceList=$forcelist;ExtensionSettings=$settings;Blocklist=$blocklist;ForceMatchCount=$forceMatch.Count;SettingsMatchCount=$settingsMatch.Count;ExistingBlockMatchCount=$blockMatch.Count}
}
function Get-ExtensionCandidate{
    Assert-ExtensionId
    $root=Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'
    if(!(Test-Path -LiteralPath $root)){return @()}
    $found=@()
    foreach($profile in Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue){
        $preferences=Join-Path $profile.FullName 'Preferences';if(!(Test-Path -LiteralPath $preferences -PathType Leaf)){continue}
        try{$pref=Get-Content -LiteralPath $preferences -Raw|ConvertFrom-Json}catch{continue}
        $settings=$pref.extensions.settings
        if(!$settings){continue}
        $entry=$settings.PSObject.Properties[$ExtensionId];if(!$entry){continue}
        $state=$entry.Value
        $enabled=([int]$state.state -eq 1)
        $fromWebStore=($state.from_webstore -eq $true)
        $extRoot=Join-Path (Join-Path $profile.FullName 'Extensions') $ExtensionId
        if(!(Test-Path -LiteralPath $extRoot)){continue}
        $versionDir=Get-ChildItem -LiteralPath $extRoot -Directory|Sort-Object Name -Descending|Select-Object -First 1
        if(!$versionDir){continue}
        $manifestPath=Join-Path $versionDir.FullName 'manifest.json';if(!(Test-Path -LiteralPath $manifestPath -PathType Leaf)){continue}
        $manifestRaw=Get-Content -LiteralPath $manifestPath -Raw;$manifest=$manifestRaw|ConvertFrom-Json
        $name=[string]$manifest.name
        $found+=[pscustomobject]@{Id=$ExtensionId;ProfileName=$profile.Name;ProfilePath=$profile.FullName;PreferencesPath=$preferences;Enabled=$enabled;FromWebStore=$fromWebStore;Name=$name;Version=[string]$manifest.version;ManifestPath=$manifestPath;ManifestSha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash;ProtectedIdentity=($name -match $protectedPattern)}
    }
    @($found)
}
function Get-ProtectedSnapshot{
    $services=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale'){if($s=Get-Service $n -ErrorAction SilentlyContinue){[ordered]@{Name=$s.Name;Status=$s.Status.ToString();StartType=$s.StartType.ToString()}}}
    $text=([ordered]@{Services=@($services)}|ConvertTo-Json -Compress -Depth 8);[pscustomobject]@{Hash=Get-TextHash $text;Snapshot=$text}
}
function Assert-Eligible($support,$ownership,[object[]]$candidates){
    if(!$support.Elevated){throw 'Elevation is required.'};if(!$support.Supported){throw 'HP Windows 11 with Edge 77 or later is required.'};if($support.Managed){throw 'Enterprise-management signals are present; mutation is refused.'}
    if($ownership.ForceMatchCount -gt 0 -or $ownership.SettingsMatchCount -gt 0){throw 'Selected extension is controlled by existing Edge extension policy.'};if($ownership.ExistingBlockMatchCount -gt 0){throw 'Selected extension is already blocklisted outside this experiment.'}
    if($candidates.Count -eq 0){throw 'Selected extension is absent from enabled user profiles.'};if($candidates.Count -gt 1){throw 'Selected extension exists in multiple profiles; one-profile mutation is required.'}
    if(!$candidates[0].Enabled -or !$candidates[0].FromWebStore){throw 'Selected extension must be enabled and user-installed from the Edge add-on store.'};if($candidates[0].ProtectedIdentity){throw 'Selected extension matches a protected security, credential, accessibility, VPN, or remote-access identity.'}
}
function Get-FreeValueName([object[]]$values){$used=@($values.Name);for($i=1;$i -lt 10000;$i++){if($used -notcontains [string]$i){return [string]$i}};throw 'No unused numeric ExtensionInstallBlocklist value is available.'}
function Save-State($support,$ownership,[object[]]$candidates){
    Assert-Eligible $support $ownership $candidates;if([string]::IsNullOrWhiteSpace($StatePath)){throw 'StatePath is required.'};if(Test-Path -LiteralPath $StatePath){throw 'State artifact already exists; overwrite refused.'}
    $protected=Get-ProtectedSnapshot;$keyExists=Test-Path -LiteralPath $policyPath;$valueName=Get-FreeValueName $ownership.Blocklist
    $state=[ordered]@{schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;support=$support;extension=$candidates[0];policy=[ordered]@{Path=$policyPath;KeyExisted=$keyExists;ValueName=$valueName;ValueExisted=$false;Data=$ExtensionId;Kind='String'};protectedScopeHash=$protected.Hash}
    $parent=Split-Path -Parent $StatePath;if($parent -and !(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$state|ConvertTo-Json -Depth 16|Set-Content -LiteralPath $StatePath -Encoding UTF8;$state
}
function Read-State{
    if([string]::IsNullOrWhiteSpace($StatePath) -or !(Test-Path -LiteralPath $StatePath)){throw 'State artifact is missing.'};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if($s.schemaVersion -ne 1 -or $s.experiment -ne $experiment -or $s.provider -ne $provider -or $s.machine -ne $env:COMPUTERNAME -or $s.userSid -ne $sid){throw 'State identity validation failed.'};if($ExtensionId -and $s.extension.Id -ne $ExtensionId){throw 'Selected ExtensionId differs from captured state.'};$s
}
function Assert-ExtensionIdentity($state){
    if(!(Test-Path -LiteralPath $state.extension.ManifestPath -PathType Leaf)){throw 'Extension manifest disappeared.'};if((Get-FileHash -LiteralPath $state.extension.ManifestPath -Algorithm SHA256).Hash -ne [string]$state.extension.ManifestSha256){throw 'Extension manifest identity drift detected.'}
}
function Test-Applied($state){if(!(Test-Path -LiteralPath $policyPath)){return $false};$k=Get-Item -LiteralPath $policyPath;if(!($k.GetValueNames() -contains [string]$state.policy.ValueName)){return $false};$k.GetValueKind([string]$state.policy.ValueName).ToString() -eq 'String' -and [string]$k.GetValue([string]$state.policy.ValueName) -eq [string]$state.extension.Id}
try{
    $support=Get-SupportState;Write-StructuredLog 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) $support
    switch($Action){
        'Check'{Assert-ExtensionId;$ownership=Get-PolicyOwnership;$candidates=Get-ExtensionCandidate;Write-StructuredLog 'candidate-inventory' 'pass' @{count=$candidates.Count;profiles=@($candidates.ProfileName)};[pscustomobject]@{Support=$support;Ownership=$ownership;Candidates=$candidates;Profile='EdgeMeasuredExtensionBlocklist'}}
        'Capture'{$ownership=Get-PolicyOwnership;$state=Save-State $support $ownership (Get-ExtensionCandidate);Write-StructuredLog 'capture' 'pass' @{extensionId=$state.extension.Id;profile=$state.extension.ProfileName;valueName=$state.policy.ValueName};$state}
        'DryRun'{$ownership=Get-PolicyOwnership;$candidates=Get-ExtensionCandidate;Assert-Eligible $support $ownership $candidates;$valueName=Get-FreeValueName $ownership.Blocklist;$r=[pscustomobject]@{WouldChange=$true;MutationCount=1;ExtensionId=$ExtensionId;Profile=$candidates[0].ProfileName;Path=$policyPath;ValueName=$valueName;Kind='String';Data=$ExtensionId;EdgeRestartRequired=$true;RebootPersistenceCheckRequired=$true;Rollback='Remove only the experiment-created blocklist value and an experiment-created empty key.'};Write-StructuredLog 'dry-run' 'pass' $r;$r}
        'Apply'{$state=if($StatePath -and (Test-Path -LiteralPath $StatePath)){Read-State}else{$ownership=Get-PolicyOwnership;Save-State $support $ownership (Get-ExtensionCandidate)};if(Test-Applied $state){Assert-ExtensionIdentity $state;Write-StructuredLog 'apply' 'idempotent' @{mutationCount=0};return [pscustomobject]@{Applied=$true;MutationCount=0}};if($support.Managed){throw 'Enterprise-management ownership appeared; mutation refused.'};Assert-ExtensionIdentity $state;if((Get-ProtectedSnapshot).Hash -ne [string]$state.protectedScopeHash){throw 'Protected-scope drift detected.'};if($WhatIfPreference){Write-StructuredLog 'apply' 'whatif' @{mutationCount=0};return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}};if(Test-Path -LiteralPath $policyPath){$k=Get-Item -LiteralPath $policyPath;if($k.GetValueNames() -contains [string]$state.policy.ValueName){throw 'Destination blocklist value appeared after capture; overwrite refused.'}};if($PSCmdlet.ShouldProcess("$policyPath::$($state.policy.ValueName)",'Block exactly one measured Edge extension')){if(!(Test-Path -LiteralPath $policyPath)){New-Item -Path $policyPath -Force|Out-Null};New-ItemProperty -LiteralPath $policyPath -Name ([string]$state.policy.ValueName) -PropertyType String -Value ([string]$state.extension.Id) -Force|Out-Null};if(!(Test-Applied $state)){throw 'Apply verification failed.'};Write-StructuredLog 'apply' 'pass' @{mutationCount=1;extensionId=$state.extension.Id};[pscustomobject]@{Applied=$true;MutationCount=1}}
        'Verify'{$state=Read-State;if(!(Test-Applied $state)){throw 'Immediate policy verification failed.'};Assert-ExtensionIdentity $state;Write-StructuredLog 'verify' 'pass' @{extensionId=$state.extension.Id;policyPresent=$true};$true}
        'VerifyReboot'{$state=Read-State;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot -le [datetime]$state.capturedBootTime){throw 'A later boot is required for reboot-persistence verification.'};if(!(Test-Applied $state)){throw 'Reboot-persistence verification failed.'};Assert-ExtensionIdentity $state;Write-StructuredLog 'verify-reboot' 'pass' @{bootTime=$boot.ToString('o');extensionId=$state.extension.Id};$true}
        'Rollback'{$state=Read-State;if($support.Managed){throw 'Enterprise-management ownership appeared; rollback refused.'};Assert-ExtensionIdentity $state;if((Get-ProtectedSnapshot).Hash -ne [string]$state.protectedScopeHash){throw 'Rollback protected-scope drift detected.'};if(!(Test-Path -LiteralPath $policyPath)){Write-StructuredLog 'rollback' 'idempotent' @{mutationCount=0};return [pscustomobject]@{RolledBack=$true;MutationCount=0}};$k=Get-Item -LiteralPath $policyPath;if(!($k.GetValueNames() -contains [string]$state.policy.ValueName)){Write-StructuredLog 'rollback' 'idempotent' @{mutationCount=0};return [pscustomobject]@{RolledBack=$true;MutationCount=0}};if($k.GetValueKind([string]$state.policy.ValueName).ToString() -ne 'String' -or [string]$k.GetValue([string]$state.policy.ValueName) -ne [string]$state.extension.Id){throw 'Rollback refused because the experiment-created policy value drifted.'};if($WhatIfPreference){Write-StructuredLog 'rollback' 'whatif' @{mutationCount=0};return [pscustomobject]@{RolledBack=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$policyPath::$($state.policy.ValueName)",'Remove experiment-created Edge extension blocklist value')){Remove-ItemProperty -LiteralPath $policyPath -Name ([string]$state.policy.ValueName);if(!$state.policy.KeyExisted -and (Get-Item -LiteralPath $policyPath).GetValueNames().Count -eq 0 -and (Get-ChildItem -LiteralPath $policyPath -ErrorAction SilentlyContinue).Count -eq 0){Remove-Item -LiteralPath $policyPath}};if(Test-Path -LiteralPath $policyPath){$k=Get-Item -LiteralPath $policyPath;if($k.GetValueNames() -contains [string]$state.policy.ValueName){throw 'Exact rollback verification failed.'}};Write-StructuredLog 'rollback' 'pass' @{mutationCount=1;restoredExactOriginal=$true};[pscustomobject]@{RolledBack=$true;MutationCount=1}}
    }
}catch{Write-StructuredLog 'failure' 'fail' @{stage=$Action;message=$_.Exception.Message;type=$_.Exception.GetType().FullName};throw}
