[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
 [string]$StatePath="$env:LOCALAPPDATA\Lacksan\EXP-058-state.json",
 [string]$LogPath="$env:LOCALAPPDATA\Lacksan\EXP-058.jsonl"
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Experiment='EXP-058'
$Provider='microsoft365-startup-folder-demand-launch'
$AllowedExecutables=@('OUTLOOK.EXE','WINWORD.EXE','EXCEL.EXE','POWERPNT.EXE','ONENOTE.EXE','MSACCESS.EXE')
$ProtectedPattern='(?i)omnissa|vmware[- ]?view|horizon|windows app|remote desktop|mstsc|msrdc|tailscale|securityhealth|defender|credential|bitlocker|firewall|windows update|recovery|intune|sccm|configmgr|mdm|driver|firmware'
function Write-Log($Event,$Result,$Data){
 $d=Split-Path $LogPath -Parent;if($d-and!(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null}
 [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$Experiment;provider=$Provider;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 24|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Hash-File($Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Same($a,$b){($a|ConvertTo-Json -Compress -Depth 24)-eq($b|ConvertTo-Json -Compress -Depth 24)}
function Startup-Root{[Environment]::GetFolderPath('Startup')}
function Get-ManagementState{
 $c=Get-CimInstance Win32_ComputerSystem
 $en=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName-match'^[0-9A-Fa-f-]{36}$'}).Count
 $om=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName-match'^[0-9A-Fa-f-]{36}$'}).Count
 $ccm=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
 [pscustomobject]@{Managed=([bool]$c.PartOfDomain-or$ccm-or($en-gt0-and$om-gt0));DomainJoined=[bool]$c.PartOfDomain;EnrollmentCount=$en;OmadmCount=$om;ConfigMgr=$ccm}
}
function Get-ShortcutState($Path){
 if([IO.Path]::GetExtension($Path)-ne'.lnk'){return $null}
 $w=New-Object -ComObject WScript.Shell;$x=$w.CreateShortcut($Path)
 [pscustomobject]@{TargetPath=$x.TargetPath;Arguments=$x.Arguments;WorkingDirectory=$x.WorkingDirectory;IconLocation=$x.IconLocation;Description=$x.Description;WindowStyle=$x.WindowStyle;Hotkey=$x.Hotkey}
}
function Get-FileState($Path){
 if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
 $f=Get-Item -LiteralPath $Path;$acl=Get-Acl -LiteralPath $Path;$sc=Get-ShortcutState $Path
 [pscustomobject]@{Path=$f.FullName;Name=$f.Name;Length=$f.Length;Sha256=Hash-File $f.FullName;CreationTimeUtc=$f.CreationTimeUtc.ToString('o');LastWriteTimeUtc=$f.LastWriteTimeUtc.ToString('o');LastAccessTimeUtc=$f.LastAccessTimeUtc.ToString('o');Attributes=[int]$f.Attributes;AclSddl=$acl.Sddl;Shortcut=$sc}
}
function Get-ExecutableIdentity($Path){
 if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
 $f=Get-Item -LiteralPath $Path;$sig=Get-AuthenticodeSignature -LiteralPath $Path;$pub=if($sig.SignerCertificate){$sig.SignerCertificate.Subject}else{$null}
 [pscustomobject]@{Path=$f.FullName;Name=$f.Name;Version=$f.VersionInfo.FileVersion;Product=$f.VersionInfo.ProductName;Company=$f.VersionInfo.CompanyName;Sha256=Hash-File $f.FullName;SignatureStatus=$sig.Status.ToString();Publisher=$pub;Thumbprint=if($sig.SignerCertificate){$sig.SignerCertificate.Thumbprint}else{$null};ValidMicrosoft=($sig.Status-eq'Valid'-and$pub-match'(?i)Microsoft Corporation')}
}
function Get-StartupSnapshot{
 $root=Startup-Root;$rows=@();if(Test-Path -LiteralPath $root){$rows=@(Get-ChildItem -LiteralPath $root -File -Force -ErrorAction SilentlyContinue|ForEach-Object{Get-FileState $_.FullName}|Sort-Object Path)}
 [pscustomobject]@{Root=$root;Rows=$rows}
}
function Get-ProtectedSnapshot{
 $services=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale')|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name|Select-Object Name,State,StartMode,PathName
 [pscustomobject]@{Services=@($services)}
}
function Get-Candidates{
 $root=Startup-Root;if(!(Test-Path -LiteralPath $root)){return @()};$out=@()
 foreach($f in Get-ChildItem -LiteralPath $root -File -Force -Filter '*.lnk' -ErrorAction SilentlyContinue){
  $state=Get-FileState $f.FullName;$sc=$state.Shortcut;if(!$sc){continue}
  if([string]::IsNullOrWhiteSpace([string]$sc.TargetPath)){continue}
  if(![string]::IsNullOrWhiteSpace([string]$sc.Arguments)){continue}
  $target=[Environment]::ExpandEnvironmentVariables([string]$sc.TargetPath)
  if($target-match$ProtectedPattern){continue}
  $id=Get-ExecutableIdentity $target;if(!$id-or!$id.ValidMicrosoft){continue}
  if($AllowedExecutables-notcontains$id.Name.ToUpperInvariant()){continue}
  if($target-notmatch'(?i)\\Microsoft Office\\|\\Microsoft\\Office\\|\\root\\Office16\\'){continue}
  $out+=[pscustomobject]@{File=$state;Executable=$id}
 }
 @($out)
}
function Get-SupportState{
 $os=Get-CimInstance Win32_OperatingSystem;$pc=Get-CimInstance Win32_ComputerSystem;$m=Get-ManagementState;$c=@(Get-Candidates);$reasons=@()
 if($os.Caption-notmatch'Windows 11'){$reasons+='Windows 11 required'}
 if($pc.Manufacturer-notmatch'(?i)^HP$|Hewlett-Packard'){$reasons+='HP platform required'}
 if($m.Managed){$reasons+='enterprise management ownership detected'}
 if($c.Count-ne1){$reasons+="exactly one eligible Microsoft 365 Startup-folder shortcut required; found $($c.Count)"}
 [pscustomobject]@{Supported=($reasons.Count-eq0);Reasons=$reasons;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$pc.Manufacturer;Model=$pc.Model;Management=$m;Candidates=$c;Protected=Get-ProtectedSnapshot;EvidenceStatus='needs-evidence'}
}
function Save-State($sup){
 if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused.'};if(!$sup.Supported){throw($sup.Reasons-join'; ')}
 $c=$sup.Candidates[0];$bytes=[Convert]::ToBase64String([IO.File]::ReadAllBytes($c.File.Path));$d=Split-Path $StatePath -Parent;if($d-and!(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null}
 $st=[ordered]@{schemaVersion=1;experiment=$Experiment;provider=$Provider;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');candidate=$c;bytesBase64=$bytes;startupSnapshot=Get-StartupSnapshot;protected=$sup.Protected;evidenceStatus='needs-evidence'}
 $st|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $StatePath -Encoding UTF8;$st
}
function Load-State{
 if(!(Test-Path -LiteralPath $StatePath)){throw 'Captured state required.'};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
 if($s.schemaVersion-ne1-or$s.experiment-ne$Experiment-or$s.provider-ne$Provider-or$s.machine-ne$env:COMPUTERNAME-or$s.userSid-ne$sid){throw 'State identity mismatch.'};$s
}
function Assert-Executable($st){
 $id=Get-ExecutableIdentity ([string]$st.candidate.Executable.Path)
 if(!$id-or!$id.ValidMicrosoft-or$id.Sha256-ne[string]$st.candidate.Executable.Sha256-or$id.Thumbprint-ne[string]$st.candidate.Executable.Thumbprint){throw 'Microsoft 365 executable identity drift detected.'}
}
function Assert-Protected($st){if(!(Same (Get-ProtectedSnapshot) $st.protected)){throw 'Protected security, update, or remote-access state drift detected.'}}
function Other-StartupMatches($st){
 $now=(Get-StartupSnapshot).Rows;$expected=@($st.startupSnapshot.Rows|Where-Object{$_.Path-ne[string]$st.candidate.File.Path});$actual=@($now|Where-Object{$_.Path-ne[string]$st.candidate.File.Path});Same $expected $actual
}
function Removed($st){!(Test-Path -LiteralPath ([string]$st.candidate.File.Path))}
function Restore-Exact($st){
 $p=[string]$st.candidate.File.Path
 if(Test-Path -LiteralPath $p){if((Hash-File $p)-eq[string]$st.candidate.File.Sha256){return};throw 'Rollback conflicting-path overwrite refused.'}
 $parent=Split-Path $p -Parent;if(!(Test-Path -LiteralPath $parent)){throw 'Captured Startup folder unavailable.'}
 [IO.File]::WriteAllBytes($p,[Convert]::FromBase64String([string]$st.bytesBase64));$f=Get-Item -LiteralPath $p;$f.CreationTimeUtc=[datetime]$st.candidate.File.CreationTimeUtc;$f.LastWriteTimeUtc=[datetime]$st.candidate.File.LastWriteTimeUtc;$f.LastAccessTimeUtc=[datetime]$st.candidate.File.LastAccessTimeUtc;$f.Attributes=[IO.FileAttributes][int]$st.candidate.File.Attributes
 $acl=New-Object Security.AccessControl.FileSecurity;$acl.SetSecurityDescriptorSddlForm([string]$st.candidate.File.AclSddl);Set-Acl -LiteralPath $p -AclObject $acl
}
try{
 $sup=Get-SupportState;Write-Log 'support-detection' $(if($sup.Supported){'pass'}else{'refused'}) $sup
 switch($Action){
  'Check'{$sup}
  'Capture'{$s=Save-State $sup;Write-Log 'capture' 'pass' @{path=$s.candidate.File.Path;sha256=$s.candidate.File.Sha256};$s}
  'DryRun'{if(!$sup.Supported){throw($sup.Reasons-join'; ')};$c=$sup.Candidates[0];$x=[pscustomobject]@{WouldChange=$true;MutationCount=1;Path=$c.File.Path;Target=$c.Executable.Path;PreserveMicrosoft365=$true;PreserveClickToRun=$true;PreserveProtectedScope=$true;RebootPersistenceRequired=$true;Rollback='restore exact shortcut bytes, metadata, ACL, and shortcut properties after collision and drift checks';EvidenceStatus='needs-evidence'};Write-Log 'dry-run' 'pass' $x;$x}
  'Apply'{$st=Load-State;if(Removed $st){Assert-Executable $st;Assert-Protected $st;if(!(Other-StartupMatches $st)){throw 'Unrelated Startup-folder drift detected.'};Write-Log 'apply' 'idempotent' @{mutationCount=0};return};Assert-Executable $st;Assert-Protected $st;$live=Get-FileState ([string]$st.candidate.File.Path);if(!$live-or$live.Sha256-ne[string]$st.candidate.File.Sha256-or!(Same $live.Shortcut $st.candidate.File.Shortcut)-or!(Other-StartupMatches $st)){throw 'Candidate or unrelated Startup-folder drift detected.'};if($WhatIfPreference){Write-Log 'apply' 'whatif' @{mutationCount=0};return};if($PSCmdlet.ShouldProcess($live.Path,'Remove exact Microsoft 365 Startup-folder shortcut')){Remove-Item -LiteralPath $live.Path -Force}else{return};if(!(Removed $st)-or!(Other-StartupMatches $st)){throw 'Apply verification failed.'};Assert-Protected $st;Write-Log 'apply' 'pass' @{mutationCount=1;path=$live.Path}}
  'Verify'{$st=Load-State;if(!(Removed $st)){throw 'Microsoft 365 Startup-folder shortcut remains present.'};Assert-Executable $st;Assert-Protected $st;if(!(Other-StartupMatches $st)){throw 'Unrelated Startup-folder drift detected.'};Write-Log 'verify' 'pass' @{removed=$true};$true}
  'VerifyReboot'{$st=Load-State;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot-le[datetime]$st.capturedBootTime){throw 'Later boot required.'};if(!(Removed $st)){throw 'Treatment failed reboot persistence.'};Assert-Executable $st;Assert-Protected $st;if(!(Other-StartupMatches $st)){throw 'Unrelated Startup-folder drift detected after reboot.'};Write-Log 'verify-reboot' 'pass' @{boot=$boot.ToString('o');evidenceStatus='needs-evidence'};$true}
  'Rollback'{$st=Load-State;Assert-Executable $st;Assert-Protected $st;if(!(Other-StartupMatches $st)){throw 'Rollback refused on unrelated Startup-folder drift.'};if(!(Removed $st)){if((Hash-File ([string]$st.candidate.File.Path))-eq[string]$st.candidate.File.Sha256){Write-Log 'rollback' 'idempotent' @{mutationCount=0};return};throw 'Rollback conflicting-path overwrite refused.'};if($WhatIfPreference){Write-Log 'rollback' 'whatif' @{mutationCount=0};return};if($PSCmdlet.ShouldProcess([string]$st.candidate.File.Path,'Restore exact Microsoft 365 Startup-folder shortcut')){Restore-Exact $st}else{return};$after=Get-FileState ([string]$st.candidate.File.Path);if(!$after-or$after.Sha256-ne[string]$st.candidate.File.Sha256-or!(Same $after.Shortcut $st.candidate.File.Shortcut)-or!(Other-StartupMatches $st)){throw 'Exact rollback verification failed.'};Assert-Protected $st;Write-Log 'rollback' 'pass' @{mutationCount=1;restoredExactOriginal=$true;sha256=$after.Sha256};$after}
 }
}catch{Write-Log 'failure' 'failure' @{stage=$Action;message=$_.Exception.Message;type=$_.Exception.GetType().FullName;evidenceStatus='needs-evidence'};throw}
