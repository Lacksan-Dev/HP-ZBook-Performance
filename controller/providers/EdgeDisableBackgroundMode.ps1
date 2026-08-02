[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action='Check',
    [string]$StatePath,
    [string]$LogPath,
    [string]$ProfileFixturePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-130'
$provider='edge-disable-background-mode'
$profile='EdgeDisableBackgroundMode'
$policyPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
$mandatoryPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$valueName='BackgroundModeEnabled'
$related=@('StartupBoostEnabled','EfficiencyModeEnabled','SleepingTabsEnabled','NewTabPagePrerenderEnabled','HardwareAccelerationModeEnabled','NetworkPredictionOptions')

function Write-Log([string]$Event,[string]$Result,[object]$Data) {
    if([string]::IsNullOrWhiteSpace($LogPath)){ return }
    $parent=Split-Path -Parent $LogPath
    if($parent -and !(Test-Path -LiteralPath $parent)){ New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [ordered]@{
        schemaVersion=1; timestampUtc=(Get-Date).ToUniversalTime().ToString('o'); experiment=$experiment; provider=$provider
        action=$Action; event=$Event; result=$Result; machine=$env:COMPUTERNAME
        userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value; data=$Data
    } | ConvertTo-Json -Compress -Depth 20 | Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Test-Elevated {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Get-Reg([string]$Path,[string]$Name) {
    if(!(Test-Path -LiteralPath $Path)){ return [pscustomobject]@{KeyExists=$false;ValueExists=$false;Kind=$null;Data=$null} }
    $key=Get-Item -LiteralPath $Path
    if($key.GetValueNames() -notcontains $Name){ return [pscustomobject]@{KeyExists=$true;ValueExists=$false;Kind=$null;Data=$null} }
    [pscustomobject]@{KeyExists=$true;ValueExists=$true;Kind=$key.GetValueKind($Name).ToString();Data=$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
}
function Same($A,$B) { ($A|ConvertTo-Json -Compress -Depth 20) -eq ($B|ConvertTo-Json -Compress -Depth 20) }
function Get-Edge {
    $paths=@($env:ProgramFiles,${env:ProgramFiles(x86)}) | Where-Object { $_ } | ForEach-Object { Join-Path $_ 'Microsoft\Edge\Application\msedge.exe' } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -Unique
    $items=@($paths | ForEach-Object {
        $item=Get-Item -LiteralPath $_; $sig=Get-AuthenticodeSignature -LiteralPath $_; $publisher=if($sig.SignerCertificate){$sig.SignerCertificate.Subject}else{$null}
        [pscustomobject]@{Path=$item.FullName;Version=$item.VersionInfo.FileVersion;Major=[int]$item.VersionInfo.FileVersion.Split('.')[0];Sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash;Signature=$sig.Status.ToString();Publisher=$publisher;Thumbprint=if($sig.SignerCertificate){$sig.SignerCertificate.Thumbprint}else{$null};ValidPublisher=($sig.Status -eq 'Valid' -and $publisher -match 'Microsoft Corporation')}
    })
    if($items.Count -ne 1){ return $null }; $items[0]
}
function Get-Management {
    $computer=Get-CimInstance Win32_ComputerSystem
    $configMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
    $enroll=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue | Where-Object {$_.PSChildName -match '^[0-9a-fA-F-]{36}$'}).Count
    $omadm=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts' -ErrorAction SilentlyContinue | Where-Object {$_.PSChildName -match '^[0-9a-fA-F-]{36}$'}).Count
    [pscustomobject]@{Managed=([bool]$computer.PartOfDomain -or $configMgr -or ($enroll -gt 0 -and $omadm -gt 0));DomainJoined=[bool]$computer.PartOfDomain;ConfigMgr=$configMgr;EnrollmentCount=$enroll;OmadmCount=$omadm}
}
function Get-Fixture {
    if([string]::IsNullOrWhiteSpace($ProfileFixturePath) -or !(Test-Path -LiteralPath $ProfileFixturePath)){ return $null }
    $marker=Join-Path $ProfileFixturePath '.lacksan-edge-background-mode.json'
    if(!(Test-Path -LiteralPath $marker)){ return $null }
    $x=Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
    if($x.experiment -ne 'EXP-130' -or $x.controlledProfile -ne $true -or $x.backgroundAppPresent -ne $true -or $x.baselineBackgroundModeEnabled -ne $true){ return $null }
    [pscustomobject]@{Path=(Resolve-Path -LiteralPath $ProfileFixturePath).Path;Marker=$marker;MarkerSha256=(Get-FileHash -LiteralPath $marker -Algorithm SHA256).Hash;Identity=[string]$x.profileId;ControlledProfile=$true;BackgroundAppPresent=$true;BaselineBackgroundModeEnabled=$true}
}
function Get-StartupFolders {
    $shell=New-Object -ComObject WScript.Shell; $rows=@()
    foreach($folder in @([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup')) | Where-Object {$_} | Select-Object -Unique){
        if(Test-Path -LiteralPath $folder){
            foreach($item in Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue){
                $target=$null; if($item.Extension -eq '.lnk'){ try{$target=$shell.CreateShortcut($item.FullName).TargetPath}catch{} }
                $rows += [pscustomobject]@{Path=$item.FullName;Target=$target;Edge=[bool]($item.Name -match '(?i)edge|msedge' -or $target -match '(?i)\\msedge\.exe$')}
            }
        }
    }
    [pscustomobject]@{EdgeEntryCount=@($rows|Where-Object Edge).Count;Entries=$rows}
}
function Get-Protected {
    $services=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','TermService','edgeupdate','edgeupdatem') | ForEach-Object { Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue } | Where-Object {$_} | Sort-Object Name | Select-Object Name,StartMode,PathName
    $remotePackages=@(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object {$_.Name -match '(?i)WindowsApp|RemoteDesktop'} | Sort-Object Name,Version | Select-Object Name,Version,PackageFullName)
    [pscustomobject]@{Services=@($services);RemotePackages=$remotePackages}
}
function Get-Policies {
    $r=[ordered]@{Recommended=Get-Reg $policyPath $valueName;Mandatory=Get-Reg $mandatoryPath $valueName;Related=[ordered]@{}}
    foreach($name in $related){ $r.Related[$name]=[ordered]@{Recommended=Get-Reg $policyPath $name;Mandatory=Get-Reg $mandatoryPath $name} }
    [pscustomobject]$r
}
function Assert-EdgeClosed { if(Get-Process msedge -ErrorAction SilentlyContinue){ throw 'Close all Edge processes before policy application or rollback.' } }
function Get-Support {
    $os=Get-CimInstance Win32_OperatingSystem; $pc=Get-CimInstance Win32_ComputerSystem; $edge=Get-Edge; $mgmt=Get-Management; $fixture=Get-Fixture; $policies=Get-Policies; $startup=Get-StartupFolders
    $supported=($os.Caption -match 'Windows 11' -and $pc.Manufacturer -match '(?i)^HP$|Hewlett-Packard' -and (Test-Elevated) -and $edge -and $edge.ValidPublisher -and $edge.Major -ge 77 -and !$mgmt.Managed -and $fixture -and !$policies.Recommended.ValueExists -and !$policies.Mandatory.ValueExists -and $startup.EdgeEntryCount -eq 0)
    [pscustomobject]@{Supported=$supported;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$pc.Manufacturer;Model=$pc.Model;Elevated=(Test-Elevated);Edge=$edge;Management=$mgmt;Fixture=$fixture;Policies=$policies;Startup=$startup;PolicySupportedFromEdgeMajor=77;EvidenceStatus='needs-evidence'}
}
function Assert-Supported($s) { if(!$s.Supported){ throw 'Unsupported, managed, ambiguous, existing-policy, ineligible-profile, unsigned Edge, old Edge, or Startup-folder state.' } }
function Save-State($s) {
    Assert-Supported $s
    if([string]::IsNullOrWhiteSpace($StatePath)){ throw 'StatePath is required.' }
    if(Test-Path -LiteralPath $StatePath){ throw 'State overwrite refused.' }
    $state=[ordered]@{schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;policyPath=$policyPath;mandatoryPath=$mandatoryPath;valueName=$valueName;original=$s.Policies.Recommended;mandatoryOriginal=$s.Policies.Mandatory;related=$s.Policies.Related;edge=$s.Edge;management=$s.Management;fixture=$s.Fixture;startupEdgeCount=$s.Startup.EdgeEntryCount;protected=Get-Protected;evidenceStatus='needs-evidence'}
    $parent=Split-Path -Parent $StatePath; if($parent -and !(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    $state | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    [pscustomobject]$state
}
function Read-State {
    if([string]::IsNullOrWhiteSpace($StatePath) -or !(Test-Path -LiteralPath $StatePath)){ throw 'State artifact is missing.' }
    $s=Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json; $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if($s.schemaVersion -ne 1 -or $s.experiment -ne $experiment -or $s.provider -ne $provider -or $s.machine -ne $env:COMPUTERNAME -or $s.userSid -ne $sid){ throw 'State identity validation failed.' }
    $s
}
function Assert-DriftFree($s) {
    $edge=Get-Edge; if(!$edge -or $edge.Sha256 -ne $s.edge.Sha256 -or $edge.Version -ne $s.edge.Version -or $edge.Thumbprint -ne $s.edge.Thumbprint){ throw 'Edge identity drift detected.' }
    if((Get-Management).Managed){ throw 'Management ownership drift detected.' }
    $fixture=Get-Fixture; if(!$fixture -or $fixture.MarkerSha256 -ne $s.fixture.MarkerSha256 -or $fixture.Identity -ne $s.fixture.Identity -or !$fixture.BackgroundAppPresent -or !$fixture.BaselineBackgroundModeEnabled){ throw 'Controlled profile drift detected.' }
    $policies=Get-Policies; if(!(Same $policies.Mandatory $s.mandatoryOriginal) -or !(Same $policies.Related $s.related)){ throw 'Related Edge policy drift detected.' }
    if((Get-StartupFolders).EdgeEntryCount -ne 0){ throw 'Edge Startup-folder drift detected.' }
    if(!(Same (Get-Protected) $s.protected)){ throw 'Protected security, update, servicing, or remote-access state drift detected.' }
}
function Test-Applied { $x=Get-Reg $policyPath $valueName; $x.ValueExists -and $x.Kind -eq 'DWord' -and [int]$x.Data -eq 0 }

try {
    $support=Get-Support; Write-Log 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) $support
    switch($Action){
        'Check' { [pscustomobject]@{Support=$support;Profile=$profile;EvidenceStatus='needs-evidence'} }
        'Capture' { $s=Save-State $support; Write-Log 'capture' 'pass' $s; $s }
        'DryRun' {
            Assert-Supported $support
            $r=[pscustomobject]@{Profile=$profile;WouldChange=$true;MutationCount=1;Path=$policyPath;Name=$valueName;Type='DWord';Value=0;DynamicPolicyRefresh=$true;RebootPersistenceCheckRequired=$true;EvidenceStatus='needs-evidence';Rollback='Restore the exact captured registry state, or remove only the experiment-created value and empty key.'}
            Write-Log 'dry-run' 'pass' $r; $r
        }
        'Apply' {
            $s=if($StatePath -and (Test-Path -LiteralPath $StatePath)){Read-State}else{Save-State $support}; Assert-DriftFree $s
            if(Test-Applied){Write-Log 'apply' 'idempotent' @{mutationCount=0}; return [pscustomobject]@{Applied=$true;MutationCount=0}}
            Assert-Supported $support
            if($WhatIfPreference){Write-Log 'apply' 'whatif' @{mutationCount=0}; return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}}
            Assert-EdgeClosed
            if($PSCmdlet.ShouldProcess("$policyPath::$valueName",'Disable Edge background mode for controlled experiment')){
                if(!(Test-Path -LiteralPath $policyPath)){New-Item -Path $policyPath -Force|Out-Null}
                New-ItemProperty -LiteralPath $policyPath -Name $valueName -PropertyType DWord -Value 0 -Force|Out-Null
            }
            if(!(Test-Applied)){throw 'Apply verification failed.'}; Write-Log 'apply' 'pass' @{mutationCount=1}; [pscustomobject]@{Applied=$true;MutationCount=1}
        }
        'Verify' {
            $s=Read-State; Assert-DriftFree $s; if(!(Test-Applied)){throw 'Policy verification failed.'}
            $r=[pscustomobject]@{Verified=$true;EvidenceStatus='needs-evidence'}; Write-Log 'verify' 'pass' $r; $r
        }
        'VerifyReboot' {
            $s=Read-State; Assert-DriftFree $s; $boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
            if($boot -le [datetime]$s.capturedBootTime){throw 'A later boot is required.'}; if(!(Test-Applied)){throw 'Reboot persistence failed.'}
            $r=[pscustomobject]@{VerifiedReboot=$true;BootTime=$boot.ToString('o');EvidenceStatus='needs-evidence'}; Write-Log 'verify-reboot' 'pass' $r; $r
        }
        'Rollback' {
            $s=Read-State; Assert-DriftFree $s; Assert-EdgeClosed; $now=Get-Reg $policyPath $valueName
            if(!$now.ValueExists -and !$s.original.ValueExists){Write-Log 'rollback' 'idempotent' @{mutationCount=0}; return [pscustomobject]@{RolledBack=$true;MutationCount=0}}
            if($s.original.ValueExists){
                if($now.ValueExists -and !(Same $now ([pscustomobject]@{KeyExists=$true;ValueExists=$true;Kind='DWord';Data=0}))){throw 'Policy drift detected; rollback overwrite refused.'}
                $kind=[Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$s.original.Kind,$true); $key=Get-Item -LiteralPath $policyPath; $key.SetValue($valueName,$s.original.Data,$kind)
            } else {
                if($now.ValueExists -and !(Test-Applied)){throw 'Policy drift detected; rollback overwrite refused.'}
                if($now.ValueExists){Remove-ItemProperty -LiteralPath $policyPath -Name $valueName}
                if(!$s.original.KeyExists -and (Test-Path -LiteralPath $policyPath) -and @((Get-Item -LiteralPath $policyPath).GetValueNames()).Count -eq 0 -and @((Get-ChildItem -LiteralPath $policyPath -ErrorAction SilentlyContinue)).Count -eq 0){Remove-Item -LiteralPath $policyPath}
            }
            $after=Get-Reg $policyPath $valueName; if(!(Same $after $s.original)){throw 'Exact rollback verification failed.'}
            Write-Log 'rollback' 'pass' @{restoredExactOriginal=$true}; [pscustomobject]@{RolledBack=$true;RestoredExactOriginal=$true}
        }
    }
} catch {
    Write-Log 'failure' 'failure' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName}
    throw
}
