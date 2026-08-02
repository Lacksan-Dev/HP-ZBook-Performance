[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Start','Continue','Status','Summarize','Stop')][string]$Action='Status',
    [ValidateRange(1,20)][int]$RunsPerArm=5,
    [ValidateRange(30,600)][int]$SampleSeconds=120,
    [ValidateRange(1,10)][int]$SampleIntervalSeconds=2,
    [switch]$AllowAutomaticReboot,
    [string]$EvidenceRoot="$PSScriptRoot\lab-evidence",
    [string]$RunDirectory,
    [string]$ProviderPath="$PSScriptRoot\..\..\controller\providers\MicrosoftTeamsSigninTask.ps1"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Experiment='EXP-125'
$TaskName='Lacksan-EXP-125-LabHarness'
$ActivePointer=Join-Path $EvidenceRoot 'active.json'

function Test-Elevation {
    $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Elevation required.'}
}
function Ensure-Directory([string]$Path){if(-not(Test-Path -LiteralPath $Path)){New-Item -ItemType Directory -Path $Path -Force|Out-Null}}
function Write-Json([string]$Path,$Value){$Value|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $Path -Encoding UTF8}
function Read-Json([string]$Path){if(-not(Test-Path -LiteralPath $Path)){throw "Required state missing: $Path"};Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
function Get-BootUtc {((Get-CimInstance Win32_OperatingSystem).LastBootUpTime).ToUniversalTime()}
function Get-Median($Values){$v=@($Values|Where-Object{$null-ne$_}|ForEach-Object{[double]$_}|Sort-Object);if($v.Count-eq0){return $null};$m=[int][math]::Floor($v.Count/2);if($v.Count%2){return [double]$v[$m]};([double]$v[$m-1]+[double]$v[$m])/2}
function Get-Mad($Values){$v=@($Values|Where-Object{$null-ne$_}|ForEach-Object{[double]$_});if($v.Count-eq0){return $null};$median=Get-Median $v;Get-Median @($v|ForEach-Object{[math]::Abs($_-$median)})}
function Get-Paths([string]$Dir){[pscustomobject]@{State=(Join-Path $Dir 'harness-state.json');ProviderState=(Join-Path $Dir 'provider-state.json');ProviderLog=(Join-Path $Dir 'provider-events.jsonl');Summary=(Join-Path $Dir 'summary.json')}}
function Resolve-RunDirectory {
    if($RunDirectory){return (Resolve-Path -LiteralPath $RunDirectory).Path}
    $active=Read-Json $ActivePointer
    if(-not $active.runDirectory){throw 'Active run pointer invalid.'}
    (Resolve-Path -LiteralPath ([string]$active.runDirectory)).Path
}
function Write-LabLog([string]$Dir,[string]$Event,[string]$Result,[hashtable]$Data){
    $row=[ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$Experiment;component='lab-harness';action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}
    ($row|ConvertTo-Json -Compress -Depth 14)|Add-Content -LiteralPath (Join-Path $Dir 'lab-events.jsonl') -Encoding UTF8
}
function Invoke-Provider([string]$ProviderAction,[string]$Dir,[switch]$WhatIfOnly){
    $p=Get-Paths $Dir;$args=@{Action=$ProviderAction;StatePath=$p.ProviderState;LogPath=$p.ProviderLog}
    if($WhatIfOnly){& $ProviderPath @args -WhatIf}else{& $ProviderPath @args}
}
function Get-ResumeTask {Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue}
function Register-ResumeTask([string]$Dir){
    if(Get-ResumeTask){throw "Scheduled task already exists: $TaskName"}
    $exe=(Get-Command powershell.exe -ErrorAction Stop).Source
    $args="-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Action Continue -RunDirectory `"$Dir`" -EvidenceRoot `"$EvidenceRoot`" -ProviderPath `"$ProviderPath`""
    $taskAction=New-ScheduledTaskAction -Execute $exe -Argument $args
    $user=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    $trigger=New-ScheduledTaskTrigger -AtLogOn -User $user
    $principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
    if($PSCmdlet.ShouldProcess($TaskName,'Register reversible reboot continuation task')){Register-ScheduledTask -TaskName $TaskName -Action $taskAction -Trigger $trigger -Principal $principal -Settings $settings|Out-Null}
}
function Remove-ResumeTask([string]$Dir){if(Get-ResumeTask){if($PSCmdlet.ShouldProcess($TaskName,'Remove reboot continuation task')){Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false;Write-LabLog $Dir 'continuation-task-removed' 'pass' @{task=$TaskName}}}}
function Get-ProtectedSnapshot {
    $services=@();foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','TermService'){try{$s=Get-Service $n -ErrorAction Stop;$services+=[pscustomobject]@{name=$n;status=$s.Status.ToString();startType=$s.StartType.ToString()}}catch{$services+=[pscustomobject]@{name=$n;status='absent';startType=$null}}}
    $processes=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)omnissa|horizon|msrdc|mstsc|tailscale|windowsapp'}|Select-Object ProcessName,Id,Responding)
    [pscustomobject]@{services=$services;processes=$processes}
}
function Get-TaskState($ProviderState){
    $task=Get-ScheduledTask -TaskName ([string]$ProviderState.task.TaskName) -TaskPath ([string]$ProviderState.task.TaskPath) -ErrorAction SilentlyContinue
    if(-not $task){return [pscustomobject]@{present=$false;enabled=$null}}
    [pscustomobject]@{present=$true;enabled=[bool]$task.Settings.Enabled}
}
function Assert-BaselineTask($ProviderState){$s=Get-TaskState $ProviderState;if(-not $s.present-or-not $s.enabled){throw 'Baseline Microsoft Teams sign-in task state drift detected.'}}
function Assert-TreatmentTask($ProviderState){$s=Get-TaskState $ProviderState;if(-not $s.present-or$s.enabled){throw 'Treatment Microsoft Teams sign-in task state drift detected.'}}
function Get-SystemSample {
    $cpu=(Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
    $disk=(Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'").DiskBytesPersec
    [pscustomobject]@{cpu=[double]$cpu;disk=[double]$disk}
}
function Get-TargetProcessSample([string]$Executable){
    $leaf=[IO.Path]::GetFileName($Executable);$rows=@()
    foreach($w in @(Get-CimInstance Win32_Process -Filter "Name='$leaf'" -ErrorAction SilentlyContinue)){
        if(-not $w.ExecutablePath){continue}
        try{if([IO.Path]::GetFullPath([string]$w.ExecutablePath)-ne[IO.Path]::GetFullPath($Executable)){continue}}catch{continue}
        $p=Get-Process -Id ([int]$w.ProcessId) -ErrorAction SilentlyContinue
        if($p){$rows+=[pscustomobject]@{pid=[int]$w.ProcessId;cpuMs=[double]$p.TotalProcessorTime.TotalMilliseconds;workingSetBytes=[int64]$p.WorkingSet64;readBytes=[uint64]$w.ReadTransferCount;writeBytes=[uint64]$w.WriteTransferCount}}
    }
    $rows
}
function Collect-Trial([string]$Phase,[int]$Ordinal,[string]$Dir,$ProviderState){
    $boot=Get-BootUtc;$protectedBefore=Get-ProtectedSnapshot;$collectorBefore=[double](Get-Process -Id $PID).TotalProcessorTime.TotalMilliseconds;$system=@();$target=@();$count=[int][math]::Ceiling($SampleSeconds/[double]$SampleIntervalSeconds)
    for($i=0;$i-lt$count;$i++){
        $system+=Get-SystemSample
        $target+=@(Get-TargetProcessSample ([string]$ProviderState.task.Action.Executable.Path)|ForEach-Object{[pscustomobject]@{sample=$i;pid=$_.pid;cpuMs=$_.cpuMs;workingSetBytes=$_.workingSetBytes;readBytes=$_.readBytes;writeBytes=$_.writeBytes}})
        if($i-lt$count-1){Start-Sleep -Seconds $SampleIntervalSeconds}
    }
    $collectorAfter=[double](Get-Process -Id $PID).TotalProcessorTime.TotalMilliseconds;$explorer=Get-Process explorer -ErrorAction SilentlyContinue|Sort-Object StartTime|Select-Object -First 1
    [ordered]@{schemaVersion=1;experiment=$Experiment;phase=$Phase;ordinal=$Ordinal;machine=$env:COMPUTERNAME;bootUtc=$boot.ToString('o');capturedUtc=(Get-Date).ToUniversalTime().ToString('o');task=(Get-TaskState $ProviderState);taskIdentity=[ordered]@{taskPath=[string]$ProviderState.task.TaskPath;taskName=[string]$ProviderState.task.TaskName;xmlSha256=[string]$ProviderState.task.XmlSha256;definitionSha256=[string]$ProviderState.task.DefinitionSha256};desktopProxy=[ordered]@{explorerPresent=[bool]$explorer;explorerResponding=if($explorer){[bool]$explorer.Responding}else{$false};bootToExplorerStartMs=if($explorer){($explorer.StartTime.ToUniversalTime()-$boot).TotalMilliseconds}else{$null}};system=[ordered]@{cpuMedianPercent=(Get-Median @($system|ForEach-Object{$_.cpu}));cpuMadPercent=(Get-Mad @($system|ForEach-Object{$_.cpu}));diskMedianBytesPerSec=(Get-Median @($system|ForEach-Object{$_.disk}));diskMadBytesPerSec=(Get-Mad @($system|ForEach-Object{$_.disk}))};targetProcess=[ordered]@{executable=[string]$ProviderState.task.Action.Executable.Path;observed=($target.Count-gt0);pids=@($target|Select-Object -ExpandProperty pid -Unique);peakWorkingSetBytes=if($target.Count){($target|Measure-Object workingSetBytes -Maximum).Maximum}else{$null};maxObservedCpuMs=if($target.Count){($target|Measure-Object cpuMs -Maximum).Maximum}else{$null};maxObservedReadBytes=if($target.Count){($target|Measure-Object readBytes -Maximum).Maximum}else{$null};maxObservedWriteBytes=if($target.Count){($target|Measure-Object writeBytes -Maximum).Maximum}else{$null}};protected=[ordered]@{before=$protectedBefore;after=(Get-ProtectedSnapshot)};functionalEvidence=[ordered]@{manualTeamsLaunch='needs-evidence';teamsSignIn='needs-evidence';messagingOrMeetingReadiness='needs-evidence';teamsServicingReadiness='needs-evidence';protectedApplicationConnectionReadiness='needs-evidence'};instrumentation=[ordered]@{collectorCpuDeltaMs=($collectorAfter-$collectorBefore);sampleCount=$system.Count;sampleIntervalSeconds=$SampleIntervalSeconds}}
}
function Summarize([string]$Dir){
    $runs=@(Get-ChildItem $Dir -Filter 'run-*.json' -File|Sort-Object Name|ForEach-Object{Read-Json $_.FullName});if($runs.Count-eq0){throw 'No runs found.'}
    $groups=[ordered]@{};foreach($phase in 'Baseline','Treatment'){$g=@($runs|Where-Object{$_.phase-eq$phase});$groups[$phase]=[ordered]@{runs=$g.Count;bootToExplorerStartMs=[ordered]@{median=(Get-Median @($g|ForEach-Object{$_.desktopProxy.bootToExplorerStartMs}));mad=(Get-Mad @($g|ForEach-Object{$_.desktopProxy.bootToExplorerStartMs}))};cpuMedianPercent=[ordered]@{median=(Get-Median @($g|ForEach-Object{$_.system.cpuMedianPercent}));mad=(Get-Mad @($g|ForEach-Object{$_.system.cpuMedianPercent}))};diskMedianBytesPerSec=[ordered]@{median=(Get-Median @($g|ForEach-Object{$_.system.diskMedianBytesPerSec}));mad=(Get-Mad @($g|ForEach-Object{$_.system.diskMedianBytesPerSec}))};targetPeakWorkingSetBytes=[ordered]@{median=(Get-Median @($g|ForEach-Object{$_.targetProcess.peakWorkingSetBytes}));mad=(Get-Mad @($g|ForEach-Object{$_.targetProcess.peakWorkingSetBytes}))}}}
    $rollback=@($runs|Where-Object{$_.phase-eq'RollbackVerify'}|Select-Object -Last 1)
    $summary=[ordered]@{schemaVersion=1;experiment=$Experiment;generatedUtc=(Get-Date).ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;groups=$groups;rollbackRebootVerified=($rollback.Count-eq1-and[bool]$rollback[0].task.present-and[bool]$rollback[0].task.enabled);remainingEvidence=@('Manual Teams launch to responsive UI','Teams sign-in and controlled messaging or meeting-readiness check','Teams supported update and servicing readiness','Timed Omnissa, Windows App, Remote Desktop, and Tailscale connection readiness','Instrumentation qualification beyond harness overhead');limitations=@('bootToExplorerStartMs is an Explorer-start readiness proxy rather than a complete usable-desktop marker','Target process sampling follows the captured Teams executable identity and can undercount descendant processes with different executable names')}
    Write-Json (Join-Path $Dir 'summary.json') $summary;$summary
}
function Reboot-IfAllowed([string]$Dir){if($AllowAutomaticReboot){Write-LabLog $Dir 'reboot-requested' 'pass' @{};Restart-Computer -Force}else{Write-LabLog $Dir 'reboot-required' 'needs-evidence' @{};Write-Output 'Reboot required. The continuation task resumes at the next interactive logon.'}}

Test-Elevation
if(-not(Test-Path -LiteralPath $ProviderPath)){throw 'EXP-125 provider missing.'}
try {
    switch($Action){
        'Start' {
            Ensure-Directory $EvidenceRoot
            if(Test-Path -LiteralPath $ActivePointer){throw 'An active EXP-125 run already exists.'}
            $check=Invoke-Provider 'Check' $EvidenceRoot
            if($WhatIfPreference){$null=$PSCmdlet.ShouldProcess($TaskName,"Prepare $RunsPerArm baseline and treatment boots plus rollback verification");return $check}
            $stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss');$dir=Join-Path $EvidenceRoot $stamp;Ensure-Directory $dir;$p=Get-Paths $dir
            Invoke-Provider 'Capture' $dir|Out-Null
            $state=[ordered]@{schemaVersion=1;phase='Baseline';completedRuns=0;runsPerArm=$RunsPerArm;lastBootUtc=$null;sampleSeconds=$SampleSeconds;sampleIntervalSeconds=$SampleIntervalSeconds}
            Write-Json $p.State $state;Write-Json $ActivePointer @{runDirectory=$dir};Register-ResumeTask $dir;Write-LabLog $dir 'started' 'pass' @{runsPerArm=$RunsPerArm;sampleSeconds=$SampleSeconds};Reboot-IfAllowed $dir
        }
        'Continue' {
            $dir=Resolve-RunDirectory;$p=Get-Paths $dir;$state=Read-Json $p.State;$providerState=Read-Json $p.ProviderState;$boot=(Get-BootUtc).ToString('o')
            if($state.lastBootUtc-eq$boot){throw 'Duplicate collection from the same boot refused.'}
            if($state.phase-eq'RollbackVerify'){
                Assert-BaselineTask $providerState
                $trial=Collect-Trial 'RollbackVerify' 1 $dir $providerState;Write-Json (Join-Path $dir 'run-RollbackVerify-01.json') $trial
                Summarize $dir|Out-Null;Remove-ResumeTask $dir;Remove-Item -LiteralPath $ActivePointer -Force;Write-LabLog $dir 'completed' 'pass' @{rollbackRebootVerified=$true};return (Read-Json $p.Summary)
            }
            if($state.phase-eq'Baseline'){Assert-BaselineTask $providerState}elseif($state.phase-eq'Treatment'){Invoke-Provider 'VerifyReboot' $dir|Out-Null;Assert-TreatmentTask $providerState}else{throw "Unknown harness phase: $($state.phase)"}
            $ordinal=[int]$state.completedRuns+1;$trial=Collect-Trial ([string]$state.phase) $ordinal $dir $providerState;Write-Json (Join-Path $dir ("run-{0}-{1:D2}.json" -f $state.phase,$ordinal)) $trial
            $state.completedRuns=$ordinal;$state.lastBootUtc=$boot
            if($state.completedRuns-ge[int]$state.runsPerArm){
                if($state.phase-eq'Baseline'){Invoke-Provider 'DryRun' $dir|Out-Null;Invoke-Provider 'Apply' $dir|Out-Null;Invoke-Provider 'Verify' $dir|Out-Null;$state.phase='Treatment';$state.completedRuns=0}
                else{Invoke-Provider 'Rollback' $dir|Out-Null;$state.phase='RollbackVerify';$state.completedRuns=0}
            }
            Write-Json $p.State $state;Write-LabLog $dir 'trial-collected' 'pass' @{phase=$trial.phase;ordinal=$ordinal;nextPhase=$state.phase};Reboot-IfAllowed $dir
        }
        'Status' {
            if(-not(Test-Path -LiteralPath $ActivePointer)){return [pscustomobject]@{Experiment=$Experiment;Active=$false}}
            $dir=Resolve-RunDirectory;$state=Read-Json (Get-Paths $dir).State;[pscustomobject]@{Experiment=$Experiment;Active=$true;RunDirectory=$dir;Phase=$state.phase;CompletedRuns=$state.completedRuns;RunsPerArm=$state.runsPerArm;LastBootUtc=$state.lastBootUtc}
        }
        'Summarize' {$dir=Resolve-RunDirectory;Summarize $dir}
        'Stop' {
            $dir=Resolve-RunDirectory;$p=Get-Paths $dir
            if(Test-Path -LiteralPath $p.ProviderState){try{Invoke-Provider 'Rollback' $dir|Out-Null;Write-LabLog $dir 'stop-rollback' 'pass' @{}}catch{Write-LabLog $dir 'stop-rollback' 'fail' @{failureDetail=$_.Exception.Message};throw}}
            Remove-ResumeTask $dir;if(Test-Path -LiteralPath $ActivePointer){Remove-Item -LiteralPath $ActivePointer -Force};Write-LabLog $dir 'stopped' 'pass' @{}
        }
    }
} catch {
    $dir=$null;try{$dir=if(Test-Path -LiteralPath $ActivePointer){Resolve-RunDirectory}else{$EvidenceRoot};Ensure-Directory $dir;Write-LabLog $dir 'failure' 'fail' @{stage=$Action;refusalReason=$_.Exception.Message;failureDetail=$_.Exception.ToString()}}catch{}
    throw
}
