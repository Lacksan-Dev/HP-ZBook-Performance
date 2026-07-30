[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
  [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
  [string]$StatePath=(Join-Path $PSScriptRoot 'state.json'),
  [string]$LogPath=(Join-Path $PSScriptRoot 'events.jsonl')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Experiment='EXP-083'
$script:PolicyPath='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
$script:ValueName='EnableDynamicContentInWSB'
$script:TargetValue=0
$script:Protected=@('omnissa','windows app','remote desktop','mstsc','tailscale','defender','firewall','bitlocker','credential guard','vbs','windows update','recovery','credential','accessibility')
function Write-ExpLog([string]$Event,[string]$Result,[hashtable]$Data=@{}){
  $p=Split-Path -Parent $LogPath;if($p-and!(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
  [ordered]@{timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$script:Experiment;action=$Action;event=$Event;result=$Result;data=$Data}|ConvertTo-Json -Compress -Depth 12|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Test-IsElevated{$i=[Security.Principal.WindowsIdentity]::GetCurrent();([Security.Principal.WindowsPrincipal]::new($i)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Get-SupportState{
  $o=Get-CimInstance Win32_OperatingSystem;$c=Get-CimInstance Win32_ComputerSystem
  $cv=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
  $edition=[string]$cv.EditionID;$build=[int]$o.BuildNumber
  $supportedEdition=$edition-match'^(Professional|ProfessionalN|Enterprise|EnterpriseN|Education|EducationN|IoTEnterprise)$'
  [pscustomobject]@{Supported=($o.Caption-match'Windows 11'-and$build-ge 22000-and$supportedEdition);OS=$o.Caption;Build=$build;Edition=$edition;Manufacturer=$c.Manufacturer;Model=$c.Model;Elevated=Test-IsElevated}
}
function Test-EnterpriseManaged{
  $c=Get-CimInstance Win32_ComputerSystem
  $signals=[ordered]@{DomainJoined=[bool]$c.PartOfDomain;MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count;PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device';ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)}
  [pscustomobject]@{Managed=($signals.DomainJoined-or$signals.MdmEnrollments-gt 0-or$signals.PolicyManager-or$signals.ConfigMgr);Signals=$signals}
}
function Get-CurrentState{
  if(!(Test-Path -LiteralPath $script:PolicyPath)){return [pscustomobject]@{KeyExists=$false;ValueExists=$false;Kind=$null;Value=$null}}
  $k=Get-Item -LiteralPath $script:PolicyPath
  if(!($k.GetValueNames()-contains$script:ValueName)){return [pscustomobject]@{KeyExists=$true;ValueExists=$false;Kind=$null;Value=$null}}
  [pscustomobject]@{KeyExists=$true;ValueExists=$true;Kind=$k.GetValueKind($script:ValueName).ToString();Value=$k.GetValue($script:ValueName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
}
function Assert-SafeCurrent($Current){if($Current.ValueExists){if($Current.Kind-ne'DWord'){throw'Existing policy value has an unexpected registry type.'};throw'Existing Search highlights policy requires owner review.'}}
function Save-State($Current){
  Assert-SafeCurrent $Current
  $s=[ordered]@{schemaVersion=1;experiment=$script:Experiment;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;policyPath=$script:PolicyPath;valueName=$script:ValueName;keyExisted=[bool]$Current.KeyExists;valueExisted=[bool]$Current.ValueExists;kind=$Current.Kind;value=$Current.Value}
  $p=Split-Path -Parent $StatePath;if($p-and!(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null};$s|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $StatePath -Encoding UTF8;$s
}
function Read-State{if(!(Test-Path -LiteralPath $StatePath)){throw"State file missing: $StatePath"};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;if($s.schemaVersion-ne 1-or$s.experiment-ne$script:Experiment-or$s.machine-ne$env:COMPUTERNAME-or$s.policyPath-ne$script:PolicyPath-or$s.valueName-ne$script:ValueName){throw'State identity validation failed.'};$s}
function Test-Applied{if(!(Test-Path -LiteralPath $script:PolicyPath)){return $false};$k=Get-Item -LiteralPath $script:PolicyPath;if(!($k.GetValueNames()-contains$script:ValueName)){return $false};($k.GetValueKind($script:ValueName).ToString()-eq'DWord'-and[int]$k.GetValue($script:ValueName)-eq$script:TargetValue)}
function Assert-AppliedIdentity{if(!(Test-Applied)){throw'Applied policy state differs from the experiment target.'}}
function Test-Restored($S){$c=Get-CurrentState;if([bool]$S.valueExisted-ne[bool]$c.ValueExists){return $false};if($S.valueExisted-and(($S.kind-ne$c.Kind)-or([string]$S.value-ne[string]$c.Value))){return $false};if(!$S.keyExisted-and(Test-Path -LiteralPath $script:PolicyPath)){return $false};$true}
try{
  $sup=Get-SupportState;Write-ExpLog support-detection $(if($sup.Supported-and$sup.Elevated){'pass'}else{'unsupported'}) @{os=$sup.OS;build=$sup.Build;edition=$sup.Edition;manufacturer=$sup.Manufacturer;model=$sup.Model;elevated=$sup.Elevated};if(!$sup.Supported){throw'EXP-083 requires a supported Windows 11 edition and build.'};if(!$sup.Elevated){throw'Elevation is required.'}
  $m=Test-EnterpriseManaged;Write-ExpLog enterprise-management-detection $(if($m.Managed){'refused'}else{'pass'}) @{signals=$m.Signals};if($m.Managed){throw'Enterprise-management signals are present; mutation is refused.'}
  switch($Action){
    'Check'{$c=Get-CurrentState;Write-ExpLog policy-inventory pass @{keyExists=$c.KeyExists;valueExists=$c.ValueExists;kind=$c.Kind;value=$c.Value};$c}
    'Capture'{$s=Save-State (Get-CurrentState);Write-ExpLog state-capture pass @{policyPath=$s.policyPath;keyExisted=$s.keyExisted;valueExisted=$s.valueExisted};$s}
    'DryRun'{$c=Get-CurrentState;Assert-SafeCurrent $c;Write-ExpLog dry-run pass @{policyPath=$script:PolicyPath;valueName=$script:ValueName;target=$script:TargetValue};[pscustomobject]@{WouldSet=$script:ValueName;Value=$script:TargetValue;PolicyPath=$script:PolicyPath;StatePath=$StatePath}}
    'Apply'{$s=if(Test-Path -LiteralPath $StatePath){Read-State}else{Save-State (Get-CurrentState)};if(Test-Applied){Write-ExpLog apply idempotent @{policyPath=$script:PolicyPath;valueName=$script:ValueName};break};Assert-SafeCurrent (Get-CurrentState);if($PSCmdlet.ShouldProcess($script:PolicyPath,'Disable Windows Search highlights')){if(!(Test-Path -LiteralPath $script:PolicyPath)){New-Item -Path $script:PolicyPath -Force|Out-Null};New-ItemProperty -LiteralPath $script:PolicyPath -Name $script:ValueName -Value $script:TargetValue -PropertyType DWord -Force|Out-Null};Assert-AppliedIdentity;Write-ExpLog apply pass @{policyPath=$script:PolicyPath;valueName=$script:ValueName;value=$script:TargetValue};$true}
    'Verify'{Read-State|Out-Null;Assert-AppliedIdentity;Write-ExpLog verify pass @{searchUiRestartOrPolicyRefreshRequired=$true};$true}
    'VerifyReboot'{$s=Read-State;Assert-AppliedIdentity;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime;Write-ExpLog verify-reboot pass @{bootTime=$boot};$true}
    'Rollback'{$s=Read-State;Assert-AppliedIdentity;if($PSCmdlet.ShouldProcess($script:PolicyPath,'Restore exact Windows Search highlights policy state')){if($s.valueExisted){New-ItemProperty -LiteralPath $script:PolicyPath -Name $script:ValueName -Value $s.value -PropertyType $s.kind -Force|Out-Null}else{Remove-ItemProperty -LiteralPath $script:PolicyPath -Name $script:ValueName -ErrorAction SilentlyContinue};if(!$s.keyExisted-and(Test-Path -LiteralPath $script:PolicyPath)){if(@((Get-Item -LiteralPath $script:PolicyPath).GetValueNames()).Count-eq 0-and@(Get-ChildItem -LiteralPath $script:PolicyPath).Count-eq 0){Remove-Item -LiteralPath $script:PolicyPath -Force}}};if(!(Test-Restored $s)){throw'Rollback verification failed.'};Write-ExpLog rollback pass @{policyPath=$script:PolicyPath;valueName=$script:ValueName};$true}
  }
}catch{Write-ExpLog failure fail @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName};throw}
