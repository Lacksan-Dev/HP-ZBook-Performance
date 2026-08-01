[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
 [string]$StatePath,
 [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-107'
$provider='logitech-runonce-demand-launch'
$runOncePaths=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce')
$protected='(?i)omnissa|vmware horizon|windows app|remote desktop|mstsc|tailscale|securityhealth|defender|credential|bitlocker|firewall|windows update|recovery|intune|sccm|configmgr|mdm|firmware|dfu|driver|pair|receiver|uninstall|repair|setup'

function Write-Log([string]$Event,[string]$Result,[object]$Data){
 if([string]::IsNullOrWhiteSpace($LogPath)){return}
 $p=Split-Path -Parent $LogPath;if($p -and !(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
 [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;provider=$provider;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 18|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-Hash([string]$Text){$s=[Security.Cryptography.SHA256]::Create();try{($s.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))|ForEach-Object{$_.ToString('x2')})-join''}finally{$s.Dispose()}}
function Test-Elevated{$p=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent();$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Get-ManagementState{
 $c=Get-CimInstance Win32_ComputerSystem
 $signals=[ordered]@{DomainJoined=[bool]$c.PartOfDomain;MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count;PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device';ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue);RunPolicy=(Test-Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run')}
 [pscustomobject]@{Managed=($signals.DomainJoined -or $signals.MdmEnrollments -gt 0 -or $signals.PolicyManager -or $signals.ConfigMgr -or $signals.RunPolicy);Signals=$signals}
}
function Get-SupportState{
 $o=Get-CimInstance Win32_OperatingSystem;$c=Get-CimInstance Win32_ComputerSystem;$m=Get-ManagementState
 [pscustomobject]@{Supported=($o.Caption -match 'Windows 11');OS=$o.Caption;Build=$o.BuildNumber;Manufacturer=$c.Manufacturer;Model=$c.Model;Elevated=(Test-Elevated);Managed=$m.Managed;ManagementSignals=$m.Signals}
}
function Get-ProtectedSnapshot{
 $services=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale'){ $x=Get-Service $n -ErrorAction SilentlyContinue;if($x){[ordered]@{Name=$x.Name;Status=$x.Status.ToString();StartType=$x.StartType.ToString()}}}
 $processes=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName -match '(?i)omnissa|vmware|mstsc|tailscale|windowsapp'}|ForEach-Object{$_.ProcessName}|Sort-Object -Unique)
 $j=[ordered]@{Services=@($services);ProtectedProcesses=$processes}|ConvertTo-Json -Compress -Depth 8;[pscustomobject]@{Hash=Get-Hash $j;Snapshot=$j}
}
function Resolve-Command([string]$Command){
 $expanded=[Environment]::ExpandEnvironmentVariables($Command).Trim();if($expanded -match $protected){return $null}
 $exe=$null;$args=''
 if($expanded -match '^\s*"(?<exe>[^"]+\.exe)"\s*(?<args>.*)$'){$exe=$matches.exe;$args=$matches.args}elseif($expanded -match '^\s*(?<exe>\S+\.exe)\s*(?<args>.*)$'){$exe=$matches.exe;$args=$matches.args}else{return $null}
 try{$exe=[IO.Path]::GetFullPath($exe)}catch{return $null}
 if($exe -notmatch '(?i)\\Logi(?:tech)?\\|\\LGHUB\\|\\LogiOptionsPlus\\|\\LogiTune\\|\\LogiBolt\\'){return $null}
 [pscustomobject]@{ExpandedCommand=$expanded;Executable=$exe;Arguments=$args.Trim()}
}
function Get-FileIdentity([string]$Path){
 if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return $null};$i=Get-Item -LiteralPath $Path;$s=Get-AuthenticodeSignature -LiteralPath $Path;$publisher=if($s.SignerCertificate){$s.SignerCertificate.Subject}else{$null}
 [pscustomobject]@{Path=$i.FullName;Sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash;FileVersion=$i.VersionInfo.FileVersion;ProductName=$i.VersionInfo.ProductName;CompanyName=$i.VersionInfo.CompanyName;SignatureStatus=$s.Status.ToString();Publisher=$publisher;Thumbprint=if($s.SignerCertificate){$s.SignerCertificate.Thumbprint}else{$null};ValidLogitechPublisher=($s.Status -eq 'Valid' -and $publisher -match '(?i)Logitech|Logi')}
}
function Get-ProductIdentity([object]$File){
 $name=[string]$File.ProductName;$path=[string]$File.Path
 $family=if("$name $path" -match '(?i)G HUB|LGHUB'){'G Hub'}elseif("$name $path" -match '(?i)Options\+'){'Logi Options+'}elseif("$name $path" -match '(?i)Logi Tune|LogiTune'){'Logi Tune'}elseif("$name $path" -match '(?i)Logi Bolt|LogiBolt'){'Logi Bolt'}else{'Other Logitech'}
 [pscustomobject]@{Family=$family;ProductName=$name;Version=$File.FileVersion}
}
function Get-Candidates{
 $out=@()
 foreach($path in $runOncePaths){
  if(!(Test-Path -LiteralPath $path)){continue};$k=Get-Item -LiteralPath $path;$acl=Get-Acl -LiteralPath $path
  foreach($name in $k.GetValueNames()){
   if($name.StartsWith('!') -or $name.StartsWith('*')){continue}
   $data=[string]$k.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$r=Resolve-Command $data;if(!$r){continue};$file=Get-FileIdentity $r.Executable;if(!$file -or !$file.ValidLogitechPublisher){continue};$product=Get-ProductIdentity $file
   $out+=[pscustomobject]@{Path=$path;Hive=if($path -like 'HKLM:*'){'HKLM'}else{'HKCU'};Name=$name;Kind=$k.GetValueKind($name).ToString();Data=$data;ExpandedCommand=$r.ExpandedCommand;Arguments=$r.Arguments;Executable=$file;Product=$product;KeyOwner=$acl.Owner;KeySddl=$acl.Sddl}
  }
 }
 @($out)
}
function Assert-Eligible($Support,[object[]]$Candidates){
 if(!$Support.Supported){throw 'Windows 11 is required.'};if($Support.Managed){throw 'Enterprise-management ownership detected.'};if($Candidates.Count -ne 1){throw "Exactly one eligible Logitech RunOnce registration is required; found $($Candidates.Count)."};if($Candidates[0].Hive -eq 'HKLM' -and !$Support.Elevated){throw 'Elevation is required for HKLM RunOnce.'}
}
function Save-State($Support,[object[]]$Candidates){
 Assert-Eligible $Support $Candidates;if([string]::IsNullOrWhiteSpace($StatePath)){throw 'StatePath is required.'};if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused.'};$p=Get-ProtectedSnapshot;$state=[ordered]@{schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;support=$Support;protectedScopeHash=$p.Hash;entry=$Candidates[0]};$parent=Split-Path -Parent $StatePath;if($parent -and !(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$state|ConvertTo-Json -Depth 18|Set-Content -LiteralPath $StatePath -Encoding UTF8;$state
}
function Read-State{if([string]::IsNullOrWhiteSpace($StatePath) -or !(Test-Path -LiteralPath $StatePath)){throw 'State artifact is missing.'};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;if($s.schemaVersion -ne 1 -or $s.experiment -ne $experiment -or $s.provider -ne $provider -or $s.machine -ne $env:COMPUTERNAME -or $s.userSid -ne $sid){throw 'State identity validation failed.'};$s}
function Test-Removed($State){if(!(Test-Path -LiteralPath $State.entry.Path)){return $true};!((Get-Item -LiteralPath $State.entry.Path).GetValueNames() -contains [string]$State.entry.Name)}
function Test-Restored($State){if(!(Test-Path -LiteralPath $State.entry.Path)){return $false};$k=Get-Item -LiteralPath $State.entry.Path;if(!($k.GetValueNames() -contains [string]$State.entry.Name)){return $false};$data=[string]$k.GetValue($State.entry.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$data -eq [string]$State.entry.Data -and $k.GetValueKind($State.entry.Name).ToString() -eq [string]$State.entry.Kind}
function Assert-Executable($State){$f=Get-FileIdentity ([string]$State.entry.Executable.Path);if(!$f -or !$f.ValidLogitechPublisher -or $f.Sha256 -ne [string]$State.entry.Executable.Sha256 -or $f.Thumbprint -ne [string]$State.entry.Executable.Thumbprint -or $f.FileVersion -ne [string]$State.entry.Executable.FileVersion){throw 'Logitech executable identity drift detected.'}}
function Assert-Product($State){$f=Get-FileIdentity ([string]$State.entry.Executable.Path);$p=Get-ProductIdentity $f;if($p.Family -ne [string]$State.entry.Product.Family -or $p.Version -ne [string]$State.entry.Product.Version){throw 'Logitech product identity drift detected.'}}
try{
 $support=Get-SupportState;Write-Log 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) @{OS=$support.OS;Build=$support.Build;Managed=$support.Managed;Elevated=$support.Elevated}
 switch($Action){
  'Check'{$c=Get-Candidates;Write-Log 'candidate-inventory' 'pass' @{count=$c.Count;names=@($c.Name);products=@($c.Product.Family)};[pscustomobject]@{Support=$support;Candidates=$c;Profile='LogitechRunOnceDemandLaunch'}}
  'Capture'{$s=Save-State $support (Get-Candidates);Write-Log 'capture' 'pass' @{path=$s.entry.Path;name=$s.entry.Name;product=$s.entry.Product.Family};$s}
  'DryRun'{$c=Get-Candidates;Assert-Eligible $support $c;$r=[pscustomobject]@{Profile='LogitechRunOnceDemandLaunch';WouldChange=$true;MutationCount=1;Path=$c[0].Path;Name=$c[0].Name;Product=$c[0].Product.Family;PreserveInstallation=$true;PreserveServices=$true;PreserveTasks=$true;PreserveDrivers=$true;RebootPersistenceCheckRequired=$true;OneShotConsumptionEvidenceRequired=$true;Rollback='Restore exact captured hive, path, value name, type, and unexpanded data.'};Write-Log 'dry-run' 'pass' $r;$r}
  'Apply'{$s=if(Test-Path -LiteralPath $StatePath){Read-State}else{Save-State $support (Get-Candidates)};if(Test-Removed $s){Assert-Executable $s;Assert-Product $s;Write-Log 'apply' 'idempotent' @{mutationCount=0};return [pscustomobject]@{Applied=$true;MutationCount=0}};Assert-Eligible $support (Get-Candidates);Assert-Executable $s;Assert-Product $s;if((Get-ProtectedSnapshot).Hash -ne [string]$s.protectedScopeHash){throw 'Protected-scope drift detected.'};if($WhatIfPreference){Write-Log 'apply' 'whatif' @{mutationCount=0};return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$($s.entry.Path)::$($s.entry.Name)",'Remove exact Logitech RunOnce registration')){Remove-ItemProperty -LiteralPath $s.entry.Path -Name $s.entry.Name};if(!(Test-Removed $s)){throw 'Apply verification failed.'};Write-Log 'apply' 'pass' @{mutationCount=1;oneShotAttribution='needs-evidence'};[pscustomobject]@{Applied=$true;MutationCount=1;NeedsEvidence='Controlled sign-in attribution, peripheral readiness, and protected-application readiness'}}
  'Verify'{$s=Read-State;if(!(Test-Removed $s)){throw 'Immediate verification failed.'};Assert-Executable $s;Assert-Product $s;Write-Log 'verify' 'pass' @{removed=$true;oneShotAttribution='needs-evidence'};$true}
  'VerifyReboot'{$s=Read-State;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot -le [datetime]$s.capturedBootTime){throw 'A later boot is required.'};if(!(Test-Removed $s)){throw 'Reboot persistence failed.'};Assert-Executable $s;Assert-Product $s;Write-Log 'verify-reboot' 'pass' @{bootTime=$boot.ToString('o');oneShotAttribution='needs-evidence'};$true}
  'Rollback'{$s=Read-State;if(!(Test-Removed $s)){if(Test-Restored $s){Write-Log 'rollback' 'idempotent' @{mutationCount=0};return [pscustomobject]@{RolledBack=$true;MutationCount=0}};throw 'Rollback overwrite refused.'};$m=Get-ManagementState;if($m.Managed){throw 'Enterprise-management ownership appeared.'};Assert-Executable $s;Assert-Product $s;if((Get-ProtectedSnapshot).Hash -ne [string]$s.protectedScopeHash){throw 'Protected-scope drift detected.'};if($WhatIfPreference){Write-Log 'rollback' 'whatif' @{mutationCount=0};return [pscustomobject]@{RolledBack=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$($s.entry.Path)::$($s.entry.Name)",'Restore exact Logitech RunOnce registration')){if(!(Test-Path -LiteralPath $s.entry.Path)){New-Item -Path $s.entry.Path -Force|Out-Null};(Get-Item -LiteralPath $s.entry.Path).SetValue([string]$s.entry.Name,[string]$s.entry.Data,[Microsoft.Win32.RegistryValueKind]::$($s.entry.Kind))};if(!(Test-Restored $s)){throw 'Exact rollback verification failed.'};Write-Log 'rollback' 'pass' @{mutationCount=1;restoredExactOriginal=$true;postRollbackSignIn='needs-evidence'};[pscustomobject]@{RolledBack=$true;MutationCount=1;NeedsEvidence='Controlled post-rollback sign-in to distinguish normal RunOnce consumption from rollback correctness'}}
 }
}catch{Write-Log 'failure' 'fail' @{stage=$Action;message=$_.Exception.Message};throw}
