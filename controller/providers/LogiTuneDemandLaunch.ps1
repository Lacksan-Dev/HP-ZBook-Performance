[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
 [string]$StatePath,
 [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-052'
$provider='logi-tune-demand-launch'
$runPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$protected='(?i)omnissa|vmware horizon|windows app|remote desktop|mstsc|tailscale|securityhealth|defender|credential|bitlocker|firewall|windows update|recovery|intune|sccm|configmgr|mdm'

function Write-Log([string]$Event,[string]$Result,[object]$Data){
 if([string]::IsNullOrWhiteSpace($LogPath)){return}
 $p=Split-Path -Parent $LogPath;if($p -and !(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
 [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;provider=$provider;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 16|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-Hash([string]$Text){$s=[Security.Cryptography.SHA256]::Create();try{($s.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))|ForEach-Object{$_.ToString('x2')})-join''}finally{$s.Dispose()}}
function Get-ManagementState{
 $c=Get-CimInstance Win32_ComputerSystem
 $signals=[ordered]@{DomainJoined=[bool]$c.PartOfDomain;MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count;PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device';ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue);RunPolicy=(Test-Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run')}
 [pscustomobject]@{Managed=($signals.DomainJoined -or $signals.MdmEnrollments -gt 0 -or $signals.PolicyManager -or $signals.ConfigMgr -or $signals.RunPolicy);Signals=$signals}
}
function Get-SupportState{
 $o=Get-CimInstance Win32_OperatingSystem;$c=Get-CimInstance Win32_ComputerSystem;$m=Get-ManagementState
 [pscustomobject]@{Supported=($o.Caption -match 'Windows 11' -and $c.Manufacturer -match '(?i)^HP$|Hewlett-Packard');OS=$o.Caption;Build=$o.BuildNumber;Manufacturer=$c.Manufacturer;Model=$c.Model;Managed=$m.Managed;ManagementSignals=$m.Signals}
}
function Get-ProtectedSnapshot{
 $s=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale'){ $x=Get-Service $n -ErrorAction SilentlyContinue;if($x){[ordered]@{Name=$x.Name;Status=$x.Status.ToString();StartType=$x.StartType.ToString()}}}
 $j=[ordered]@{Services=@($s)}|ConvertTo-Json -Compress -Depth 8;[pscustomobject]@{Hash=Get-Hash $j;Snapshot=$j}
}
function Resolve-Command([string]$Command){
 $e=[Environment]::ExpandEnvironmentVariables($Command).Trim();if($e -match $protected){return $null}
 $exe=$null;$args=''
 if($e -match '^\s*"(?<exe>[^"]+)"\s*(?<args>.*)$'){$exe=$matches.exe;$args=$matches.args}elseif($e -match '^\s*(?<exe>\S+\.exe)\s*(?<args>.*)$'){$exe=$matches.exe;$args=$matches.args}else{return $null}
 try{$exe=[IO.Path]::GetFullPath($exe)}catch{return $null}
 if($exe -notmatch '(?i)\\Logi(?:tech)?\\.*\\?(LogiTune|LogiTuneAgent|LogiTuneApp)\.exe$' -and $exe -notmatch '(?i)\\LogiTune\\.*\\?(LogiTune|LogiTuneAgent|LogiTuneApp)\.exe$'){return $null}
 if($exe -match '(?i)updat|uninstall|repair|firmware|dfu|pair'){return $null}
 if($args -and $args -notmatch '(?i)background|minimi[sz]ed|startup|tray|silent|autostart|^\s*$'){return $null}
 [pscustomobject]@{ExpandedCommand=$e;Executable=$exe;Arguments=$args}
}
function Get-FileIdentity([string]$Path){
 if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return $null};$i=Get-Item -LiteralPath $Path;$s=Get-AuthenticodeSignature -LiteralPath $Path;$p=if($s.SignerCertificate){$s.SignerCertificate.Subject}else{$null}
 [pscustomobject]@{Path=$i.FullName;Sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash;FileVersion=$i.VersionInfo.FileVersion;ProductName=$i.VersionInfo.ProductName;CompanyName=$i.VersionInfo.CompanyName;SignatureStatus=$s.Status.ToString();Publisher=$p;Thumbprint=if($s.SignerCertificate){$s.SignerCertificate.Thumbprint}else{$null};ValidLogitechPublisher=($s.Status -eq 'Valid' -and $p -match '(?i)Logitech|Logi')}
}
function Get-Candidates{
 if(!(Test-Path -LiteralPath $runPath)){return @()};$k=Get-Item -LiteralPath $runPath;$out=@()
 foreach($n in $k.GetValueNames()){
  if($n -notmatch '(?i)^logi(?:tech)?[ ._-]*tune$|^logitune$'){continue};$d=[string]$k.GetValue($n,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$r=Resolve-Command $d;if(!$r){continue};$id=Get-FileIdentity $r.Executable;if(!$id -or !$id.ValidLogitechPublisher){continue}
  $a=Get-Acl -LiteralPath $runPath;$out+=[pscustomobject]@{Path=$runPath;Name=$n;Kind=$k.GetValueKind($n).ToString();Data=$d;ExpandedCommand=$r.ExpandedCommand;Executable=$id;KeyOwner=$a.Owner;KeySddl=$a.Sddl}
 };@($out)
}
function Assert-Eligible($Support,[object[]]$Candidates){if(!$Support.Supported){throw 'HP Windows 11 is required.'};if($Support.Managed){throw 'Enterprise-management ownership detected.'};if($Candidates.Count -ne 1){throw "Exactly one eligible Logi Tune Run registration is required; found $($Candidates.Count)."}}
function Save-State($Support,[object[]]$Candidates){Assert-Eligible $Support $Candidates;if([string]::IsNullOrWhiteSpace($StatePath)){throw 'StatePath is required.'};if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused.'};$p=Get-ProtectedSnapshot;$s=[ordered]@{schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;support=$Support;protectedScopeHash=$p.Hash;entry=$Candidates[0]};$parent=Split-Path -Parent $StatePath;if($parent -and !(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$s|ConvertTo-Json -Depth 16|Set-Content -LiteralPath $StatePath -Encoding UTF8;$s}
function Read-State{if([string]::IsNullOrWhiteSpace($StatePath) -or !(Test-Path -LiteralPath $StatePath)){throw 'State artifact is missing.'};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;if($s.schemaVersion -ne 1 -or $s.experiment -ne $experiment -or $s.provider -ne $provider -or $s.machine -ne $env:COMPUTERNAME -or $s.userSid -ne $sid){throw 'State identity validation failed.'};$s}
function Test-Removed($State){if(!(Test-Path -LiteralPath $State.entry.Path)){return $true};!((Get-Item -LiteralPath $State.entry.Path).GetValueNames() -contains [string]$State.entry.Name)}
function Assert-Executable($State){$e=Get-FileIdentity ([string]$State.entry.Executable.Path);if(!$e -or !$e.ValidLogitechPublisher -or $e.Sha256 -ne [string]$State.entry.Executable.Sha256 -or $e.Thumbprint -ne [string]$State.entry.Executable.Thumbprint){throw 'Logi Tune executable identity drift detected.'}}
function Test-Restored($State){if(!(Test-Path -LiteralPath $State.entry.Path)){return $false};$k=Get-Item -LiteralPath $State.entry.Path;if(!($k.GetValueNames() -contains [string]$State.entry.Name)){return $false};$d=[string]$k.GetValue($State.entry.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$d -eq [string]$State.entry.Data -and $k.GetValueKind($State.entry.Name).ToString() -eq [string]$State.entry.Kind}
try{
 $support=Get-SupportState;Write-Log 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) $support
 switch($Action){
  'Check'{$c=Get-Candidates;Write-Log 'candidate-inventory' 'pass' @{count=$c.Count;names=@($c.Name)};[pscustomobject]@{Support=$support;Candidates=$c;Profile='LogiTuneDemandLaunch'}}
  'Capture'{$s=Save-State $support (Get-Candidates);Write-Log 'capture' 'pass' @{path=$s.entry.Path;name=$s.entry.Name};$s}
  'DryRun'{$c=Get-Candidates;Assert-Eligible $support $c;$r=[pscustomobject]@{Profile='LogiTuneDemandLaunch';WouldChange=$true;MutationCount=1;Path=$c[0].Path;Name=$c[0].Name;PreserveApplication=$true;PreserveDrivers=$true;PreserveAudioVideoDevices=$true;RebootPersistenceCheckRequired=$true;Rollback='Restore exact captured value name, kind, and unexpanded data.'};Write-Log 'dry-run' 'pass' $r;$r}
  'Apply'{$s=if(Test-Path -LiteralPath $StatePath){Read-State}else{Save-State $support (Get-Candidates)};if(Test-Removed $s){Assert-Executable $s;Write-Log 'apply' 'idempotent' @{mutationCount=0};return [pscustomobject]@{Applied=$true;MutationCount=0}};Assert-Eligible $support (Get-Candidates);Assert-Executable $s;if((Get-ProtectedSnapshot).Hash -ne [string]$s.protectedScopeHash){throw 'Protected-scope drift detected.'};if($WhatIfPreference){Write-Log 'apply' 'whatif' @{mutationCount=0};return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$($s.entry.Path)::$($s.entry.Name)",'Remove exact Logi Tune Run registration')){Remove-ItemProperty -LiteralPath $s.entry.Path -Name $s.entry.Name};if(!(Test-Removed $s)){throw 'Apply verification failed.'};Write-Log 'apply' 'pass' @{mutationCount=1};[pscustomobject]@{Applied=$true;MutationCount=1}}
  'Verify'{$s=Read-State;if(!(Test-Removed $s)){throw 'Immediate verification failed.'};Assert-Executable $s;Write-Log 'verify' 'pass' @{removed=$true};$true}
  'VerifyReboot'{$s=Read-State;$b=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($b -le [datetime]$s.capturedBootTime){throw 'A later boot is required.'};if(!(Test-Removed $s)){throw 'Reboot persistence failed.'};Assert-Executable $s;Write-Log 'verify-reboot' 'pass' @{bootTime=$b.ToString('o')};$true}
  'Rollback'{$s=Read-State;if(!(Test-Removed $s)){if(Test-Restored $s){Write-Log 'rollback' 'idempotent' @{mutationCount=0};return [pscustomobject]@{RolledBack=$true;MutationCount=0}};throw 'Rollback overwrite refused.'};if($support.Managed){throw 'Management ownership appeared.'};Assert-Executable $s;if((Get-ProtectedSnapshot).Hash -ne [string]$s.protectedScopeHash){throw 'Protected-scope drift detected.'};if($WhatIfPreference){Write-Log 'rollback' 'whatif' @{mutationCount=0};return [pscustomobject]@{RolledBack=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$($s.entry.Path)::$($s.entry.Name)",'Restore exact Logi Tune Run registration')){if(!(Test-Path -LiteralPath $s.entry.Path)){New-Item -Path $s.entry.Path -Force|Out-Null};(Get-Item -LiteralPath $s.entry.Path).SetValue([string]$s.entry.Name,[string]$s.entry.Data,[Microsoft.Win32.RegistryValueKind]::$($s.entry.Kind))};if(!(Test-Restored $s)){throw 'Exact rollback verification failed.'};Write-Log 'rollback' 'pass' @{mutationCount=1;restoredExactOriginal=$true};[pscustomobject]@{RolledBack=$true;MutationCount=1}}
 }
}catch{Write-Log 'failure' 'fail' @{stage=$Action;message=$_.Exception.Message};throw}
