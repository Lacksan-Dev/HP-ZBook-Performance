[CmdletBinding(SupportsShouldProcess=$true)]
param(
 [ValidateSet('Start','Continue','Stop','Summary')][string]$Action='Start',
 [ValidateRange(3,20)][int]$RunsPerArm=5,
 [ValidateRange(30,600)][int]$SampleSeconds=120,
 [switch]$AllowAutomaticReboot,
 [string]$SessionPath="$PSScriptRoot\lab-session.json"
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Provider=Join-Path $PSScriptRoot 'Invoke-Exp131HpCommRecovery.ps1'
$TaskName='Lacksan-EXP131-LabContinuation'
function Save($s){$s|ConvertTo-Json -Depth 12|Set-Content $SessionPath}
function Load{if(-not(Test-Path $SessionPath)){throw 'EXP-131 lab session missing'};Get-Content $SessionPath -Raw|ConvertFrom-Json}
function Median($a){$x=@($a|Sort-Object);if(!$x.Count){return $null};$m=[int]($x.Count/2);if($x.Count%2){[double]$x[$m]}else{([double]$x[$m-1]+[double]$x[$m])/2}}
function Mad($a){if(!$a.Count){return $null};$m=Median $a;Median @($a|%{[math]::Abs([double]$_-$m)})}
function BootId{(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')}
function Protected{[ordered]@{Tailscale=@(Get-Service -Name 'Tailscale*' -ErrorAction SilentlyContinue|%{$_.Status.ToString()});RemoteDesktop=@(Get-Service TermService -ErrorAction SilentlyContinue|%{$_.Status.ToString()});Omnissa=@(Get-Process -ErrorAction SilentlyContinue|?{$_.ProcessName -match '(?i)vmware|omnissa'}|% ProcessName);WindowsApp=@(Get-Process -ErrorAction SilentlyContinue|?{$_.ProcessName -match '(?i)msrdc|rdclient|windowsapp'}|% ProcessName)}}
function Sample($seconds){$cpu0=(Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue;$disk0=(Get-Counter '\PhysicalDisk(_Total)\Disk Bytes/sec').CounterSamples.CookedValue;$p0=@(Get-Process HPCommRecovery -ErrorAction SilentlyContinue);Start-Sleep -Seconds $seconds;$cpu1=(Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue;$disk1=(Get-Counter '\PhysicalDisk(_Total)\Disk Bytes/sec').CounterSamples.CookedValue;$p1=@(Get-Process HPCommRecovery -ErrorAction SilentlyContinue);[ordered]@{cpuPct=($cpu0+$cpu1)/2;diskBytesPerSec=($disk0+$disk1)/2;serviceCpuSeconds=(@($p1|% CPU|Measure-Object -Sum).Sum);serviceWorkingSet=(@($p1|% WorkingSet64|Measure-Object -Sum).Sum);protected=Protected}}
function RegisterContinuation{if(Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue){throw 'Continuation task identity already exists'};$arg="-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Action Continue -RunsPerArm $RunsPerArm -SampleSeconds $SampleSeconds -SessionPath `"$SessionPath`"";if($AllowAutomaticReboot){$arg+=' -AllowAutomaticReboot'};$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg;$t=New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME;$p=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest;Register-ScheduledTask -TaskName $TaskName -Action $a -Trigger $t -Principal $p|Out-Null}
function RemoveContinuation{Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue}
function Summarize($s){$o=[ordered]@{};foreach($arm in 'Baseline','Treatment'){$r=@($s.runs|? arm -eq $arm);$o[$arm]=[ordered]@{runs=$r.Count;cpuMedian=Median @($r|%{$_.metrics.cpuPct});cpuMad=Mad @($r|%{$_.metrics.cpuPct});diskMedian=Median @($r|%{$_.metrics.diskBytesPerSec});diskMad=Mad @($r|%{$_.metrics.diskBytesPerSec});serviceCpuMedian=Median @($r|%{$_.metrics.serviceCpuSeconds});serviceCpuMad=Mad @($r|%{$_.metrics.serviceCpuSeconds})}};$o}
if($Action -eq 'Start'){if(Test-Path $SessionPath){throw 'Existing session refused'};& $Provider -Action Check|Out-Null;& $Provider -Action Capture;$s=[ordered]@{schema=1;experiment='EXP-131';runsPerArm=$RunsPerArm;sampleSeconds=$SampleSeconds;phase='Baseline';lastBoot=$null;runs=@();created=(Get-Date).ToUniversalTime().ToString('o')};Save $s;RegisterContinuation;Write-Output 'EXP-131 session armed. Reboot to collect baseline.';return}
if($Action -eq 'Stop'){$s=Load;try{& $Provider -Action Rollback}catch{};RemoveContinuation;$s.phase='Stopped';Save $s;return}
$s=Load
if($Action -eq 'Summary'){Summarize $s|ConvertTo-Json -Depth 8;return}
$boot=BootId;if($s.lastBoot -eq $boot){throw 'Duplicate collection from same boot refused'}
if($s.phase -eq 'Treatment'){& $Provider -Action VerifyReboot}
$m=Sample ([int]$s.sampleSeconds);$s.runs+=@([ordered]@{arm=$s.phase;boot=$boot;utc=(Get-Date).ToUniversalTime().ToString('o');metrics=$m});$s.lastBoot=$boot
$armCount=@($s.runs|? arm -eq $s.phase).Count
if($s.phase -eq 'Baseline' -and $armCount -ge [int]$s.runsPerArm){& $Provider -Action Apply;& $Provider -Action Verify;$s.phase='Treatment'}
elseif($s.phase -eq 'Treatment' -and $armCount -ge [int]$s.runsPerArm){& $Provider -Action Rollback;$s.phase='RollbackVerification'}
elseif($s.phase -eq 'RollbackVerification'){& $Provider -Action Check|Out-Null;$s.phase='Complete';$s.summary=Summarize $s;RemoveContinuation}
Save $s
if($s.phase -ne 'Complete' -and $AllowAutomaticReboot){Restart-Computer -Force}
elseif($s.phase -ne 'Complete'){Write-Output "EXP-131 collected $armCount run(s); reboot when ready to continue."}
else{$s.summary|ConvertTo-Json -Depth 8}
