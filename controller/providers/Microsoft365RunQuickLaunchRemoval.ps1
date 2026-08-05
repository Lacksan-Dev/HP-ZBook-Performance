[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
 [string]$StatePath="$env:ProgramData\Lacksan\EXP-124-m365-run-state.json",
 [string]$LogPath="$env:ProgramData\Lacksan\EXP-124-m365-run-events.jsonl"
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Experiment='EXP-124'
$Provider='m365-run-quick-launch-removal'
$RunPath='Software\Microsoft\Windows\CurrentVersion\Run'
$RunOncePath='Software\Microsoft\Windows\CurrentVersion\RunOnce'
$OfficeExecutables=@('WINWORD.EXE','EXCEL.EXE','POWERPNT.EXE','OUTLOOK.EXE','ONENOTE.EXE','MSACCESS.EXE')
$RefusalPattern='(?i)clicktorun|office.*update|update(r|s|service)?|setup|install|repair|activation|licens|security|credential|recovery|accessib|intune|sccm|configmgr|mdm|driver|firmware|windows update|omnissa|vmware[- ]?view|horizon|windows app|remote desktop|mstsc|msrdc|tailscale'

function Write-Event([string]$Event,[string]$Result,$Before=$null,$After=$null,[string]$Reason=$null,[string]$Failure=$null){
 if([string]::IsNullOrWhiteSpace($LogPath)){return}
 $parent=Split-Path -Parent $LogPath
 if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
 [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$Experiment;provider=$Provider;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;action=$Action;event=$Event;result=$Result;before=$Before;after=$After;refusalReason=$Reason;failureDetail=$Failure;evidenceStatus='needs-evidence'}|ConvertTo-Json -Compress -Depth 30|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-Hash([string]$Text){$sha=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','')}finally{$sha.Dispose()}}
function Test-Same($A,$B){($A|ConvertTo-Json -Compress -Depth 30)-eq($B|ConvertTo-Json -Compress -Depth 30)}
function Test-Elevated{([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Get-ManagementState{
 $computer=Get-CimInstance Win32_ComputerSystem
 $configMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
 $enrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName-match'^[0-9A-Fa-f-]{36}$'}).Count
 $omadm=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName-match'^[0-9A-Fa-f-]{36}$'}).Count
 [pscustomobject]@{Managed=([bool]$computer.PartOfDomain-or$configMgr-or($enrollments-gt0-and$omadm-gt0));DomainJoined=[bool]$computer.PartOfDomain;ConfigMgr=$configMgr;EnrollmentCount=$enrollments;OmadmCount=$omadm}
}
function Open-RegistryKey([string]$Hive,[string]$View,[string]$Path,[bool]$Writable){
 $h=if($Hive-eq'HKCU'){[Microsoft.Win32.RegistryHive]::CurrentUser}else{[Microsoft.Win32.RegistryHive]::LocalMachine}
 $v=[Enum]::Parse([Microsoft.Win32.RegistryView],$View,$true)
 $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey($h,$v)
 try{$key=$base.OpenSubKey($Path,$Writable);$key}finally{$base.Dispose()}
}
function Resolve-Command([string]$Raw){
 $expanded=[Environment]::ExpandEnvironmentVariables($Raw).Trim()
 $m=[regex]::Match($expanded,'^\s*(?:"(?<exe>[^"]+\.exe)"|(?<exe>[^\s]+\.exe))(?:\s+(?<args>.*))?$')
 if(!$m.Success){return $null}
 try{$exe=[IO.Path]::GetFullPath($m.Groups['exe'].Value)}catch{return $null}
 [pscustomobject]@{Expanded=$expanded;Executable=$exe;Arguments=$m.Groups['args'].Value}
}
function Get-FileIdentity([string]$Path){
 if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
 $file=Get-Item -LiteralPath $Path;$sig=Get-AuthenticodeSignature -LiteralPath $Path;$publisher=if($sig.SignerCertificate){$sig.SignerCertificate.Subject}else{$null}
 [pscustomobject]@{Path=$file.FullName;Name=$file.Name.ToUpperInvariant();Sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash;FileVersion=$file.VersionInfo.FileVersion;ProductVersion=$file.VersionInfo.ProductVersion;ProductName=$file.VersionInfo.ProductName;CompanyName=$file.VersionInfo.CompanyName;SignatureStatus=$sig.Status.ToString();Publisher=$publisher;Thumbprint=if($sig.SignerCertificate){$sig.SignerCertificate.Thumbprint}else{$null};MicrosoftSigned=($sig.Status-eq'Valid'-and$publisher-match'(?i)Microsoft Corporation')}
}
function Get-OfficeProduct{
 $p='HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
 if(!(Test-Path -LiteralPath $p)){return $null}
 $x=Get-ItemProperty -LiteralPath $p
 if([string]::IsNullOrWhiteSpace([string]$x.VersionToReport)-or[string]::IsNullOrWhiteSpace([string]$x.ProductReleaseIds)){return $null}
 [pscustomobject]@{VersionToReport=[string]$x.VersionToReport;ProductReleaseIds=[string]$x.ProductReleaseIds;ClientCulture=[string]$x.ClientCulture;Platform=[string]$x.Platform}
}
function Get-ValueState($Candidate){
 $key=Open-RegistryKey $Candidate.Hive $Candidate.RegistryView $RunPath $false
 if(!$key){return [pscustomobject]@{KeyExists=$false;ValueExists=$false;Kind=$null;Data=$null;KeyOwner=$null;KeySddl=$null}}
 try{$names=@($key.GetValueNames());$exists=$names-contains[string]$Candidate.ValueName;$acl=$key.GetAccessControl();[pscustomobject]@{KeyExists=$true;ValueExists=$exists;Kind=if($exists){$key.GetValueKind([string]$Candidate.ValueName).ToString()}else{$null};Data=if($exists){[string]$key.GetValue([string]$Candidate.ValueName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}else{$null};KeyOwner=$acl.GetOwner([Security.Principal.NTAccount]).Value;KeySddl=$acl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)}}finally{$key.Dispose()}
}
function Get-RegistryStartupInventory{
 $rows=@()
 foreach($spec in @([pscustomobject]@{Hive='HKCU';View='Registry64'},[pscustomobject]@{Hive='HKLM';View='Registry64'},[pscustomobject]@{Hive='HKLM';View='Registry32'})){
  foreach($path in @($RunPath,$RunOncePath)){
   $key=Open-RegistryKey $spec.Hive $spec.View $path $false
   if(!$key){continue}
   try{foreach($name in @($key.GetValueNames()|Sort-Object)){$rows+=[pscustomobject]@{Hive=$spec.Hive;RegistryView=$spec.View;Path=$path;ValueName=$name;Kind=$key.GetValueKind($name).ToString();Data=[string]$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}}}finally{$key.Dispose()}
  }
 }
 @($rows|Sort-Object Hive,RegistryView,Path,ValueName)
}
function Get-EligibleCandidates{
 $rows=@()
 foreach($row in @(Get-RegistryStartupInventory|Where-Object{$_.Path-eq$RunPath-and$_.Kind-in@('String','ExpandString')})){
  $command=Resolve-Command $row.Data;if(!$command){continue}
  $id=Get-FileIdentity $command.Executable;if(!$id-or!$id.MicrosoftSigned-or$id.Name-notin$OfficeExecutables){continue}
  $text="$($row.ValueName) $($row.Data) $($command.Arguments) $($id.Path) $($id.ProductName) $($id.CompanyName)"
  if($text-match$RefusalPattern){continue}
  $rows+=[pscustomobject]@{Hive=$row.Hive;RegistryView=$row.RegistryView;Path=$row.Path;ValueName=$row.ValueName;Kind=$row.Kind;Data=$row.Data;Command=$command;Executable=$id}
 }
 @($rows)
}
function Get-ProtectedConfiguration{
 $names=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','ClickToRunSvc','TermService','Tailscale')
 $services=@($names|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name|Select-Object Name,StartMode,PathName)
 [pscustomobject]@{Services=$services}
}
function Get-Support{
 $os=Get-CimInstance Win32_OperatingSystem;$computer=Get-CimInstance Win32_ComputerSystem;$management=Get-ManagementState;$product=Get-OfficeProduct;$candidates=@(Get-EligibleCandidates);$reasons=@()
 if($os.Caption-notmatch'Windows 11'){$reasons+='Windows 11 required.'}
 if($computer.Manufacturer-notmatch'(?i)^HP$|Hewlett-Packard'){$reasons+='HP platform required.'}
 if(!(Test-Elevated)){$reasons+='Elevation required for exact cross-hive qualification and rollback.'}
 if($management.Managed){$reasons+='Enterprise management ownership detected.'}
 if(!$product){$reasons+='Microsoft 365 Click-to-Run product identity/version unavailable.'}
 if($candidates.Count-ne1){$reasons+="Exactly one eligible Microsoft 365 persistent Run candidate required; found $($candidates.Count)."}
 [pscustomobject]@{Supported=($reasons.Count-eq0);Reasons=$reasons;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$computer.Manufacturer;Model=$computer.Model;Elevated=(Test-Elevated);Management=$management;OfficeProduct=$product;Candidates=$candidates;EvidenceStatus='needs-evidence'}
}
function Save-State($Support){
 if(!$Support.Supported){throw($Support.Reasons-join' ')}
 if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused.'}
 $candidate=$Support.Candidates[0];$value=Get-ValueState $candidate;$inventory=Get-RegistryStartupInventory;$other=@($inventory|Where-Object{!($_.Hive-eq$candidate.Hive-and$_.RegistryView-eq$candidate.RegistryView-and$_.Path-eq$RunPath-and$_.ValueName-eq$candidate.ValueName)});$protected=Get-ProtectedConfiguration
 $parent=Split-Path -Parent $StatePath;if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
 $state=[ordered]@{schemaVersion=1;experiment=$Experiment;provider=$Provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootUtc=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;candidate=$candidate;original=$value;officeProduct=$Support.OfficeProduct;management=$Support.Management;otherStartupHash=Get-Hash($other|ConvertTo-Json -Compress -Depth 15);protectedHash=Get-Hash($protected|ConvertTo-Json -Compress -Depth 15);evidenceStatus='needs-evidence'}
 $state|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $StatePath -Encoding UTF8
 [pscustomobject]$state
}
function Read-State{
 if(!(Test-Path -LiteralPath $StatePath)){throw 'Captured state required.'}
 $state=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
 if($state.schemaVersion-ne1-or$state.experiment-ne$Experiment-or$state.provider-ne$Provider-or$state.machine-ne$env:COMPUTERNAME-or$state.userSid-ne$sid){throw 'State identity validation failed.'}
 $state
}
function Assert-DriftFree($State){
 if(!(Test-Elevated)){throw 'Elevation drift detected.'};if((Get-ManagementState).Managed){throw 'Management ownership drift detected.'}
 $product=Get-OfficeProduct;if(!$product-or!(Test-Same $product $State.officeProduct)){throw 'Microsoft 365 product identity/version drift detected.'}
 $id=Get-FileIdentity ([string]$State.candidate.Executable.Path);if(!$id-or!$id.MicrosoftSigned-or$id.Sha256-ne[string]$State.candidate.Executable.Sha256-or$id.Thumbprint-ne[string]$State.candidate.Executable.Thumbprint-or$id.FileVersion-ne[string]$State.candidate.Executable.FileVersion){throw 'Office executable identity drift detected.'}
 $current=Get-ValueState $State.candidate;if($current.KeyOwner-ne[string]$State.original.KeyOwner-or$current.KeySddl-ne[string]$State.original.KeySddl){throw 'Run-key ownership or ACL drift detected.'}
 $inventory=Get-RegistryStartupInventory;$other=@($inventory|Where-Object{!($_.Hive-eq[string]$State.candidate.Hive-and$_.RegistryView-eq[string]$State.candidate.RegistryView-and$_.Path-eq$RunPath-and$_.ValueName-eq[string]$State.candidate.ValueName)});if((Get-Hash($other|ConvertTo-Json -Compress -Depth 15))-ne[string]$State.otherStartupHash){throw 'Unrelated Run or RunOnce registration drift detected.'}
 if((Get-Hash((Get-ProtectedConfiguration)|ConvertTo-Json -Compress -Depth 15))-ne[string]$State.protectedHash){throw 'Protected security, update, Office servicing, or remote-access configuration drift detected.'}
 $current
}
function Test-ExactOriginal($State){$v=Get-ValueState $State.candidate;$v.ValueExists-and$v.Kind-eq[string]$State.original.Kind-and$v.Data-eq[string]$State.original.Data}
function Test-Removed($State){!(Get-ValueState $State.candidate).ValueExists}
function Restore-Exact($State){
 $current=Get-ValueState $State.candidate
 if($current.ValueExists){if(Test-ExactOriginal $State){return}else{throw 'Rollback collision detected; overwrite refused.'}}
 $key=Open-RegistryKey ([string]$State.candidate.Hive) ([string]$State.candidate.RegistryView) $RunPath $true;if(!$key){throw 'Captured Run key is unavailable.'}
 try{$kind=[Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$State.original.Kind,$true);$key.SetValue([string]$State.candidate.ValueName,[string]$State.original.Data,$kind)}finally{$key.Dispose()}
}
try{
 $support=Get-Support;Write-Event 'support-detection' $(if($support.Supported){'pass'}else{'refused'}) $null $support ($(if($support.Supported){$null}else{$support.Reasons-join' '}))
 switch($Action){
  'Check'{$support}
  'Capture'{$state=Save-State $support;Write-Event 'capture' 'pass' $null $state;$state}
  'DryRun'{if(!$support.Supported){throw($support.Reasons-join' ')};$c=$support.Candidates[0];$result=[pscustomobject]@{WouldChange=$true;MutationCount=1;Hive=$c.Hive;RegistryView=$c.RegistryView;Path=$c.Path;ValueName=$c.ValueName;Kind=$c.Kind;ExactUnexpandedDataCaptured=$true;PreserveRunOnce=$true;PreserveOfficeServicing=$true;PreserveProtectedScope=$true;RebootPersistenceRequired=$true;Rollback='Restore exact captured registry type and raw unexpanded data after identity, ownership, management, unrelated-startup, and protected-configuration drift checks.';EvidenceStatus='needs-evidence'};Write-Event 'dry-run' 'pass' $c $result;$result}
  'Apply'{$state=if(Test-Path -LiteralPath $StatePath){Read-State}else{Save-State $support};$before=Assert-DriftFree $state;if(!$before.ValueExists){Write-Event 'apply' 'idempotent' $before $before;return [pscustomobject]@{Applied=$true;MutationCount=0}};if(!(Test-ExactOriginal $state)){throw 'Candidate value drift detected before application.'};if($WhatIfPreference){Write-Event 'apply' 'whatif' $before $before;return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$($state.candidate.Hive)\$RunPath::$($state.candidate.ValueName)",'Delete one EXP-124 Microsoft 365 persistent Run value')){$key=Open-RegistryKey ([string]$state.candidate.Hive) ([string]$state.candidate.RegistryView) $RunPath $true;try{$key.DeleteValue([string]$state.candidate.ValueName,$true)}finally{$key.Dispose()}}else{return};if(!(Test-Removed $state)){throw 'Application verification failed.'};$after=Assert-DriftFree $state;Write-Event 'apply' 'pass' $before $after;[pscustomobject]@{Applied=$true;MutationCount=1}}
  'Verify'{$state=Read-State;$before=Assert-DriftFree $state;if($before.ValueExists){throw 'Immediate verification failed.'};$result=[pscustomobject]@{Verified=$true;RegistrationAbsent=$true;OfficeManualLaunch='needs-evidence';OfficeServicing='needs-evidence';ProtectedApplicationReadiness='needs-evidence'};Write-Event 'verify' 'pass' $before $result;$result}
  'VerifyReboot'{$state=Read-State;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot-le[datetime]$state.capturedBootUtc){throw 'A later boot is required.'};$before=Assert-DriftFree $state;if($before.ValueExists){throw 'Treatment failed reboot persistence.'};$result=[pscustomobject]@{VerifiedReboot=$true;BootUtc=$boot.ToString('o');RegistrationAbsent=$true;Performance='needs-evidence';OfficeManualLaunch='needs-evidence';OfficeServicing='needs-evidence';ProtectedApplicationReadiness='needs-evidence'};Write-Event 'verify-reboot' 'pass' $before $result;$result}
  'Rollback'{$state=Read-State;$before=Assert-DriftFree $state;if(Test-ExactOriginal $state){Write-Event 'rollback' 'idempotent' $before $before;return [pscustomobject]@{RolledBack=$true;MutationCount=0}};if($before.ValueExists){throw 'Rollback collision detected; overwrite refused.'};if($WhatIfPreference){Write-Event 'rollback' 'whatif' $before $before;return [pscustomobject]@{RolledBack=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$($state.candidate.Hive)\$RunPath::$($state.candidate.ValueName)",'Restore exact EXP-124 Microsoft 365 persistent Run value')){Restore-Exact $state}else{return};if(!(Test-ExactOriginal $state)){throw 'Exact rollback verification failed.'};$after=Assert-DriftFree $state;Write-Event 'rollback' 'pass' $before $after;[pscustomobject]@{RolledBack=$true;MutationCount=1;RestoredExactOriginal=$true;PostRollbackRebootCheck='needs-evidence'}}
 }
}catch{Write-Event 'failure' 'failure' $null $null $null $_.Exception.Message;throw}
