[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [ValidateSet('Start','Continue','Status','Summarize','Stop')]
  [string]$Action='Status',
  [ValidateRange(1,20)]
  [int]$RunsPerArm=5,
  [ValidateRange(30,600)]
  [int]$SampleSeconds=120,
  [ValidateRange(1,10)]
  [int]$SampleIntervalSeconds=2,
  [switch]$AllowAutomaticReboot,
  [string]$EvidenceRoot="$PSScriptRoot\lab-evidence",
  [string]$RunDirectory,
  [string]$ControllerPath="$PSScriptRoot\Invoke-Exp024HpTouchpoint.ps1"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$TaskName='Lacksan-EXP-024-LabHarness'
$ServiceName='HPTouchpointAnalyticsService'
$ActivePointer=Join-Path $EvidenceRoot 'active.json'

function Test-Elevation {
  $p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Elevation required'}
}
function Ensure-Directory([string]$Path){if(-not(Test-Path -LiteralPath $Path)){New-Item -ItemType Directory -Path $Path -Force|Out-Null}}
function Get-BootUtc {((Get-CimInstance Win32_OperatingSystem).LastBootUpTime).ToUniversalTime()}
function Write-JsonFile([string]$Path,$Value){$Value|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $Path -Encoding UTF8}
function Read-JsonFile([string]$Path){if(-not(Test-Path -LiteralPath $Path)){throw "Required state missing: $Path"};Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
function Write-LabEvent([string]$Event,[hashtable]$Data,[string]$Dir){
  $row=[ordered]@{utc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-024';component='lab-harness';action=$Action;event=$Event;computer=$env:COMPUTERNAME;data=$Data}
  ($row|ConvertTo-Json -Compress -Depth 10)|Add-Content -LiteralPath (Join-Path $Dir 'lab-events.jsonl') -Encoding UTF8
}
function Resolve-RunDirectory {
  if($RunDirectory){return (Resolve-Path -LiteralPath $RunDirectory).Path}
  $active=Read-JsonFile $ActivePointer
  if(-not $active.runDirectory){throw 'Active run pointer is invalid'}
  (Resolve-Path -LiteralPath ([string]$active.runDirectory)).Path
}
function Get-RunPaths([string]$Dir){
  [pscustomobject]@{
    State=(Join-Path $Dir 'harness-state.json')
    ControllerState=(Join-Path $Dir 'controller-state.json')
    ControllerLog=(Join-Path $Dir 'controller-events.jsonl')
    Summary=(Join-Path $Dir 'summary.json')
  }
}
function Invoke-Controller([string]$ControllerAction,[string]$Dir,[switch]$WhatIfController){
  $p=Get-RunPaths $Dir
  $args=@{Action=$ControllerAction;StatePath=$p.ControllerState;LogPath=$p.ControllerLog}
  if($WhatIfController){& $ControllerPath @args -WhatIf}else{& $ControllerPath @args}
}
function Get-TaskOrNull {Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue}
function Register-HarnessTask([string]$Dir){
  if(Get-TaskOrNull){throw "Scheduled task already exists: $TaskName"}
  $exe=(Get-Command powershell.exe -ErrorAction Stop).Source
  $quotedScript=$PSCommandPath.Replace('"','\"')
  $quotedDir=$Dir.Replace('"','\"')
  $quotedEvidence=$EvidenceRoot.Replace('"','\"')
  $quotedController=$ControllerPath.Replace('"','\"')
  $arguments="-NoProfile -ExecutionPolicy Bypass -File `"$quotedScript`" -Action Continue -RunDirectory `"$quotedDir`" -EvidenceRoot `"$quotedEvidence`" -ControllerPath `"$quotedController`""
  $taskAction=New-ScheduledTaskAction -Execute $exe -Argument $arguments
  $trigger=New-ScheduledTaskTrigger -AtLogOn -User ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
  $principal=New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
  $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
  if($PSCmdlet.ShouldProcess($TaskName,'Register EXP-024 logon validation task')){Register-ScheduledTask -TaskName $TaskName -Action $taskAction -Trigger $trigger -Principal $principal -Settings $settings|Out-Null}
}
function Unregister-HarnessTask([string]$Dir){
  if(Get-TaskOrNull){if($PSCmdlet.ShouldProcess($TaskName,'Unregister EXP-024 logon validation task')){Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false;Write-LabEvent 'task-removed' @{task=$TaskName} $Dir}}
}
function Get-ServiceSnapshot {
  $svc=Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
  $proc=$null
  if([int]$svc.ProcessId -gt 0){
    $gp=Get-Process -Id ([int]$svc.ProcessId) -ErrorAction SilentlyContinue
    $wp=Get-CimInstance Win32_Process -Filter "ProcessId=$($svc.ProcessId)" -ErrorAction SilentlyContinue
    if($gp -and $wp){$proc=[ordered]@{pid=[int]$svc.ProcessId;cpuMs=[double]$gp.TotalProcessorTime.TotalMilliseconds;workingSetBytes=[int64]$gp.WorkingSet64;readTransferBytes=[uint64]$wp.ReadTransferCount;writeTransferBytes=[uint64]$wp.WriteTransferCount;startUtc=$gp.StartTime.ToUniversalTime().ToString('o')}}
  }
  $tcp=@()
  if([int]$svc.ProcessId -gt 0){$tcp=@(Get-NetTCPConnection -OwningProcess ([int]$svc.ProcessId) -ErrorAction SilentlyContinue|Select-Object State,LocalAddress,LocalPort,RemoteAddress,RemotePort)}
  [pscustomobject]@{name=$svc.Name;displayName=$svc.DisplayName;startMode=$svc.StartMode;state=$svc.State;processId=[int]$svc.ProcessId;process=$proc;tcpConnections=$tcp}
}
function Get-SystemSample {
  $cpu=(Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop).PercentProcessorTime
  $disk=(Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" -ErrorAction Stop).DiskBytesPersec
  $net=@(Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction SilentlyContinue)
  $netBytes=0.0
  foreach($n in $net){$netBytes += [double]$n.BytesTotalPersec}
  [pscustomobject]@{utc=(Get-Date).ToUniversalTime().ToString('o');cpuPercent=[double]$cpu;diskBytesPerSec=[double]$disk;networkBytesPerSec=$netBytes}
}
function Get-DesktopProxy([datetime]$BootUtc){
  $explorer=Get-Process explorer -ErrorAction SilentlyContinue|Sort-Object StartTime|Select-Object -First 1
  if(-not $explorer){return [pscustomobject]@{explorerPresent=$false;explorerResponding=$false;bootToExplorerStartMs=$null;bootToCollectorStartMs=((Get-Date).ToUniversalTime()-$BootUtc).TotalMilliseconds}}
  [pscustomobject]@{explorerPresent=$true;explorerResponding=[bool]$explorer.Responding;bootToExplorerStartMs=($explorer.StartTime.ToUniversalTime()-$BootUtc).TotalMilliseconds;bootToCollectorStartMs=((Get-Date).ToUniversalTime()-$BootUtc).TotalMilliseconds}
}
function Get-ProtectedSnapshot {
  $services=@()
  foreach($name in 'Tailscale','TermService'){try{$s=Get-Service -Name $name -ErrorAction Stop;$services+=[pscustomobject]@{name=$name;status=$s.Status.ToString();startType=$s.StartType.ToString()}}catch{$services+=[pscustomobject]@{name=$name;status='absent';startType=$null}}}
  $processes=@(Get-Process -ErrorAction SilentlyContinue|Where-Object {$_.ProcessName -match '(?i)tailscale|msrdc|windowsapp|omnissa|horizon|vmware-view|wswc'}|Select-Object ProcessName,Id,Responding)
  [pscustomobject]@{services=$services;processes=$processes}
}
function Get-Median([double[]]$Values){
  $v=@($Values|Where-Object {$_ -ne $null}|Sort-Object)
  if($v.Count -eq 0){return $null};$m=[int][math]::Floor($v.Count/2)
  if($v.Count%2){return [double]$v[$m]};([double]$v[$m-1]+[double]$v[$m])/2.0
}
function Get-Mad([double[]]$Values){
  $v=@($Values|Where-Object {$_ -ne $null});if($v.Count -eq 0){return $null};$median=Get-Median $v;Get-Median @($v|ForEach-Object {[math]::Abs([double]$_-$median)})
}
function Collect-Trial([string]$Phase,[int]$Ordinal,[string]$Dir,[int]$Seconds,[int]$Interval){
  $boot=Get-BootUtc
  $collector=Get-Process -Id $PID
  $collectorCpuBefore=[double]$collector.TotalProcessorTime.TotalMilliseconds
  $serviceBefore=Get-ServiceSnapshot
  $protectedBefore=Get-ProtectedSnapshot
  $desktop=Get-DesktopProxy $boot
  $samples=New-Object System.Collections.Generic.List[object]
  $iterations=[int][math]::Ceiling($Seconds/[double]$Interval)
  for($i=0;$i -lt $iterations;$i++){$samples.Add((Get-SystemSample));if($i -lt ($iterations-1)){Start-Sleep -Seconds $Interval}}
  $serviceAfter=Get-ServiceSnapshot
  $protectedAfter=Get-ProtectedSnapshot
  $collectorCpuAfter=[double](Get-Process -Id $PID).TotalProcessorTime.TotalMilliseconds
  $cpu=@($samples|ForEach-Object {[double]$_.cpuPercent});$disk=@($samples|ForEach-Object {[double]$_.diskBytesPerSec});$net=@($samples|ForEach-Object {[double]$_.networkBytesPerSec})
  $serviceCpuDelta=$null;$serviceReadDelta=$null;$serviceWriteDelta=$null
  if($serviceBefore.process -and $serviceAfter.process -and $serviceBefore.process.pid -eq $serviceAfter.process.pid){
    $serviceCpuDelta=[double]$serviceAfter.process.cpuMs-[double]$serviceBefore.process.cpuMs
    $serviceReadDelta=[double]$serviceAfter.process.readTransferBytes-[double]$serviceBefore.process.readTransferBytes
    $serviceWriteDelta=[double]$serviceAfter.process.writeTransferBytes-[double]$serviceBefore.process.writeTransferBytes
  }
  [ordered]@{
    schema=1;experiment='EXP-024';phase=$Phase;ordinal=$Ordinal;computer=$env:COMPUTERNAME;bootUtc=$boot.ToString('o');capturedUtc=(Get-Date).ToUniversalTime().ToString('o');sampleSeconds=$Seconds;sampleIntervalSeconds=$Interval
    desktopProxy=$desktop
    system=[ordered]@{cpuMedianPercent=(Get-Median $cpu);cpuMadPercent=(Get-Mad $cpu);diskMedianBytesPerSec=(Get-Median $disk);diskMadBytesPerSec=(Get-Mad $disk);networkMedianBytesPerSec=(Get-Median $net);networkMadBytesPerSec=(Get-Mad $net)}
    service=[ordered]@{before=$serviceBefore;after=$serviceAfter;cpuDeltaMs=$serviceCpuDelta;readTransferDeltaBytes=$serviceReadDelta;writeTransferDeltaBytes=$serviceWriteDelta}
    protected=[ordered]@{before=$protectedBefore;after=$protectedAfter}
    instrumentation=[ordered]@{collectorCpuDeltaMs=($collectorCpuAfter-$collectorCpuBefore);sampleCount=$samples.Count}
  }
}
function Assert-PhaseConfiguration([string]$Phase,[string]$Dir){
  $p=Get-RunPaths $Dir
  if($Phase -eq 'Treatment'){Invoke-Controller 'VerifyReboot' $Dir|Out-Null;return}
  $original=Read-JsonFile $p.ControllerState
  $current=Invoke-Controller 'Check' $Dir
  if($current.StartMode -ne $original.startMode -or [int]$current.DelayedAutoStart -ne [int]$original.delayedAutoStart){throw 'Baseline configuration drift detected'}
}
function Prepare-Phase([string]$Phase,[string]$Dir){
  if($Phase -eq 'Treatment'){Invoke-Controller 'Apply' $Dir|Out-Null}else{Invoke-Controller 'Rollback' $Dir|Out-Null}
  Write-LabEvent 'phase-prepared' @{phase=$Phase;bootUtc=(Get-BootUtc).ToString('o')} $Dir
}
function Summarize-Run([string]$Dir){
  $runs=@(Get-ChildItem -LiteralPath $Dir -Filter 'run-*.json' -File -ErrorAction SilentlyContinue|Sort-Object Name|ForEach-Object {Read-JsonFile $_.FullName})
  if($runs.Count -eq 0){throw 'No run evidence found'}
  $groups=[ordered]@{}
  foreach($phase in 'Baseline','Treatment'){
    $g=@($runs|Where-Object {$_.phase -eq $phase})
    $groups[$phase]=[ordered]@{
      runs=$g.Count
      bootToExplorerStartMs=[ordered]@{median=(Get-Median @($g|ForEach-Object {[double]$_.desktopProxy.bootToExplorerStartMs}));mad=(Get-Mad @($g|ForEach-Object {[double]$_.desktopProxy.bootToExplorerStartMs}))}
      cpuMedianPercent=[ordered]@{median=(Get-Median @($g|ForEach-Object {[double]$_.system.cpuMedianPercent}));mad=(Get-Mad @($g|ForEach-Object {[double]$_.system.cpuMedianPercent}))}
      diskMedianBytesPerSec=[ordered]@{median=(Get-Median @($g|ForEach-Object {[double]$_.system.diskMedianBytesPerSec}));mad=(Get-Mad @($g|ForEach-Object {[double]$_.system.diskMedianBytesPerSec}))}
      networkMedianBytesPerSec=[ordered]@{median=(Get-Median @($g|ForEach-Object {[double]$_.system.networkMedianBytesPerSec}));mad=(Get-Mad @($g|ForEach-Object {[double]$_.system.networkMedianBytesPerSec}))}
      serviceCpuDeltaMs=[ordered]@{median=(Get-Median @($g|ForEach-Object {if($_.service.cpuDeltaMs -ne $null){[double]$_.service.cpuDeltaMs}}));mad=(Get-Mad @($g|ForEach-Object {if($_.service.cpuDeltaMs -ne $null){[double]$_.service.cpuDeltaMs}}))}
    }
  }
  $summary=[ordered]@{schema=1;experiment='EXP-024';generatedUtc=(Get-Date).ToUniversalTime().ToString('o');computer=$env:COMPUTERNAME;groups=$groups;limitations=@('bootToExplorerStartMs is a desktop-readiness proxy rather than a direct first-input latency measurement','network measurement is system-wide; service TCP endpoints are captured separately','HP customer workflow demand-start behavior still requires an identified supported local HP workflow')}
  Write-JsonFile (Join-Path $Dir 'summary.json') $summary
  Write-LabEvent 'summary-written' @{runs=$runs.Count} $Dir
  $summary
}

Test-Elevation
if(-not(Test-Path -LiteralPath $ControllerPath -PathType Leaf)){throw "Controller missing: $ControllerPath"}
Ensure-Directory $EvidenceRoot

switch($Action){
  'Start' {
    if(Get-TaskOrNull){throw "Existing harness task must be resolved first: $TaskName"}
    $stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $Dir=Join-Path $EvidenceRoot ("$stamp-$([guid]::NewGuid().ToString('N').Substring(0,8))")
    Ensure-Directory $Dir
    $p=Get-RunPaths $Dir
    $check=Invoke-Controller 'Check' $Dir
    if($check.StartMode -ne 'Auto'){throw "Baseline startup mode must be Auto; observed $($check.StartMode)"}
    Invoke-Controller 'Capture' $Dir|Out-Null
    $state=[ordered]@{schema=1;experiment='EXP-024';computer=$env:COMPUTERNAME;status='awaiting-reboot';phase='Baseline';completedRuns=0;runsPerArm=$RunsPerArm;totalRuns=($RunsPerArm*2);sampleSeconds=$SampleSeconds;sampleIntervalSeconds=$SampleIntervalSeconds;allowAutomaticReboot=[bool]$AllowAutomaticReboot;preparedBootUtc=(Get-BootUtc).ToString('o');preparedUtc=(Get-Date).ToUniversalTime().ToString('o');lastCollectedBootUtc=$null;runDirectory=$Dir}
    Write-JsonFile $p.State $state
    Write-JsonFile $ActivePointer ([ordered]@{runDirectory=$Dir;createdUtc=(Get-Date).ToUniversalTime().ToString('o')})
    Register-HarnessTask $Dir
    Write-LabEvent 'run-started' @{runsPerArm=$RunsPerArm;sampleSeconds=$SampleSeconds;automaticReboot=[bool]$AllowAutomaticReboot} $Dir
    if($AllowAutomaticReboot){if($PSCmdlet.ShouldProcess($env:COMPUTERNAME,'Restart for EXP-024 baseline boot')){Restart-Computer -Force}}
    $state
  }
  'Continue' {
    $Dir=Resolve-RunDirectory;$p=Get-RunPaths $Dir;$state=Read-JsonFile $p.State
    if($state.computer -ne $env:COMPUTERNAME){throw 'Harness state belongs to another computer'}
    if($state.status -eq 'complete'){Unregister-HarnessTask $Dir;break}
    $boot=Get-BootUtc
    if($boot -le ([datetime]$state.preparedBootUtc).ToUniversalTime()){throw 'A clean reboot is required before collecting this trial'}
    if($state.lastCollectedBootUtc -and $boot -eq ([datetime]$state.lastCollectedBootUtc).ToUniversalTime()){throw 'This boot was already collected'}
    Assert-PhaseConfiguration ([string]$state.phase) $Dir
    $ordinal=[int]$state.completedRuns+1
    Write-LabEvent 'trial-started' @{phase=$state.phase;ordinal=$ordinal;bootUtc=$boot.ToString('o')} $Dir
    $trial=Collect-Trial ([string]$state.phase) $ordinal $Dir ([int]$state.sampleSeconds) ([int]$state.sampleIntervalSeconds)
    $runPath=Join-Path $Dir ('run-{0:D2}-{1}.json' -f $ordinal,([string]$state.phase).ToLowerInvariant())
    Write-JsonFile $runPath $trial
    $state.completedRuns=$ordinal;$state.lastCollectedBootUtc=$boot.ToString('o')
    Write-LabEvent 'trial-collected' @{phase=$state.phase;ordinal=$ordinal;path=$runPath} $Dir
    if($ordinal -ge [int]$state.totalRuns){
      Invoke-Controller 'Rollback' $Dir|Out-Null
      $state.status='complete';$state.completedUtc=(Get-Date).ToUniversalTime().ToString('o');Write-JsonFile $p.State $state
      $summary=Summarize-Run $Dir
      Unregister-HarnessTask $Dir
      Write-LabEvent 'run-complete' @{runs=$ordinal;rollback='verified'} $Dir
      $summary
      break
    }
    $nextPhase=if([string]$state.phase -eq 'Baseline'){'Treatment'}else{'Baseline'}
    Prepare-Phase $nextPhase $Dir
    $state.phase=$nextPhase;$state.status='awaiting-reboot';$state.preparedBootUtc=$boot.ToString('o');$state.preparedUtc=(Get-Date).ToUniversalTime().ToString('o');Write-JsonFile $p.State $state
    if([bool]$state.allowAutomaticReboot){if($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"Restart for EXP-024 $nextPhase boot")){Restart-Computer -Force}}
    $state
  }
  'Status' {$Dir=Resolve-RunDirectory;$p=Get-RunPaths $Dir;Read-JsonFile $p.State}
  'Summarize' {$Dir=Resolve-RunDirectory;Summarize-Run $Dir}
  'Stop' {
    $Dir=Resolve-RunDirectory;$p=Get-RunPaths $Dir;$state=Read-JsonFile $p.State
    Invoke-Controller 'Rollback' $Dir|Out-Null
    Unregister-HarnessTask $Dir
    $state.status='stopped';$state.stoppedUtc=(Get-Date).ToUniversalTime().ToString('o');Write-JsonFile $p.State $state
    Write-LabEvent 'run-stopped' @{rollback='verified'} $Dir
    $state
  }
}
