[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
    [string]$StatePath,
    [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-054'
$provider='edge-startup-boost-policy'
$recommendedPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
$mandatoryPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$valueName='StartupBoostEnabled'

function Write-ProviderLog([string]$Event,[string]$Result,[object]$Data){
    if([string]::IsNullOrWhiteSpace($LogPath)){return}
    $parent=Split-Path -Parent $LogPath
    if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    $record=[ordered]@{timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;provider=$provider;action=$Action;event=$Event;result=$Result;data=$Data}
    Add-Content -LiteralPath $LogPath -Value ($record|ConvertTo-Json -Compress -Depth 12) -Encoding UTF8
}
function Get-EdgePath{
    $paths=@("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe","$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")
    @($paths|Where-Object{$_-and(Test-Path -LiteralPath $_ -PathType Leaf)})|Select-Object -First 1
}
function Get-ManagementState{
    $cs=Get-CimInstance Win32_ComputerSystem
    $signals=[ordered]@{
        DomainJoined=[bool]$cs.PartOfDomain
        MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count
        PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device'
        ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
    }
    [pscustomobject]@{Managed=($signals.DomainJoined-or$signals.MdmEnrollments-gt0-or$signals.PolicyManager-or$signals.ConfigMgr);Signals=$signals}
}
function Get-SupportState{
    $os=Get-CimInstance Win32_OperatingSystem
    $cs=Get-CimInstance Win32_ComputerSystem
    $edge=Get-EdgePath
    $version=$null
    $hash=$null
    $publisher=$null
    if($edge){
        $raw=(Get-Item -LiteralPath $edge).VersionInfo.ProductVersion
        if($raw){$version=[version]$raw}
        $hash=(Get-FileHash -LiteralPath $edge -Algorithm SHA256).Hash
        $sig=Get-AuthenticodeSignature -LiteralPath $edge
        if($sig.SignerCertificate){$publisher=$sig.SignerCertificate.Subject}
    }
    $management=Get-ManagementState
    $admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    [pscustomobject]@{
        Supported=($os.Caption-match'Windows 11'-and$cs.Manufacturer-match'(?i)^HP$|Hewlett-Packard'-and$edge-and$version-and$version.Major-ge88-and$publisher-match'(?i)Microsoft')
        OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$cs.Manufacturer;Model=$cs.Model;EdgePath=$edge
        EdgeVersion=$(if($version){$version.ToString()}else{$null});EdgeHash=$hash;EdgePublisher=$publisher
        Managed=$management.Managed;ManagementSignals=$management.Signals;Elevated=$admin
    }
}
function Get-ValueState([string]$Path){
    $keyExists=Test-Path -LiteralPath $Path
    $valueExists=$false;$data=$null;$kind=$null
    if($keyExists){
        $key=Get-Item -LiteralPath $Path
        $valueExists=$key.GetValueNames()-contains$valueName
        if($valueExists){
            $data=$key.GetValue($valueName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $kind=$key.GetValueKind($valueName).ToString()
        }
    }
    [pscustomobject]@{Path=$Path;KeyExists=$keyExists;ValueExists=$valueExists;Data=$data;Kind=$kind}
}
function Assert-Safe($Support,$Recommended,$Mandatory){
    if(!$Support.Elevated){throw'Elevation is required.'}
    if($Support.Managed){throw'Enterprise-management signals are present; mutation is refused.'}
    if($Mandatory.ValueExists){throw'Existing mandatory Edge StartupBoostEnabled policy detected; mutation is refused.'}
    if($Recommended.ValueExists){throw'Existing recommended Edge StartupBoostEnabled policy detected; mutation is refused.'}
}
function Save-State($Support,$Recommended,$Mandatory){
    if([string]::IsNullOrWhiteSpace($StatePath)){throw'StatePath is required.'}
    $state=[ordered]@{
        schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o')
        machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        recommendedPath=$recommendedPath;mandatoryPath=$mandatoryPath;valueName=$valueName
        edgePath=$Support.EdgePath;edgeVersion=$Support.EdgeVersion;edgeHash=$Support.EdgeHash;edgePublisher=$Support.EdgePublisher
        recommended=$Recommended;mandatory=$Mandatory
    }
    $parent=Split-Path -Parent $StatePath
    if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    $state|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $StatePath -Encoding UTF8
    $state
}
function Read-State{
    if([string]::IsNullOrWhiteSpace($StatePath)-or!(Test-Path -LiteralPath $StatePath)){throw"State file missing: $StatePath"}
    $state=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if($state.schemaVersion-ne1-or$state.experiment-ne$experiment-or$state.provider-ne$provider-or$state.machine-ne$env:COMPUTERNAME-or$state.userSid-ne$sid-or$state.recommendedPath-ne$recommendedPath-or$state.mandatoryPath-ne$mandatoryPath-or$state.valueName-ne$valueName){throw'State identity validation failed.'}
    $state
}
function Assert-EdgeIdentity($State,$Support){
    foreach($field in 'EdgePath','EdgeVersion','EdgeHash','EdgePublisher'){
        $savedName=$field.Substring(0,1).ToLowerInvariant()+$field.Substring(1)
        if([string]$Support.$field-ne[string]$State.$savedName){throw"Edge identity drift detected: $field"}
    }
}
function Test-Applied{
    $current=Get-ValueState $recommendedPath
    $current.ValueExists-and$current.Kind-eq'DWord'-and[int]$current.Data-eq0
}
function Restore-State($State){
    if($State.recommended.ValueExists){throw'Captured state was ineligible for application.'}
    $current=Get-ValueState $recommendedPath
    if($current.ValueExists-and!($current.Kind-eq'DWord'-and[int]$current.Data-eq0)){throw'Rollback refused because the policy changed after application.'}
    if($current.ValueExists-and$PSCmdlet.ShouldProcess("$recommendedPath::$valueName",'Remove experiment policy')){Remove-ItemProperty -LiteralPath $recommendedPath -Name $valueName}
    if(!$State.recommended.KeyExists-and(Test-Path -LiteralPath $recommendedPath)){
        $key=Get-Item -LiteralPath $recommendedPath
        if($key.ValueCount-eq0-and@(Get-ChildItem -LiteralPath $recommendedPath -ErrorAction SilentlyContinue).Count-eq0){
            if($PSCmdlet.ShouldProcess($recommendedPath,'Remove empty experiment-created key')){Remove-Item -LiteralPath $recommendedPath -Force}
        }
    }
}

try{
    $support=Get-SupportState
    Write-ProviderLog 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) $support
    if(!$support.Supported){throw'Provider supports HP Windows 11 systems with signed Microsoft Edge 88 or later only.'}
    $recommended=Get-ValueState $recommendedPath
    $mandatory=Get-ValueState $mandatoryPath
    switch($Action){
        'Check'{[pscustomobject]@{Support=$support;Recommended=$recommended;Mandatory=$mandatory}}
        'Capture'{Assert-Safe $support $recommended $mandatory;$state=Save-State $support $recommended $mandatory;Write-ProviderLog 'capture' 'pass' @{statePath=$StatePath};$state}
        'DryRun'{Assert-Safe $support $recommended $mandatory;$result=[pscustomobject]@{Provider=$provider;WouldChange=$true;Path=$recommendedPath;Name=$valueName;Kind='DWord';Data=0;BrowserRestartRequired=$true;RebootPersistenceCheckRequired=$true};Write-ProviderLog 'dry-run' 'pass' $result;$result}
        'Apply'{
            if(Test-Path -LiteralPath $StatePath){$state=Read-State;Assert-EdgeIdentity $state $support;if(Test-Applied){Write-ProviderLog 'apply' 'idempotent' @{changed=$false};return [pscustomobject]@{Provider=$provider;Applied=$true;MutationCount=0;BrowserRestartRequired=$true;RebootRequired=$false}}}
            else{Assert-Safe $support $recommended $mandatory;$state=Save-State $support $recommended $mandatory}
            if($PSCmdlet.ShouldProcess("$recommendedPath::$valueName",'Set REG_DWORD 0')){if(!(Test-Path -LiteralPath $recommendedPath)){New-Item -Path $recommendedPath -Force|Out-Null};New-ItemProperty -LiteralPath $recommendedPath -Name $valueName -PropertyType DWord -Value 0 -Force|Out-Null}
            if(!(Test-Applied)){throw'Apply verification failed.'}
            Write-ProviderLog 'apply' 'pass' @{changed=$true;browserRestartRequired=$true}
            [pscustomobject]@{Provider=$provider;Applied=$true;MutationCount=1;BrowserRestartRequired=$true;RebootRequired=$false}
        }
        'Verify'{$state=Read-State;Assert-EdgeIdentity $state $support;$ok=Test-Applied;Write-ProviderLog 'verify' $(if($ok){'pass'}else{'fail'}) @{browserRestartRequired=$true};if(!$ok){throw'Policy verification failed.'};$true}
        'VerifyReboot'{$state=Read-State;Assert-EdgeIdentity $state $support;$ok=Test-Applied;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime;Write-ProviderLog 'verify-reboot' $(if($ok){'pass'}else{'fail'}) @{bootTime=$boot};if(!$ok){throw'Reboot persistence verification failed.'};$true}
        'Rollback'{$state=Read-State;Assert-EdgeIdentity $state $support;Restore-State $state;$current=Get-ValueState $recommendedPath;$ok=-not$current.ValueExists;Write-ProviderLog 'rollback' $(if($ok){'pass'}else{'fail'}) @{restoredExactOriginal=$ok};if(!$ok){throw'Rollback verification failed.'};[pscustomobject]@{Provider=$provider;RolledBack=$true;MutationCount=1}}
    }
}catch{Write-ProviderLog 'failure' 'fail' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName};throw}
