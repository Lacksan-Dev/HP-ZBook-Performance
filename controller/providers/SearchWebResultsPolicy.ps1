[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
  [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
  [string]$StatePath="$env:ProgramData\Lacksan\EXP-082-state.json",
  [string]$LogPath="$env:ProgramData\Lacksan\EXP-082.jsonl"
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Experiment='EXP-082'
$PolicyPath='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
$Treatment=[ordered]@{DisableWebSearch=1;ConnectedSearchUseWeb=0}

function Write-ExpLog([string]$Event,[string]$Result,$Data){
  $dir=Split-Path $LogPath -Parent
  if($dir -and !(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
  [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$Experiment;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 24|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Test-Elevated{([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Same($A,$B){($A|ConvertTo-Json -Compress -Depth 24)-eq($B|ConvertTo-Json -Compress -Depth 24)}
function Get-ValueState([string]$Name){
  $keyExists=Test-Path $PolicyPath
  if(!$keyExists){return [pscustomobject]@{Name=$Name;KeyExists=$false;ValueExists=$false;Kind=$null;Data=$null;Owner=$null;Sddl=$null}}
  $key=Get-Item $PolicyPath;$acl=Get-Acl $PolicyPath;$exists=$key.GetValueNames()-contains $Name
  [pscustomobject]@{Name=$Name;KeyExists=$true;ValueExists=$exists;Kind=$(if($exists){$key.GetValueKind($Name).ToString()}else{$null});Data=$(if($exists){$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}else{$null});Owner=$acl.Owner;Sddl=$acl.Sddl}
}
function Get-RegState{[pscustomobject]@{Path=$PolicyPath;DisableWebSearch=(Get-ValueState 'DisableWebSearch');ConnectedSearchUseWeb=(Get-ValueState 'ConnectedSearchUseWeb')}}
function Get-ManagementState{
  $cs=Get-CimInstance Win32_ComputerSystem
  $en=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName-match'^[0-9A-Fa-f-]{36}$'}).Count
  $om=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName-match'^[0-9A-Fa-f-]{36}$'}).Count
  $ccm=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
  [pscustomobject]@{Managed=([bool]$cs.PartOfDomain-or$ccm-or($en-gt0-and$om-gt0));DomainJoined=[bool]$cs.PartOfDomain;EnrollmentCount=$en;OmadmCount=$om;ConfigMgr=$ccm}
}
function Get-ProtectedState{
  $names=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale')
  $services=@($names|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name|Select-Object Name,State,StartMode,PathName)
  [pscustomobject]@{Services=$services}
}
function Get-Support{
  $os=Get-CimInstance Win32_OperatingSystem;$cs=Get-CimInstance Win32_ComputerSystem;$mgmt=Get-ManagementState;$reg=Get-RegState;$reasons=@()
  if($os.Caption-notmatch'Windows 11'){$reasons+='Windows 11 required'}
  if($os.Caption-notmatch'(?i)Pro|Enterprise|Education|IoT Enterprise'){$reasons+='supported Windows 11 edition required'}
  if(!(Test-Elevated)){$reasons+='elevation required'}
  if($mgmt.Managed){$reasons+='enterprise management ownership detected'}
  if($reg.DisableWebSearch.ValueExists-or$reg.ConnectedSearchUseWeb.ValueExists){$reasons+='existing Windows Search web policy ownership detected'}
  [pscustomobject]@{Supported=($reasons.Count-eq0);Reasons=$reasons;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$cs.Manufacturer;Model=$cs.Model;Elevated=(Test-Elevated);Management=$mgmt;Original=$reg;Protected=(Get-ProtectedState);EvidenceStatus='needs-evidence'}
}
function Save-State($Support){
  if(Test-Path $StatePath){throw 'State overwrite refused.'}
  $dir=Split-Path $StatePath -Parent;if($dir-and!(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
  $state=[ordered]@{schemaVersion=1;experiment=$Experiment;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;support=$Support;original=$Support.Original;protected=$Support.Protected;evidenceStatus='needs-evidence'}
  $state|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $StatePath -Encoding UTF8
  $state
}
function Load-State{
  if(!(Test-Path $StatePath)){throw 'Captured state required.'}
  $s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json
  if($s.schemaVersion-ne1-or$s.experiment-ne$Experiment-or$s.machine-ne$env:COMPUTERNAME-or$s.userSid-ne[Security.Principal.WindowsIdentity]::GetCurrent().User.Value){throw 'State identity validation failed.'}
  $s
}
function Test-Applied{
  $r=Get-RegState
  $r.DisableWebSearch.ValueExists-and$r.DisableWebSearch.Kind-eq'DWord'-and[int]$r.DisableWebSearch.Data-eq1-and$r.ConnectedSearchUseWeb.ValueExists-and$r.ConnectedSearchUseWeb.Kind-eq'DWord'-and[int]$r.ConnectedSearchUseWeb.Data-eq0
}
function Assert-DriftSafe($State,[switch]$AllowTreatment){
  if((Get-ManagementState).Managed){throw 'Management ownership drift detected.'}
  if(!(Same (Get-ProtectedState) $State.protected)){throw 'Protected security update or remote-access state drift detected.'}
  $cur=Get-RegState
  if($AllowTreatment){if(!(Test-Applied)){throw 'Candidate policy pair drift detected.'}}
  elseif(!(Same $cur $State.original)){throw 'Candidate policy pair drift detected.'}
}
function Restore-Value($Original,[string]$Name){
  if($Original.ValueExists){
    $kind=[Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$Original.Kind,$true)
    if(!(Test-Path $PolicyPath)){New-Item -Path $PolicyPath -Force|Out-Null}
    (Get-Item $PolicyPath).SetValue($Name,$Original.Data,$kind)
  } elseif(Test-Path $PolicyPath){Remove-ItemProperty -Path $PolicyPath -Name $Name -ErrorAction SilentlyContinue}
}

try{
  switch($Action){
    'Check'{$support=Get-Support;Write-ExpLog 'support-detection' $(if($support.Supported){'pass'}else{'refused'}) $support;$support}
    'Capture'{$support=Get-Support;Write-ExpLog 'support-detection' $(if($support.Supported){'pass'}else{'refused'}) $support;if(!$support.Supported){throw ($support.Reasons-join'; ')};$s=Save-State $support;Write-ExpLog 'capture' 'pass' $s;$s}
    'DryRun'{$support=Get-Support;Write-ExpLog 'support-detection' $(if($support.Supported){'pass'}else{'refused'}) $support;if(!$support.Supported){throw ($support.Reasons-join'; ')};$r=[pscustomobject]@{WouldChange=$true;MutationCount=2;Path=$PolicyPath;Values=$Treatment;AtomicPair=$true;RebootPersistenceRequired=$true;Rollback='Restore each captured value and type exactly, or remove only experiment-created values and an experiment-created empty key.';EvidenceStatus='needs-evidence'};Write-ExpLog 'dry-run' 'pass' $r;$r}
    'Apply'{$s=Load-State;if(Test-Applied){Assert-DriftSafe $s -AllowTreatment;Write-ExpLog 'apply' 'idempotent' @{mutationCount=0};return [pscustomobject]@{Applied=$true;MutationCount=0}};Assert-DriftSafe $s;if($WhatIfPreference){Write-ExpLog 'apply' 'whatif' @{mutationCount=0};return [pscustomobject]@{Applied=$false;MutationCount=0;WhatIf=$true}};if($PSCmdlet.ShouldProcess($PolicyPath,'Disable Windows Search web queries and web results as one atomic policy pair')){if(!(Test-Path $PolicyPath)){New-Item -Path $PolicyPath -Force|Out-Null};try{New-ItemProperty -Path $PolicyPath -Name 'DisableWebSearch' -PropertyType DWord -Value 1 -Force|Out-Null;New-ItemProperty -Path $PolicyPath -Name 'ConnectedSearchUseWeb' -PropertyType DWord -Value 0 -Force|Out-Null}catch{Restore-Value $s.original.DisableWebSearch 'DisableWebSearch';Restore-Value $s.original.ConnectedSearchUseWeb 'ConnectedSearchUseWeb';throw}};if(!(Test-Applied)){Restore-Value $s.original.DisableWebSearch 'DisableWebSearch';Restore-Value $s.original.ConnectedSearchUseWeb 'ConnectedSearchUseWeb';throw 'Atomic apply verification failed; original pair restored.'};Write-ExpLog 'apply' 'pass' @{mutationCount=2;after=(Get-RegState)};[pscustomobject]@{Applied=$true;MutationCount=2}}
    'Verify'{$s=Load-State;Assert-DriftSafe $s -AllowTreatment;Write-ExpLog 'verify' 'pass' @{policy=(Get-RegState);localApplicationSearch='needs-evidence';localSettingSearch='needs-evidence';localFileSearch='needs-evidence';indexedContentSearch='needs-evidence';webResultsAbsent='needs-evidence';searchHostNetwork='needs-evidence'};$true}
    'VerifyReboot'{$s=Load-State;Assert-DriftSafe $s -AllowTreatment;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot-le[datetime]$s.capturedBootTime){throw 'A later boot is required.'};Write-ExpLog 'verify-reboot' 'pass' @{boot=$boot.ToString('o');policy=(Get-RegState);evidenceStatus='needs-evidence'};$true}
    'Rollback'{$s=Load-State;$cur=Get-RegState;if((Same $cur $s.original)){Write-ExpLog 'rollback' 'idempotent' @{mutationCount=0};return [pscustomobject]@{RolledBack=$true;MutationCount=0}};Assert-DriftSafe $s -AllowTreatment;if($WhatIfPreference){Write-ExpLog 'rollback' 'whatif' @{mutationCount=0};return [pscustomobject]@{RolledBack=$false;MutationCount=0;WhatIf=$true}};if($PSCmdlet.ShouldProcess($PolicyPath,'Restore exact captured Windows Search web policy pair')){Restore-Value $s.original.DisableWebSearch 'DisableWebSearch';Restore-Value $s.original.ConnectedSearchUseWeb 'ConnectedSearchUseWeb';if(!$s.original.DisableWebSearch.KeyExists-and!$s.original.ConnectedSearchUseWeb.KeyExists-and(Test-Path $PolicyPath)-and@((Get-Item $PolicyPath).GetValueNames()).Count-eq0-and@((Get-ChildItem $PolicyPath -ErrorAction SilentlyContinue)).Count-eq0){Remove-Item -Path $PolicyPath}};$after=Get-RegState;if(!(Same $after $s.original)){throw 'Exact rollback verification failed.'};Write-ExpLog 'rollback' 'pass' @{mutationCount=2;after=$after};[pscustomobject]@{RolledBack=$true;MutationCount=2}}
  }
}catch{Write-ExpLog 'failure' 'failed' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName;evidenceStatus='needs-evidence'};throw}
