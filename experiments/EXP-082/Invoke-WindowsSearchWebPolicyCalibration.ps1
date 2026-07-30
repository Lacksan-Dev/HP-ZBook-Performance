[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
  [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
  [string]$StatePath=(Join-Path $PSScriptRoot 'state.json'),
  [string]$LogPath=(Join-Path $PSScriptRoot 'events.jsonl')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Experiment='EXP-082'
$script:PolicyPath='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
$script:Targets=[ordered]@{DisableWebSearch=[ordered]@{Kind='DWord';Value=1};ConnectedSearchUseWeb=[ordered]@{Kind='DWord';Value=0}}
$script:Protected=@('omnissa','windows app','remote desktop','mstsc','tailscale','defender','firewall','bitlocker','credential guard','vbs','windows update','recovery','credential','accessibility')
function Write-ExpLog([string]$Event,[string]$Result,[hashtable]$Data=@{}){
  $p=Split-Path -Parent $LogPath;if($p-and!(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
  [ordered]@{timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$script:Experiment;action=$Action;event=$Event;result=$Result;data=$Data}|ConvertTo-Json -Compress -Depth 12|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Test-IsElevated{$i=[Security.Principal.WindowsIdentity]::GetCurrent();([Security.Principal.WindowsPrincipal]::new($i)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Get-SupportState{
  $o=Get-CimInstance Win32_OperatingSystem;$c=Get-CimInstance Win32_ComputerSystem
  $edition=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).EditionID
  $build=[int]$o.BuildNumber;$supportedEdition=$edition-match'^(Professional|ProfessionalN|Enterprise|EnterpriseN|Education|EducationN|IoTEnterprise)$'
  [pscustomobject]@{Supported=($o.Caption-match'Windows 11'-and$build-ge 22000-and$supportedEdition);OS=$o.Caption;Build=$build;Edition=$edition;Manufacturer=$c.Manufacturer;Model=$c.Model;Elevated=Test-IsElevated}
}
function Test-EnterpriseManaged{
  $c=Get-CimInstance Win32_ComputerSystem
  $signals=[ordered]@{DomainJoined=[bool]$c.PartOfDomain;MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count;PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device';ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)}
  [pscustomobject]@{Managed=($signals.DomainJoined-or$signals.MdmEnrollments-gt 0-or$signals.PolicyManager-or$signals.ConfigMgr);Signals=$signals}
}
function Get-ValueState([string]$Name){
  if(!(Test-Path -LiteralPath $script:PolicyPath)){return [pscustomobject]@{Name=$Name;Exists=$false;Kind=$null;Value=$null}}
  $k=Get-Item -LiteralPath $script:PolicyPath
  if(!($k.GetValueNames()-contains$Name)){return [pscustomobject]@{Name=$Name;Exists=$false;Kind=$null;Value=$null}}
  [pscustomobject]@{Name=$Name;Exists=$true;Kind=$k.GetValueKind($Name).ToString();Value=$k.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
}
function Get-CurrentState{
  $values=@();foreach($name in $script:Targets.Keys){$values+=Get-ValueState $name}
  [pscustomobject]@{KeyExists=Test-Path -LiteralPath $script:PolicyPath;Values=$values}
}
function Assert-Unconfigured($Current){foreach($v in $Current.Values){if($v.Exists){throw"Existing configured Windows Search policy '$($v.Name)' requires owner review."}}}
function Save-State($Current){
  Assert-Unconfigured $Current
  $s=[ordered]@{schemaVersion=1;experiment=$script:Experiment;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;policyPath=$script:PolicyPath;keyExisted=[bool]$Current.KeyExists;values=@($Current.Values)}
  $p=Split-Path -Parent $StatePath;if($p-and!(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null};$s|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $StatePath -Encoding UTF8;$s
}
function Read-State{if(!(Test-Path -LiteralPath $StatePath)){throw"State file missing: $StatePath"};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;if($s.schemaVersion-ne 1-or$s.experiment-ne$script:Experiment-or$s.machine-ne$env:COMPUTERNAME-or$s.policyPath-ne$script:PolicyPath){throw'State identity validation failed.'};$s}
function Test-Applied{
  if(!(Test-Path -LiteralPath $script:PolicyPath)){return $false};$k=Get-Item -LiteralPath $script:PolicyPath
  foreach($name in $script:Targets.Keys){if(!($k.GetValueNames()-contains$name)){return $false};if($k.GetValueKind($name).ToString()-ne'DWord'){return $false};if([int]$k.GetValue($name)-ne[int]$script:Targets[$name].Value){return $false}}
  $true
}
function Assert-AppliedIdentity{if(!(Test-Applied)){throw'Applied policy state differs from the experiment target.'}}
function Test-Restored($S){
  foreach($v in $S.values){$cur=Get-ValueState ([string]$v.Name);if([bool]$v.Exists-ne[bool]$cur.Exists){return $false};if($v.Exists-and(($v.Kind-ne$cur.Kind)-or([string]$v.Value-ne[string]$cur.Value))){return $false}}
  if(!$S.keyExisted-and(Test-Path -LiteralPath $script:PolicyPath)){if(@((Get-Item -LiteralPath $script:PolicyPath).GetValueNames()).Count-eq 0-and@(Get-ChildItem -LiteralPath $script:PolicyPath).Count-eq 0){return $false}}
  $true
}
try{
  $sup=Get-SupportState;Write-ExpLog support-detection $(if($sup.Supported-and$sup.Elevated){'pass'}else{'unsupported'}) @{os=$sup.OS;build=$sup.Build;edition=$sup.Edition;manufacturer=$sup.Manufacturer;model=$sup.Model;elevated=$sup.Elevated};if(!$sup.Supported){throw'EXP-082 requires a supported Windows 11 edition and build.'};if(!$sup.Elevated){throw'Elevation is required.'}
  $m=Test-EnterpriseManaged;Write-ExpLog enterprise-management-detection $(if($m.Managed){'refused'}else{'pass'}) @{signals=$m.Signals};if($m.Managed){throw'Enterprise-management signals are present; mutation is refused.'}
  switch($Action){
    'Check'{$c=Get-CurrentState;Write-ExpLog policy-inventory pass @{keyExists=$c.KeyExists;values=$c.Values};$c}
    'Capture'{$s=Save-State (Get-CurrentState);Write-ExpLog state-capture pass @{policyPath=$s.policyPath;keyExisted=$s.keyExisted};$s}
    'DryRun'{$c=Get-CurrentState;Assert-Unconfigured $c;Write-ExpLog dry-run pass @{policyPath=$script:PolicyPath;targets=$script:Targets};[pscustomobject]@{WouldSet=$script:Targets;PolicyPath=$script:PolicyPath;StatePath=$StatePath}}
    'Apply'{$s=if(Test-Path -LiteralPath $StatePath){Read-State}else{Save-State (Get-CurrentState)};if(Test-Applied){Write-ExpLog apply idempotent @{policyPath=$script:PolicyPath};break};Assert-Unconfigured (Get-CurrentState);if($PSCmdlet.ShouldProcess($script:PolicyPath,'Set Windows Search web-result policies atomically')){if(!(Test-Path -LiteralPath $script:PolicyPath)){New-Item -Path $script:PolicyPath -Force|Out-Null};foreach($name in $script:Targets.Keys){New-ItemProperty -LiteralPath $script:PolicyPath -Name $name -Value $script:Targets[$name].Value -PropertyType DWord -Force|Out-Null}};Assert-AppliedIdentity;Write-ExpLog apply pass @{policyPath=$script:PolicyPath;targets=$script:Targets};$true}
    'Verify'{Read-State|Out-Null;Assert-AppliedIdentity;Write-ExpLog verify pass @{searchUiRestartRequired=$true};$true}
    'VerifyReboot'{$s=Read-State;Assert-AppliedIdentity;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime;Write-ExpLog verify-reboot pass @{bootTime=$boot;searchUiRestartRequired=$false};$true}
    'Rollback'{$s=Read-State;Assert-AppliedIdentity;if($PSCmdlet.ShouldProcess($script:PolicyPath,'Restore exact Windows Search policy state')){foreach($v in $s.values){if($v.Exists){New-ItemProperty -LiteralPath $script:PolicyPath -Name $v.Name -Value $v.Value -PropertyType $v.Kind -Force|Out-Null}else{Remove-ItemProperty -LiteralPath $script:PolicyPath -Name $v.Name -ErrorAction SilentlyContinue}};if(!$s.keyExisted-and(Test-Path -LiteralPath $script:PolicyPath)){if(@((Get-Item -LiteralPath $script:PolicyPath).GetValueNames()).Count-eq 0-and@(Get-ChildItem -LiteralPath $script:PolicyPath).Count-eq 0){Remove-Item -LiteralPath $script:PolicyPath -Force}}};if(!(Test-Restored $s)){throw'Rollback verification failed.'};Write-ExpLog rollback pass @{policyPath=$script:PolicyPath};$true}
  }
}catch{Write-ExpLog failure fail @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName};throw}
