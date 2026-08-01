[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
 [string]$StatePath,
 [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-092'
$provider='onedrive-demand-launch'
$runPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$oneDrivePolicyPaths=@('HKLM:\SOFTWARE\Policies\Microsoft\OneDrive','HKCU:\SOFTWARE\Policies\Microsoft\OneDrive')
$protected='(?i)omnissa|vmware horizon|windows app|remote desktop|mstsc|tailscale|securityhealth|defender|credential|bitlocker|firewall|windows update|recovery|intune|sccm|configmgr|mdm'

function Write-Log([string]$Event,[string]$Result,[object]$Data){
 if([string]::IsNullOrWhiteSpace($LogPath)){return}
 $p=Split-Path -Parent $LogPath;if($p -and !(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
 [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;provider=$provider;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 18|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-Hash([string]$Text){$s=[Security.Cryptography.SHA256]::Create();try{($s.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))|ForEach-Object{$_.ToString('x2')})-join''}finally{$s.Dispose()}}
function Get-ManagementState{
 $c=Get-CimInstance Win32_ComputerSystem
 $signals=[ordered]@{DomainJoined=[bool]$c.PartOfDomain;MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count;PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device';ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue);RunPolicy=(Test-Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run')}
 [pscustomobject]@{Managed=($signals.DomainJoined -or $signals.MdmEnrollments -gt 0 -or $signals.PolicyManager -or $signals.ConfigMgr -or $signals.RunPolicy);Signals=$signals}
}
function Get-OneDrivePolicyState{
 $names=@('KFMSilentOptIn','KFMOptInWithWizard','KFMSilentOptInWithNotification','KFMBlockOptIn','DisableFileSyncNGSC','FilesOnDemandEnabled','DisablePersonalSync','DisableLibrariesDefaultSaveToOneDrive')
 $items=@()
 foreach($path in $oneDrivePolicyPaths){
  if(!(Test-Path -LiteralPath $path)){continue};$k=Get-Item -LiteralPath $path
  foreach($n in $names){if($k.GetValueNames() -contains $n){$items+=[pscustomobject]@{Path=$path;Name=$n;Kind=$k.GetValueKind($n).ToString();Value=[string]$k.GetValue($n,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}}
 }
 $kfm=@($items|Where-Object{$_.Name -match '^KFM'});[pscustomobject]@{Entries=@($items);KfmEntries=@($kfm);PolicyOwned=($items.Count -gt 0)}
}
function Get-SupportState{
 $o=Get-CimInstance Win32_OperatingSystem;$c=Get-CimInstance Win32_ComputerSystem;$m=Get-ManagementState;$p=Get-OneDrivePolicyState
 [pscustomobject]@{Supported=($o.Caption -match 'Windows 11' -and $c.Manufacturer -match '(?i)^HP$|Hewlett-Packard');OS=$o.Caption;Build=$o.BuildNumber;Manufacturer=$c.Manufacturer;Model=$c.Model;Managed=$m.Managed;ManagementSignals=$m.Signals;OneDrivePolicy=$p}
}
function Get-ProtectedSnapshot{
 $s=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale'){ $x=Get-Service $n -ErrorAction SilentlyContinue;if($x){[ordered]@{Name=$x.Name;Status=$x.Status.ToString();StartType=$x.StartType.ToString()}}}
 $j=[ordered]@{Services=@($s)}|ConvertTo-Json -Compress -Depth 8;[pscustomobject]@{Hash=Get-Hash $j;Snapshot=$j}
}
function Resolve-Command([string]$Command){
 $e=[Environment]::ExpandEnvironmentVariables($Command).Trim();if($e -match $protected){return $null}
 $exe=$null;$args=''
 if($e -match '^\s*"(?<exe>[^"]+OneDrive\.exe)"\s*(?<args>.*)$'){$exe=$matches.exe;$args=$matches.args}elseif($e -match '^\s*(?<exe>\S+OneDrive\.exe)\s*(?<args>.*)$'){$exe=$matches.exe;$args=$matches.args}else{return $null}
 try{$exe=[IO.Path]::GetFullPath($exe)}catch{return $null}
 if($exe -notmatch '(?i)\\Microsoft OneDrive\\OneDrive\.exe$' -and $exe -notmatch '(?i)\\OneDrive\\OneDrive\.exe$'){return $null}
 if($args.Trim() -notmatch '(?i)^/background$'){return $null}
 [pscustomobject]@{ExpandedCommand=$e;Executable=$exe;Arguments=$args.Trim()}
}
function Get-FileIdentity([string]$Path){
 if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return $null};$i=Get-Item -LiteralPath $Path;$s=Get-AuthenticodeSignature -LiteralPath $Path;$p=if($s.SignerCertificate){$s.SignerCertificate.Subject}else{$null}
 [pscustomobject]@{Path=$i.FullName;Sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash;FileVersion=$i.VersionInfo.FileVersion;ProductName=$i.VersionInfo.ProductName;CompanyName=$i.VersionInfo.CompanyName;SignatureStatus=$s.Status.ToString();Publisher=$p;Thumbprint=if($s.SignerCertificate){$s.SignerCertificate.Thumbprint}else{$null};ValidMicrosoftPublisher=($s.Status -eq 'Valid' -and $p -match '(?i)Microsoft Corporation')}
}
function Get-OneDriveAccountState{
 $root='HKCU:\Software\Microsoft\OneDrive\Accounts';$accounts=@()
 if(Test-Path -LiteralPath $root){
  foreach($a in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue){
   $p=Get-ItemProperty -LiteralPath $a.PSPath -ErrorAction SilentlyContinue;$mount=$null
   foreach($n in 'UserFolder','MountPoint'){if($p.PSObject.Properties.Name -contains $n -and $p.$n){$mount=[string]$p.$n;break}}
   $fod=$null;if($p.PSObject.Properties.Name -contains 'FilesOnDemandEnabled'){$fod=[string]$p.FilesOnDemandEnabled}
   $accounts+=[pscustomobject]@{AccountKeyHash=Get-Hash $a.PSChildName;SyncRootHash=if($mount){Get-Hash $mount}else{$null};FilesOnDemandEnabled=$fod}
  }
 }
 $proc=@(Get-Process OneDrive -ErrorAction SilentlyContinue)
 [pscustomobject]@{AccountCount=$accounts.Count;Accounts=@($accounts);ProcessCount=$proc.Count;SyncHealth='needs-evidence';SensitiveIdentifiersCaptured=$false}
}
function Get-Candidates{
 if(!(Test-Path -LiteralPath $runPath)){return @()};$k=Get-Item -LiteralPath $runPath;$out=@()
 foreach($n in $k.GetValueNames()){
  if($n -notmatch '(?i)^OneDrive$|^Microsoft OneDrive$'){continue};$d=[string]$k.GetValue($n,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$r=Resolve-Command $d;if(!$r){continue};$id=Get-FileIdentity $r.Executable;if(!$id -or !$id.ValidMicrosoftPublisher){continue}
  $a=Get-Acl -LiteralPath $runPath;$out+=[pscustomobject]@{Path=$runPath;Name=$n;Kind=$k.GetValueKind($n).ToString();Data=$d;ExpandedCommand=$r.ExpandedCommand;Executable=$id;KeyOwner=$a.Owner;KeySddl=$a.Sddl}
 };@($out)
}
function Assert-Eligible($Support,[object[]]$Candidates,$AccountState){
 if(!$Support.Supported){throw 'HP Windows 11 is required.'};if($Support.Managed){throw 'Enterprise-management ownership detected.'};if($Support.OneDrivePolicy.PolicyOwned){throw 'OneDrive policy ownership detected.'};if($Support.OneDrivePolicy.KfmEntries.Count -gt 0){throw 'Known Folder Move policy detected.'};if($Candidates.Count -ne 1){throw "Exactly one eligible OneDrive Run registration is required; found $($Candidates.Count)."};if($AccountState.AccountCount -lt 1){throw 'At least one configured OneDrive account is required.'};if($AccountState.AccountCount -gt 1){throw 'Multiple OneDrive accounts require separate evidence before mutation.'}
}
function Save-State($Support,[object[]]$Candidates,$AccountState){
 Assert-Eligible $Support $Candidates $AccountState;if([string]::IsNullOrWhiteSpace($StatePath)){throw 'StatePath is required.'};if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused.'};$p=Get-ProtectedSnapshot;$s=[ordered]@{schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;support=$Support;protectedScopeHash=$p.Hash;accountState=$AccountState;entry=$Candidates[0]};$parent=Split-Path -Parent $StatePath;if($parent -and !(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$s|ConvertTo-Json -Depth 18|Set-Content -LiteralPath $StatePath -Encoding UTF8;$s
}
function Read-State{if([string]::IsNullOrWhiteSpace($StatePath) -or !(Test-Path -LiteralPath $StatePath)){throw 'State artifact is missing.'};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;if($s.schemaVersion -ne 1 -or $s.experiment -ne $experiment -or $s.provider -ne $provider -or $s.machine -ne $env:COMPUTERNAME -or $s.userSid -ne $sid){throw 'State identity validation failed.'};$s}
function Test-Removed($State){if(!(Test-Path -LiteralPath $State.entry.Path)){return $true};!((Get-Item -LiteralPath $State.entry.Path).GetValueNames() -contains [string]$State.entry.Name)}
function Assert-Executable($State){$e=Get-FileIdentity ([string]$State.entry.Executable.Path);if(!$e -or !$e.ValidMicrosoftPublisher -or $e.Sha256 -ne [string]$State.entry.Executable.Sha256 -or $e.Thumbprint -ne [string]$State.entry.Executable.Thumbprint){throw 'OneDrive executable identity drift detected.'}}
function Assert-AccountState($State){$a=Get-OneDriveAccountState;if($a.AccountCount -ne [int]$State.accountState.AccountCount){throw 'OneDrive account-count drift detected.'};$before=@($State.accountState.Accounts|ForEach-Object{$_.SyncRootHash}|Sort-Object);$after=@($a.Accounts|ForEach-Object{$_.SyncRootHash}|Sort-Object);if(($before -join ',') -ne ($after -join ',')){throw 'OneDrive sync-root drift detected.'}}
function Test-Restored($State){if(!(Test-Path -LiteralPath $State.entry.Path)){return $false};$k=Get-Item -LiteralPath $State.entry.Path;if(!($k.GetValueNames() -contains [string]$State.entry.Name)){return $false};$d=[string]$k.GetValue($State.entry.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$d -eq [string]$State.entry.Data -and $k.GetValueKind($State.entry.Name).ToString() -eq [string]$State.entry.Kind}
try{
 $support=Get-SupportState;Write-Log 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) @{OS=$support.OS;Build=$support.Build;Manufacturer=$support.Manufacturer;Model=$support.Model;Managed=$support.Managed;OneDrivePolicyOwned=$support.OneDrivePolicy.PolicyOwned}
 switch($Action){
  'Check'{$c=Get-Candidates;$a=Get-OneDriveAccountState;Write-Log 'candidate-inventory' 'pass' @{count=$c.Count;names=@($c.Name);accountCount=$a.AccountCount;syncHealth=$a.SyncHealth};[pscustomobject]@{Support=$support;Candidates=$c;AccountState=$a;Profile='OneDriveDemandLaunch'}}
  'Capture'{$a=Get-OneDriveAccountState;$s=Save-State $support (Get-Candidates) $a;Write-Log 'capture' 'pass' @{path=$s.entry.Path;name=$s.entry.Name;accountCount=$a.AccountCount;syncHealth=$a.SyncHealth};$s}
  'DryRun'{$c=Get-Candidates;$a=Get-OneDriveAccountState;Assert-Eligible $support $c $a;$r=[pscustomobject]@{Profile='OneDriveDemandLaunch';WouldChange=$true;MutationCount=1;Path=$c[0].Path;Name=$c[0].Name;PreserveInstallation=$true;PreserveSyncRoots=$true;PreserveFilesOnDemand=$true;PreserveShellIntegration=$true;SyncHealthEvidenceRequired=$true;RebootPersistenceCheckRequired=$true;Rollback='Restore exact captured value name, kind, and unexpanded data.'};Write-Log 'dry-run' 'pass' $r;$r}
  'Apply'{$a=Get-OneDriveAccountState;$s=if(Test-Path -LiteralPath $StatePath){Read-State}else{Save-State $support (Get-Candidates) $a};if(Test-Removed $s){Assert-Executable $s;Assert-AccountState $s;Write-Log 'apply' 'idempotent' @{mutationCount=0};return [pscustomobject]@{Applied=$true;MutationCount=0}};Assert-Eligible $support (Get-Candidates) $a;Assert-Executable $s;Assert-AccountState $s;if((Get-ProtectedSnapshot).Hash -ne [string]$s.protectedScopeHash){throw 'Protected-scope drift detected.'};if($WhatIfPreference){Write-Log 'apply' 'whatif' @{mutationCount=0};return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$($s.entry.Path)::$($s.entry.Name)",'Remove exact OneDrive background Run registration')){Remove-ItemProperty -LiteralPath $s.entry.Path -Name $s.entry.Name};if(!(Test-Removed $s)){throw 'Apply verification failed.'};Write-Log 'apply' 'pass' @{mutationCount=1;syncHealth='needs-evidence'};[pscustomobject]@{Applied=$true;MutationCount=1;NeedsEvidence='OneDrive sync health and controlled upload/download after manual launch'}}
  'Verify'{$s=Read-State;if(!(Test-Removed $s)){throw 'Immediate verification failed.'};Assert-Executable $s;Assert-AccountState $s;Write-Log 'verify' 'pass' @{removed=$true;syncHealth='needs-evidence'};$true}
  'VerifyReboot'{$s=Read-State;$b=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($b -le [datetime]$s.capturedBootTime){throw 'A later boot is required.'};if(!(Test-Removed $s)){throw 'Reboot persistence failed.'};Assert-Executable $s;Assert-AccountState $s;Write-Log 'verify-reboot' 'pass' @{bootTime=$b.ToString('o');syncHealth='needs-evidence'};$true}
  'Rollback'{$s=Read-State;if(!(Test-Removed $s)){if(Test-Restored $s){Write-Log 'rollback' 'idempotent' @{mutationCount=0};return [pscustomobject]@{RolledBack=$true;MutationCount=0}};throw 'Rollback overwrite refused.'};if($support.Managed -or $support.OneDrivePolicy.PolicyOwned){throw 'Management or OneDrive policy ownership appeared.'};Assert-Executable $s;Assert-AccountState $s;if((Get-ProtectedSnapshot).Hash -ne [string]$s.protectedScopeHash){throw 'Protected-scope drift detected.'};if($WhatIfPreference){Write-Log 'rollback' 'whatif' @{mutationCount=0};return [pscustomobject]@{RolledBack=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$($s.entry.Path)::$($s.entry.Name)",'Restore exact OneDrive Run registration')){if(!(Test-Path -LiteralPath $s.entry.Path)){New-Item -Path $s.entry.Path -Force|Out-Null};(Get-Item -LiteralPath $s.entry.Path).SetValue([string]$s.entry.Name,[string]$s.entry.Data,[Microsoft.Win32.RegistryValueKind]::$($s.entry.Kind))};if(!(Test-Restored $s)){throw 'Exact rollback verification failed.'};Write-Log 'rollback' 'pass' @{mutationCount=1;restoredExactOriginal=$true;syncHealth='needs-evidence'};[pscustomobject]@{RolledBack=$true;MutationCount=1;NeedsEvidence='Verify sign-in launch and OneDrive sync health after reboot'}}
 }
}catch{Write-Log 'failure' 'fail' @{stage=$Action;message=$_.Exception.Message};throw}
