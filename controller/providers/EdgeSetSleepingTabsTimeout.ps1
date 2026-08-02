[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action,
    [string]$StatePath = "$env:ProgramData\Lacksan\EXP-073-state.json",
    [string]$LogPath = "$env:ProgramData\Lacksan\EXP-073.jsonl"
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ExperimentId='EXP-073'
$PolicyPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
$MandatoryPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$ValueName='SleepingTabsTimeout'
$Treatment=900

function Write-ExpLog([string]$Phase,[string]$Result,$Before,$After,[string]$Detail='') {
    $dir=Split-Path $LogPath -Parent; if($dir -and -not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
    [ordered]@{experiment=$ExperimentId;timestamp=(Get-Date).ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value;phase=$Phase;result=$Result;before=$Before;after=$After;detail=$Detail}|ConvertTo-Json -Depth 8 -Compress|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-RegValue($Path,$Name){
    if(-not(Test-Path $Path)){return [ordered]@{keyExists=$false;valueExists=$false;kind=$null;raw=$null}}
    $key=Get-Item -LiteralPath $Path
    $names=@($key.GetValueNames())
    if($names -notcontains $Name){return [ordered]@{keyExists=$true;valueExists=$false;kind=$null;raw=$null}}
    [ordered]@{keyExists=$true;valueExists=$true;kind=$key.GetValueKind($Name).ToString();raw=$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
}
function Get-Edge {
    $paths=@("$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe","$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")|Where-Object{$_ -and (Test-Path $_)}|Select-Object -Unique
    if(@($paths).Count -ne 1){throw 'Refuse: Edge installation is absent or ambiguous.'}
    $p=$paths[0]; $sig=Get-AuthenticodeSignature -LiteralPath $p; $ver=[version](Get-Item $p).VersionInfo.ProductVersion
    if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Microsoft'){throw 'Refuse: Edge publisher identity failed.'}
    if($ver -lt [version]'88.0.0.0'){throw 'Refuse: Edge 88+ required.'}
    [ordered]@{path=$p;version=$ver.ToString();sha256=(Get-FileHash $p -Algorithm SHA256).Hash;publisher=$sig.SignerCertificate.Subject}
}
function Get-Management {
    $domain=(Get-CimInstance Win32_ComputerSystem).PartOfDomain
    $ccm=Get-Service CcmExec -ErrorAction SilentlyContinue
    $enroll=Test-Path 'HKLM:\SOFTWARE\Microsoft\Enrollments'
    [ordered]@{domainJoined=[bool]$domain;configMgr=[bool]$ccm;enrollmentTree=[bool]$enroll}
}
function Get-StartupFolders {
    $shell=New-Object -ComObject Shell.Application
    $paths=@([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))|Where-Object{$_}
    $hits=@(); foreach($d in $paths){if(Test-Path $d){Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue|ForEach-Object{if($_.Name -match 'Edge|msedge'){$hits+=$_.FullName}}}}
    @($hits)
}
function Get-ProtectedState {
    $services='WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale','edgeupdate','edgeupdatem'
    $s=@{}; foreach($n in $services){$x=Get-Service $n -ErrorAction SilentlyContinue; if($x){$s[$n]=[ordered]@{status=$x.Status.ToString();startType=$x.StartType.ToString()}}}
    [ordered]@{services=$s}
}
function Get-Snapshot {
    $os=Get-CimInstance Win32_OperatingSystem; $cs=Get-CimInstance Win32_ComputerSystem
    if([version]$os.Version -lt [version]'10.0.22000.0'){throw 'Refuse: Windows 11 required.'}
    if($cs.Manufacturer -notmatch 'HP|Hewlett'){throw 'Refuse: HP platform required.'}
    $admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if(-not $admin){throw 'Refuse: elevation required.'}
    $mgmt=Get-Management; if($mgmt.domainJoined -or $mgmt.configMgr){throw 'Refuse: enterprise management ownership detected.'}
    $mandatory=Get-RegValue $MandatoryPath $ValueName; $recommended=Get-RegValue $PolicyPath $ValueName
    if($mandatory.valueExists){throw 'Refuse: mandatory SleepingTabsTimeout already exists.'}
    $sleepEnabled=Get-RegValue $PolicyPath 'SleepingTabsEnabled'; $sleepEnabledMandatory=Get-RegValue $MandatoryPath 'SleepingTabsEnabled'
    if(($sleepEnabled.valueExists -and [int]$sleepEnabled.raw -eq 0) -or ($sleepEnabledMandatory.valueExists -and [int]$sleepEnabledMandatory.raw -eq 0)){throw 'Refuse: Sleeping Tabs is explicitly disabled.'}
    [ordered]@{experiment=$ExperimentId;capturedAt=(Get-Date).ToUniversalTime().ToString('o');boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');edge=Get-Edge;policy=[ordered]@{mandatory=$mandatory;recommended=$recommended;sleepingTabsRecommended=$sleepEnabled;sleepingTabsMandatory=$sleepEnabledMandatory};management=$mgmt;startupFolders=Get-StartupFolders;protected=Get-ProtectedState;needsEvidence=$true}
}
function Save-State($s){$d=Split-Path $StatePath -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$s|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $StatePath -Encoding UTF8}
function Load-State {if(-not(Test-Path $StatePath)){throw 'Captured state is required.'};Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json}
function Assert-DriftSafe($state) {
    $e=Get-Edge; if($e.sha256 -ne $state.edge.sha256 -or $e.version -ne $state.edge.version){throw 'Refuse: Edge identity drift.'}
    $m=Get-Management; if($m.domainJoined -or $m.configMgr){throw 'Refuse: management drift.'}
    if((Get-StartupFolders|ConvertTo-Json -Compress) -ne (@($state.startupFolders)|ConvertTo-Json -Compress)){throw 'Refuse: Edge startup-folder drift.'}
}
try {
    switch($Action){
        'Check' {$s=Get-Snapshot;Write-ExpLog $Action 'eligible' $null $s;$s}
        'Capture' {$s=Get-Snapshot;Save-State $s;Write-ExpLog $Action 'captured' $null $s;$s}
        'DryRun' {$s=Get-Snapshot;Write-ExpLog $Action 'would-set' $s.policy.recommended @{SleepingTabsTimeout=$Treatment};[ordered]@{eligible=$true;wouldSet=$Treatment;needsEvidence=$true}}
        'Apply' {
            $s=Load-State; Assert-DriftSafe $s; $cur=Get-RegValue $PolicyPath $ValueName
            if($cur.valueExists -and [int]$cur.raw -eq $Treatment){Write-ExpLog $Action 'idempotent' $cur $cur;return $cur}
            if($cur.valueExists){throw 'Refuse: policy changed since capture.'}
            if($PSCmdlet.ShouldProcess("$PolicyPath\$ValueName","Set REG_DWORD $Treatment")){
                if(-not(Test-Path $PolicyPath)){New-Item -Path $PolicyPath -Force|Out-Null}
                New-ItemProperty -Path $PolicyPath -Name $ValueName -PropertyType DWord -Value $Treatment -Force|Out-Null
            }
            $after=Get-RegValue $PolicyPath $ValueName; if(-not $after.valueExists -or [int]$after.raw -ne $Treatment){throw 'Treatment verification failed.'}
            Write-ExpLog $Action 'applied' $cur $after;$after
        }
        'Verify' {$s=Load-State;Assert-DriftSafe $s;$cur=Get-RegValue $PolicyPath $ValueName;if(-not $cur.valueExists -or [int]$cur.raw -ne $Treatment){throw 'Treatment absent.'};Write-ExpLog $Action 'verified' $null $cur;$cur}
        'VerifyReboot' {$s=Load-State;Assert-DriftSafe $s;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot -le [datetime]$s.boot){throw 'A later boot is required.'};$cur=Get-RegValue $PolicyPath $ValueName;if(-not $cur.valueExists -or [int]$cur.raw -ne $Treatment){throw 'Treatment failed reboot persistence.'};Write-ExpLog $Action 'verified-after-reboot' $s.boot $boot.ToString('o');$cur}
        'Rollback' {
            $s=Load-State;Assert-DriftSafe $s;$cur=Get-RegValue $PolicyPath $ValueName
            if($cur.valueExists -and [int]$cur.raw -ne $Treatment){throw 'Refuse: rollback collision or policy drift.'}
            if($PSCmdlet.ShouldProcess("$PolicyPath\$ValueName",'Restore captured state')){
                if($s.policy.recommended.valueExists){
                    $kind=[Microsoft.Win32.RegistryValueKind]::$($s.policy.recommended.kind)
                    $k=Get-Item -LiteralPath $PolicyPath; $k.SetValue($ValueName,$s.policy.recommended.raw,$kind)
                } elseif(Test-Path $PolicyPath){Remove-ItemProperty -Path $PolicyPath -Name $ValueName -ErrorAction SilentlyContinue}
            }
            $after=Get-RegValue $PolicyPath $ValueName
            if([bool]$after.valueExists -ne [bool]$s.policy.recommended.valueExists){throw 'Rollback verification failed.'}
            if($after.valueExists -and ($after.kind -ne $s.policy.recommended.kind -or "$($after.raw)" -ne "$($s.policy.recommended.raw)")){throw 'Rollback exact-state mismatch.'}
            Write-ExpLog $Action 'rolled-back' $cur $after;$after
        }
    }
} catch {Write-ExpLog $Action 'failed' $null $null $_.Exception.Message;throw}
