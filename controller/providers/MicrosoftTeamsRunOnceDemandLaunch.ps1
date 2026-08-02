[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
    [string]$StatePath,
    [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-133'
$issue=301
$provider='microsoft-teams-runonce-demand-launch'
$profile='MicrosoftTeamsRunOnceDemandLaunch'
$runOncePaths=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce')
$protected='(?i)omnissa|vmware horizon|windows app|remote desktop|mstsc|tailscale|defender|securityhealth|firewall|bitlocker|credential|windows update|wuauserv|usosvc|bits|recovery|intune|sccm|configmgr|mdm|driver|firmware|accessibility'
$servicing='(?i)update|updater|servic|repair|install|setup|webview.*servic|edgeupdate|security|credential|accessibility|recovery|driver|firmware|windows.?update|squirrel.*update|update\.exe'

function Write-Log([string]$Event,[string]$Result,[object]$Data){
    if([string]::IsNullOrWhiteSpace($LogPath)){return}
    $parent=Split-Path -Parent $LogPath
    if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;issue=$issue;provider=$provider;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 24|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-TextHash([string]$Text){$sha=[Security.Cryptography.SHA256]::Create();try{($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))|ForEach-Object{$_.ToString('x2')})-join''}finally{$sha.Dispose()}}
function Test-Elevated{([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Get-ManagementState{
    $c=Get-CimInstance Win32_ComputerSystem
    $signals=[ordered]@{DomainJoined=[bool]$c.PartOfDomain;MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count;PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device';ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue);Intune=[bool](Get-Service IntuneManagementExtension -ErrorAction SilentlyContinue);RunPolicy=(Test-Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run')-or(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run')}
    [pscustomobject]@{Managed=($signals.DomainJoined-or$signals.MdmEnrollments-gt0-or$signals.PolicyManager-or$signals.ConfigMgr-or$signals.Intune-or$signals.RunPolicy);Signals=$signals}
}
function Get-SupportState{
    $o=Get-CimInstance Win32_OperatingSystem;$c=Get-CimInstance Win32_ComputerSystem;$m=Get-ManagementState
    [pscustomobject]@{Supported=($o.Caption-match'Windows 11'-and$c.Manufacturer-match'(?i)^HP$|Hewlett-Packard');OS=$o.Caption;Build=$o.BuildNumber;Manufacturer=$c.Manufacturer;Model=$c.Model;Elevated=Test-Elevated;Managed=$m.Managed;ManagementSignals=$m.Signals}
}
function Get-ProtectedSnapshot{
    $services=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale'){if($s=Get-Service $n -ErrorAction SilentlyContinue){[ordered]@{Name=$s.Name;StartType=$s.StartType.ToString()}}}
    $processes=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)omnissa|horizon|msrdc|mstsc|tailscale|windowsapp'}|Select-Object -ExpandProperty ProcessName|Sort-Object -Unique)
    $configJson=[ordered]@{Services=@($services)}|ConvertTo-Json -Compress -Depth 8
    [pscustomobject]@{Hash=Get-TextHash $configJson;Config=$configJson;ObservedProcesses=$processes}
}
function Get-TeamsPackages{
    @((Get-AppxPackage -Name MSTeams -ErrorAction SilentlyContinue)|Sort-Object PackageFullName|ForEach-Object{[ordered]@{Name=$_.Name;PackageFamilyName=$_.PackageFamilyName;PackageFullName=$_.PackageFullName;Version=$_.Version.ToString();Publisher=$_.Publisher}})
}
function Get-TeamsPackageHash{Get-TextHash ((Get-TeamsPackages|ConvertTo-Json -Compress -Depth 8))}
function Resolve-Command([string]$Command){
    $expanded=[Environment]::ExpandEnvironmentVariables($Command).Trim();if($expanded-match$protected-or$expanded-match$servicing){return $null}
    if($expanded-match'^\s*"(?<exe>[^"]+\.exe)"\s*(?<args>.*)$'){$exe=$matches.exe;$args=$matches.args}elseif($expanded-match'^\s*(?<exe>\S+\.exe)\s*(?<args>.*)$'){$exe=$matches.exe;$args=$matches.args}else{return $null}
    try{$full=[IO.Path]::GetFullPath($exe)}catch{return $null}
    [pscustomobject]@{ExpandedCommand=$expanded;Executable=$full;Arguments=$args.Trim()}
}
function Get-FileIdentity([string]$Path){
    if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return $null};$f=Get-Item -LiteralPath $Path;$sig=Get-AuthenticodeSignature -LiteralPath $Path;$pub=if($sig.SignerCertificate){$sig.SignerCertificate.Subject}else{$null}
    [pscustomobject]@{Path=$f.FullName;Sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash;FileVersion=$f.VersionInfo.FileVersion;ProductVersion=$f.VersionInfo.ProductVersion;ProductName=$f.VersionInfo.ProductName;CompanyName=$f.VersionInfo.CompanyName;SignatureStatus=$sig.Status.ToString();Publisher=$pub;Thumbprint=if($sig.SignerCertificate){$sig.SignerCertificate.Thumbprint}else{$null};ValidPublisher=($sig.Status-eq'Valid'-and$pub-match'(?i)Microsoft Corporation')}
}
function Test-TeamsUserApp($Resolved,$Identity){
    $leaf=[IO.Path]::GetFileName([string]$Resolved.Executable);if($leaf-notmatch'(?i)^(Teams|ms-teams|msteams)\.exe$'){return $false}
    $joined="$leaf $($Identity.ProductName) $($Identity.CompanyName) $($Resolved.Arguments) $($Resolved.Executable)";if($joined-match$protected-or$joined-match$servicing){return $false}
    ($Identity.CompanyName+' '+$Identity.ProductName)-match'(?i)Microsoft.*Teams|Teams.*Microsoft'
}
function Get-RelatedTeamsStartupState([string]$ExcludedPath,[string]$ExcludedName){
    $items=@()
    foreach($path in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'){
        if(!(Test-Path -LiteralPath $path)){continue};$k=Get-Item -LiteralPath $path
        foreach($n in $k.GetValueNames()|Sort-Object){if($path-eq$ExcludedPath-and$n-eq$ExcludedName){continue};$d=[string]$k.GetValue($n,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);if("$n $d"-match'(?i)teams|msteams'){ $items+="registry|$path|$n|$($k.GetValueKind($n))|$(Get-TextHash $d)"}}
    }
    foreach($folder in @([Environment]::GetFolderPath([Environment+SpecialFolder]::Startup),[Environment]::GetFolderPath([Environment+SpecialFolder]::CommonStartup))){if($folder-and(Test-Path -LiteralPath $folder)){foreach($f in Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue|Sort-Object Name){if($f.Name-match'(?i)teams'){ $items+="startup|$(Get-TextHash $f.FullName)|$($f.Length)|$($f.LastWriteTimeUtc.ToString('o'))"}}}}
    foreach($t in Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName){$a=@($t.Actions|ForEach-Object{"$($_.Execute) $($_.Arguments)"})-join'|';if(("$($t.TaskPath)$($t.TaskName) $a")-match'(?i)teams|msteams'){ $items+="task|$(Get-TextHash ($t.TaskPath+$t.TaskName))|$(Get-TextHash $a)|$([bool]$t.Settings.Enabled)"}}
    foreach($p in Get-TeamsPackages){try{$m=Get-AppxPackageManifest -Package $p.PackageFullName -ErrorAction Stop;$nodes=@($m.Package.Applications.Application.Extensions.Extension|Where-Object{[string]$_.Category-match'(?i)windows.startupTask'});foreach($n in $nodes){$items+="startuptask|$($p.PackageFamilyName)|$([string]$n.StartupTask.TaskId)|$([string]$n.Executable)|$([string]$n.EntryPoint)"}}catch{}}
    $normalized=@($items|Sort-Object);[pscustomobject]@{Count=$normalized.Count;Hash=Get-TextHash (($normalized|ConvertTo-Json -Compress));Items=$normalized}
}
function Get-Candidates{
    $out=@()
    foreach($path in $runOncePaths){
        if(!(Test-Path -LiteralPath $path)){continue};$key=Get-Item -LiteralPath $path;$acl=Get-Acl -LiteralPath $path
        foreach($name in $key.GetValueNames()){
            if($name.StartsWith('!')-or$name.StartsWith('*')){continue};$kind=$key.GetValueKind($name).ToString();if($kind-notin @('String','ExpandString')){continue}
            $data=[string]$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);if("$name $data"-match$protected-or"$name $data"-match$servicing){continue}
            $resolved=Resolve-Command $data;if(!$resolved){continue};$file=Get-FileIdentity $resolved.Executable;if(!$file-or!$file.ValidPublisher-or!(Test-TeamsUserApp $resolved $file)){continue}
            $out+=[pscustomobject]@{Path=$path;Hive=if($path-like'HKLM:*'){'HKLM'}else{'HKCU'};Name=$name;Kind=$kind;Data=$data;ExpandedCommand=$resolved.ExpandedCommand;Arguments=$resolved.Arguments;Executable=$file;Product=[ordered]@{Name=$file.ProductName;FileVersion=$file.FileVersion;ProductVersion=$file.ProductVersion;Company=$file.CompanyName};KeyOwner=$acl.Owner;KeySddl=$acl.Sddl}
        }
    }
    @($out)
}
function Assert-Eligible($Support,[object[]]$Candidates){
    if(!$Support.Supported){throw 'HP Windows 11 is required.'};if($Support.Managed){throw 'Enterprise-management ownership detected.'};if($Candidates.Count-ne1){throw "Exactly one eligible Microsoft Teams RunOnce registration is required; found $($Candidates.Count)."};if($Candidates[0].Hive-eq'HKLM'-and!$Support.Elevated){throw 'Elevation is required for HKLM RunOnce.'}
}
function Save-State($Support,[object[]]$Candidates){
    Assert-Eligible $Support $Candidates;if([string]::IsNullOrWhiteSpace($StatePath)){throw 'StatePath is required.'};if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused.'};$p=Get-ProtectedSnapshot;$entry=$Candidates[0];$related=Get-RelatedTeamsStartupState $entry.Path $entry.Name;$packages=Get-TeamsPackages
    $state=[ordered]@{schemaVersion=1;experiment=$experiment;issue=$issue;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;support=$Support;protectedScopeHash=$p.Hash;protectedScope=$p.Config;observedProtectedProcesses=$p.ObservedProcesses;teamsPackageHash=Get-TextHash (($packages|ConvertTo-Json -Compress -Depth 8));teamsPackages=$packages;relatedTeamsStartupHash=$related.Hash;relatedTeamsStartupCount=$related.Count;entry=$entry;treatmentAppliedByExperiment=$false;applyUtc=$null}
    $parent=Split-Path -Parent $StatePath;if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$state|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $StatePath -Encoding UTF8;$state
}
function Read-State{if([string]::IsNullOrWhiteSpace($StatePath)-or!(Test-Path -LiteralPath $StatePath)){throw 'State artifact is missing.'};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;if($s.schemaVersion-ne1-or$s.experiment-ne$experiment-or$s.issue-ne$issue-or$s.provider-ne$provider-or$s.machine-ne$env:COMPUTERNAME-or$s.userSid-ne$sid){throw 'State identity validation failed.'};$s}
function Save-UpdatedState($State){$State|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $StatePath -Encoding UTF8}
function Test-Removed($State){if(!(Test-Path -LiteralPath $State.entry.Path)){return $true};!((Get-Item -LiteralPath $State.entry.Path).GetValueNames()-contains[string]$State.entry.Name)}
function Test-Restored($State){if(!(Test-Path -LiteralPath $State.entry.Path)){return $false};$k=Get-Item -LiteralPath $State.entry.Path;if(!($k.GetValueNames()-contains[string]$State.entry.Name)){return $false};$d=[string]$k.GetValue([string]$State.entry.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$d-eq[string]$State.entry.Data-and$k.GetValueKind([string]$State.entry.Name).ToString()-eq[string]$State.entry.Kind}
function Assert-KeyOwnership($State){if(!(Test-Path -LiteralPath $State.entry.Path)){throw 'RunOnce registry key disappeared.'};$acl=Get-Acl -LiteralPath ([string]$State.entry.Path);if($acl.Owner-ne[string]$State.entry.KeyOwner-or$acl.Sddl-ne[string]$State.entry.KeySddl){throw 'RunOnce key ownership or ACL drift detected.'}}
function Assert-Executable($State){$f=Get-FileIdentity ([string]$State.entry.Executable.Path);if(!$f-or!$f.ValidPublisher-or$f.Sha256-ne[string]$State.entry.Executable.Sha256-or$f.Thumbprint-ne[string]$State.entry.Executable.Thumbprint-or$f.FileVersion-ne[string]$State.entry.Executable.FileVersion-or$f.ProductVersion-ne[string]$State.entry.Executable.ProductVersion){throw 'Microsoft Teams executable identity drift detected.'};$r=[pscustomobject]@{Executable=$f.Path;Arguments=[string]$State.entry.Arguments};if(!(Test-TeamsUserApp $r $f)){throw 'Microsoft Teams product identity drift detected.'};if((Get-TeamsPackageHash)-ne[string]$State.teamsPackageHash){throw 'Microsoft Teams package identity drift detected.'}}
function Assert-EnvironmentDriftFree($State){$m=Get-ManagementState;if($m.Managed){throw 'Enterprise-management ownership appeared.'};if((Get-ProtectedSnapshot).Hash-ne[string]$State.protectedScopeHash){throw 'Protected-scope configuration drift detected.'};Assert-KeyOwnership $State;Assert-Executable $State;$related=Get-RelatedTeamsStartupState ([string]$State.entry.Path) ([string]$State.entry.Name);if($related.Hash-ne[string]$State.relatedTeamsStartupHash-or$related.Count-ne[int]$State.relatedTeamsStartupCount){throw 'Related Microsoft Teams startup state drift detected.'}}

try{
    $support=Get-SupportState;Write-Log 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) @{OS=$support.OS;Build=$support.Build;Manufacturer=$support.Manufacturer;Model=$support.Model;Managed=$support.Managed;Elevated=$support.Elevated}
    switch($Action){
        'Check'{$c=Get-Candidates;Write-Log 'candidate-inventory' 'pass' @{count=$c.Count;paths=@($c.Path);names=@($c.Name);products=@($c.Product.Name)};[pscustomobject]@{Support=$support;Candidates=$c;Profile=$profile}}
        'Capture'{$s=Save-State $support (Get-Candidates);Write-Log 'capture' 'pass' @{before=@{present=$true;path=$s.entry.Path;name=$s.entry.Name;kind=$s.entry.Kind;dataHash=Get-TextHash ([string]$s.entry.Data);exeSha256=$s.entry.Executable.Sha256;teamsPackageHash=$s.teamsPackageHash;relatedStartupHash=$s.relatedTeamsStartupHash};after=@{captured=$true}};$s}
        'DryRun'{$c=Get-Candidates;Assert-Eligible $support $c;$r=[pscustomobject]@{Profile=$profile;WouldChange=$true;MutationCount=1;Path=$c[0].Path;Name=$c[0].Name;FromPresent=$true;ToPresent=$false;PreserveTeamsInstallation=$true;PreserveTeamsData=$true;PreserveTeamsServicing=$true;PreservePersistentRun=$true;PreserveStartupFolders=$true;PreserveStartupTasks=$true;PreserveScheduledTasks=$true;PreserveServices=$true;OneShotConsumptionEvidenceRequired=$true;RebootPersistenceCheckRequired=$true;Rollback='Restore exact captured hive, path, value name, registry type, and unexpanded data only after attribution and drift checks.'};Write-Log 'dry-run' 'pass' @{before=@{present=$true};after=@{present=$false};plan=$r};$r}
        'Apply'{
            $s=if($StatePath-and(Test-Path -LiteralPath $StatePath)){Read-State}else{Save-State $support (Get-Candidates)}
            if(Test-Removed $s){if([bool]$s.treatmentAppliedByExperiment){Assert-EnvironmentDriftFree $s;Write-Log 'apply' 'idempotent' @{before=@{present=$false};after=@{present=$false};mutationCount=0;oneShotAttribution='experiment'};return [pscustomobject]@{Applied=$true;MutationCount=0;OneShotAttribution='experiment'}};Write-Log 'apply' 'refused' @{before=@{present=$false};after=@{present=$false};refusalReason='RunOnce disappeared before experiment application';oneShotAttribution='windows-or-external-needs-evidence'};throw 'RunOnce disappeared before experiment application; preserve as one-shot consumption evidence.'}
            Assert-Eligible $support (Get-Candidates);Assert-EnvironmentDriftFree $s;$k=Get-Item -LiteralPath ([string]$s.entry.Path);$d=[string]$k.GetValue([string]$s.entry.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);if($d-ne[string]$s.entry.Data-or$k.GetValueKind([string]$s.entry.Name).ToString()-ne[string]$s.entry.Kind){throw 'RunOnce registration drift detected.'}
            if($WhatIfPreference){Write-Log 'apply' 'whatif' @{before=@{present=$true};after=@{present=$true};mutationCount=0};return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}}
            if($PSCmdlet.ShouldProcess("$($s.entry.Path)::$($s.entry.Name)",'Remove exact Microsoft Teams RunOnce user-launch registration')){Remove-ItemProperty -LiteralPath ([string]$s.entry.Path) -Name ([string]$s.entry.Name)}
            if(!(Test-Removed $s)){throw 'Apply verification failed.'};$s.treatmentAppliedByExperiment=$true;$s.applyUtc=(Get-Date).ToUniversalTime().ToString('o');Save-UpdatedState $s;Write-Log 'apply' 'pass' @{before=@{present=$true};after=@{present=$false};mutationCount=1;oneShotAttribution='experiment'};[pscustomobject]@{Applied=$true;MutationCount=1;OneShotAttribution='experiment';NeedsEvidence='Controlled sign-in attribution plus Teams and protected-application readiness'}
        }
        'Verify'{$s=Read-State;if(![bool]$s.treatmentAppliedByExperiment){throw 'Verification refused because experiment application is unproven.'};if(!(Test-Removed $s)){throw 'Immediate verification failed.'};Assert-EnvironmentDriftFree $s;Write-Log 'verify' 'pass' @{before=@{capturedPresent=$true};after=@{present=$false};oneShotAttribution='experiment'};$true}
        'VerifyReboot'{$s=Read-State;if(![bool]$s.treatmentAppliedByExperiment){throw 'Reboot verification refused because experiment application is unproven.'};$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot-le[datetime]$s.capturedBootTime){throw 'A later boot is required.'};if(!(Test-Removed $s)){throw 'Reboot persistence failed.'};Assert-EnvironmentDriftFree $s;Write-Log 'verify-reboot' 'pass' @{before=@{capturedPresent=$true};after=@{present=$false};bootTime=$boot.ToString('o');oneShotAttribution='experiment'};$true}
        'Rollback'{
            $s=Read-State;if(Test-Restored $s){Write-Log 'rollback' 'idempotent' @{before=@{present=$true};after=@{present=$true};mutationCount=0;restoredExactOriginal=$true};return [pscustomobject]@{RolledBack=$true;MutationCount=0}}
            if(![bool]$s.treatmentAppliedByExperiment){throw 'Rollback refused because the experiment did not remove the RunOnce value.'};if(!(Test-Removed $s)){throw 'Rollback overwrite refused.'};Assert-EnvironmentDriftFree $s
            if($WhatIfPreference){Write-Log 'rollback' 'whatif' @{before=@{present=$false};after=@{present=$false};mutationCount=0};return [pscustomobject]@{RolledBack=$false;WhatIf=$true;MutationCount=0}}
            if($PSCmdlet.ShouldProcess("$($s.entry.Path)::$($s.entry.Name)",'Restore exact captured Microsoft Teams RunOnce registration')){New-ItemProperty -LiteralPath ([string]$s.entry.Path) -Name ([string]$s.entry.Name) -PropertyType ([string]$s.entry.Kind) -Value ([string]$s.entry.Data) -Force|Out-Null}
            if(!(Test-Restored $s)){throw 'Exact rollback verification failed.'};Write-Log 'rollback' 'pass' @{before=@{present=$false};after=@{present=$true;kind=$s.entry.Kind;dataHash=Get-TextHash ([string]$s.entry.Data)};mutationCount=1;restoredExactOriginal=$true;oneShotPostRollbackConsumption='needs-evidence'};[pscustomobject]@{RolledBack=$true;MutationCount=1;RestoredExactOriginal=$true;NeedsEvidence='Subsequent sign-in must distinguish normal RunOnce consumption from rollback correctness'}
        }
    }
}catch{Write-Log 'failure' 'fail' @{stage=$Action;refusalReason=$_.Exception.Message;failureDetail=[ordered]@{message=$_.Exception.Message;type=$_.Exception.GetType().FullName;stack=$_.ScriptStackTrace}};throw}
