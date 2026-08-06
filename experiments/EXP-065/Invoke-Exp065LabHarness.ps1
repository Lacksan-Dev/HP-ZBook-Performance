[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [ValidateSet('Start','Continue','Status','Summarize','Stop')][string]$Action='Status',
  [ValidateRange(1,20)][int]$RunsPerArm=5,
  [ValidateRange(30,600)][int]$SampleSeconds=120,
  [ValidateRange(1,10)][int]$SampleIntervalSeconds=2,
  [switch]$AllowAutomaticReboot,
  [switch]$Unattended,
  [string]$EvidenceRoot="$PSScriptRoot\lab-evidence",
  [string]$RunDirectory,
  [string]$ControllerPath="$PSScriptRoot\Invoke-Exp065HpSystemInfo.ps1",
  [string]$FunctionalVerifierPath="$PSScriptRoot\Test-Exp065FunctionalReadiness.ps1"
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if($Unattended){$ConfirmPreference='None'}
$TaskName='Lacksan-EXP-065-LabHarness'
$ServiceName='HPSysInfoCap'
$ActivePointer=Join-Path $EvidenceRoot 'active.json'

function Test-Elevation {$p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent());if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Elevation required'}}
function Ensure-Directory([string]$Path){if(-not(Test-Path -LiteralPath $Path)){New-Item -ItemType Directory -Path $Path -Force|Out-Null}}
function Write-Json([string]$Path,$Value){$Value|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $Path -Encoding UTF8}
function Read-Json([string]$Path){if(-not(Test-Path -LiteralPath $Path)){throw "Required state missing: $Path"};Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
function Get-BootUtc {((Get-CimInstance Win32_OperatingSystem).LastBootUpTime).ToUniversalTime()}
function Get-Median($Values){$v=@($Values|Where-Object {$null -ne $_}|ForEach-Object {[double]$_}|Sort-Object);if($v.Count -eq 0){return $null};$m=[int][math]::Floor($v.Count/2);if($v.Count%2){return [double]$v[$m]};([double]$v[$m-1]+[double]$v[$m])/2}
function Get-Mad($Values){$v=@($Values|Where-Object {$null -ne $_}|ForEach-Object {[double]$_});if($v.Count -eq 0){return $null};$median=Get-Median $v;Get-Median @($v|ForEach-Object {[math]::Abs($_-$median)})}
function Same($A,$B){(($A|ConvertTo-Json -Compress -Depth 12)-eq($B|ConvertTo-Json -Compress -Depth 12))}
function Get-ProtectedConfiguration($Rows){@($Rows|ForEach-Object {[pscustomobject][ordered]@{Name=[string]$_.Name;StartMode=[string]$_.StartMode;PathName=[string]$_.PathName}}|Sort-Object Name)}
function Assert-BaselineConfiguration($OriginalState,$CurrentSupport){if(-not[bool]$CurrentSupport.Supported){throw('Baseline support drift detected: '+(@($CurrentSupport.Reasons)-join'; '))};$original=$OriginalState.support.Service;$current=$CurrentSupport.Service;if($current.Name-ne$original.Name-or$current.DisplayName-ne$original.DisplayName-or$current.PathName-ne$original.PathName-or$current.ExecutableHash-ne$original.ExecutableHash-or$current.SignatureThumbprint-ne$original.SignatureThumbprint-or$current.PublisherTrustMode-ne$original.PublisherTrustMode){throw'Baseline service identity drift detected'};if($current.StartMode-ne$original.StartMode-or$current.State-ne$original.State-or-not(Same $current.DelayedAutoStart $original.DelayedAutoStart)){throw'Baseline configuration drift detected'};if(-not(Same $current.Dependencies $original.Dependencies)-or-not(Same $current.Dependents $original.Dependents)){throw'Baseline service dependency drift detected'};if(-not(Same $CurrentSupport.Management $OriginalState.support.Management)){throw'Baseline management state drift detected'};if(-not(Same (Get-ProtectedConfiguration $CurrentSupport.Protected) (Get-ProtectedConfiguration $OriginalState.protected))){throw'Baseline protected-scope configuration drift detected'}}
function Paths([string]$Dir){[pscustomobject]@{State=(Join-Path $Dir 'harness-state.json');ControllerState=(Join-Path $Dir 'controller-state.json');ControllerLog=(Join-Path $Dir 'controller-events.jsonl');FunctionalReference=(Join-Path $Dir 'functional-reference.json');Summary=(Join-Path $Dir 'summary.json')}}
function Resolve-RunDirectory {if($RunDirectory){return (Resolve-Path -LiteralPath $RunDirectory).Path};$a=Read-Json $ActivePointer;if(-not $a.runDirectory){throw 'Active run pointer invalid'};(Resolve-Path -LiteralPath ([string]$a.runDirectory)).Path}
function Log([string]$Dir,[string]$Event,[hashtable]$Data){$row=[ordered]@{utc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-065';component='lab-harness';action=$Action;event=$Event;computer=$env:COMPUTERNAME;data=$Data};($row|ConvertTo-Json -Compress -Depth 10)|Add-Content -LiteralPath (Join-Path $Dir 'lab-events.jsonl') -Encoding UTF8}
function Controller([string]$ControllerAction,[string]$Dir,[switch]$DryRun){$p=Paths $Dir;$args=@{Action=$ControllerAction;StatePath=$p.ControllerState;LogPath=$p.ControllerLog;Confirm=$false};if($DryRun){& $ControllerPath @args -WhatIf}else{& $ControllerPath @args}}
function Functional([string]$Phase,[int]$Ordinal,[string]$Dir){if(!(Test-Path -LiteralPath $FunctionalVerifierPath -PathType Leaf)){throw 'EXP-065 functional verifier missing'};$p=Paths $Dir;$result=& $FunctionalVerifierPath -Phase $Phase -ReferencePath $p.FunctionalReference -Confirm:$false;Write-Json (Join-Path $Dir ("functional-{0}-{1:D2}.json" -f $Phase,$Ordinal)) $result;$result}
function RestoreAfterCollectionFailure([string]$Dir){
  $initialRollbackError=$null;$readinessError=$null;$finalRollbackError=$null
  try{
    try{Controller 'Rollback' $Dir|Out-Null}catch{$initialRollbackError=$_}
    if(!$initialRollbackError){try{$null=Functional 'Rollback' 1 $Dir}catch{$readinessError=$_}}
  }finally{
    try{Controller 'Rollback' $Dir|Out-Null}catch{$finalRollbackError=$_}
  }
  Log $Dir 'collection-failure-rollback' @{initialRollback=[bool](!$initialRollbackError);readiness=[bool](!$readinessError-and!$initialRollbackError);finalRollback=[bool](!$finalRollbackError)}
  if($finalRollbackError){throw 'Final exact rollback failed after a collection exception; retain the active cycle for guarded recovery.'}
  [pscustomobject]@{exactRollback=$true;readinessChecked=[bool](!$readinessError-and!$initialRollbackError)}
}
function Task {Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue}
function Register-ResumeTask([string]$Dir){if(Task){throw "Scheduled task already exists: $TaskName"};$exe=(Get-Command powershell.exe -ErrorAction Stop).Source;$automaticRebootArgument=if($AllowAutomaticReboot){' -AllowAutomaticReboot'}else{''};$args="-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Action Continue -RunDirectory `"$Dir`" -EvidenceRoot `"$EvidenceRoot`" -ControllerPath `"$ControllerPath`" -FunctionalVerifierPath `"$FunctionalVerifierPath`" -Unattended$automaticRebootArgument";$a=New-ScheduledTaskAction -Execute $exe -Argument $args;$user=[System.Security.Principal.WindowsIdentity]::GetCurrent().Name;$t=New-ScheduledTaskTrigger -AtLogOn -User $user;$pr=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest;$s=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 20);if($PSCmdlet.ShouldProcess($TaskName,'Register reboot continuation task')){Register-ScheduledTask -TaskName $TaskName -Action $a -Trigger $t -Principal $pr -Settings $s|Out-Null}}
function Remove-ResumeTask([string]$Dir){if(Task){if($PSCmdlet.ShouldProcess($TaskName,'Remove reboot continuation task')){Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false;Log $Dir 'task-removed' @{task=$TaskName}}}}
function ProtectedSnapshot {$services=@();foreach($n in 'Tailscale','TermService'){try{$s=Get-Service $n -ErrorAction Stop;$services+=[pscustomobject]@{name=$n;status=$s.Status.ToString();startType=$s.StartType.ToString()}}catch{$services+=[pscustomobject]@{name=$n;status='absent';startType=$null}}};$processes=@(Get-Process -ErrorAction SilentlyContinue|Where-Object {$_.ProcessName -match '(?i)tailscale|msrdc|windowsapp|omnissa|horizon|vmware-view|wswc'}|Select-Object ProcessName,Id,Responding);[pscustomobject]@{services=$services;processes=$processes}}
function ServiceSnapshot {$s=Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop;$proc=$null;if([int]$s.ProcessId -gt 0){$gp=Get-Process -Id ([int]$s.ProcessId) -ErrorAction SilentlyContinue;$wp=Get-CimInstance Win32_Process -Filter "ProcessId=$($s.ProcessId)" -ErrorAction SilentlyContinue;if($gp -and $wp){$proc=[ordered]@{pid=[int]$s.ProcessId;cpuMs=[double]$gp.TotalProcessorTime.TotalMilliseconds;workingSetBytes=[int64]$gp.WorkingSet64;readBytes=[uint64]$wp.ReadTransferCount;writeBytes=[uint64]$wp.WriteTransferCount;startUtc=$gp.StartTime.ToUniversalTime().ToString('o')}}};[pscustomobject]@{name=$s.Name;startMode=$s.StartMode;state=$s.State;process=$proc}}
function SystemSample {$cpu=(Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime;$disk=(Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'").DiskBytesPersec;[pscustomobject]@{cpu=[double]$cpu;disk=[double]$disk}}
function Collect([string]$Phase,[int]$Ordinal,[string]$Dir){$boot=Get-BootUtc;$before=ServiceSnapshot;$protectedBefore=ProtectedSnapshot;$collectorBefore=[double](Get-Process -Id $PID).TotalProcessorTime.TotalMilliseconds;$samples=@();$count=[int][math]::Ceiling($SampleSeconds/[double]$SampleIntervalSeconds);for($i=0;$i -lt $count;$i++){$samples+=SystemSample;if($i -lt $count-1){Start-Sleep -Seconds $SampleIntervalSeconds}};$after=ServiceSnapshot;$collectorAfter=[double](Get-Process -Id $PID).TotalProcessorTime.TotalMilliseconds;$cpuDelta=$null;$readDelta=$null;$writeDelta=$null;if($before.process -and $after.process -and $before.process.pid -eq $after.process.pid){$cpuDelta=[double]$after.process.cpuMs-[double]$before.process.cpuMs;$readDelta=[double]$after.process.readBytes-[double]$before.process.readBytes;$writeDelta=[double]$after.process.writeBytes-[double]$before.process.writeBytes};$explorer=Get-Process explorer -ErrorAction SilentlyContinue|Sort-Object StartTime|Select-Object -First 1;$functional=Functional $Phase $Ordinal $Dir;[ordered]@{schema=1;experiment='EXP-065';phase=$Phase;ordinal=$Ordinal;computer=$env:COMPUTERNAME;bootUtc=$boot.ToString('o');capturedUtc=(Get-Date).ToUniversalTime().ToString('o');desktopProxy=[ordered]@{explorerPresent=[bool]$explorer;explorerResponding=if($explorer){[bool]$explorer.Responding}else{$false};bootToExplorerStartMs=if($explorer){($explorer.StartTime.ToUniversalTime()-$boot).TotalMilliseconds}else{$null}};system=[ordered]@{cpuMedianPercent=(Get-Median @($samples|ForEach-Object {$_.cpu}));cpuMadPercent=(Get-Mad @($samples|ForEach-Object {$_.cpu}));diskMedianBytesPerSec=(Get-Median @($samples|ForEach-Object {$_.disk}));diskMadBytesPerSec=(Get-Mad @($samples|ForEach-Object {$_.disk}))};service=[ordered]@{before=$before;after=$after;cpuDeltaMs=$cpuDelta;readDeltaBytes=$readDelta;writeDeltaBytes=$writeDelta;startedDuringSample=(!$before.process -and $after.process)};protected=[ordered]@{before=$protectedBefore;after=(ProtectedSnapshot)};functional=$functional;instrumentation=[ordered]@{collectorCpuDeltaMs=($collectorAfter-$collectorBefore);sampleCount=$samples.Count;functionalCheckRunsAfterBenchmark=$true}}}
function ScopePassed($Result,[string]$Scope){
  if(!$Result){return $false}
  $readiness=if($Result.PSObject.Properties['functional']){$Result.functional.protectedReadiness}else{$Result.protectedReadiness}
  if(!$readiness-or!$readiness.PSObject.Properties['scopeResults']){return $false}
  $property=$readiness.scopeResults.PSObject.Properties[$Scope]
  ($null-ne$property-and[bool]$property.Value)
}
function Summarize([string]$Dir){
  $runs=@(Get-ChildItem $Dir -Filter 'run-*.json' -File|Sort-Object Name|ForEach-Object {Read-Json $_.FullName})
  if($runs.Count -eq 0){throw 'No runs found'}
  $groups=[ordered]@{}
  foreach($phase in 'Baseline','Treatment'){
    $g=@($runs|Where-Object {$_.phase -eq $phase})
    $groups[$phase]=[ordered]@{
      runs=$g.Count
      bootToExplorerStartMs=[ordered]@{median=(Get-Median @($g|ForEach-Object {$_.desktopProxy.bootToExplorerStartMs}));mad=(Get-Mad @($g|ForEach-Object {$_.desktopProxy.bootToExplorerStartMs}))}
      cpuMedianPercent=[ordered]@{median=(Get-Median @($g|ForEach-Object {$_.system.cpuMedianPercent}));mad=(Get-Mad @($g|ForEach-Object {$_.system.cpuMedianPercent}))}
      diskMedianBytesPerSec=[ordered]@{median=(Get-Median @($g|ForEach-Object {$_.system.diskMedianBytesPerSec}));mad=(Get-Mad @($g|ForEach-Object {$_.system.diskMedianBytesPerSec}))}
      serviceCpuDeltaMs=[ordered]@{median=(Get-Median @($g|ForEach-Object {$_.service.cpuDeltaMs}));mad=(Get-Mad @($g|ForEach-Object {$_.service.cpuDeltaMs}))}
      demandStartLatencyMs=[ordered]@{median=(Get-Median @($g|ForEach-Object {$_.functional.hpSystemInformation.demandStartLatencyMs}));mad=(Get-Mad @($g|ForEach-Object {$_.functional.hpSystemInformation.demandStartLatencyMs}))}
    }
  }
  $baseline=@($runs|Where-Object{$_.phase -eq 'Baseline'})
  $treatment=@($runs|Where-Object{$_.phase -eq 'Treatment'})
  $rollbackPath=Join-Path $Dir 'functional-Rollback-01.json'
  $rollback=if(Test-Path -LiteralPath $rollbackPath){Read-Json $rollbackPath}else{$null}
  $functional=($baseline.Count -ge $RunsPerArm -and $treatment.Count -ge $RunsPerArm -and @($runs|Where-Object{-not[bool]$_.functional.passed}).Count -eq 0 -and @($treatment|Where-Object{-not[bool]$_.functional.hpSystemInformation.demandStartObserved}).Count -eq 0 -and $rollback -and [bool]$rollback.passed)
  $scopeProof=[ordered]@{}
  foreach($scope in @('WindowsSecurity','WindowsUpdate','EdgeUpdate','Credentials','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Networking','Omnissa','WindowsApp','RemoteDesktop','Tailscale')){
    $scopeProof[$scope]=($baseline.Count -ge $RunsPerArm -and $treatment.Count -ge $RunsPerArm -and @($runs|Where-Object{-not(ScopePassed $_ $scope)}).Count -eq 0 -and $rollback -and (ScopePassed $rollback $scope))
  }
  $protected=($functional -and @($scopeProof.GetEnumerator()|Where-Object{-not[bool]$_.Value}).Count -eq 0)
  $summary=[ordered]@{
    schema=1;experiment='EXP-065';generatedUtc=(Get-Date).ToUniversalTime().ToString('o');computer=$env:COMPUTERNAME;groups=$groups
    classification=if($functional -and $protected){'unqualified'}else{'inconclusive'}
    verification=[ordered]@{
      functional=[bool]$functional;protectedScopes=[bool]$protected;protectedScopeResults=$scopeProof
      rollbackFunctional=[bool]($rollback -and $rollback.passed)
      hpDemandStart=[bool]($treatment.Count -ge $RunsPerArm -and @($treatment|Where-Object{-not[bool]$_.functional.hpSystemInformation.demandStartObserved}).Count -eq 0)
      hpUpdateDiscovery=[bool]($rollback -and [bool]$rollback.hpUpdate.discoverySucceeded -and @($runs|Where-Object{-not[bool]$_.functional.hpUpdate.discoverySucceeded -or -not[bool]$_.functional.hpUpdate.packageVersionStable}).Count -eq 0)
      updateInstallationAttempted=$false
    }
    limitations=@('bootToExplorerStartMs is a desktop-readiness proxy','HP update verification uses read-only Microsoft Store discovery; no update is installed so the service-start experiment remains single-variable','The post-rollback readiness check does not launch the app, and an idempotent provider rollback is the final state transition','Application content and machine-specific identifiers are excluded from functional evidence')
  }
  Write-Json (Join-Path $Dir 'summary.json') $summary
  $summary
}
function RebootIfAllowed([string]$Dir){if($AllowAutomaticReboot){Log $Dir 'reboot-requested' @{};Restart-Computer -Force}else{Log $Dir 'reboot-required' @{};Write-Output "Reboot required. Continue will resume automatically at next logon."}}

Test-Elevation;if(-not(Test-Path -LiteralPath $ControllerPath)){throw 'Controller missing'}
switch($Action){
 'Start' {Ensure-Directory $EvidenceRoot;if(Test-Path $ActivePointer){throw 'An active EXP-065 run already exists'};$check=Controller 'Check' $EvidenceRoot;if($WhatIfPreference){$null=$PSCmdlet.ShouldProcess($TaskName,"Prepare $RunsPerArm baseline and treatment boots");return $check};$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss');$dir=Join-Path $EvidenceRoot $stamp;Ensure-Directory $dir;$p=Paths $dir;Controller 'Capture' $dir|Out-Null;Controller 'DryRun' $dir|Out-Null;$state=[ordered]@{schema=1;phase='Baseline';completedRuns=0;runsPerArm=$RunsPerArm;lastBootUtc=$null;sampleSeconds=$SampleSeconds;sampleIntervalSeconds=$SampleIntervalSeconds};Write-Json $p.State $state;Write-Json $ActivePointer @{runDirectory=$dir};Register-ResumeTask $dir;Log $dir 'started' @{runsPerArm=$RunsPerArm;dryRun='pass'};RebootIfAllowed $dir}
 'Continue' {$dir=Resolve-RunDirectory;$p=Paths $dir;$state=Read-Json $p.State;$boot=(Get-BootUtc).ToString('o');if($state.lastBootUtc -eq $boot){throw 'Duplicate collection from same boot refused'};if($state.phase -eq 'Treatment'){Controller 'VerifyReboot' $dir|Out-Null}else{$originalState=Read-Json $p.ControllerState;$currentSupport=Controller 'Check' $dir;Assert-BaselineConfiguration $originalState $currentSupport};$ordinal=[int]$state.completedRuns+1;$trial=$null;try{$trial=Collect $state.phase $ordinal $dir}catch{$collectionFailure=$_;try{$null=RestoreAfterCollectionFailure $dir}catch{throw};Log $dir 'collection-failed' @{phase=$state.phase;ordinal=$ordinal;exactRollback=$true};throw $collectionFailure};Write-Json (Join-Path $dir ("run-{0}-{1:D2}.json" -f $state.phase,$ordinal)) $trial;if(-not[bool]$trial.functional.passed){Controller 'Rollback' $dir|Out-Null;try{$null=Functional 'Rollback' 1 $dir}finally{Controller 'Rollback' $dir|Out-Null};$null=Summarize $dir;Remove-ResumeTask $dir;Remove-Item $ActivePointer -Force;Log $dir 'functional-failed' @{phase=$state.phase;ordinal=$ordinal};throw 'EXP-065 functional or protected-readiness verification failed; exact rollback was executed.'};$state.completedRuns=$ordinal;$state.lastBootUtc=$boot;if($state.completedRuns -ge [int]$state.runsPerArm){if($state.phase -eq 'Baseline'){$state.phase='Treatment';$state.completedRuns=0;Controller 'Apply' $dir|Out-Null;Controller 'Verify' $dir|Out-Null}else{Controller 'Rollback' $dir|Out-Null;try{$rollbackFunctional=Functional 'Rollback' 1 $dir}finally{Controller 'Rollback' $dir|Out-Null};if(-not[bool]$rollbackFunctional.passed){Log $dir 'rollback-functional-failed' @{}};Summarize $dir|Out-Null;Remove-ResumeTask $dir;Remove-Item $ActivePointer -Force;Write-Json $p.State $state;Log $dir 'completed' @{functional=[bool]$rollbackFunctional.passed};return (Read-Json $p.Summary)}};Write-Json $p.State $state;Log $dir 'trial-collected' @{phase=$trial.phase;ordinal=$ordinal;functional=[bool]$trial.functional.passed};RebootIfAllowed $dir}
 'Status' {if(Test-Path $ActivePointer){$dir=Resolve-RunDirectory;Read-Json (Paths $dir).State}else{[pscustomobject]@{active=$false}}}
 'Summarize' {$dir=Resolve-RunDirectory;Summarize $dir}
 'Stop' {$dir=Resolve-RunDirectory;$p=Paths $dir;Controller 'Rollback' $dir|Out-Null;Remove-ResumeTask $dir;Remove-Item $ActivePointer -Force -ErrorAction SilentlyContinue;Log $dir 'stopped' @{};[pscustomobject]@{stopped=$true;runDirectory=$dir}}
}
