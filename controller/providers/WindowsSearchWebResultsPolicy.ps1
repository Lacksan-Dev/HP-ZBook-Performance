[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
  [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
  [string]$StatePath,
  [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-082'
$provider='windows-search-web-results-policy'
$policyPath='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
$desired=[ordered]@{DisableWebSearch=1;ConnectedSearchUseWeb=0}

function Write-Log([string]$Event,[string]$Result,[object]$Data){
  if([string]::IsNullOrWhiteSpace($LogPath)){return}
  $parent=Split-Path -Parent $LogPath
  if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  [ordered]@{timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;provider=$provider;action=$Action;event=$Event;result=$Result;data=$Data}|ConvertTo-Json -Compress -Depth 14|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-ManagementState{
  $cs=Get-CimInstance Win32_ComputerSystem
  $signals=[ordered]@{DomainJoined=[bool]$cs.PartOfDomain;MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count;PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device';ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)}
  [pscustomobject]@{Managed=($signals.DomainJoined-or$signals.MdmEnrollments-gt0-or$signals.PolicyManager-or$signals.ConfigMgr);Signals=$signals}
}
function Get-SupportState{
  $os=Get-CimInstance Win32_OperatingSystem
  $cs=Get-CimInstance Win32_ComputerSystem
  $management=Get-ManagementState
  $admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  $editionSupported=$os.Caption-match'Windows 11 (Pro|Enterprise|Education|IoT Enterprise)'
  [pscustomobject]@{Supported=($editionSupported-and$cs.Manufacturer-match'(?i)^HP$|Hewlett-Packard');OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$cs.Manufacturer;Model=$cs.Model;Elevated=$admin;Managed=$management.Managed;ManagementSignals=$management.Signals}
}
function Get-OneValueState([string]$Name){
  $keyExists=Test-Path -LiteralPath $policyPath
  $valueExists=$false;$data=$null;$kind=$null
  if($keyExists){$key=Get-Item -LiteralPath $policyPath;$valueExists=$key.GetValueNames()-contains$Name;if($valueExists){$data=$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$kind=$key.GetValueKind($Name).ToString()}}
  [pscustomobject]@{Name=$Name;ValueExists=$valueExists;Data=$data;Kind=$kind}
}
function Get-PolicyState{
  [pscustomobject]@{Path=$policyPath;KeyExists=(Test-Path -LiteralPath $policyPath);Values=@(Get-OneValueState 'DisableWebSearch';Get-OneValueState 'ConnectedSearchUseWeb')}
}
function Assert-Safe($Support,$Current){
  if(!$Support.Elevated){throw'Elevation is required.'}
  if($Support.Managed){throw'Enterprise-management signals are present; mutation is refused.'}
  if(@($Current.Values|Where-Object ValueExists).Count-gt0){throw'Existing Windows Search web policy detected; mutation is refused.'}
}
function Save-State($Support,$Current){
  if([string]::IsNullOrWhiteSpace($StatePath)){throw'StatePath is required.'}
  if(Test-Path -LiteralPath $StatePath){throw'State artifact already exists; overwrite is refused.'}
  $state=[ordered]@{schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;policyPath=$policyPath;desired=$desired;support=$Support;original=$Current}
  $parent=Split-Path -Parent $StatePath;if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  $state|ConvertTo-Json -Depth 14|Set-Content -LiteralPath $StatePath -Encoding UTF8
  $state
}
function Read-State{
  if([string]::IsNullOrWhiteSpace($StatePath)-or!(Test-Path -LiteralPath $StatePath)){throw"State file missing: $StatePath"}
  $state=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json
  $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  if($state.schemaVersion-ne1-or$state.experiment-ne$experiment-or$state.provider-ne$provider-or$state.machine-ne$env:COMPUTERNAME-or$state.userSid-ne$sid-or$state.policyPath-ne$policyPath){throw'State identity validation failed.'}
  if([int]$state.desired.DisableWebSearch-ne1-or[int]$state.desired.ConnectedSearchUseWeb-ne0){throw'State treatment validation failed.'}
  $state
}
function Test-Applied{
  $current=Get-PolicyState
  foreach($name in $desired.Keys){$v=$current.Values|Where-Object Name -eq $name;if(!$v.ValueExists-or$v.Kind-ne'DWord'-or[int]$v.Data-ne[int]$desired[$name]){return $false}}
  $true
}
function Restore-State($State){
  if(@($State.original.Values|Where-Object ValueExists).Count-gt0){throw'Captured state was ineligible for application.'}
  $current=Get-PolicyState
  foreach($name in $desired.Keys){
    $v=$current.Values|Where-Object Name -eq $name
    if($v.ValueExists-and!($v.Kind-eq'DWord'-and[int]$v.Data-eq[int]$desired[$name])){throw"Rollback refused because policy state drifted for $name."}
  }
  foreach($name in $desired.Keys){$v=$current.Values|Where-Object Name -eq $name;if($v.ValueExists-and$PSCmdlet.ShouldProcess("$policyPath::$name",'Remove experiment policy')){Remove-ItemProperty -LiteralPath $policyPath -Name $name}}
  if(!$State.original.KeyExists-and(Test-Path -LiteralPath $policyPath)){$key=Get-Item -LiteralPath $policyPath;if($key.ValueCount-eq0-and@(Get-ChildItem -LiteralPath $policyPath -ErrorAction SilentlyContinue).Count-eq0){if($PSCmdlet.ShouldProcess($policyPath,'Remove empty experiment-created key')){Remove-Item -LiteralPath $policyPath -Force}}}
}
try{
  $support=Get-SupportState;Write-Log 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) $support
  if(!$support.Supported){throw'Provider supports HP Windows 11 Pro, Enterprise, Education, or IoT Enterprise only.'}
  $current=Get-PolicyState
  switch($Action){
    'Check'{[pscustomobject]@{Support=$support;Current=$current;SearchUiRestartGuidance='Close SearchHost through sign-out or reboot before treatment measurement.'}}
    'Capture'{Assert-Safe $support $current;$state=Save-State $support $current;Write-Log 'capture' 'pass' @{statePath=$StatePath;valueCount=2};$state}
    'DryRun'{Assert-Safe $support $current;$result=[pscustomobject]@{Provider=$provider;WouldChange=$true;MutationCount=2;Path=$policyPath;Values=$desired;AtomicTransaction=$true;RebootPersistenceCheckRequired=$true};Write-Log 'dry-run' 'pass' $result;$result}
    'Apply'{
      if(Test-Path -LiteralPath $StatePath){$state=Read-State;if(Test-Applied){Write-Log 'apply' 'idempotent' @{changed=$false};return [pscustomobject]@{Provider=$provider;Applied=$true;MutationCount=0}}}else{Assert-Safe $support $current;$state=Save-State $support $current}
      if($PSCmdlet.ShouldProcess($policyPath,'Set atomic Windows Search web policy pair')){
        if(!(Test-Path -LiteralPath $policyPath)){New-Item -Path $policyPath -Force|Out-Null}
        try{foreach($name in $desired.Keys){New-ItemProperty -LiteralPath $policyPath -Name $name -PropertyType DWord -Value ([int]$desired[$name]) -Force|Out-Null}}catch{foreach($name in $desired.Keys){Remove-ItemProperty -LiteralPath $policyPath -Name $name -ErrorAction SilentlyContinue};throw}
      }
      if(!(Test-Applied)){foreach($name in $desired.Keys){Remove-ItemProperty -LiteralPath $policyPath -Name $name -ErrorAction SilentlyContinue};throw'Atomic apply verification failed; experiment-created values were removed.'}
      Write-Log 'apply' 'pass' @{changed=$true;mutationCount=2};[pscustomobject]@{Provider=$provider;Applied=$true;MutationCount=2}
    }
    'Verify'{$null=Read-State;$ok=Test-Applied;Write-Log 'verify' $(if($ok){'pass'}else{'fail'}) @{valueCount=2};if(!$ok){throw'Policy-pair verification failed.'};$true}
    'VerifyReboot'{$null=Read-State;$ok=Test-Applied;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime;Write-Log 'verify-reboot' $(if($ok){'pass'}else{'fail'}) @{bootTime=$boot;valueCount=2};if(!$ok){throw'Reboot persistence verification failed.'};$true}
    'Rollback'{$state=Read-State;Restore-State $state;$after=Get-PolicyState;$ok=@($after.Values|Where-Object ValueExists).Count-eq0;Write-Log 'rollback' $(if($ok){'pass'}else{'fail'}) @{restoredExactOriginal=$ok};if(!$ok){throw'Rollback verification failed.'};[pscustomobject]@{Provider=$provider;RolledBack=$true;MutationCount=2}}
  }
}catch{Write-Log 'failure' 'fail' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName};throw}
