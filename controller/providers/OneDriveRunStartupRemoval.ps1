[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
 [string]$StatePath="$env:ProgramData\Lacksan\EXP-092-onedrive-run-state.json",
 [string]$LogPath="$env:ProgramData\Lacksan\EXP-092-onedrive-run-events.jsonl"
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Experiment='EXP-092'
$Provider='onedrive-run-startup-removal'
$RunPath='Software\Microsoft\Windows\CurrentVersion\Run'
$ProtectedServices=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale')

function Write-Event([string]$Event,[string]$Result,$Before=$null,$After=$null,[string]$Reason=$null,[string]$Failure=$null){
 if([string]::IsNullOrWhiteSpace($LogPath)){return}
 $parent=Split-Path -Parent $LogPath;if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
 [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$Experiment;provider=$Provider;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;action=$Action;event=$Event;result=$Result;before=$Before;after=$After;refusalReason=$Reason;failureDetail=$Failure;evidenceStatus='needs-evidence'}|ConvertTo-Json -Compress -Depth 30|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-Hash([string]$Text){$sha=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','')}finally{$sha.Dispose()}}
function Test-Elevated{([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Open-RunKey([bool]$Writable){$base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser,[Microsoft.Win32.RegistryView]::Registry64);try{$base.OpenSubKey($RunPath,$Writable)}finally{$base.Dispose()}}
function Get-ManagementState{
 $computer=Get-CimInstance Win32_ComputerSystem
 $configMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
 $enrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName-match'^[0-9A-Fa-f-]{36}$'}).Count
 $omadm=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName-match'^[0-9A-Fa-f-]{36}$'}).Count
 [pscustomobject]@{Managed=([bool]$computer.PartOfDomain-or$configMgr-or($enrollments-gt0-and$omadm-gt0));DomainJoined=[bool]$computer.PartOfDomain;ConfigMgr=$configMgr;EnrollmentCount=$enrollments;OmadmCount=$omadm}
}
function Resolve-Command([string]$Raw){
 $expanded=[Environment]::ExpandEnvironmentVariables($Raw).Trim();$m=[regex]::Match($expanded,'^\s*(?:"(?<exe>[^"]+\.exe)"|(?<exe>[^\s]+\.exe))(?:\s+(?<args>.*))?$');if(!$m.Success){return $null}
 try{$exe=[IO.Path]::GetFullPath($m.Groups['exe'].Value)}catch{return $null};[pscustomobject]@{Expanded=$expanded;Executable=$exe;Arguments=$m.Groups['args'].Value}
}
function Get-FileIdentity([string]$Path){
 if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return $null};$f=Get-Item -LiteralPath $Path;$sig=Get-AuthenticodeSignature -LiteralPath $Path;$pub=if($sig.SignerCertificate){$sig.SignerCertificate.Subject}else{$null}
 [pscustomobject]@{Path=$f.FullName;Name=$f.Name;Sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash;FileVersion=$f.VersionInfo.FileVersion;ProductVersion=$f.VersionInfo.ProductVersion;ProductName=$f.VersionInfo.ProductName;CompanyName=$f.VersionInfo.CompanyName;SignatureStatus=$sig.Status.ToString();Publisher=$pub;Thumbprint=if($sig.SignerCertificate){$sig.SignerCertificate.Thumbprint}else{$null};MicrosoftSigned=($sig.Status-eq'Valid'-and$pub-match'(?i)Microsoft Corporation')}
}
function Get-OneDrivePolicy{
 $paths=@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive','HKCU:\SOFTWARE\Policies\Microsoft\OneDrive','HKLM:\SOFTWARE\Policies\Microsoft\OneDrive')
 $rows=@();foreach($p in $paths){if(Test-Path -LiteralPath $p){$x=Get-ItemProperty -LiteralPath $p;$rows+=[pscustomobject]@{Path=$p;Json=($x|Select-Object * -ExcludeProperty PSPath,PSParentPath,PSChildName,PSDrive,PSProvider|ConvertTo-Json -Compress -Depth 10)}}};@($rows)
}
function Get-SyncRoots{
 $rows=@();foreach($p in @(Get-ChildItem 'HKCU:\Software\Microsoft\OneDrive\Accounts' -ErrorAction SilentlyContinue)){try{$x=Get-ItemProperty -LiteralPath $p.PSPath;$rows+=[pscustomobject]@{Account=$p.PSChildName;UserFolder=[string]$x.UserFolder;DisplayName=[string]$x.DisplayName;Business=[bool]($p.PSChildName-match'^Business')}}catch{}};@($rows)
}
function Get-ValueState{
 $key=Open-RunKey $false;if(!$key){return [pscustomobject]@{KeyExists=$false;ValueExists=$false;ValueName=$null;Kind=$null;Data=$null;Owner=$null;Sddl=$null}}
 try{$matches=@($key.GetValueNames()|Where-Object{$_-match'(?i)^OneDrive$'});if($matches.Count-ne1){return [pscustomobject]@{KeyExists=$true;ValueExists=$false;ValueName=$null;Kind=$null;Data=$null;Owner=$null;Sddl=$null;MatchCount=$matches.Count}};$name=$matches[0];$acl=$key.GetAccessControl();[pscustomobject]@{KeyExists=$true;ValueExists=$true;ValueName=$name;Kind=$key.GetValueKind($name).ToString();Data=[string]$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);Owner=$acl.GetOwner([Security.Principal.NTAccount]).Value;Sddl=$acl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access);MatchCount=1}}finally{$key.Dispose()}
}
function Get-ProtectedConfiguration{$services=@($ProtectedServices|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name|Select-Object Name,StartMode,State,PathName);[pscustomobject]@{Services=$services;Policies=Get-OneDrivePolicy}}
function Get-Candidate{
 $v=Get-ValueState;if(!$v.ValueExists){return $null};if($v.Kind-notin@('String','ExpandString')){return $null};$cmd=Resolve-Command $v.Data;if(!$cmd){return $null};$id=Get-FileIdentity $cmd.Executable;if(!$id-or!$id.MicrosoftSigned-or$id.Name-notmatch'(?i)^OneDrive\.exe$'){return $null};if($cmd.Arguments-notmatch'(?i)(^|\s)/background(\s|$)'){return $null};[pscustomobject]@{Value=$v;Command=$cmd;Executable=$id}
}
function Get-Support{
 $os=Get-CimInstance Win32_OperatingSystem;$computer=Get-CimInstance Win32_ComputerSystem;$mgmt=Get-ManagementState;$candidate=Get-Candidate;$roots=@(Get-SyncRoots);$policies=@(Get-OneDrivePolicy);$reasons=@()
 if($os.Caption-notmatch'Windows 11'){$reasons+='Windows 11 required.'};if($computer.Manufacturer-notmatch'(?i)^HP$|Hewlett-Packard'){$reasons+='HP platform required.'};if(!(Test-Elevated)){$reasons+='Elevation required for protected-scope and management qualification.'};if($mgmt.Managed){$reasons+='Enterprise management ownership detected.'};if(!$candidate){$reasons+='Exactly one Microsoft-signed OneDrive /background HKCU Run registration required.'};if($roots.Count-lt1){$reasons+='OneDrive account/sync-root identity unavailable.'};if($policies.Count-gt0){$reasons+='OneDrive policy ownership detected; treatment refused.'}
 [pscustomobject]@{Supported=($reasons.Count-eq0);Reasons=$reasons;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$computer.Manufacturer;Model=$computer.Model;Elevated=(Test-Elevated);Management=$mgmt;Candidate=$candidate;SyncRoots=$roots;Policies=$policies;EvidenceStatus='needs-evidence'}
}
function Save-State($Support){
 if(!$Support.Supported){throw($Support.Reasons-join' ')};if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused.'};$parent=Split-Path -Parent $StatePath;if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
 $protected=Get-ProtectedConfiguration;$state=[ordered]@{schemaVersion=1;experiment=$Experiment;provider=$Provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootUtc=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;candidate=$Support.Candidate;syncRoots=$Support.SyncRoots;management=$Support.Management;protectedHash=Get-Hash($protected|ConvertTo-Json -Compress -Depth 20);evidenceStatus='needs-evidence'};$state|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $StatePath -Encoding UTF8;[pscustomobject]$state
}
function Read-State{if(!(Test-Path -LiteralPath $StatePath)){throw 'Captured state required.'};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;if($s.schemaVersion-ne1-or$s.experiment-ne$Experiment-or$s.provider-ne$Provider-or$s.machine-ne$env:COMPUTERNAME-or$s.userSid-ne$sid){throw 'State identity validation failed.'};$s}
function Assert-DriftFree($State){
 if(!(Test-Elevated)){throw 'Elevation drift detected.'};if((Get-ManagementState).Managed){throw 'Management ownership drift detected.'};if(@(Get-OneDrivePolicy).Count-gt0){throw 'OneDrive policy drift detected.'};$id=Get-FileIdentity ([string]$State.candidate.Executable.Path);if(!$id-or!$id.MicrosoftSigned-or$id.Sha256-ne[string]$State.candidate.Executable.Sha256-or$id.Thumbprint-ne[string]$State.candidate.Executable.Thumbprint-or$id.FileVersion-ne[string]$State.candidate.Executable.FileVersion){throw 'OneDrive executable identity drift detected.'};$roots=@(Get-SyncRoots);if((Get-Hash($roots|ConvertTo-Json -Compress -Depth 10))-ne(Get-Hash($State.syncRoots|ConvertTo-Json -Compress -Depth 10))){throw 'OneDrive account or sync-root drift detected.'};if((Get-Hash((Get-ProtectedConfiguration)|ConvertTo-Json -Compress -Depth 20))-ne[string]$State.protectedHash){throw 'Protected configuration drift detected.'};Get-ValueState
}
function Test-ExactOriginal($State){$v=Get-ValueState;$v.ValueExists-and$v.ValueName-eq[string]$State.candidate.Value.ValueName-and$v.Kind-eq[string]$State.candidate.Value.Kind-and$v.Data-eq[string]$State.candidate.Value.Data}
function Test-Removed{!(Get-ValueState).ValueExists}
function Remove-Candidate($State){$key=Open-RunKey $true;if(!$key){throw 'Run key unavailable.'};try{$key.DeleteValue([string]$State.candidate.Value.ValueName,$false)}finally{$key.Dispose()}}
function Restore-Exact($State){$v=Get-ValueState;if($v.ValueExists){if(Test-ExactOriginal $State){return};throw 'Rollback collision detected; overwrite refused.'};$key=Open-RunKey $true;if(!$key){throw 'Captured Run key unavailable.'};try{$kind=[Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$State.candidate.Value.Kind,$true);$key.SetValue([string]$State.candidate.Value.ValueName,[string]$State.candidate.Value.Data,$kind)}finally{$key.Dispose()}}

