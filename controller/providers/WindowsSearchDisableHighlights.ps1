[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
 [string]$StatePath,
 [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Experiment='EXP-083'
$Provider='windows-search-disable-highlights'
$PolicyPath='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
$ValueName='EnableDynamicContentInWSB'
$Treatment=0

function Write-Log([string]$Event,[string]$Result,[object]$Data){
 if([string]::IsNullOrWhiteSpace($LogPath)){return}
 $parent=Split-Path -Parent $LogPath
 if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
 [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$Experiment;provider=$Provider;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 20|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Test-Elevated{([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Test-Same($A,$B){($A|ConvertTo-Json -Compress -Depth 20)-eq($B|ConvertTo-Json -Compress -Depth 20)}
function Get-Reg([string]$Path,[string]$Name){
 if(!(Test-Path -LiteralPath $Path)){return [pscustomobject]@{KeyExists=$false;ValueExists=$false;Kind=$null;Data=$null}}
 $key=Get-Item -LiteralPath $Path
 if($key.GetValueNames()-notcontains$Name){return [pscustomobject]@{KeyExists=$true;ValueExists=$false;Kind=$null;Data=$null}}
 [pscustomobject]@{KeyExists=$true;ValueExists=$true;Kind=$key.GetValueKind($Name).ToString();Data=$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
}
function Get-Management{
 $computer=Get-CimInstance Win32_ComputerSystem
 $configMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
 $enrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName-match'^[0-9a-fA-F-]{36}$'}).Count
 $omadm=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName-match'^[0-9a-fA-F-]{36}$'}).Count
 [pscustomobject]@{Managed=([bool]$computer.PartOfDomain-or$configMgr-or($enrollments-gt0-and$omadm-gt0));DomainJoined=[bool]$computer.PartOfDomain;ConfigMgr=$configMgr;EnrollmentCount=$enrollments;OmadmCount=$omadm}
}
function Get-Protected{
 $rows=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','WSearch','Tailscale','TermService')|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name
 [pscustomobject]@{Configuration=@($rows|Select-Object Name,StartMode,PathName);Runtime=@($rows|Select-Object Name,State)}
}
function Get-Platform{
 $os=Get-CimInstance Win32_OperatingSystem
 $computer=Get-CimInstance Win32_ComputerSystem
 $edition=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
 [pscustomobject]@{Caption=$os.Caption;Build=[int]$os.BuildNumber;Edition=$edition;Manufacturer=$computer.Manufacturer;Model=$computer.Model}
}
function Get-Support{
 $platform=Get-Platform;$management=Get-Management;$candidate=Get-Reg $PolicyPath $ValueName
 $supportedEdition=$platform.Edition-match'^(Professional|ProfessionalEducation|ProfessionalWorkstation|Enterprise|EnterpriseS|Education|IoTEnterprise)'
 $supported=($platform.Caption-match'Windows 11'-and$supportedEdition-and$platform.Build-ge22000-and(Test-Elevated)-and!$management.Managed-and!$candidate.ValueExists)
 [pscustomobject]@{Supported=$supported;Platform=$platform;Elevated=(Test-Elevated);Management=$management;Candidate=$candidate;EvidenceStatus='needs-evidence'}
}
function Assert-Supported($Support){if(!$Support.Supported){throw 'Unsupported edition/build, elevation missing, enterprise management detected, or existing Search highlights policy owns the setting.'}}
function Save-State($Support){
 Assert-Supported $Support
 if([string]::IsNullOrWhiteSpace($StatePath)){throw 'StatePath is required.'}
 if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused.'}
 $protected=Get-Protected
 $state=[ordered]@{schemaVersion=1;experiment=$Experiment;provider=$Provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;policyPath=$PolicyPath;valueName=$ValueName;original=$Support.Candidate;platform=$Support.Platform;management=$Support.Management;protectedConfiguration=$protected.Configuration;protectedRuntime=$protected.Runtime;evidenceStatus='needs-evidence'}
 $parent=Split-Path -Parent $StatePath;if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
 $state|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $StatePath -Encoding UTF8
 [pscustomobject]$state
}
function Read-State{
 if([string]::IsNullOrWhiteSpace($StatePath)-or!(Test-Path -LiteralPath $StatePath)){throw 'State artifact is missing.'}
 $state=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json
 $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
 if($state.schemaVersion-ne1-or$state.experiment-ne$Experiment-or$state.provider-ne$Provider-or$state.machine-ne$env:COMPUTERNAME-or$state.userSid-ne$sid){throw 'State identity validation failed.'}
 $state
}
function Assert-DriftFree($State){
 $platform=Get-Platform
 if($platform.Build-ne[int]$State.platform.Build-or$platform.Edition-ne$State.platform.Edition-or$platform.Manufacturer-ne$State.platform.Manufacturer-or$platform.Model-ne$State.platform.Model){throw 'Platform drift detected.'}
 if((Get-Management).Managed){throw 'Management ownership drift detected.'}
 $protected=Get-Protected
 if(!(Test-Same $protected.Configuration $State.protectedConfiguration)){throw 'Protected service configuration drift detected.'}
 [pscustomobject]@{ProtectedRuntime=$protected.Runtime}
}
function Test-Applied{$candidate=Get-Reg $PolicyPath $ValueName;$candidate.ValueExists-and$candidate.Kind-eq'DWord'-and[int]$candidate.Data-eq$Treatment}
try{
 $support=Get-Support;Write-Log 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) $support
 switch($Action){
  'Check'{[pscustomobject]@{Support=$support;Profile='WindowsSearchDisableHighlights'}}
  'Capture'{$state=Save-State $support;Write-Log 'capture' 'pass' $state;$state}
  'DryRun'{Assert-Supported $support;$result=[pscustomobject]@{WouldChange=$true;MutationCount=1;Path=$PolicyPath;Name=$ValueName;Type='DWord';Value=$Treatment;RebootPersistenceCheckRequired=$true;Rollback='Remove only the experiment-created value and remove the policy key only when the experiment created it and it remains empty.';EvidenceStatus='needs-evidence'};Write-Log 'dry-run' 'pass' $result;$result}
  'Apply'{
   $state=if($StatePath-and(Test-Path -LiteralPath $StatePath)){Read-State}else{Save-State $support};$drift=Assert-DriftFree $state
   if(Test-Applied){Write-Log 'apply' 'idempotent' @{mutationCount=0;protectedRuntime=$drift.ProtectedRuntime};return [pscustomobject]@{Applied=$true;MutationCount=0}}
   Assert-Supported $support
   if($WhatIfPreference){Write-Log 'apply' 'whatif' @{mutationCount=0};return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}}
   if($PSCmdlet.ShouldProcess("$PolicyPath::$ValueName",'Disable Windows Search highlights')){if(!(Test-Path -LiteralPath $PolicyPath)){New-Item -Path $PolicyPath -Force|Out-Null};New-ItemProperty -LiteralPath $PolicyPath -Name $ValueName -PropertyType DWord -Value $Treatment -Force|Out-Null}
   if(!(Test-Applied)){throw 'Apply verification failed.'}
   Write-Log 'apply' 'pass' @{mutationCount=1;protectedRuntime=$drift.ProtectedRuntime};[pscustomobject]@{Applied=$true;MutationCount=1}
  }
  'Verify'{$state=Read-State;$drift=Assert-DriftFree $state;if(!(Test-Applied)){throw 'Policy verification failed.'};$result=[pscustomobject]@{Verified=$true;ProtectedRuntime=$drift.ProtectedRuntime;EvidenceStatus='needs-evidence'};Write-Log 'verify' 'pass' $result;$result}
  'VerifyReboot'{$state=Read-State;$drift=Assert-DriftFree $state;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot-le[datetime]$state.capturedBootTime){throw 'A later boot is required.'};if(!(Test-Applied)){throw 'Reboot persistence failed.'};$result=[pscustomobject]@{VerifiedReboot=$true;BootTime=$boot.ToString('o');ProtectedRuntime=$drift.ProtectedRuntime;EvidenceStatus='needs-evidence'};Write-Log 'verify-reboot' 'pass' $result;$result}
  'Rollback'{
   $state=Read-State;$drift=Assert-DriftFree $state;$now=Get-Reg $PolicyPath $ValueName
   if(!$now.ValueExists-and!$state.original.ValueExists){Write-Log 'rollback' 'idempotent' @{mutationCount=0;protectedRuntime=$drift.ProtectedRuntime};return [pscustomobject]@{RolledBack=$true;MutationCount=0}}
   if($now.ValueExists-and!(Test-Applied)){throw 'Policy drift detected; rollback overwrite refused.'}
   if($state.original.ValueExists){$kind=[Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$state.original.Kind,$true);$key=Get-Item -LiteralPath $PolicyPath;$key.SetValue($ValueName,$state.original.Data,$kind)}else{if($now.ValueExists){Remove-ItemProperty -LiteralPath $PolicyPath -Name $ValueName};if(!$state.original.KeyExists-and(Test-Path -LiteralPath $PolicyPath)-and@((Get-Item -LiteralPath $PolicyPath).GetValueNames()).Count-eq0-and@((Get-ChildItem -LiteralPath $PolicyPath -ErrorAction SilentlyContinue)).Count-eq0){Remove-Item -LiteralPath $PolicyPath}}
   $after=Get-Reg $PolicyPath $ValueName;if(!(Test-Same $after $state.original)){throw 'Exact rollback verification failed.'}
   $post=Get-Protected;if(!(Test-Same $post.Configuration $state.protectedConfiguration)){throw 'Protected configuration changed during rollback.'}
   Write-Log 'rollback' 'pass' @{restoredExactOriginal=$true;protectedRuntime=$post.Runtime};[pscustomobject]@{RolledBack=$true;RestoredExactOriginal=$true}
  }
 }
}catch{Write-Log 'failure' 'failure' @{stage=$Action;message=$_.Exception.Message;type=$_.Exception.GetType().FullName;evidenceStatus='needs-evidence'};throw}
