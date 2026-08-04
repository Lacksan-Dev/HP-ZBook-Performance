[CmdletBinding(SupportsShouldProcess=$true)]
param(
 [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
 [string]$StatePath="$PSScriptRoot\state.json",
 [string]$LogPath="$PSScriptRoot\events.jsonl"
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ServiceName='HotKeyServiceUWP'
$ServiceKey="HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
$MinimumFixedVersion=[version]'8.10.50.393'

function Event([string]$Name,[hashtable]$Data){$d=Split-Path -Parent $LogPath;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$r=[ordered]@{utc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-120';action=$Action;event=$Name;computer=$env:COMPUTERNAME;userSid=([Security.Principal.WindowsIdentity]::GetCurrent().User.Value);data=$Data};($r|ConvertTo-Json -Compress -Depth 10)|Add-Content $LogPath -Encoding UTF8}
function Elevated {$p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent());if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Elevation required'}}
function Exe([string]$p){if($p.TrimStart().StartsWith('"')){$m=[regex]::Match($p,'^\s*"([^"]+)"')}else{$m=[regex]::Match($p,'^\s*([^\s]+\.exe)','IgnoreCase')};if(-not $m.Success){throw 'Service executable path unresolved'};$m.Groups[1].Value}
function Delayed {try{[int](Get-ItemProperty $ServiceKey -Name DelayedAutoStart -ErrorAction Stop).DelayedAutoStart}catch{0}}
function Mdm {$r='HKLM:\SOFTWARE\Microsoft\Enrollments';if(Test-Path $r){foreach($k in Get-ChildItem $r -ErrorAction SilentlyContinue){$p=Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue;if($p -and ($p.ProviderID -or $p.UPN -or $p.DiscoveryServiceFullURL)){return $true}}};$false}
function Candidate {
 Elevated;$os=Get-CimInstance Win32_OperatingSystem;$cs=Get-CimInstance Win32_ComputerSystem
 if($os.Caption -notmatch 'Windows 11' -or $cs.Manufacturer -notmatch 'HP|Hewlett-Packard'){throw 'Unsupported platform'}
 if($cs.PartOfDomain -or (Mdm)){throw 'Enterprise-managed state refused'}
 $m=@(Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue);if($m.Count -ne 1){throw 'Candidate absent or ambiguous'};$s=$m[0]
 if($s.DisplayName -notmatch '(?i)HP.*Hotkey.*UWP'){throw 'Display identity refused'};$e=Exe $s.PathName;if((Split-Path -Leaf $e) -notmatch '(?i)^HotKeyServiceUWP\.exe$'){throw 'Executable identity refused'}
 if(-not(Test-Path $e -PathType Leaf)){throw 'Executable missing'};$sig=Get-AuthenticodeSignature $e;if($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch '(?i)HP Inc|Hewlett-Packard'){throw 'HP publisher signature refused'}
 $v=(Get-Item $e).VersionInfo.FileVersion;if(-not $v){throw 'Version indeterminate'};try{$pv=[version]($v -replace '[^0-9\.].*$','')}catch{throw 'Version indeterminate'};if($pv -lt $MinimumFixedVersion){throw "HP Hotkey Support version below HPSBHF04102 fixed minimum $MinimumFixedVersion"}
 $g=Get-Service $ServiceName;$deps=@($g.ServicesDependedOn|% Name);$dependents=@($g.DependentServices|% Name);foreach($n in @($deps+$dependents)){if($n -match '(?i)WinDefend|mpssvc|bfe|wuauserv|bits|cryptsvc|Tailscale|TermService|RasMan|NlaSvc|Dhcp|Dnscache|Credential|Vault'){throw "Protected dependency refused: $n"}}
 if($s.StartMode -eq 'Disabled' -or $s.StartMode -eq 'Manual'){throw 'Manual or Disabled baseline refused'}
 [pscustomobject]@{Service=$s;Executable=$e;Version=$pv.ToString();Hash=(Get-FileHash $e -Algorithm SHA256).Hash;Signature=$sig.SignerCertificate.Subject;Delayed=(Delayed);Dependencies=$deps;Dependents=$dependents;WindowsBuild=$os.BuildNumber;Model=$cs.Model}
}
function Save($c){$d=Split-Path -Parent $StatePath;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$s=$c.Service;$o=[ordered]@{schema=1;computer=$env:COMPUTERNAME;service=$s.Name;displayName=$s.DisplayName;path=$s.PathName;executable=$c.Executable;version=$c.Version;hash=$c.Hash;signature=$c.Signature;startMode=$s.StartMode;delayed=[int]$c.Delayed;state=$s.State;account=$s.StartName;dependencies=@($c.Dependencies);dependents=@($c.Dependents);windowsBuild=$c.WindowsBuild;model=$c.Model;capturedUtc=(Get-Date).ToUniversalTime().ToString('o')};$o|ConvertTo-Json -Depth 8|Set-Content $StatePath -Encoding UTF8;Event 'state-captured' @{hash=$c.Hash;version=$c.Version;startMode=$s.StartMode;delayed=$c.Delayed};$o}
function ReadState {if(-not(Test-Path $StatePath)){throw 'State missing'};$s=Get-Content $StatePath -Raw|ConvertFrom-Json;if($s.schema -ne 1 -or $s.computer -ne $env:COMPUTERNAME -or $s.service -ne $ServiceName){throw 'State identity refused'};$s}
function Drift($s,$c){if($s.path -ne $c.Service.PathName -or $s.executable -ne $c.Executable -or $s.hash -ne $c.Hash -or $s.signature -ne $c.Signature -or $s.version -ne $c.Version){throw 'Service identity drift refused'};if(Compare-Object @($s.dependencies) @($c.Dependencies)){throw 'Dependency drift refused'};if(Compare-Object @($s.dependents) @($c.Dependents)){throw 'Dependent drift refused'}}
function SetMode([string]$mode,[int]$delay){Set-Service $ServiceName -StartupType $mode;Set-ItemProperty $ServiceKey -Name DelayedAutoStart -Type DWord -Value $delay}
$c=Candidate;$s=$c.Service
switch($Action){
 'Check'{Event 'supported' @{version=$c.Version;hash=$c.Hash;startMode=$s.StartMode;delayed=$c.Delayed};[pscustomobject]@{Name=$s.Name;StartMode=$s.StartMode;DelayedAutoStart=$c.Delayed;State=$s.State;Version=$c.Version;SHA256=$c.Hash;Model=$c.Model}}
 'DryRun'{Event 'dry-run' @{before=$s.StartMode;beforeDelayed=$c.Delayed;after='Auto';afterDelayed=1};$null=$PSCmdlet.ShouldProcess($ServiceName,'Set Automatic Delayed Start');[pscustomobject]@{Supported=$true;WouldChange=($s.StartMode-ne'Auto'-or$c.Delayed-ne 1);Before=$s.StartMode;BeforeDelayed=$c.Delayed;After='Auto';AfterDelayed=1}}
 'Capture'{Save $c|Out-Null}
 'Apply'{if($WhatIfPreference){Event 'dry-run' @{before=$s.StartMode;beforeDelayed=$c.Delayed;after='Auto';afterDelayed=1};$null=$PSCmdlet.ShouldProcess($ServiceName,'Set Automatic Delayed Start');break};if(-not(Test-Path $StatePath)){Save $c|Out-Null};if($s.StartMode -eq 'Auto' -and $c.Delayed -eq 1){Event 'already-applied' @{};break};if($s.StartMode -ne 'Auto'){throw 'Treatment requires Automatic baseline'};if($PSCmdlet.ShouldProcess($ServiceName,'Set Automatic Delayed Start')){SetMode Automatic 1}else{break};$a=Candidate;if($a.Service.StartMode -ne 'Auto' -or $a.Delayed -ne 1){throw 'Apply verification failed'};Event 'applied' @{delayed=1}}
 'Verify'{if($s.StartMode -ne 'Auto' -or $c.Delayed -ne 1){throw 'Verification failed'};Event 'verified' @{state=$s.State}}
 'VerifyReboot'{if($s.StartMode -ne 'Auto' -or $c.Delayed -ne 1){throw 'Reboot persistence failed'};Event 'reboot-verified' @{state=$s.State}}
 'Rollback'{$o=ReadState;Drift $o $c;if($WhatIfPreference){Event 'rollback-dry-run' @{restoreMode=$o.startMode;restoreDelayed=[int]$o.delayed;restoreState=$o.state};$null=$PSCmdlet.ShouldProcess($ServiceName,'Restore captured startup state');break};if($PSCmdlet.ShouldProcess($ServiceName,'Restore captured startup state')){SetMode Automatic ([int]$o.delayed);$st=(Get-Service $ServiceName).Status;if($o.state -eq 'Running' -and $st -ne 'Running'){Start-Service $ServiceName}elseif($o.state -eq 'Stopped' -and $st -eq 'Running'){Stop-Service $ServiceName -Force}};$a=Candidate;if($a.Service.StartMode -ne $o.startMode -or $a.Delayed -ne [int]$o.delayed){throw 'Rollback verification failed'};Event 'rolled-back' @{startMode=$a.Service.StartMode;delayed=$a.Delayed;state=$a.Service.State}}
}
