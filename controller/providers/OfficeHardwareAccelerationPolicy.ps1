[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
  [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
  [string]$StatePath,
  [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-084'
$provider='office-hardware-acceleration-policy'
$policyPath='HKCU:\Software\Microsoft\Office\16.0\Common\Graphics'
$valueName='DisableHardwareAcceleration'
$treatment=1

function Write-Log([string]$Event,[string]$Result,[object]$Data){
  if([string]::IsNullOrWhiteSpace($LogPath)){return}
  $parent=Split-Path -Parent $LogPath
  if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  [ordered]@{timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;provider=$provider;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 14|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-ManagementState{
  $cs=Get-CimInstance Win32_ComputerSystem
  $signals=[ordered]@{DomainJoined=[bool]$cs.PartOfDomain;MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count;PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device';ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue);OfficePolicyValue=Test-Path 'HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Graphics'}
  [pscustomobject]@{Managed=($signals.DomainJoined-or$signals.MdmEnrollments-gt0-or$signals.PolicyManager-or$signals.ConfigMgr-or$signals.OfficePolicyValue);Signals=$signals}
}
function Get-OutlookInstall{
  $candidates=@(
    "$env:ProgramFiles\Microsoft Office\root\Office16\OUTLOOK.EXE",
    "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\OUTLOOK.EXE"
  )|Where-Object{$_-and(Test-Path -LiteralPath $_)}
  if($candidates.Count-ne1){return $null}
  $path=$candidates[0];$item=Get-Item -LiteralPath $path;$sig=Get-AuthenticodeSignature -FilePath $path
  [pscustomobject]@{Path=$path;Version=$item.VersionInfo.FileVersion;Product=$item.VersionInfo.ProductName;Sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;SignatureStatus=$sig.Status.ToString();Publisher=$sig.SignerCertificate.Subject}
}
function Get-GraphicsInventory{
  @(Get-CimInstance Win32_VideoController|ForEach-Object{[pscustomobject]@{Name=$_.Name;DriverVersion=$_.DriverVersion;PNPDeviceID=$_.PNPDeviceID;VideoMode=$_.VideoModeDescription}})
}
function Get-SupportState{
  $os=Get-CimInstance Win32_OperatingSystem;$cs=Get-CimInstance Win32_ComputerSystem;$management=Get-ManagementState;$outlook=Get-OutlookInstall
  $supported=$os.Caption-match'Windows 11' -and $cs.Manufacturer-match'(?i)^HP$|Hewlett-Packard' -and $null-ne$outlook -and $outlook.SignatureStatus-eq'Valid' -and $outlook.Publisher-match'(?i)Microsoft Corporation'
  [pscustomobject]@{Supported=$supported;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$cs.Manufacturer;Model=$cs.Model;Outlook=$outlook;Graphics=Get-GraphicsInventory;Managed=$management.Managed;ManagementSignals=$management.Signals}
}
function Get-ValueState{
  $keyExists=Test-Path -LiteralPath $policyPath;$valueExists=$false;$data=$null;$kind=$null
  if($keyExists){$key=Get-Item -LiteralPath $policyPath;$valueExists=$key.GetValueNames()-contains$valueName;if($valueExists){$data=$key.GetValue($valueName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$kind=$key.GetValueKind($valueName).ToString()}}
  [pscustomobject]@{Path=$policyPath;KeyExists=$keyExists;ValueExists=$valueExists;Data=$data;Kind=$kind}
}
function Get-OfficeProcesses{@(Get-Process OUTLOOK,WINWORD,EXCEL,POWERPNT,ONENOTE,MSACCESS -ErrorAction SilentlyContinue|Select-Object ProcessName,Id,StartTime)}
function Assert-Safe($Support,$Current){
  if(!$Support.Supported){throw'Provider requires one Microsoft-signed classic Outlook installation on HP Windows 11.'}
  if($Support.Managed){throw'Enterprise-management or Office policy ownership detected; mutation is refused.'}
  if((Get-OfficeProcesses).Count-gt0){throw'All Office applications must be closed before mutation.'}
  if($Current.ValueExists){throw'Existing Office graphics preference detected; overwrite is refused.'}
}
function Save-State($Support,$Current){
  if([string]::IsNullOrWhiteSpace($StatePath)){throw'StatePath is required.'}
  if(Test-Path -LiteralPath $StatePath){throw'State artifact already exists; overwrite is refused.'}
  $state=[ordered]@{schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;policyPath=$policyPath;valueName=$valueName;treatment=$treatment;support=$Support;original=$Current}
  $parent=Split-Path -Parent $StatePath;if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  $state|ConvertTo-Json -Depth 14|Set-Content -LiteralPath $StatePath -Encoding UTF8;$state
}
function Read-State{
  if([string]::IsNullOrWhiteSpace($StatePath)-or!(Test-Path -LiteralPath $StatePath)){throw"State file missing: $StatePath"}
  $state=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  if($state.schemaVersion-ne1-or$state.experiment-ne$experiment-or$state.provider-ne$provider-or$state.machine-ne$env:COMPUTERNAME-or$state.userSid-ne$sid-or$state.policyPath-ne$policyPath-or$state.valueName-ne$valueName-or[int]$state.treatment-ne$treatment){throw'State identity validation failed.'}
  $currentSupport=Get-SupportState
  if($currentSupport.Outlook.Path-ne$state.support.Outlook.Path-or$currentSupport.Outlook.Sha256-ne$state.support.Outlook.Sha256){throw'Outlook executable identity drift detected.'}
  $state
}
function Test-Applied{$current=Get-ValueState;$current.ValueExists-and$current.Kind-eq'DWord'-and[int]$current.Data-eq$treatment}
function Restore-State($State){
  if((Get-OfficeProcesses).Count-gt0){throw'All Office applications must be closed before rollback.'}
  if($State.original.ValueExists){throw'Captured state was ineligible for application.'}
  $current=Get-ValueState
  if($current.ValueExists-and!($current.Kind-eq'DWord'-and[int]$current.Data-eq$treatment)){throw'Rollback refused because the applied value drifted.'}
  if($current.ValueExists-and$PSCmdlet.ShouldProcess("$policyPath::$valueName",'Remove experiment-created Office graphics preference')){Remove-ItemProperty -LiteralPath $policyPath -Name $valueName}
  if(!$State.original.KeyExists-and(Test-Path -LiteralPath $policyPath)){$key=Get-Item -LiteralPath $policyPath;if($key.ValueCount-eq0-and@(Get-ChildItem -LiteralPath $policyPath -ErrorAction SilentlyContinue).Count-eq0){if($PSCmdlet.ShouldProcess($policyPath,'Remove empty experiment-created key')){Remove-Item -LiteralPath $policyPath -Force}}}
}
try{
  $support=Get-SupportState;Write-Log 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) $support;$current=Get-ValueState
  switch($Action){
    'Check'{[pscustomobject]@{Support=$support;Current=$current;OfficeProcesses=Get-OfficeProcesses}}
    'Capture'{Assert-Safe $support $current;$state=Save-State $support $current;Write-Log 'capture' 'pass' @{statePath=$StatePath};$state}
    'DryRun'{Assert-Safe $support $current;$result=[pscustomobject]@{Provider=$provider;WouldChange=$true;Path=$policyPath;Name=$valueName;Kind='DWord';Data=$treatment;OfficeRestartRequired=$true;RebootPersistenceCheckRequired=$true};Write-Log 'dry-run' 'pass' $result;$result}
    'Apply'{if(Test-Path -LiteralPath $StatePath){$state=Read-State;if(Test-Applied){Write-Log 'apply' 'idempotent' @{changed=$false};return [pscustomobject]@{Provider=$provider;Applied=$true;MutationCount=0}}}else{Assert-Safe $support $current;$state=Save-State $support $current};if($PSCmdlet.ShouldProcess("$policyPath::$valueName",'Set REG_DWORD 1')){if(!(Test-Path -LiteralPath $policyPath)){New-Item -Path $policyPath -Force|Out-Null};New-ItemProperty -LiteralPath $policyPath -Name $valueName -PropertyType DWord -Value $treatment -Force|Out-Null};if(!(Test-Applied)){throw'Apply verification failed.'};Write-Log 'apply' 'pass' @{changed=$true};[pscustomobject]@{Provider=$provider;Applied=$true;MutationCount=1}}
    'Verify'{$null=Read-State;$ok=Test-Applied;Write-Log 'verify' $(if($ok){'pass'}else{'fail'}) @{officeProcesses=Get-OfficeProcesses};if(!$ok){throw'Office graphics preference verification failed.'};$true}
    'VerifyReboot'{$null=Read-State;$ok=Test-Applied;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime;Write-Log 'verify-reboot' $(if($ok){'pass'}else{'fail'}) @{bootTime=$boot};if(!$ok){throw'Reboot persistence verification failed.'};$true}
    'Rollback'{$state=Read-State;Restore-State $state;$after=Get-ValueState;$ok=(-not$after.ValueExists);Write-Log 'rollback' $(if($ok){'pass'}else{'fail'}) @{restoredExactOriginal=$ok};if(!$ok){throw'Rollback verification failed.'};[pscustomobject]@{Provider=$provider;RolledBack=$true;MutationCount=1}}
  }
}catch{Write-Log 'failure' 'fail' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName};throw}