try{
 $support=Get-Support;Write-Event 'support-detection' $(if($support.Supported){'pass'}else{'refused'}) $null $support ($(if($support.Supported){$null}else{$support.Reasons-join' '}))
 switch($Action){
  'Check'{$support}
  'Capture'{$s=Save-State $support;Write-Event 'capture' 'pass' $null $s;$s}
  'DryRun'{if(!$support.Supported){throw($support.Reasons-join' ')};$r=[pscustomobject]@{WouldChange=$true;MutationCount=1;Hive='HKCU';Path=$RunPath;ValueName=$support.Candidate.Value.ValueName;PreserveInstallation=$true;PreserveAccounts=$true;PreserveSyncRoots=$true;PreserveFilesOnDemand=$true;PreserveProtectedScope=$true;RebootPersistenceRequired=$true;Rollback='Restore exact captured value name, registry type, and raw unexpanded data after identity and drift checks.';EvidenceStatus='needs-evidence'};Write-Event 'dry-run' 'pass' $support.Candidate $r;$r}
  'Apply'{$s=if(Test-Path -LiteralPath $StatePath){Read-State}else{Save-State $support};$before=Assert-DriftFree $s;if(!$before.ValueExists){Write-Event 'apply' 'pass' $before $before;'already-applied';break};if(!$PSCmdlet.ShouldProcess("HKCU\$RunPath\$($s.candidate.Value.ValueName)",'Remove OneDrive startup registration')){Write-Event 'apply' 'whatif' $before $before;'whatif';break};Remove-Candidate $s;if(!(Test-Removed)){throw 'Application verification failed.'};$after=Get-ValueState;Write-Event 'apply' 'pass' $before $after;$after}
  'Verify'{$s=Read-State;Assert-DriftFree $s|Out-Null;$ok=Test-Removed;Write-Event 'verify' $(if($ok){'pass'}else{'fail'}) $null @{Removed=$ok};if(!$ok){throw 'Treatment state missing.'};$true}
  'VerifyReboot'{$s=Read-State;Assert-DriftFree $s|Out-Null;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');if($boot-eq[string]$s.capturedBootUtc){throw 'A later boot is required for persistence verification.'};$ok=Test-Removed;Write-Event 'verify-reboot' $(if($ok){'pass'}else{'fail'}) @{CapturedBoot=$s.capturedBootUtc} @{CurrentBoot=$boot;Removed=$ok};if(!$ok){throw 'Treatment did not persist across reboot.'};$true}
  'Rollback'{$s=Read-State;$before=Assert-DriftFree $s;if(Test-ExactOriginal $s){Write-Event 'rollback' 'pass' $before $before;'already-restored';break};if(!$PSCmdlet.ShouldProcess("HKCU\$RunPath\$($s.candidate.Value.ValueName)",'Restore exact OneDrive startup registration')){Write-Event 'rollback' 'whatif' $before $before;'whatif';break};Restore-Exact $s;if(!(Test-ExactOriginal $s)){throw 'Rollback verification failed.'};$after=Get-ValueState;Write-Event 'rollback' 'pass' $before $after;$after}
 }
}catch{Write-Event 'failure' 'fail' $null $null $null $_.Exception.Message;throw}
