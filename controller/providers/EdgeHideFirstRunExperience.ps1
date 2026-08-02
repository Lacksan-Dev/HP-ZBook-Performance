[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action='Check',
    [string]$StatePath,
    [string]$LogPath,
    [string]$ProfileFixturePath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-138'; $provider='edge-hide-first-run-experience'; $profile='EdgeHideFirstRunExperience'
$policyPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge'; $valueName='HideFirstRunExperience'
$related=@('StartupBoostEnabled','BackgroundModeEnabled','SleepingTabsEnabled','NewTabPagePrerenderEnabled','BrowserSignin')

function Write-Log([string]$Event,[string]$Result,[object]$Data){
 if([string]::IsNullOrWhiteSpace($LogPath)){return}; $p=Split-Path -Parent $LogPath; if($p -and !(Test-Path $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
 [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;provider=$provider;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 20|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Test-Elevated { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
function Get-Reg([string]$Path,[string]$Name){
 if(!(Test-Path $Path)){return [pscustomobject]@{KeyExists=$false;ValueExists=$false;Kind=$null;Data=$null}}
 $k=Get-Item $Path; if($k.GetValueNames() -notcontains $Name){return [pscustomobject]@{KeyExists=$true;ValueExists=$false;Kind=$null;Data=$null}}
 [pscustomobject]@{KeyExists=$true;ValueExists=$true;Kind=$k.GetValueKind($Name).ToString();Data=$k.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
}
function Same($A,$B){($A|ConvertTo-Json -Compress -Depth 20) -eq ($B|ConvertTo-Json -Compress -Depth 20)}
function Get-Edge {
 $paths=@($env:ProgramFiles,${env:ProgramFiles(x86)})|Where-Object{$_}|ForEach-Object{Join-Path $_ 'Microsoft\Edge\Application\msedge.exe'}|Where-Object{Test-Path $_}|Select-Object -Unique
 $items=@($paths|ForEach-Object{$i=Get-Item $_;$s=Get-AuthenticodeSignature $_;$pub=if($s.SignerCertificate){$s.SignerCertificate.Subject}else{$null};[pscustomobject]@{Path=$i.FullName;Version=$i.VersionInfo.FileVersion;Major=[int]$i.VersionInfo.FileVersion.Split('.')[0];Sha256=(Get-FileHash $_ -Algorithm SHA256).Hash;Signature=$s.Status.ToString();Publisher=$pub;Thumbprint=if($s.SignerCertificate){$s.SignerCertificate.Thumbprint}else{$null};ValidPublisher=($s.Status -eq 'Valid' -and $pub -match 'Microsoft Corporation')}})
 if($items.Count -ne 1){return $null};$items[0]
}
function Get-Management {
 $c=Get-CimInstance Win32_ComputerSystem; $cfg=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
 $enroll=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName -match '^[0-9a-fA-F-]{36}$'}).Count
 $omadm=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts' -ErrorAction SilentlyContinue|Where-Object{$_.PSChildName -match '^[0-9a-fA-F-]{36}$'}).Count
 [pscustomobject]@{Managed=([bool]$c.PartOfDomain -or $cfg -or ($enroll -gt 0 -and $omadm -gt 0));DomainJoined=[bool]$c.PartOfDomain;ConfigMgr=$cfg;EnrollmentCount=$enroll;OmadmCount=$omadm}
}
function Get-StartupFolders {
 $shell=New-Object -ComObject WScript.Shell; $rows=@(); foreach($f in @([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))|Where-Object{$_}|Select-Object -Unique){if(Test-Path $f){foreach($i in Get-ChildItem $f -File -ErrorAction SilentlyContinue){$t=$null;if($i.Extension -eq '.lnk'){try{$t=$shell.CreateShortcut($i.FullName).TargetPath}catch{}};$rows+=[pscustomobject]@{Path=$i.FullName;Target=$t;Edge=[bool]($i.Name -match '(?i)edge|msedge' -or $t -match '(?i)\\msedge\.exe$')}}}}
 [pscustomobject]@{EdgeEntryCount=@($rows|Where-Object Edge).Count;Entries=$rows}
}
function Get-Fixture {
 if([string]::IsNullOrWhiteSpace($ProfileFixturePath) -or !(Test-Path -LiteralPath $ProfileFixturePath)){return $null}
 $m=Join-Path $ProfileFixturePath '.lacksan-pristine-edge-profile.json'; if(!(Test-Path $m)){return $null}; $x=Get-Content $m -Raw|ConvertFrom-Json
 if($x.experiment -ne 'EXP-138' -or $x.controlledPristineProfile -ne $true -or $x.firstRunComplete -ne $false){return $null}
 [pscustomobject]@{Path=(Resolve-Path $ProfileFixturePath).Path;Marker=$m;MarkerSha256=(Get-FileHash $m -Algorithm SHA256).Hash;Identity=[string]$x.profileId;FirstRunComplete=[bool]$x.firstRunComplete;ProductionProfile=$false}
}
function Get-Protected {
 $svc=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','edgeupdate','edgeupdatem')|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name|Select-Object Name,StartMode,PathName
 [pscustomobject]@{Services=@($svc)}
}
function Get-Policies { $r=[ordered]@{Main=Get-Reg $policyPath $valueName;Related=[ordered]@{}};foreach($n in $related){$r.Related[$n]=Get-Reg $policyPath $n};[pscustomobject]$r }
function Get-Support {
 $os=Get-CimInstance Win32_OperatingSystem;$pc=Get-CimInstance Win32_ComputerSystem;$edge=Get-Edge;$mgmt=Get-Management;$fix=Get-Fixture;$pol=Get-Policies;$startup=Get-StartupFolders
 [pscustomobject]@{Supported=($os.Caption -match 'Windows 11' -and $pc.Manufacturer -match '(?i)^HP$|Hewlett-Packard' -and (Test-Elevated) -and $edge -and $edge.Major -ge 80 -and $edge.ValidPublisher -and !$mgmt.Managed -and $fix -and !$pol.Main.ValueExists -and $startup.EdgeEntryCount -eq 0);OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$pc.Manufacturer;Model=$pc.Model;Elevated=(Test-Elevated);Edge=$edge;Management=$mgmt;Fixture=$fix;Policies=$pol;Startup=$startup}
}
function Assert-Supported($s){if(!$s.Supported){throw 'Unsupported, managed, ambiguous, existing-policy, production-profile, completed-first-run, unsigned Edge, or Startup-folder state.'}}
function Save-State($s){
 Assert-Supported $s;if([string]::IsNullOrWhiteSpace($StatePath)){throw 'StatePath is required.'};if(Test-Path $StatePath){throw 'State overwrite refused.'}
 $state=[ordered]@{schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;policyPath=$policyPath;valueName=$valueName;original=$s.Policies.Main;related=$s.Policies.Related;edge=$s.Edge;management=$s.Management;fixture=$s.Fixture;startupEdgeCount=$s.Startup.EdgeEntryCount;protected=Get-Protected}
 $p=Split-Path -Parent $StatePath;if($p -and !(Test-Path $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null};$state|ConvertTo-Json -Depth 20|Set-Content $StatePath -Encoding UTF8;[pscustomobject]$state
}
function Read-State {if([string]::IsNullOrWhiteSpace($StatePath) -or !(Test-Path $StatePath)){throw 'State artifact is missing.'};$s=Get-Content $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;if($s.schemaVersion -ne 1 -or $s.experiment -ne $experiment -or $s.provider -ne $provider -or $s.machine -ne $env:COMPUTERNAME -or $s.userSid -ne $sid){throw 'State identity validation failed.'};$s}
function Assert-DriftFree($s){
 $e=Get-Edge;if(!$e -or $e.Sha256 -ne $s.edge.Sha256 -or $e.Version -ne $s.edge.Version -or $e.Thumbprint -ne $s.edge.Thumbprint){throw 'Edge identity drift detected.'};if((Get-Management).Managed){throw 'Management ownership drift detected.'};$f=Get-Fixture;if(!$f -or $f.MarkerSha256 -ne $s.fixture.MarkerSha256 -or $f.Identity -ne $s.fixture.Identity -or $f.FirstRunComplete){throw 'Controlled pristine profile drift detected.'};$p=Get-Policies;if(!(Same $p.Related $s.related)){throw 'Related Edge policy drift detected.'};if((Get-StartupFolders).EdgeEntryCount -ne 0){throw 'Edge Startup-folder drift detected.'};if(!(Same (Get-Protected) $s.protected)){throw 'Protected service configuration drift detected.'}
}
function Test-Applied {$x=Get-Reg $policyPath $valueName;$x.ValueExists -and $x.Kind -eq 'DWord' -and [int]$x.Data -eq 1}
try{
 $support=Get-Support;Write-Log 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) $support
 switch($Action){
  'Check' {[pscustomobject]@{Support=$support;Profile=$profile}}
  'Capture' {$s=Save-State $support;Write-Log 'capture' 'pass' $s;$s}
  'DryRun' {Assert-Supported $support;$r=[pscustomobject]@{Profile=$profile;WouldChange=$true;MutationCount=1;Path=$policyPath;Name=$valueName;Type='DWord';Value=1;BrowserRestartRequired=$true;RebootPersistenceCheckRequired=$true;Rollback='Restore exact captured registry state or remove only experiment-created value/key.'};Write-Log 'dry-run' 'pass' $r;$r}
  'Apply' {$s=if($StatePath -and (Test-Path $StatePath)){Read-State}else{Save-State $support};Assert-DriftFree $s;if(Test-Applied){Write-Log 'apply' 'idempotent' @{mutationCount=0};return [pscustomobject]@{Applied=$true;MutationCount=0}};Assert-Supported $support;if($WhatIfPreference){Write-Log 'apply' 'whatif' @{mutationCount=0};return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$policyPath::$valueName",'Suppress Edge first-run experience for controlled pristine-profile comparison')){if(!(Test-Path $policyPath)){New-Item -Path $policyPath -Force|Out-Null};New-ItemProperty -Path $policyPath -Name $valueName -PropertyType DWord -Value 1 -Force|Out-Null};if(!(Test-Applied)){throw 'Apply verification failed.'};Write-Log 'apply' 'pass' @{mutationCount=1;browserRestartRequired=$true};[pscustomobject]@{Applied=$true;MutationCount=1;BrowserRestartRequired=$true}}
  'Verify' {$s=Read-State;Assert-DriftFree $s;if(!(Test-Applied)){throw 'Policy verification failed.'};$r=[pscustomobject]@{Verified=$true;BrowserRestartRequired=$true};Write-Log 'verify' 'pass' $r;$r}
  'VerifyReboot' {$s=Read-State;Assert-DriftFree $s;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot -le [datetime]$s.capturedBootTime){throw 'A later boot is required.'};if(!(Test-Applied)){throw 'Reboot persistence failed.'};$r=[pscustomobject]@{VerifiedReboot=$true;BootTime=$boot.ToString('o')};Write-Log 'verify-reboot' 'pass' $r;$r}
  'Rollback' {$s=Read-State;Assert-DriftFree $s;$now=Get-Reg $policyPath $valueName;if(!$now.ValueExists -and !$s.original.ValueExists){Write-Log 'rollback' 'idempotent' @{mutationCount=0};return [pscustomobject]@{RolledBack=$true;MutationCount=0}};if($s.original.ValueExists){if($now.ValueExists -and !((Same $now ([pscustomobject]@{KeyExists=$true;ValueExists=$true;Kind='DWord';Data=1})))){throw 'Policy drift detected; rollback overwrite refused.'};$kind=[Microsoft.Win32.RegistryValueKind]::$($s.original.Kind);$k=Get-Item $policyPath;$k.SetValue($valueName,$s.original.Data,$kind)}else{if($now.ValueExists -and !(Test-Applied)){throw 'Policy drift detected; rollback overwrite refused.'};if($now.ValueExists){Remove-ItemProperty -Path $policyPath -Name $valueName};if(!$s.original.KeyExists -and (Test-Path $policyPath) -and @((Get-Item $policyPath).GetValueNames()).Count -eq 0 -and @((Get-ChildItem $policyPath -ErrorAction SilentlyContinue)).Count -eq 0){Remove-Item $policyPath}};$after=Get-Reg $policyPath $valueName;if(!(Same $after $s.original)){throw 'Exact rollback verification failed.'};Write-Log 'rollback' 'pass' @{restoredExactOriginal=$true};[pscustomobject]@{RolledBack=$true;restoredExactOriginal=$true}}
 }
}catch{Write-Log 'failure' 'failure' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName};throw}
