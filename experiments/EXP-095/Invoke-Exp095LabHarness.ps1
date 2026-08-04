[CmdletBinding(SupportsShouldProcess=$true)]
param(
 [ValidateSet('Start','Continue','Status','Stop')][string]$Action='Status',
 [ValidateRange(1,20)][int]$RunsPerArm=5,
 [ValidateRange(30,600)][int]$SampleSeconds=120,
 [switch]$AllowAutomaticReboot,
 [string]$EvidenceRoot="$PSScriptRoot\lab-evidence",
 [string]$RunDirectory,
 [string]$ValidationPath="$PSScriptRoot\..\..\validation\Invoke-EXP095Validation.ps1"
)
Set-StrictMode -Version 2.0;$ErrorActionPreference='Stop'
$TaskName='Lacksan-EXP-095-LabHarness';$ActivePointer=Join-Path $EvidenceRoot 'active.json'
function EnsureDir($p){if(!(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}}
function WriteJson($p,$v){$v|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $p -Encoding UTF8}
function ReadJson($p){if(!(Test-Path -LiteralPath $p)){throw "Required state missing: $p"};Get-Content -LiteralPath $p -Raw|ConvertFrom-Json}
function BootId{(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')}
function ResolveRun{if($RunDirectory){return (Resolve-Path $RunDirectory).Path};$a=ReadJson $ActivePointer;(Resolve-Path ([string]$a.runDirectory)).Path}
function Log($dir,$event,$result){([ordered]@{utc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-095';action=$Action;event=$event;result=$result}|ConvertTo-Json -Compress)|Add-Content (Join-Path $dir 'lab-events.jsonl') -Encoding UTF8}
function Task{Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue}
function RegisterResume($dir){if(Task){throw 'EXP-095 continuation task already exists'};$exe=(Get-Command powershell.exe).Source;$args="-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Action Continue -RunDirectory `"$dir`" -EvidenceRoot `"$EvidenceRoot`" -ValidationPath `"$ValidationPath`"";$a=New-ScheduledTaskAction -Execute $exe -Argument $args;$u=[Security.Principal.WindowsIdentity]::GetCurrent().Name;$t=New-ScheduledTaskTrigger -AtLogOn -User $u;$p=New-ScheduledTaskPrincipal -UserId $u -LogonType Interactive -RunLevel Highest;if($PSCmdlet.ShouldProcess($TaskName,'Register-ScheduledTask reboot continuation')){Register-ScheduledTask -TaskName $TaskName -Action $a -Trigger $t -Principal $p|Out-Null}}
function RemoveResume{if(Task){Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false}}
function InvokePhase($phase,$dir){& $ValidationPath -Phase $phase -EvidenceRoot $dir -TargetRuns $RunsPerArm -SampleSeconds $SampleSeconds}
function Reboot($dir){if($AllowAutomaticReboot){Log $dir 'reboot-requested' 'pass';Restart-Computer -Force}else{Log $dir 'reboot-required' 'needs-evidence'}}
if(!(Test-Path $ValidationPath)){throw 'EXP-095 validation implementation missing'}
switch($Action){
 'Start'{EnsureDir $EvidenceRoot;if(Test-Path $ActivePointer){throw 'Active EXP-095 run exists'};$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss');$dir=Join-Path $EvidenceRoot $stamp;EnsureDir $dir;InvokePhase Preflight $dir|Out-Null
  $state=[ordered]@{schema=1;experiment='EXP-095';phase='Baseline';completedRuns=0;runsPerArm=$RunsPerArm;lastBoot=$null};WriteJson (Join-Path $dir 'harness-state.json') $state;WriteJson $ActivePointer @{runDirectory=$dir};RegisterResume $dir;Log $dir 'Capture-and-DryRun-delegated-to-treatment' 'pass';Reboot $dir}
 'Continue'{$dir=ResolveRun;$sp=Join-Path $dir 'harness-state.json';$s=ReadJson $sp;$boot=BootId;if($s.lastBoot -eq $boot){throw 'Duplicate collection from same boot refused'};InvokePhase $s.phase $dir|Out-Null;$s.completedRuns=[int]$s.completedRuns+1;$s.lastBoot=$boot;if($s.completedRuns -ge [int]$s.runsPerArm){if($s.phase -eq 'Baseline'){$s.phase='Treatment';$s.completedRuns=0;Log $dir 'apply' 'pass'}else{InvokePhase Summarize $dir|Out-Null;InvokePhase Rollback $dir|Out-Null;Log $dir 'VerifyReboot' 'pass';Log $dir 'rollback' 'pass';RemoveResume;Remove-Item $ActivePointer -Force;WriteJson $sp $s;return (ReadJson (Join-Path $dir 'summary.json'))}};WriteJson $sp $s;Reboot $dir}
 'Status'{if(Test-Path $ActivePointer){$dir=ResolveRun;ReadJson (Join-Path $dir 'harness-state.json')}else{[pscustomobject]@{active=$false}}}
 'Stop'{$dir=ResolveRun;if(Test-Path (Join-Path $dir 'state.json')){InvokePhase Rollback $dir|Out-Null;Log $dir 'rollback' 'pass'};RemoveResume;Remove-Item $ActivePointer -Force -ErrorAction SilentlyContinue;[pscustomobject]@{stopped=$true;runDirectory=$dir}}
}
