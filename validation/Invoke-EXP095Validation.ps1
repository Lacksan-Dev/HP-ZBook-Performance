[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [ValidateSet('Preflight','Baseline','Treatment','Summarize','Rollback')][string]$Phase='Summarize',
  [string]$EvidenceRoot="$PSScriptRoot/../evidence/EXP-095",
  [int]$TargetRuns=5,
  [int]$SampleSeconds=120,
  [switch]$AllowReboot
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$provider=Join-Path $PSScriptRoot '../controller/providers/HPCaslDelayedStart.ps1'
$state=Join-Path $EvidenceRoot 'state.json'
$log=Join-Path $EvidenceRoot 'provider.jsonl'
$raw=Join-Path $EvidenceRoot 'raw'
New-Item -ItemType Directory -Force -Path $raw | Out-Null
function Median([double[]]$v){if(!$v-or$v.Count-eq0){return $null};$s=@($v|Sort-Object);$n=$s.Count;if($n%2){[double]$s[[int]($n/2)]}else{([double]$s[$n/2-1]+[double]$s[$n/2])/2}}
function Mad([double[]]$v){if(!$v-or$v.Count-eq0){return $null};$m=Median $v;Median @($v|ForEach-Object{[math]::Abs($_-$m)})}
function Improvement($baseline,$treatment){if($null-ne$baseline-and[double]$baseline-ne0-and$null-ne$treatment){100*([double]$baseline-[double]$treatment)/[double]$baseline}else{$null}}
function BootId{(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')}
function Protected{[ordered]@{Tailscale=[bool](Get-Service Tailscale -ErrorAction SilentlyContinue);Rdp=[bool](Get-Process mstsc,msrdc -ErrorAction SilentlyContinue);Omnissa=[bool](Get-Process vmware-view,horizon-client -ErrorAction SilentlyContinue);Defender=[bool](Get-Service WinDefend -ErrorAction SilentlyContinue);Firewall=[bool](Get-Service mpssvc -ErrorAction SilentlyContinue)}}
function Collect([string]$kind){
  $boot=BootId;$existing=@(Get-ChildItem $raw -Filter "$kind-*.json" -ErrorAction SilentlyContinue|ForEach-Object{Get-Content $_.FullName -Raw|ConvertFrom-Json});if($existing.bootId -contains $boot){throw 'This boot already has a run for this phase.'};if($existing.Count-ge$TargetRuns){throw 'Target run count already reached.'}
  $cpu0=(Get-Process|Measure-Object CPU -Sum).Sum;$t0=Get-Date
  $diskSamples=@((Get-Counter '\PhysicalDisk(_Total)\Disk Bytes/sec' -SampleInterval 1 -MaxSamples $SampleSeconds).CounterSamples|ForEach-Object{[double]$_.CookedValue})
  $cpu1=(Get-Process|Measure-Object CPU -Sum).Sum;$casl=Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.Path -match'(?i)hpqcaslwmiex'}|Select-Object ProcessName,Id,CPU,WorkingSet64,Path
  $diskAverage=if($diskSamples.Count){[double](($diskSamples|Measure-Object -Average).Average)}else{0.0}
  $r=[ordered]@{schemaVersion=1;experiment='EXP-095';phase=$kind;run=$existing.Count+1;bootId=$boot;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');sampleSeconds=$SampleSeconds;elapsedSeconds=((Get-Date)-$t0).TotalSeconds;processCpuDeltaSeconds=[double]($cpu1-$cpu0);diskBytesPerSecondAverage=$diskAverage;diskSampleCount=$diskSamples.Count;casl=@($casl);protected=Protected;machine=$env:COMPUTERNAME;windowsBuild=(Get-CimInstance Win32_OperatingSystem).BuildNumber;model=(Get-CimInstance Win32_ComputerSystem).Model;bios=(Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion}
  $path=Join-Path $raw ("{0}-{1:D2}.json"-f$kind,$r.run);$r|ConvertTo-Json -Depth 12|Set-Content $path -Encoding UTF8;$r
}
function Summary{
  $runs=@(Get-ChildItem $raw -Filter '*.json' -ErrorAction SilentlyContinue|ForEach-Object{Get-Content $_.FullName -Raw|ConvertFrom-Json});$b=@($runs|Where-Object phase -eq Baseline);$t=@($runs|Where-Object phase -eq Treatment)
  $cpuBm=Median @($b|ForEach-Object{[double]$_.processCpuDeltaSeconds});$cpuTm=Median @($t|ForEach-Object{[double]$_.processCpuDeltaSeconds});$cpuPct=Improvement $cpuBm $cpuTm
  $diskBm=Median @($b|ForEach-Object{[double]$_.diskBytesPerSecondAverage});$diskTm=Median @($t|ForEach-Object{[double]$_.diskBytesPerSecondAverage});$diskPct=Improvement $diskBm $diskTm
  $class=if($b.Count-lt$TargetRuns-or$t.Count-lt$TargetRuns){'inconclusive'}elseif(($null-ne$cpuPct-and$cpuPct-lt-1)-or($null-ne$diskPct-and$diskPct-lt-1)){'failed'}elseif(($null-ne$cpuPct-and$cpuPct-gt1)-or($null-ne$diskPct-and$diskPct-gt1)){'favorable'}else{'zero-benefit'}
  $s=[ordered]@{schemaVersion=1;experiment='EXP-095';baselineRuns=$b.Count;treatmentRuns=$t.Count;metric='processCpuDeltaSeconds';baselineMedian=$cpuBm;baselineMAD=Mad @($b|ForEach-Object{[double]$_.processCpuDeltaSeconds});treatmentMedian=$cpuTm;treatmentMAD=Mad @($t|ForEach-Object{[double]$_.processCpuDeltaSeconds});improvementPercent=$cpuPct;diskMetric='diskBytesPerSecondAverage';diskBaselineMedian=$diskBm;diskBaselineMAD=Mad @($b|ForEach-Object{[double]$_.diskBytesPerSecondAverage});diskTreatmentMedian=$diskTm;diskTreatmentMAD=Mad @($t|ForEach-Object{[double]$_.diskBytesPerSecondAverage});diskImprovementPercent=$diskPct;classification=$class;rawRuns=@($runs|Select-Object phase,run,bootId,capturedUtc)};$s|ConvertTo-Json -Depth 8|Set-Content (Join-Path $EvidenceRoot 'summary.json') -Encoding UTF8;$s
}
switch($Phase){
 'Preflight'{& $provider -Action Check -LogPath $log|Out-Null;& $provider -Action DryRun -LogPath $log|Out-Null}
 'Baseline'{& $provider -Action Check -LogPath $log|Out-Null;Collect Baseline}
 'Treatment'{if(!(Test-Path $state)){& $provider -Action Capture -StatePath $state -LogPath $log|Out-Null;& $provider -Action DryRun -StatePath $state -LogPath $log|Out-Null;& $provider -Action Apply -StatePath $state -LogPath $log|Out-Null;& $provider -Action Verify -StatePath $state -LogPath $log|Out-Null}else{& $provider -Action VerifyReboot -StatePath $state -LogPath $log|Out-Null};Collect Treatment}
 'Summarize'{Summary}
 'Rollback'{& $provider -Action Rollback -StatePath $state -LogPath $log|Out-Null}
}
if($AllowReboot-and$Phase-in@('Baseline','Treatment')){if($PSCmdlet.ShouldProcess($env:COMPUTERNAME,'Restart for next EXP-095 run')){Restart-Computer -Force}}
