[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
 [Parameter(Mandatory=$true)][string]$SelectionPath,
 [string]$StatePath="$env:LOCALAPPDATA\Lacksan\EXP-160-state.json",
 [string]$LogPath="$env:LOCALAPPDATA\Lacksan\EXP-160.jsonl"
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Experiment='EXP-160'
$ProtectedPattern='(?i)omnissa|vmware[- ]?view|horizon|windows app|remote desktop|mstsc|msrdc|tailscale|securityhealth|defender|credential|bitlocker|firewall|windows update|recovery|intune|sccm|configmgr|mdm|driver|firmware|bluetooth|receiver|hid'

function Write-Log($Event,$Result,$Data){
 $dir=Split-Path $LogPath -Parent
 if($dir -and !(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
 [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$Experiment;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 24|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-HashText([string]$Text){$h=[Security.Cryptography.SHA256]::Create();try{($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))|ForEach-Object{$_.ToString('x2')})-join''}finally{$h.Dispose()}}
function Get-HashFile($Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Test-Same($a,$b){($a|ConvertTo-Json -Compress -Depth 24)-eq($b|ConvertTo-Json -Compress -Depth 24)}
function Test-Elevated{$id=[Security.Principal.WindowsIdentity]::GetCurrent();$p=New-Object Security.Principal.WindowsPrincipal($id);$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Get-StartupRoots{@([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))|Where-Object{$_}|Select-Object -Unique}
function Get-Selection{
 if(!(Test-Path -LiteralPath $SelectionPath -PathType Leaf)){throw 'EXP-143 selection artifact required.'}
 $s=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
 if($s.experiment-ne'EXP-143'-or$s.classification-ne'priority-target'-or$s.surface-ne'StartupFolder'-or[string]::IsNullOrWhiteSpace([string]$s.inventoryHash)-or[string]::IsNullOrWhiteSpace([string]$s.path)){throw 'Selection must bind one EXP-143 priority-target StartupFolder record and inventory hash.'}
 $s
}
function Get-Shortcut($Path){
 if([IO.Path]::GetExtension($Path)-ne'.lnk'){return $null}
 $w=New-Object -ComObject WScript.Shell;$x=$w.CreateShortcut($Path)
 [pscustomobject]@{TargetPath=$x.TargetPath;Arguments=$x.Arguments;WorkingDirectory=$x.WorkingDirectory;IconLocation=$x.IconLocation;Description=$x.Description;WindowStyle=$x.WindowStyle;Hotkey=$x.Hotkey}
}
function Get-FileState($Path){
 if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
 $f=Get-Item -LiteralPath $Path;$acl=Get-Acl -LiteralPath $Path;$sc=Get-Shortcut $Path
 [pscustomobject]@{Path=$f.FullName;Name=$f.Name;Length=$f.Length;Sha256=Get-HashFile $f.FullName;CreationTimeUtc=$f.CreationTimeUtc.ToString('o');LastWriteTimeUtc=$f.LastWriteTimeUtc.ToString('o');LastAccessTimeUtc=$f.LastAccessTimeUtc.ToString('o');Attributes=[int]$f.Attributes;Owner=$acl.Owner;AclSddl=$acl.Sddl;Shortcut=$sc}
}
function Get-StartupSnapshot{
 $rows=@();foreach($r in Get-StartupRoots){if(Test-Path -LiteralPath $r){$rows+=@(Get-ChildItem -LiteralPath $r -File -Force -ErrorAction SilentlyContinue|ForEach-Object{Get-FileState $_.FullName})}}
 $rows=@($rows|Sort-Object Path);$json=$rows|ConvertTo-Json -Compress -Depth 12
 [pscustomobject]@{Rows=$rows;Hash=Get-HashText $json}
}
function Get-ProtectedState{
 $services=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale')|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name|Select-Object Name,StartMode,PathName
 $startup=@((Get-StartupSnapshot).Rows|Where-Object{($_.Path+$_.Shortcut.TargetPath+$_.Shortcut.Arguments)-match$ProtectedPattern})
 [pscustomobject]@{Services=@($services);Startup=@($startup)}
}
function Get-ManagementState{
 $c=Get-CimInstance Win32_ComputerSystem
 $en=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName-match'^[0-9A-Fa-f-]{36}$'}).Count
 $om=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName-match'^[0-9A-Fa-f-]{36}$'}).Count
 $ccm=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
 [pscustomobject]@{Managed=([bool]$c.PartOfDomain-or$ccm-or($en-gt0-and$om-gt0));DomainJoined=[bool]$c.PartOfDomain;EnrollmentCount=$en;OmadmCount=$om;ConfigMgr=$ccm}
}
function Get-Candidate{
 $s=Get-Selection;$full=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables([string]$s.path));$roots=@(Get-StartupRoots|ForEach-Object{[IO.Path]::GetFullPath($_).TrimEnd('\')+'\'})
 if(!($roots|Where-Object{$full.StartsWith($_,[StringComparison]::OrdinalIgnoreCase)})){throw 'Selected path is outside approved Startup folders.'}
 $f=Get-FileState $full;if(!$f){return $null}
 $text=$f.Path+$(if($f.Shortcut){$f.Shortcut.TargetPath+$f.Shortcut.Arguments+$f.Shortcut.WorkingDirectory}else{''});if($text-match$ProtectedPattern){throw 'Protected startup identity refused.'}
 $target=if($f.Shortcut){[Environment]::ExpandEnvironmentVariables([string]$f.Shortcut.TargetPath)}else{$f.Path};if(!$target-or!(Test-Path -LiteralPath $target -PathType Leaf)){throw 'Resolved executable identity required.'}
 if($f.Shortcut-and!([string]::IsNullOrWhiteSpace([string]$f.Shortcut.Arguments))){throw 'Shortcut arguments require separate qualification.'}
 $sig=Get-AuthenticodeSignature -LiteralPath $target;$pub=if($sig.SignerCertificate){$sig.SignerCertificate.Subject}else{$null}
 if($sig.Status-ne'Valid'-or$pub-notmatch'(?i)Microsoft Corporation|Logitech|Logi'){throw 'EXP-160 requires a valid Microsoft or Logitech publisher.'}
 [pscustomobject]@{Selection=$s;File=$f;Executable=[pscustomobject]@{Path=(Get-Item $target).FullName;Sha256=Get-HashFile $target;Version=(Get-Item $target).VersionInfo.FileVersion;Publisher=$pub;Thumbprint=$sig.SignerCertificate.Thumbprint}}
}
function Get-Support{
 $os=Get-CimInstance Win32_OperatingSystem;$pc=Get-CimInstance Win32_ComputerSystem;$m=Get-ManagementState;$reasons=@();$c=$null
 if($os.Caption-notmatch'Windows 11'){$reasons+='Windows 11 required'};if($pc.Manufacturer-notmatch'(?i)^HP$|Hewlett-Packard'){$reasons+='HP platform required'};if(!(Test-Elevated)){$reasons+='elevation required'};if($m.Managed){$reasons+='enterprise management ownership detected'}
 try{$c=Get-Candidate}catch{$reasons+=$_.Exception.Message};if(!$c){$reasons+='exact selected Startup-folder registration required'}
 [pscustomobject]@{Supported=($reasons.Count-eq0);Reasons=$reasons;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$pc.Manufacturer;Model=$pc.Model;Elevated=(Test-Elevated);Management=$m;Candidate=$c;Protected=Get-ProtectedState;EvidenceStatus='needs-evidence'}
}
function Save-State($sup){
 if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused.'};$snap=Get-StartupSnapshot;$bytes=[Convert]::ToBase64String([IO.File]::ReadAllBytes($sup.Candidate.File.Path));$d=Split-Path $StatePath -Parent;if($d-and!(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null}
 $st=[ordered]@{schemaVersion=1;experiment=$Experiment;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');selection=$sup.Candidate.Selection;candidate=$sup.Candidate;bytesBase64=$bytes;startupSnapshot=$snap;protected=$sup.Protected;evidenceStatus='needs-evidence'}
 $st|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $StatePath -Encoding UTF8;$st
}
function Load-State{if(!(Test-Path -LiteralPath $StatePath)){throw 'Captured state required.'};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;if($s.experiment-ne$Experiment-or$s.machine-ne$env:COMPUTERNAME-or$s.userSid-ne$sid){throw 'State identity mismatch.'};$s}
function Assert-Executable($st){$p=[string]$st.candidate.Executable.Path;if(!(Test-Path -LiteralPath $p)-or(Get-HashFile $p)-ne[string]$st.candidate.Executable.Sha256){throw 'Executable identity drift detected.'};$sig=Get-AuthenticodeSignature -LiteralPath $p;if($sig.Status-ne'Valid'-or$sig.SignerCertificate.Thumbprint-ne[string]$st.candidate.Executable.Thumbprint){throw 'Executable publisher drift detected.'}}
function Assert-Protected($st){if(!(Test-Same (Get-ProtectedState) $st.protected)){throw 'Protected security update or remote-access configuration drift detected.'}}
function Test-RemainingMatches($st){$now=Get-StartupSnapshot;$expected=@($st.startupSnapshot.Rows|Where-Object{$_.Path-ne[string]$st.candidate.File.Path});$actual=@($now.Rows|Where-Object{$_.Path-ne[string]$st.candidate.File.Path});Test-Same $expected $actual}
function Test-Removed($st){!(Test-Path -LiteralPath ([string]$st.candidate.File.Path))}
function Restore-Exact($st){
 $p=[string]$st.candidate.File.Path;if(Test-Path -LiteralPath $p){if((Get-HashFile $p)-eq[string]$st.candidate.File.Sha256){return}else{throw 'Rollback conflicting-path overwrite refused.'}}
 $parent=Split-Path $p -Parent;if(!(Test-Path $parent)){throw 'Captured Startup folder is unavailable.'};[IO.File]::WriteAllBytes($p,[Convert]::FromBase64String([string]$st.bytesBase64));$f=Get-Item $p;$f.CreationTimeUtc=[datetime]$st.candidate.File.CreationTimeUtc;$f.LastWriteTimeUtc=[datetime]$st.candidate.File.LastWriteTimeUtc;$f.LastAccessTimeUtc=[datetime]$st.candidate.File.LastAccessTimeUtc;$f.Attributes=[IO.FileAttributes][int]$st.candidate.File.Attributes
 $acl=New-Object Security.AccessControl.FileSecurity;$acl.SetSecurityDescriptorSddlForm([string]$st.candidate.File.AclSddl);Set-Acl -LiteralPath $p -AclObject $acl
}
try{
 $sup=Get-Support;Write-Log 'support-detection' $(if($sup.Supported){'pass'}else{'refused'}) $sup
 switch($Action){
  'Check'{$sup}
  'Capture'{if(!$sup.Supported){throw($sup.Reasons-join'; ')};$s=Save-State $sup;Write-Log 'capture' 'pass' @{path=$s.candidate.File.Path;sha256=$s.candidate.File.Sha256;inventoryHash=$s.selection.inventoryHash};$s}
  'DryRun'{if(!$sup.Supported){throw($sup.Reasons-join'; ')};$x=[pscustomobject]@{WouldChange=$true;MutationCount=1;Path=$sup.Candidate.File.Path;Sha256=$sup.Candidate.File.Sha256;InventoryHash=$sup.Candidate.Selection.inventoryHash;PreserveApplication=$true;PreserveProtectedScope=$true;RebootPersistenceRequired=$true;Rollback='restore exact captured bytes, metadata, owner/ACL, and shortcut content after collision check';EvidenceStatus='needs-evidence'};Write-Log 'dry-run' 'pass' $x;$x}
  'Apply'{$st=Load-State;if(Test-Removed $st){Assert-Executable $st;Assert-Protected $st;if(!(Test-RemainingMatches $st)){throw 'Unrelated Startup-folder drift detected.'};Write-Log 'apply' 'idempotent' @{mutationCount=0};return};Assert-Executable $st;Assert-Protected $st;$live=Get-FileState ([string]$st.candidate.File.Path);if(!$live-or$live.Sha256-ne[string]$st.candidate.File.Sha256-or!(Test-RemainingMatches $st)){throw 'Candidate or unrelated Startup-folder drift detected.'};if($WhatIfPreference){Write-Log 'apply' 'whatif' @{mutationCount=0};return};if($PSCmdlet.ShouldProcess($live.Path,'Remove selected EXP-143 Startup-folder registration')){Remove-Item -LiteralPath $live.Path -Force}else{return};if(!(Test-Removed $st)-or!(Test-RemainingMatches $st)){throw 'Apply verification failed.'};Assert-Protected $st;Write-Log 'apply' 'pass' @{mutationCount=1;path=$live.Path}}
  'Verify'{$st=Load-State;if(!(Test-Removed $st)){throw 'Selected Startup-folder registration remains present.'};Assert-Executable $st;Assert-Protected $st;if(!(Test-RemainingMatches $st)){throw 'Unrelated Startup-folder drift detected.'};Write-Log 'verify' 'pass' @{removed=$true};$true}
  'VerifyReboot'{$st=Load-State;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot-le[datetime]$st.capturedBootTime){throw 'Later boot required.'};if(!(Test-Removed $st)){throw 'Treatment failed reboot persistence.'};Assert-Executable $st;Assert-Protected $st;if(!(Test-RemainingMatches $st)){throw 'Unrelated Startup-folder drift detected after reboot.'};Write-Log 'verify-reboot' 'pass' @{boot=$boot.ToString('o');evidenceStatus='needs-evidence'};$true}
  'Rollback'{$st=Load-State;Assert-Executable $st;Assert-Protected $st;if(!(Test-RemainingMatches $st)){throw 'Rollback refused on unrelated Startup-folder drift.'};if(!(Test-Removed $st)){if((Get-HashFile ([string]$st.candidate.File.Path))-eq[string]$st.candidate.File.Sha256){Write-Log 'rollback' 'idempotent' @{mutationCount=0};return};throw 'Rollback conflicting-path overwrite refused.'};if($WhatIfPreference){Write-Log 'rollback' 'whatif' @{mutationCount=0};return};if($PSCmdlet.ShouldProcess([string]$st.candidate.File.Path,'Restore exact captured Startup-folder registration')){Restore-Exact $st}else{return};$after=Get-FileState ([string]$st.candidate.File.Path);if(!$after-or$after.Sha256-ne[string]$st.candidate.File.Sha256-or$after.Owner-ne[string]$st.candidate.File.Owner-or$after.AclSddl-ne[string]$st.candidate.File.AclSddl-or!(Test-Same $after.Shortcut $st.candidate.File.Shortcut)-or!(Test-RemainingMatches $st)){throw 'Exact rollback verification failed.'};Assert-Protected $st;Write-Log 'rollback' 'pass' @{mutationCount=1;restoredExactOriginal=$true;sha256=$after.Sha256};$after}
 }
}catch{Write-Log 'failure' 'failure' @{stage=$Action;message=$_.Exception.Message;type=$_.Exception.GetType().FullName;evidenceStatus='needs-evidence'};throw}
