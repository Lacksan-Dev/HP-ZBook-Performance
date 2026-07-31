[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param([ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',[string]$StatePath,[string]$LogPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-088';$provider='hp-support-assistant-quick-start-task'
function Write-Log($event,$result,$data){if(!$LogPath){return};$p=Split-Path $LogPath -Parent;if($p-and!(Test-Path $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null};[ordered]@{timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;provider=$provider;action=$Action;event=$event;result=$result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$data}|ConvertTo-Json -Compress -Depth 12|Add-Content -LiteralPath $LogPath -Encoding UTF8}
function Get-ManagementState{$cs=Get-CimInstance Win32_ComputerSystem;$s=[ordered]@{DomainJoined=[bool]$cs.PartOfDomain;MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count;PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device';ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)};[pscustomobject]@{Managed=($s.DomainJoined-or$s.MdmEnrollments-gt0-or$s.PolicyManager-or$s.ConfigMgr);Signals=$s}}
function Get-SupportState{$os=Get-CimInstance Win32_OperatingSystem;$cs=Get-CimInstance Win32_ComputerSystem;$m=Get-ManagementState;$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);[pscustomobject]@{Supported=($os.Caption-match'Windows 11'-and$cs.Manufacturer-match'(?i)^HP$|Hewlett-Packard');OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$cs.Manufacturer;Model=$cs.Model;Elevated=$admin;Managed=$m.Managed;ManagementSignals=$m.Signals}}
function Resolve-ActionPath($execute){$raw=[Environment]::ExpandEnvironmentVariables($execute.Trim('"'));if($raw-match'^"([^"]+)"'){return $matches[1]};if($raw-match'^([^ ]+\.exe)'){return $matches[1]};$raw}
function Get-Candidates{
 @(
  Get-ScheduledTask -ErrorAction Stop|ForEach-Object{
   $task=$_;$xml=Export-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath
   $actions=@($task.Actions);$triggers=@($task.Triggers)
   if($actions.Count-ne1){return}
   $exe=Resolve-ActionPath ([string]$actions[0].Execute)
   $nameText="$($task.TaskPath)$($task.TaskName) $($actions[0].Execute) $($actions[0].Arguments)"
   $quick=$nameText-match'(?i)HP.*(Support Assistant|Support Solutions|Quick Start)|Quick Start.*HP'
   $unsafe=$nameText-match'(?i)firmware|bios|driver|security|recovery|update service|windows update'
   $logon=@($triggers|Where-Object{$_.CimClass.CimClassName-match'LogonTrigger'}).Count-gt0
   if(!$quick-or$unsafe-or!$logon-or!(Test-Path -LiteralPath $exe -PathType Leaf)){return}
   $sig=Get-AuthenticodeSignature -LiteralPath $exe;$publisher=if($sig.SignerCertificate){$sig.SignerCertificate.Subject}else{$null}
   if($sig.Status-ne'Valid'-or$publisher-notmatch'(?i)HP Inc|Hewlett-Packard'){return}
   $info=Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $task.TaskPath
   [pscustomobject]@{TaskName=$task.TaskName;TaskPath=$task.TaskPath;Enabled=($task.State-ne'Disabled');State=[string]$task.State;Xml=$xml;XmlHash=([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::Unicode.GetBytes($xml))));Execute=$actions[0].Execute;Arguments=$actions[0].Arguments;ExecutablePath=$exe;ExecutableHash=(Get-FileHash $exe -Algorithm SHA256).Hash;Publisher=$publisher;Author=$task.Author;Principal=$task.Principal;Triggers=$triggers;Actions=$actions;Settings=$task.Settings;LastRunTime=$info.LastRunTime;LastTaskResult=$info.LastTaskResult;NextRunTime=$info.NextRunTime}
  }
 )
}
function Assert-Safe($s,$c){if(!$s.Elevated){throw'Elevation is required.'};if($s.Managed){throw'Enterprise-management signals are present; mutation is refused.'};if(@($c).Count-ne1){throw'Exactly one eligible HP Support Assistant Quick Start task is required.'};if(!$c.Enabled){throw'Candidate task is already disabled.'}}
function Save-State($s,$c){if(!$StatePath){throw'StatePath is required.'};$state=[ordered]@{schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;support=$s;task=$c};$p=Split-Path $StatePath -Parent;if($p-and!(Test-Path $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null};$state|ConvertTo-Json -Depth 20|Set-Content $StatePath -Encoding UTF8;$state}
function Read-State{if(!$StatePath-or!(Test-Path $StatePath)){throw'State file missing.'};$s=Get-Content $StatePath -Raw|ConvertFrom-Json;if($s.schemaVersion-ne1-or$s.experiment-ne$experiment-or$s.provider-ne$provider-or$s.machine-ne$env:COMPUTERNAME-or$s.userSid-ne[Security.Principal.WindowsIdentity]::GetCurrent().User.Value){throw'State identity validation failed.'};$s}
function Get-Current($s){$t=Get-ScheduledTask -TaskName $s.task.TaskName -TaskPath $s.task.TaskPath -ErrorAction Stop;$xml=Export-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath;$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::Unicode.GetBytes($xml)));[pscustomobject]@{Task=$t;Xml=$xml;XmlHash=$hash;Enabled=($t.State-ne'Disabled')}}
try{$support=Get-SupportState;Write-Log support-detection $(if($support.Supported){'pass'}else{'unsupported'}) $support;if(!$support.Supported){throw'Provider supports HP Windows 11 only.'};$candidates=Get-Candidates
 switch($Action){
 'Check'{[pscustomobject]@{Support=$support;Candidates=$candidates}}
 'Capture'{Assert-Safe $support $candidates;Save-State $support $candidates[0]}
 'DryRun'{Assert-Safe $support $candidates;$r=[pscustomobject]@{Provider=$provider;WouldChange=$true;TaskPath=$candidates[0].TaskPath;TaskName=$candidates[0].TaskName;Mutation='Disable only';RebootPersistenceCheckRequired=$true};Write-Log dry-run pass $r;$r}
 'Apply'{$state=if(Test-Path $StatePath){Read-State}else{Assert-Safe $support $candidates;Save-State $support $candidates[0]};$cur=Get-Current $state;if($cur.XmlHash-ne$state.task.XmlHash){throw'Task-definition drift detected.'};if(!$cur.Enabled){Write-Log apply idempotent @{changed=$false};return [pscustomobject]@{Applied=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$($state.task.TaskPath)$($state.task.TaskName)",'Disable scheduled task')){Disable-ScheduledTask -TaskName $state.task.TaskName -TaskPath $state.task.TaskPath|Out-Null};if((Get-Current $state).Enabled){throw'Apply verification failed.'};Write-Log apply pass @{changed=$true};[pscustomobject]@{Applied=$true;MutationCount=1}}
 'Verify'{$state=Read-State;$cur=Get-Current $state;if($cur.XmlHash-ne$state.task.XmlHash-or$cur.Enabled){throw'Verification failed.'};Write-Log verify pass @{disabled=$true};$true}
 'VerifyReboot'{$state=Read-State;$cur=Get-Current $state;if($cur.XmlHash-ne$state.task.XmlHash-or$cur.Enabled){throw'Reboot persistence verification failed.'};Write-Log verify-reboot pass @{bootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime};$true}
 'Rollback'{$state=Read-State;$cur=Get-Current $state;if($cur.XmlHash-ne$state.task.XmlHash){throw'Rollback refused because task definition drifted.'};if($state.task.Enabled-and!$cur.Enabled-and$PSCmdlet.ShouldProcess("$($state.task.TaskPath)$($state.task.TaskName)",'Restore enabled state')){Enable-ScheduledTask -TaskName $state.task.TaskName -TaskPath $state.task.TaskPath|Out-Null};$after=Get-Current $state;if($after.XmlHash-ne$state.task.XmlHash-or$after.Enabled-ne[bool]$state.task.Enabled){throw'Rollback verification failed.'};Write-Log rollback pass @{restoredExactXml=$true;restoredEnabled=$after.Enabled};[pscustomobject]@{RolledBack=$true;MutationCount=1}}
 }}catch{Write-Log failure fail @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName};throw}
