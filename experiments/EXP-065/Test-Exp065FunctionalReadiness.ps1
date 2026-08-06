[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
param(
  [ValidateSet('Baseline','Treatment','Rollback')][string]$Phase,
  [Parameter(Mandatory=$true)][string]$ReferencePath,
  [ValidateRange(10,120)][int]$DemandStartTimeoutSeconds=60
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ServiceName='HPSysInfoCap'
$PackageName='AD2F1837.HPSystemInformation'
$StoreId='9MTKLT3PWWN1'
$ExpectedExecutable='HP System Information.exe'

function Write-JsonFile([string]$Path,$Value){
  $parent=Split-Path -Parent $Path
  if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  $Value|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $Path -Encoding UTF8
}
function Read-JsonFile([string]$Path){Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
function Get-Hash($Value){
  $json=$Value|ConvertTo-Json -Compress -Depth 20
  $sha=[Security.Cryptography.SHA256]::Create()
  try{([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($json)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Get-HpAppIdentity{
  $packages=@(Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue)
  if($packages.Count-ne1){throw 'Exactly one HP System Information package is required.'}
  $package=$packages[0]
  $manifest=Get-AppxPackageManifest -Package $package
  $applications=@($manifest.Package.Applications.Application)
  if($applications.Count-ne1-or[string]$applications[0].Id-ne'App'-or[string]$applications[0].Executable-ne$ExpectedExecutable){throw 'HP System Information package application identity is unsupported.'}
  $aumid="$($package.PackageFamilyName)!App"
  $startApps=@(Get-StartApps|Where-Object{[string]$_.AppID-eq$aumid})
  [pscustomobject][ordered]@{
    packageName=[string]$package.Name
    packageFamily=[string]$package.PackageFamilyName
    version=$package.Version.ToString()
    status=$package.Status.ToString()
    appUserModelId=$aumid
    executableName=$ExpectedExecutable
    startRegistrationPresent=($startApps.Count-eq1)
  }
}
function Get-ServiceRows{
  $names=@('WinDefend','mpssvc','BFE','wuauserv','UsoSvc','BITS','edgeupdate','edgeupdatem','CryptSvc','KeyIso','VaultSvc','NgcSvc','NgcCtnrSvc','TermService','RasMan','NlaSvc','Dhcp','Dnscache','Tailscale')
  @($names|ForEach-Object{
    $service=Get-Service -Name $_ -ErrorAction SilentlyContinue
    if($service){[pscustomobject][ordered]@{name=[string]$service.Name;startType=$service.StartType.ToString();status=$service.Status.ToString()}}
  }|Sort-Object name)
}
function Get-RegistryScalar([string]$Path,[string]$Name){
  try{[pscustomobject][ordered]@{present=$true;value=[string](Get-ItemPropertyValue -LiteralPath $Path -Name $Name -ErrorAction Stop)}}catch{[pscustomobject][ordered]@{present=$false;value=$null}}
}
function Get-ManagementHealth{
  $computer=Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
  $mdm=$false;$root='HKLM:\SOFTWARE\Microsoft\Enrollments'
  if(Test-Path -LiteralPath $root){foreach($key in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue){try{$row=Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop;if($row.ProviderID-or$row.UPN-or$row.DiscoveryServiceFullURL){$mdm=$true;break}}catch{}}}
  [pscustomobject][ordered]@{domainJoined=[bool]$computer.PartOfDomain;mdmEnrolled=$mdm;configMgrPresent=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)}
}
function Get-CredentialHealth{
  $deviceGuard=Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
  $credentialServices=@(Get-ServiceRows|Where-Object{$_.name-in@('CryptSvc','KeyIso','VaultSvc','NgcSvc','NgcCtnrSvc')}|Select-Object name,startType|Sort-Object name)
  [pscustomobject][ordered]@{
    lsaProtection=Get-RegistryScalar 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL'
    credentialGuardPolicy=Get-RegistryScalar 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags'
    configuredServices=if($deviceGuard){@($deviceGuard.SecurityServicesConfigured|ForEach-Object{[int]$_}|Sort-Object)}else{@()}
    runningServices=if($deviceGuard){@($deviceGuard.SecurityServicesRunning|ForEach-Object{[int]$_}|Sort-Object)}else{@()}
    credentialServices=$credentialServices
    subsystemsPresent=(@($credentialServices|Where-Object{$_.name-in@('CryptSvc','KeyIso','VaultSvc')}).Count-eq3)
  }
}
function Get-RecoveryHealth{
  $reagent=Get-Command reagentc.exe -ErrorAction SilentlyContinue
  $querySucceeded=$false;$statusHash=$null
  if($reagent){
    $priorErrorActionPreference=$ErrorActionPreference
    try{$ErrorActionPreference='Continue';$output=& $reagent.Source /info 2>&1;$querySucceeded=($LASTEXITCODE-eq0);$statusHash=Get-Hash @($output|ForEach-Object{[string]$_})}
    finally{$ErrorActionPreference=$priorErrorActionPreference}
  }
  $recoveryType='{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'
  $partitions=@(Get-Partition -ErrorAction SilentlyContinue|Where-Object{[string]$_.GptType-eq$recoveryType})
  [pscustomobject][ordered]@{querySucceeded=$querySucceeded;statusHash=$statusHash;recoveryPartitionCount=$partitions.Count}
}
function Get-AppReadiness{
  $startApps=@(Get-StartApps)
  $running=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)tailscale|msrdc|windowsapp|omnissa|horizon|vmware-view|wswc'})
  $unresponsive=@($running|Where-Object{-not$_.Responding}).Count
  [pscustomobject][ordered]@{
    omnissaRegistered=(@($startApps|Where-Object{$_.Name-match'(?i)Omnissa|Horizon'}).Count-gt0)
    windowsAppRegistered=(@($startApps|Where-Object{$_.Name-match'(?i)^Windows App$'}).Count-gt0)
    remoteDesktopRegistered=(@($startApps|Where-Object{$_.Name-match'(?i)Remote Desktop'}).Count-gt0)
    protectedRuntimeProcessCount=$running.Count
    protectedRuntimeResponsive=($unresponsive-eq0)
  }
}
function Get-DeviceHealth{
  $problems=@()
  if(Get-Command Get-PnpDevice -ErrorAction SilentlyContinue){$problems=@(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue|Where-Object{[string]$_.Status-ne'OK'})}
  else{$problems=@(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue|Where-Object{[int]$_.ConfigManagerErrorCode-ne0})}
  $drivers=@(Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue|ForEach-Object{
    [pscustomobject][ordered]@{deviceClass=[string]$_.DeviceClass;provider=[string]$_.DriverProviderName;version=[string]$_.DriverVersion;date=[string]$_.DriverDate;inf=[string]$_.InfName}
  }|Sort-Object deviceClass,provider,version,date,inf)
  [pscustomobject][ordered]@{problemCount=$problems.Count;driverCount=$drivers.Count;driverInventoryHash=Get-Hash $drivers}
}
function Get-SecurityHealth{
  $defender=$null
  try{$mp=Get-MpComputerStatus -ErrorAction Stop;$defender=[pscustomobject][ordered]@{querySucceeded=$true;antivirusEnabled=[bool]$mp.AntivirusEnabled;realTimeProtectionEnabled=[bool]$mp.RealTimeProtectionEnabled;behaviorMonitorEnabled=[bool]$mp.BehaviorMonitorEnabled;amServiceEnabled=[bool]$mp.AMServiceEnabled}}catch{$defender=[pscustomobject][ordered]@{querySucceeded=$false}}
  $firewall=@(Get-NetFirewallProfile -ErrorAction SilentlyContinue|Sort-Object Name|ForEach-Object{[pscustomobject][ordered]@{name=[string]$_.Name;enabled=[bool]$_.Enabled}})
  $deviceGuard=Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
  $bitlocker=@(Get-BitLockerVolume -ErrorAction SilentlyContinue|Sort-Object MountPoint|ForEach-Object{[pscustomobject][ordered]@{volumeType=[string]$_.VolumeType;protectionStatus=[string]$_.ProtectionStatus}})
  [pscustomobject][ordered]@{
    defender=$defender
    firewall=$firewall
    vbsStatus=if($deviceGuard){[int]$deviceGuard.VirtualizationBasedSecurityStatus}else{$null}
    securityServicesRunning=if($deviceGuard){@($deviceGuard.SecurityServicesRunning|ForEach-Object{[int]$_}|Sort-Object)}else{@()}
    bitlocker=$bitlocker
  }
}
function Get-NetworkHealth{
  $up=@(Get-NetAdapter -ErrorAction SilentlyContinue|Where-Object{$_.Status-eq'Up'})
  $routes=@(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue|Where-Object{$_.State-eq'Alive'})
  [pscustomobject][ordered]@{upAdapterCount=$up.Count;activeDefaultRouteCount=$routes.Count}
}
function Get-ProtectedSnapshot{
  $services=Get-ServiceRows
  $apps=Get-AppReadiness
  $security=Get-SecurityHealth
  $network=Get-NetworkHealth
  $device=Get-DeviceHealth
  $management=Get-ManagementHealth
  $credentials=Get-CredentialHealth
  $recovery=Get-RecoveryHealth
  [pscustomobject][ordered]@{
    configurationHash=Get-Hash @($services|Select-Object name,startType)
    services=$services
    applications=$apps
    security=$security
    network=$network
    device=$device
    management=$management
    credentials=$credentials
    recovery=$recovery
  }
}
function Get-ScopeHashes($Protected){
  $services=@($Protected.services)
  [ordered]@{
    WindowsSecurity=Get-Hash $Protected.security
    WindowsUpdate=Get-Hash @($services|Where-Object{$_.name-in@('wuauserv','UsoSvc','BITS')}|Select-Object name,startType|Sort-Object name)
    EdgeUpdate=Get-Hash @($services|Where-Object{$_.name-in@('edgeupdate','edgeupdatem')}|Select-Object name,startType|Sort-Object name)
    Credentials=Get-Hash $Protected.credentials
    Recovery=Get-Hash $Protected.recovery
    EnterpriseManagement=Get-Hash $Protected.management
    DeviceCriticalDrivers=[string]$Protected.device.driverInventoryHash
    Networking=Get-Hash ([ordered]@{up=([int]$Protected.network.upAdapterCount-gt0);route=([int]$Protected.network.activeDefaultRouteCount-gt0)})
    Omnissa=Get-Hash ([ordered]@{registered=[bool]$Protected.applications.omnissaRegistered;responsive=[bool]$Protected.applications.protectedRuntimeResponsive})
    WindowsApp=Get-Hash ([ordered]@{registered=[bool]$Protected.applications.windowsAppRegistered;responsive=[bool]$Protected.applications.protectedRuntimeResponsive})
    RemoteDesktop=Get-Hash ([ordered]@{registered=[bool]$Protected.applications.remoteDesktopRegistered;responsive=[bool]$Protected.applications.protectedRuntimeResponsive})
    Tailscale=Get-Hash @($services|Where-Object{$_.name-eq'Tailscale'}|Select-Object name,startType|Sort-Object name)
  }
}
function Test-UpdateDiscovery($Identity){
  $winget=Get-Command winget.exe -ErrorAction SilentlyContinue
  if(!$winget){return [pscustomobject][ordered]@{succeeded=$false;packageMatched=$false;installedVersion=[string]$Identity.version;installationAttempted=$false}}
  $output=& $winget.Source list --id $StoreId --source msstore --exact --accept-source-agreements --disable-interactivity 2>&1
  $exit=$LASTEXITCODE
  $text=($output|Out-String)
  [pscustomobject][ordered]@{
    succeeded=($exit-eq0)
    packageMatched=($text-match[regex]::Escape($StoreId)-and$text-match'(?i)HP System Information')
    installedVersion=[string]$Identity.version
    installationAttempted=$false
  }
}
function Invoke-HpApp($Identity){
  $serviceBefore=Get-Service -Name $ServiceName -ErrorAction Stop
  if($Phase-eq'Rollback'){
    return [pscustomobject][ordered]@{launchAttempted=$false;serviceBefore=$serviceBefore.Status.ToString();serviceAfter=$serviceBefore.Status.ToString();appProcessResponding=$true;appWindowPresent=$true;demandStartObserved=$false;demandStartLatencyMs=$null}
  }
  $before=@(Get-CimInstance Win32_Process -Filter "Name='$ExpectedExecutable'" -ErrorAction SilentlyContinue|ForEach-Object{[int]$_.ProcessId})
  if($PSCmdlet.ShouldProcess('HP System Information','Launch the installed app for a functional readiness check')){
    Start-Process explorer.exe -ArgumentList ("shell:AppsFolder\"+[string]$Identity.appUserModelId)|Out-Null
  }else{return [pscustomobject][ordered]@{
    wouldLaunch=$true
    launchAttempted=$false
    serviceBefore=$serviceBefore.Status.ToString()
    serviceAfter=$serviceBefore.Status.ToString()
    appProcessResponding=$false
    appWindowPresent=$false
    demandStartObserved=$false
    demandStartLatencyMs=$null
  }}
  $started=Get-Date
  $responding=$false;$windowPresent=$false;$serviceAfter=$serviceBefore.Status.ToString();$latency=$null;$newProcesses=@()
  do{
    Start-Sleep -Milliseconds 500
    $currentService=Get-Service -Name $ServiceName -ErrorAction Stop
    $serviceAfter=$currentService.Status.ToString()
    if($serviceAfter-eq'Running'-and$null-eq$latency){$latency=[math]::Round(((Get-Date)-$started).TotalMilliseconds,0)}
    $rows=@(Get-CimInstance Win32_Process -Filter "Name='$ExpectedExecutable'" -ErrorAction SilentlyContinue)
    $newProcesses=@($rows|Where-Object{$before-notcontains[int]$_.ProcessId})
    $processes=@($rows|ForEach-Object{Get-Process -Id ([int]$_.ProcessId) -ErrorAction SilentlyContinue}|Where-Object{$_})
    $responding=($processes.Count-gt0-and@($processes|Where-Object{-not$_.Responding}).Count-eq0)
    $windowPresent=(@($processes|Where-Object{$_.MainWindowHandle-ne0}).Count-gt0)
  }while((Get-Date)-lt$started.AddSeconds($DemandStartTimeoutSeconds)-and-not($responding-and$windowPresent-and$serviceAfter-eq'Running'))
  foreach($row in $newProcesses){$process=Get-Process -Id ([int]$row.ProcessId) -ErrorAction SilentlyContinue;if($process-and$process.MainWindowHandle-ne0){$null=$process.CloseMainWindow()}}
  [pscustomobject][ordered]@{
    launchAttempted=$true
    serviceBefore=$serviceBefore.Status.ToString()
    serviceAfter=$serviceAfter
    appProcessResponding=$responding
    appWindowPresent=$windowPresent
    demandStartObserved=($Phase-eq'Treatment'-and$serviceBefore.Status-eq'Stopped'-and$serviceAfter-eq'Running')
    demandStartLatencyMs=if($Phase-eq'Treatment'){$latency}else{$null}
  }
}

$identity=Get-HpAppIdentity
$protected=Get-ProtectedSnapshot
$scopeHashes=Get-ScopeHashes $protected
$update=Test-UpdateDiscovery $identity
$app=Invoke-HpApp $identity
$reference=$null
if(Test-Path -LiteralPath $ReferencePath){$reference=Read-JsonFile $ReferencePath}
elseif($Phase-eq'Baseline'){
  $reference=[ordered]@{
    packageName=$identity.packageName;packageFamily=$identity.packageFamily;version=$identity.version;status=$identity.status
    protectedConfigurationHash=$protected.configurationHash;driverInventoryHash=$protected.device.driverInventoryHash
    driverCount=$protected.device.driverCount;problemCount=$protected.device.problemCount;securityHash=Get-Hash $protected.security
    scopeHashes=$scopeHashes
  }
  if(-not$WhatIfPreference){Write-JsonFile -Path $ReferencePath -Value $reference}
}else{throw 'Baseline functional reference is required before treatment or rollback verification.'}
$identityStable=([string]$reference.packageName-eq[string]$identity.packageName-and[string]$reference.packageFamily-eq[string]$identity.packageFamily-and[string]$reference.version-eq[string]$identity.version-and[string]$reference.status-eq[string]$identity.status)
$deviceStable=([string]$reference.driverInventoryHash-eq[string]$protected.device.driverInventoryHash-and[int]$reference.driverCount-eq[int]$protected.device.driverCount-and[int]$protected.device.problemCount-le[int]$reference.problemCount)
$serviceMap=@{};foreach($row in $protected.services){$serviceMap[[string]$row.name]=$row}
$scopeStable=@{};foreach($name in @('WindowsSecurity','WindowsUpdate','EdgeUpdate','Credentials','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Networking','Omnissa','WindowsApp','RemoteDesktop','Tailscale')){$scopeStable[$name]=([string]$reference.scopeHashes.$name-eq[string]$scopeHashes[$name])}
$scopeResults=[ordered]@{
  WindowsSecurity=($scopeStable.WindowsSecurity-and[bool]$protected.security.defender.querySucceeded-and@($protected.security.firewall).Count-gt0-and@($protected.security.firewall|Where-Object{-not$_.enabled}).Count-eq0)
  WindowsUpdate=($scopeStable.WindowsUpdate-and@(@('wuauserv','UsoSvc','BITS')|Where-Object{-not$serviceMap.ContainsKey($_)}).Count-eq0)
  EdgeUpdate=($scopeStable.EdgeUpdate-and@(@('edgeupdate','edgeupdatem')|Where-Object{$serviceMap.ContainsKey($_)}).Count-gt0)
  Credentials=($scopeStable.Credentials-and[bool]$protected.credentials.subsystemsPresent)
  Recovery=($scopeStable.Recovery-and[bool]$protected.recovery.querySucceeded)
  EnterpriseManagement=[bool]$scopeStable.EnterpriseManagement
  DeviceCriticalDrivers=$deviceStable
  Networking=($scopeStable.Networking-and$protected.network.upAdapterCount-gt0-and$protected.network.activeDefaultRouteCount-gt0)
  Omnissa=($scopeStable.Omnissa-and$protected.applications.omnissaRegistered-and$protected.applications.protectedRuntimeResponsive)
  WindowsApp=($scopeStable.WindowsApp-and$protected.applications.windowsAppRegistered-and$protected.applications.protectedRuntimeResponsive)
  RemoteDesktop=($scopeStable.RemoteDesktop-and$protected.applications.remoteDesktopRegistered-and$protected.applications.protectedRuntimeResponsive)
  Tailscale=($scopeStable.Tailscale-and$serviceMap.ContainsKey('Tailscale')-and[string]$serviceMap['Tailscale'].status-eq'Running')
}
$failedScopes=@($scopeResults.GetEnumerator()|Where-Object{-not[bool]$_.Value})
$protectedReady=($failedScopes.Count-eq0)
$demandSatisfied=if($Phase-eq'Treatment'){[bool]$app.demandStartObserved}elseif($Phase-eq'Rollback'){$true}else{[string]$app.serviceAfter-eq'Running'}
$appReady=if($Phase-eq'Rollback'){$true}else{[bool]$app.appProcessResponding-and[bool]$app.appWindowPresent}
$passed=($identity.startRegistrationPresent-and$identityStable-and$update.succeeded-and$update.packageMatched-and$appReady-and$demandSatisfied-and$protectedReady-and$deviceStable)
[pscustomobject][ordered]@{
  schemaVersion=1;experiment='EXP-065';phase=$Phase;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');passed=$passed
  hpSystemInformation=[ordered]@{packageIdentityStable=$identityStable;startRegistrationPresent=[bool]$identity.startRegistrationPresent;launchAttempted=[bool]$app.launchAttempted;appProcessResponding=[bool]$app.appProcessResponding;appWindowPresent=[bool]$app.appWindowPresent;serviceBefore=[string]$app.serviceBefore;serviceAfter=[string]$app.serviceAfter;demandStartObserved=[bool]$app.demandStartObserved;demandStartLatencyMs=$app.demandStartLatencyMs}
  hpUpdate=[ordered]@{discoverySucceeded=[bool]$update.succeeded;packageMatched=[bool]$update.packageMatched;packageVersionStable=$identityStable;installationAttempted=$false}
  protectedReadiness=[ordered]@{allDeclaredScopesPassed=$protectedReady;verifiedScopeCount=($scopeResults.Count-$failedScopes.Count);scopeResults=[pscustomobject]$scopeResults;networkReady=($protected.network.upAdapterCount-gt0-and$protected.network.activeDefaultRouteCount-gt0);tailscaleReady=($serviceMap.ContainsKey('Tailscale')-and[string]$serviceMap['Tailscale'].status-eq'Running')}
  deviceHealth=[ordered]@{driverInventoryStable=$deviceStable;presentProblemCount=[int]$protected.device.problemCount;noNewProblems=([int]$protected.device.problemCount-le[int]$reference.problemCount)}
  limitations=@('The update check performs read-only Microsoft Store discovery; it does not install an update or change the tested package.','The post-rollback check is read-only and intentionally does not launch the app so exact restored service runtime remains the final state.','Application content, serial numbers, customer data, paths, and process identifiers are not recorded.')
}
