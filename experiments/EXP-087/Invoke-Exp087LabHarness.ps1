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
    [string]$ProviderPath="$PSScriptRoot\..\..\controller\providers\HPSupportSolutionsFrameworkManual.ps1"
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($Unattended){$ConfirmPreference='None'}
$TaskName='Lacksan-EXP-087-LabHarness'
$ActivePointer=Join-Path $EvidenceRoot 'active.json'

function Elevated {
    $p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Ensure($p){if(!(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}}
function WriteJson($p,$v){$v|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $p -Encoding UTF8}
function ReadJson($p){if(!(Test-Path -LiteralPath $p)){throw "Missing evidence state: $p"};Get-Content -LiteralPath $p -Raw|ConvertFrom-Json}
function Median($x){$v=@($x|Where-Object{$null-ne$_}|ForEach-Object{[double]$_}|Sort-Object);if(!$v.Count){return $null};$m=[math]::Floor($v.Count/2);if($v.Count%2){return $v[$m]};($v[$m-1]+$v[$m])/2}
function Mad($x){$v=@($x|Where-Object{$null-ne$_}|ForEach-Object{[double]$_});if(!$v.Count){return $null};$m=Median $v;Median @($v|ForEach-Object{[math]::Abs($_-$m)})}
function Boot{(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()}
function Paths($d){[pscustomobject]@{Harness=Join-Path $d 'harness-state.json';Provider=Join-Path $d 'provider-state.json';Log=Join-Path $d 'provider-events.jsonl';Summary=Join-Path $d 'summary.json'}}
function ActiveDir{if($RunDirectory){return (Resolve-Path $RunDirectory).Path};$a=ReadJson $ActivePointer;(Resolve-Path ([string]$a.runDirectory)).Path}
function Log($d,$event,$data){[ordered]@{schema=1;utc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-087';event=$event;computer=$env:COMPUTERNAME;data=$data}|ConvertTo-Json -Compress -Depth 12|Add-Content (Join-Path $d 'lab-events.jsonl') -Encoding UTF8}
function Provider($a,$d){$p=Paths $d;& $ProviderPath -Action $a -StatePath $p.Provider -LogPath $p.Log -Confirm:$false}
function Protected{[pscustomobject]@{services=@('WinDefend','mpssvc','wuauserv','TermService','Tailscale'|ForEach-Object{$s=Get-Service $_ -ErrorAction SilentlyContinue;if($s){[pscustomobject]@{name=$_.ToString();status=$s.Status.ToString();startType=$s.StartType.ToString()}}});processes=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)tailscale|msrdc|windowsapp|omnissa|horizon|vmware-view|wswc'}|Select-Object ProcessName,Id,Responding)}}
function SampleSystem{[pscustomobject]@{cpu=[double](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime;disk=[double](Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'").DiskBytesPersec}}
function FrameworkProcesses{@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.Path-match'(?i)HP.*Support.*Solutions|HPSF'}|Select-Object Id,ProcessName,Path,CPU,WorkingSet64)}
function Collect($phase,$ordinal,$d){
    $boot=Boot;$before=FrameworkProcesses;$pb=Protected;$self0=(Get-Process -Id $PID).TotalProcessorTime.TotalMilliseconds;$samples=@();$n=[math]::Ceiling($SampleSeconds/[double]$SampleIntervalSeconds)
    for($i=0;$i-lt$n;$i++){$samples+=SampleSystem;if($i-lt$n-1){Start-Sleep $SampleIntervalSeconds}}
    $after=FrameworkProcesses;$self1=(Get-Process -Id $PID).TotalProcessorTime.TotalMilliseconds;$explorer=Get-Process explorer -ErrorAction SilentlyContinue|Sort-Object StartTime|Select-Object -First 1
    [ordered]@{schema=1;experiment='EXP-087';phase=$phase;ordinal=$ordinal;computer=$env:COMPUTERNAME;bootUtc=$boot.ToString('o');capturedUtc=(Get-Date).ToUniversalTime().ToString('o');desktop=[ordered]@{explorerPresent=[bool]$explorer;bootToExplorerStartMs=if($explorer){($explorer.StartTime.ToUniversalTime()-$boot).TotalMilliseconds}else{$null}};system=[ordered]@{cpuMedianPercent=Median @($samples.cpu);cpuMadPercent=Mad @($samples.cpu);diskMedianBytesPerSec=Median @($samples.disk);diskMadBytesPerSec=Mad @($samples.disk)};framework=[ordered]@{before=$before;after=$after};protected=[ordered]@{before=$pb;after=Protected};functional=[ordered]@{hpProductDetection='needs-evidence';hpDiagnostics='needs-evidence';localhostEndpoint='needs-evidence';demandOrManualStart='needs-evidence'};instrumentation=[ordered]@{collectorCpuDeltaMs=$self1-$self0;sampleCount=$samples.Count}}
}
function Summary($d){
    $r=@(Get-ChildItem $d -Filter 'run-*.json' -File|Sort-Object Name|ForEach-Object{ReadJson $_.FullName});$g=[ordered]@{}
    foreach($phase in 'Baseline','Treatment'){$x=@($r|Where-Object{$_.phase-eq$phase});$g[$phase]=[ordered]@{runs=$x.Count;bootToExplorerStartMs=[ordered]@{median=Median @($x.desktop.bootToExplorerStartMs);mad=Mad @($x.desktop.bootToExplorerStartMs)};cpuMedianPercent=[ordered]@{median=Median @($x.system.cpuMedianPercent);mad=Mad @($x.system.cpuMedianPercent)};diskMedianBytesPerSec=[ordered]@{median=Median @($x.system.diskMedianBytesPerSec);mad=Mad @($x.system.diskMedianBytesPerSec)}}}
    $s=[ordered]@{schema=1;experiment='EXP-087';generatedUtc=(Get-Date).ToUniversalTime().ToString('o');groups=$g;classification=if($g.Baseline.runs-lt$RunsPerArm-or$g.Treatment.runs-lt$RunsPerArm){'inconclusive'}else{'needs-functional-evidence'};functionalEvidence='needs-evidence';limitations=@('Explorer start is a usable-desktop proxy','HP product detection, diagnostics, localhost endpoint, and demand/manual-start require physical observation')};WriteJson (Paths $d).Summary $s;$s
}
function Task{Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue}
function RegisterTask($d){
    if(Task){throw 'Continuation task already exists'};$exe=(Get-Command powershell.exe).Source;$arg="-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Action Continue -Unattended -RunDirectory `"$d`" -EvidenceRoot `"$EvidenceRoot`" -ProviderPath `"$ProviderPath`"";if($AllowAutomaticReboot){$arg+=' -AllowAutomaticReboot'}
    $a=New-ScheduledTaskAction -Execute $exe -Argument $arg;$u=[Security.Principal.WindowsIdentity]::GetCurrent().Name;$t=New-ScheduledTaskTrigger -AtLogOn -User $u;$pr=New-ScheduledTaskPrincipal -UserId $u -LogonType Interactive -RunLevel Highest
    if($PSCmdlet.ShouldProcess($TaskName,'Register continuation task')){Register-ScheduledTask -TaskName $TaskName -Action $a -Trigger $t -Principal $pr|Out-Null}
}
function RemoveTask($d){if(Task){Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false;Log $d 'continuation-task-removed' @{}}}
function Reboot($d){if($AllowAutomaticReboot){Log $d 'reboot-requested' @{};Restart-Computer -Force}else{Log $d 'reboot-required' @{};Write-Output 'Reboot required; continuation resumes at next logon.'}}

if(!(Elevated)){throw 'Elevation required'}
if(!(Test-Path $ProviderPath)){throw 'EXP-087 provider missing'}

switch($Action){
    'Start'{Ensure $EvidenceRoot;if(Test-Path $ActivePointer){throw 'Active EXP-087 run exists'};$check=Provider 'Check' $EvidenceRoot;if(!$check.Supported){throw ($check.Reasons-join'; ')};if($WhatIfPreference){return $check};$d=Join-Path $EvidenceRoot (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss');Ensure $d;$p=Paths $d;Provider 'Capture' $d|Out-Null;Provider 'DryRun' $d|Out-Null;WriteJson $p.Harness ([ordered]@{schema=1;phase='Baseline';completedRuns=0;runsPerArm=$RunsPerArm;lastBootUtc=$null});WriteJson $ActivePointer @{runDirectory=$d};RegisterTask $d;Log $d 'started' @{runsPerArm=$RunsPerArm;sampleSeconds=$SampleSeconds;dryRun='pass';automaticReboot=[bool]$AllowAutomaticReboot};Reboot $d}
    'Continue'{$d=ActiveDir;$p=Paths $d;$s=ReadJson $p.Harness;$b=(Boot).ToString('o');if($s.lastBootUtc-eq$b){throw 'Duplicate collection from same boot refused'};if($s.phase-eq'Treatment'){Provider 'VerifyReboot' $d|Out-Null};$n=[int]$s.completedRuns+1;$trial=Collect $s.phase $n $d;WriteJson (Join-Path $d ("run-{0}-{1:D2}.json"-f$s.phase,$n)) $trial;$s.completedRuns=$n;$s.lastBootUtc=$b;if($n-ge[int]$s.runsPerArm){if($s.phase-eq'Baseline'){$s.phase='Treatment';$s.completedRuns=0;Provider 'Apply' $d|Out-Null;Provider 'Verify' $d|Out-Null}else{Provider 'Rollback' $d|Out-Null;WriteJson $p.Harness $s;$out=Summary $d;RemoveTask $d;Remove-Item $ActivePointer -Force;Log $d 'completed' @{classification=$out.classification};return $out}};WriteJson $p.Harness $s;Log $d 'trial-collected' @{phase=$trial.phase;ordinal=$n};Reboot $d}
    'Status'{if(Test-Path $ActivePointer){$d=ActiveDir;ReadJson (Paths $d).Harness}else{[pscustomobject]@{active=$false}}}
    'Summarize'{$d=ActiveDir;Summary $d}
    'Stop'{$d=ActiveDir;Provider 'Rollback' $d|Out-Null;RemoveTask $d;Remove-Item $ActivePointer -Force -ErrorAction SilentlyContinue;Log $d 'stopped' @{};[pscustomobject]@{stopped=$true;runDirectory=$d}}
}
