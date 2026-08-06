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
function Get-FileSha256([string]$Path){
  $stream=[IO.File]::OpenRead($Path)
  $sha=[Security.Cryptography.SHA256]::Create()
  try{([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose();$stream.Dispose()}
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
  $installRoot=[IO.Path]::GetFullPath([string]$package.InstallLocation).TrimEnd('\')+'\'
  $executablePath=[IO.Path]::GetFullPath((Join-Path $installRoot $ExpectedExecutable))
  if(-not$executablePath.StartsWith($installRoot,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $executablePath -PathType Leaf)){throw 'HP System Information executable path is unsupported.'}
  $file=Get-Item -LiteralPath $executablePath
  $signature=Get-AuthenticodeSignature -LiteralPath $executablePath
  $signerName=if($signature.SignerCertificate){[string]$signature.SignerCertificate.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::SimpleName,$false)}else{$null}
  $signatureValid=($signature.Status-eq'Valid'-and$signature.SignerCertificate-and$signerName-in@('HP Inc.','Hewlett-Packard Company','Hewlett-Packard Development Company, L.P.')-and[string]$file.VersionInfo.CompanyName-in@('HP Inc.','HP Inc','Hewlett-Packard Company','Hewlett-Packard'))
  if(-not$signatureValid){throw 'HP System Information executable publisher identity is unsupported.'}
  [pscustomobject][ordered]@{
    packageName=[string]$package.Name
    packageFamily=[string]$package.PackageFamilyName
    version=$package.Version.ToString()
    status=$package.Status.ToString()
    appUserModelId=$aumid
    executableName=$ExpectedExecutable
    executablePath=$executablePath
    executableHash=Get-FileSha256 $executablePath
    signerThumbprint=[string]$signature.SignerCertificate.Thumbprint
    signerName=$signerName
    publisherTrust=$true
    startRegistrationPresent=($startApps.Count-eq1)
  }
}
function Test-HpExecutableIdentity($Identity){
  if(-not(Test-Path -LiteralPath ([string]$Identity.executablePath) -PathType Leaf)){return $false}
  $file=Get-Item -LiteralPath ([string]$Identity.executablePath)
  $signature=Get-AuthenticodeSignature -LiteralPath ([string]$Identity.executablePath)
  $hash=Get-FileSha256 ([string]$Identity.executablePath)
  $signerName=if($signature.SignerCertificate){[string]$signature.SignerCertificate.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::SimpleName,$false)}else{$null}
  ($signature.Status-eq'Valid'-and$signature.SignerCertificate-and[string]$signature.SignerCertificate.Thumbprint-eq[string]$Identity.signerThumbprint-and[string]$signerName-eq[string]$Identity.signerName-and$signerName-in@('HP Inc.','Hewlett-Packard Company','Hewlett-Packard Development Company, L.P.')-and[string]$hash-eq[string]$Identity.executableHash-and[string]$file.VersionInfo.CompanyName-in@('HP Inc.','HP Inc','Hewlett-Packard Company','Hewlett-Packard'))
}
function Invoke-AumidActivation([string]$AppUserModelId,[string]$ExpectedExecutablePath){
  $typeName='Lacksan.PortfolioValidation.ApplicationActivation'
  $activationType=$typeName-as[type]
  if(!$activationType){
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace Lacksan.PortfolioValidation
{
    [Flags]
    internal enum ActivateOptions
    {
        None = 0
    }

    [ComImport]
    [Guid("2E941141-7F97-4756-BA1D-9DECDE894A3D")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IApplicationActivationManager
    {
        [PreserveSig]
        int ActivateApplication(
            [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
            [MarshalAs(UnmanagedType.LPWStr)] string arguments,
            ActivateOptions options,
            out uint processId);
    }

    public sealed class ProcessCleanupResult
    {
        public bool Succeeded { get; private set; }
        public bool Forced { get; private set; }

        internal ProcessCleanupResult(bool succeeded, bool forced)
        {
            Succeeded = succeeded;
            Forced = forced;
        }
    }

    public sealed class OwnedApplicationProcess : IDisposable
    {
        private const uint STILL_ACTIVE = 259;
        private const uint WAIT_OBJECT_0 = 0;
        private IntPtr _handle;
        private readonly string _expectedPath;
        private readonly long _creationFileTime;

        public uint ProcessId { get; private set; }

        internal OwnedApplicationProcess(IntPtr handle, uint processId, string expectedPath, long launchRequestedFileTime)
        {
            _handle = handle;
            ProcessId = processId;
            _expectedPath = Path.GetFullPath(expectedPath);
            _creationFileTime = GetCreationFileTime(_handle);
            if (_creationFileTime < launchRequestedFileTime)
                throw new InvalidOperationException("Activation returned a process created before the launch request.");
            if (!VerifyIdentity())
                throw new InvalidOperationException("Activation returned an unsupported process identity.");
        }

        public bool IsRunning
        {
            get
            {
                uint exitCode;
                return _handle != IntPtr.Zero && GetExitCodeProcess(_handle, out exitCode) && exitCode == STILL_ACTIVE;
            }
        }

        public bool IdentityVerified { get { return VerifyIdentity(); } }

        public ProcessCleanupResult Cleanup(int waitMilliseconds)
        {
            if (_handle == IntPtr.Zero) return new ProcessCleanupResult(false, false);
            if (!IsRunning) return new ProcessCleanupResult(true, false);
            if (!VerifyIdentity()) return new ProcessCleanupResult(false, false);
            if (!TerminateProcess(_handle, 0))
                return new ProcessCleanupResult(!IsRunning, false);
            uint waitResult = WaitForSingleObject(_handle, (uint)waitMilliseconds);
            return new ProcessCleanupResult(waitResult == WAIT_OBJECT_0 && !IsRunning, true);
        }

        private bool VerifyIdentity()
        {
            if (!IsRunning) return false;
            try
            {
                return GetCreationFileTime(_handle) == _creationFileTime &&
                    String.Equals(GetImagePath(_handle), _expectedPath, StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        private static long GetCreationFileTime(IntPtr handle)
        {
            NativeFileTime creation, exit, kernel, user;
            if (!GetProcessTimes(handle, out creation, out exit, out kernel, out user))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            return creation.ToInt64();
        }

        private static string GetImagePath(IntPtr handle)
        {
            StringBuilder path = new StringBuilder(32768);
            uint length = (uint)path.Capacity;
            if (!QueryFullProcessImageName(handle, 0, path, ref length))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            return Path.GetFullPath(path.ToString());
        }

        public void Dispose()
        {
            if (_handle != IntPtr.Zero)
            {
                CloseHandle(_handle);
                _handle = IntPtr.Zero;
            }
            GC.SuppressFinalize(this);
        }

        ~OwnedApplicationProcess() { Dispose(); }

        [StructLayout(LayoutKind.Sequential)]
        private struct NativeFileTime
        {
            public uint Low;
            public uint High;
            public long ToInt64() { return ((long)High << 32) | Low; }
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetProcessTimes(IntPtr process, out NativeFileTime creation, out NativeFileTime exit, out NativeFileTime kernel, out NativeFileTime user);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool QueryFullProcessImageName(IntPtr process, uint flags, StringBuilder path, ref uint size);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool TerminateProcess(IntPtr process, uint exitCode);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);
    }

    public static class ApplicationActivation
    {
        private const uint CLSCTX_LOCAL_SERVER = 0x4;
        private const uint PROCESS_TERMINATE = 0x0001;
        private const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
        private const uint SYNCHRONIZE = 0x00100000;

        [DllImport("ole32.dll")]
        private static extern int CoCreateInstance(
            ref Guid classId,
            IntPtr outer,
            uint context,
            ref Guid interfaceId,
            out IntPtr instance);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr OpenProcess(uint access, bool inheritHandle, uint processId);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);

        public static OwnedApplicationProcess ActivateOwned(string appUserModelId, string expectedExecutablePath)
        {
            Guid classId = new Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C");
            Guid interfaceId = new Guid("2E941141-7F97-4756-BA1D-9DECDE894A3D");
            IntPtr pointer = IntPtr.Zero;
            object instance = null;
            try
            {
                int result = CoCreateInstance(ref classId, IntPtr.Zero, CLSCTX_LOCAL_SERVER, ref interfaceId, out pointer);
                Marshal.ThrowExceptionForHR(result);
                instance = Marshal.GetObjectForIUnknown(pointer);
                Marshal.Release(pointer);
                pointer = IntPtr.Zero;
                uint processId;
                long launchRequestedFileTime = DateTime.UtcNow.ToFileTimeUtc();
                result = ((IApplicationActivationManager)instance).ActivateApplication(appUserModelId, null, ActivateOptions.None, out processId);
                Marshal.ThrowExceptionForHR(result);
                if (processId == 0) throw new InvalidOperationException("Application activation returned no process.");
                IntPtr processHandle = OpenProcess(PROCESS_TERMINATE | PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE, false, processId);
                if (processHandle == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
                try
                {
                    OwnedApplicationProcess owned = new OwnedApplicationProcess(processHandle, processId, expectedExecutablePath, launchRequestedFileTime);
                    processHandle = IntPtr.Zero;
                    return owned;
                }
                finally
                {
                    if (processHandle != IntPtr.Zero) CloseHandle(processHandle);
                }
            }
            finally
            {
                if (pointer != IntPtr.Zero) Marshal.Release(pointer);
                if (instance != null && Marshal.IsComObject(instance)) Marshal.FinalReleaseComObject(instance);
            }
        }
    }
}
'@
    $activationType=$typeName-as[type]
  }
  if(!$activationType){throw 'Windows packaged-application activation support is unavailable.'}
  $activationType.GetMethod('ActivateOwned').Invoke($null,@([string]$AppUserModelId,[string]$ExpectedExecutablePath))
}
function Get-ExactHpProcessRows($Identity){
  @(Get-CimInstance Win32_Process -Filter "Name='$ExpectedExecutable'" -ErrorAction SilentlyContinue|Where-Object{
    if(-not$_.ExecutablePath){return $false}
    try{[IO.Path]::GetFullPath([string]$_.ExecutablePath)-eq[string]$Identity.executablePath}catch{$false}
  })
}
function Test-OwnedProcessCleanupProof([bool]$HandleCleanupSucceeded,[int]$ExactProcessCount){
  ($HandleCleanupSucceeded-and$ExactProcessCount-eq0)
}
function Test-AppLaunchProof($App,[string]$CurrentPhase){
  if($CurrentPhase-eq'Rollback'){return $true}
  ([bool]$App.activationReturnedProcess-and[bool]$App.activationOwnedNewProcess-and[bool]$App.newProcessObserved-and[bool]$App.appProcessLive-and[int]$App.stableLivePolls-ge4-and[bool]$App.createdProcessCleanupSucceeded-and[bool]$App.noPostActivationExactProcesses)
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
    return [pscustomobject][ordered]@{launchAttempted=$false;activationReturnedProcess=$false;activationOwnedNewProcess=$false;newProcessObserved=$false;stableLivePolls=0;createdProcessCount=0;createdProcessCleanupSucceeded=$true;noPostActivationExactProcesses=$true;cleanupForced=$false;serviceBefore=$serviceBefore.Status.ToString();serviceAfter=$serviceBefore.Status.ToString();appProcessLive=$false;appWindowPresent=$false;windowResponding=$false;demandStartObserved=$false;demandStartLatencyMs=$null}
  }
  if(-not(Test-HpExecutableIdentity $Identity)){throw 'HP System Information executable identity drift detected before launch.'}
  $before=@(Get-ExactHpProcessRows $Identity)
  $started=Get-Date
  $activation=$null
  if($PSCmdlet.ShouldProcess('HP System Information','Launch the installed app for a functional readiness check')){
    if($before.Count-gt0){throw 'A pre-existing exact HP System Information process prevents causal launch verification.'}
    $activation=Invoke-AumidActivation ([string]$Identity.appUserModelId) ([string]$Identity.executablePath)
  }else{return [pscustomobject][ordered]@{
    wouldLaunch=$true;launchAttempted=$false;activationReturnedProcess=$false;activationOwnedNewProcess=$false;newProcessObserved=$false;stableLivePolls=0;createdProcessCount=0;createdProcessCleanupSucceeded=$true;noPostActivationExactProcesses=$true;cleanupForced=$false
    serviceBefore=$serviceBefore.Status.ToString();serviceAfter=$serviceBefore.Status.ToString();appProcessLive=$false;appWindowPresent=$false;windowResponding=$false;demandStartObserved=$false;demandStartLatencyMs=$null
  }}
  $livePolls=0;$windowPresent=$false;$windowResponding=$false;$serviceAfter=$serviceBefore.Status.ToString();$latency=$null
  if($activation){do{
    Start-Sleep -Milliseconds 500
    $currentService=Get-Service -Name $ServiceName -ErrorAction Stop
    $serviceAfter=$currentService.Status.ToString()
    if($serviceAfter-eq'Running'-and$null-eq$latency){$latency=[math]::Round(((Get-Date)-$started).TotalMilliseconds,0)}
    if(-not[bool]$activation.IdentityVerified){break}
    $livePolls++
    $process=Get-Process -Id ([int]$activation.ProcessId) -ErrorAction SilentlyContinue
    $windowPresent=[bool]($process-and$process.MainWindowHandle-ne0)
    $windowResponding=[bool]($windowPresent-and$process.Responding)
  }while((Get-Date)-lt$started.AddSeconds($DemandStartTimeoutSeconds)-and-not($livePolls-ge4-and$serviceAfter-eq'Running'))}
  else{
    $currentService=Get-Service -Name $ServiceName -ErrorAction Stop
    $serviceAfter=$currentService.Status.ToString()
    if($serviceAfter-eq'Running'){$latency=[math]::Round(((Get-Date)-$started).TotalMilliseconds,0)}
  }
  $handleCleanupSucceeded=$false;$cleanupForced=$false
  if($activation){try{
    if(Test-HpExecutableIdentity $Identity){$cleanup=$activation.Cleanup(5000);$handleCleanupSucceeded=[bool]$cleanup.Succeeded;$cleanupForced=[bool]$cleanup.Forced}
  }finally{$activation.Dispose()}}
  $exactProcessCount=@(Get-ExactHpProcessRows $Identity).Count
  $cleanupSucceeded=Test-OwnedProcessCleanupProof $handleCleanupSucceeded $exactProcessCount
  $noPostActivationExactProcesses=($exactProcessCount-eq0)
  [pscustomobject][ordered]@{
    launchAttempted=$true;activationReturnedProcess=[bool]$activation;activationOwnedNewProcess=[bool]$activation;newProcessObserved=[bool]$activation;stableLivePolls=$livePolls;createdProcessCount=if($activation){1}else{0};createdProcessCleanupSucceeded=$cleanupSucceeded;noPostActivationExactProcesses=$noPostActivationExactProcesses;cleanupForced=$cleanupForced
    serviceBefore=$serviceBefore.Status.ToString();serviceAfter=$serviceAfter;appProcessLive=($livePolls-ge4);appWindowPresent=$windowPresent;windowResponding=$windowResponding
    demandStartObserved=($Phase-eq'Treatment'-and$serviceBefore.Status-eq'Stopped'-and$serviceAfter-eq'Running');demandStartLatencyMs=if($Phase-eq'Treatment'){$latency}else{$null}
  }
}

$identity=Get-HpAppIdentity
$protectedBefore=Get-ProtectedSnapshot
$scopeHashesBefore=Get-ScopeHashes $protectedBefore
$update=Test-UpdateDiscovery $identity
$app=Invoke-HpApp $identity
$protected=Get-ProtectedSnapshot
$scopeHashes=Get-ScopeHashes $protected
$reference=$null
if(Test-Path -LiteralPath $ReferencePath){$reference=Read-JsonFile $ReferencePath}
elseif($Phase-eq'Baseline'){
  $reference=[ordered]@{
    packageName=$identity.packageName;packageFamily=$identity.packageFamily;version=$identity.version;status=$identity.status;executableHash=$identity.executableHash;signerThumbprint=$identity.signerThumbprint;signerName=$identity.signerName
    protectedConfigurationHash=$protected.configurationHash;driverInventoryHash=$protected.device.driverInventoryHash
    driverCount=$protected.device.driverCount;problemCount=$protected.device.problemCount;securityHash=Get-Hash $protected.security
    scopeHashes=$scopeHashes
  }
  if(-not$WhatIfPreference){Write-JsonFile -Path $ReferencePath -Value $reference}
}else{throw 'Baseline functional reference is required before treatment or rollback verification.'}
$identityStable=([string]$reference.packageName-eq[string]$identity.packageName-and[string]$reference.packageFamily-eq[string]$identity.packageFamily-and[string]$reference.version-eq[string]$identity.version-and[string]$reference.status-eq[string]$identity.status-and[string]$reference.executableHash-eq[string]$identity.executableHash-and[string]$reference.signerThumbprint-eq[string]$identity.signerThumbprint-and[string]$reference.signerName-eq[string]$identity.signerName-and[bool]$identity.publisherTrust)
$deviceStable=([string]$reference.driverInventoryHash-eq[string]$protected.device.driverInventoryHash-and[string]$protectedBefore.device.driverInventoryHash-eq[string]$protected.device.driverInventoryHash-and[int]$reference.driverCount-eq[int]$protected.device.driverCount-and[int]$protectedBefore.device.driverCount-eq[int]$protected.device.driverCount-and[int]$protected.device.problemCount-le[int]$reference.problemCount-and[int]$protected.device.problemCount-le[int]$protectedBefore.device.problemCount)
$serviceMap=@{};foreach($row in $protected.services){$serviceMap[[string]$row.name]=$row}
$scopeStable=@{};foreach($name in @('WindowsSecurity','WindowsUpdate','EdgeUpdate','Credentials','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Networking','Omnissa','WindowsApp','RemoteDesktop','Tailscale')){$scopeStable[$name]=([string]$reference.scopeHashes.$name-eq[string]$scopeHashes[$name]-and[string]$scopeHashesBefore[$name]-eq[string]$scopeHashes[$name])}
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
$appReady=Test-AppLaunchProof $app $Phase
$passed=($identity.startRegistrationPresent-and$identityStable-and$update.succeeded-and$update.packageMatched-and$appReady-and$demandSatisfied-and$protectedReady-and$deviceStable)
[pscustomobject][ordered]@{
  schemaVersion=1;experiment='EXP-065';phase=$Phase;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');passed=$passed
  hpSystemInformation=[ordered]@{packageIdentityStable=$identityStable;executableIdentityStable=$identityStable;startRegistrationPresent=[bool]$identity.startRegistrationPresent;launchAttempted=[bool]$app.launchAttempted;activationReturnedProcess=[bool]$app.activationReturnedProcess;activationOwnedNewProcess=[bool]$app.activationOwnedNewProcess;newProcessObserved=[bool]$app.newProcessObserved;stableLivePolls=[int]$app.stableLivePolls;createdProcessCount=[int]$app.createdProcessCount;createdProcessCleanupSucceeded=[bool]$app.createdProcessCleanupSucceeded;noPostActivationExactProcesses=[bool]$app.noPostActivationExactProcesses;cleanupForced=[bool]$app.cleanupForced;appProcessLive=[bool]$app.appProcessLive;appWindowPresent=[bool]$app.appWindowPresent;windowResponding=[bool]$app.windowResponding;serviceBefore=[string]$app.serviceBefore;serviceAfter=[string]$app.serviceAfter;demandStartObserved=[bool]$app.demandStartObserved;demandStartLatencyMs=$app.demandStartLatencyMs}
  hpUpdate=[ordered]@{discoverySucceeded=[bool]$update.succeeded;packageMatched=[bool]$update.packageMatched;packageVersionStable=$identityStable;installationAttempted=$false}
  protectedReadiness=[ordered]@{allDeclaredScopesPassed=$protectedReady;verifiedScopeCount=($scopeResults.Count-$failedScopes.Count);scopeResults=[pscustomobject]$scopeResults;networkReady=($protected.network.upAdapterCount-gt0-and$protected.network.activeDefaultRouteCount-gt0);tailscaleReady=($serviceMap.ContainsKey('Tailscale')-and[string]$serviceMap['Tailscale'].status-eq'Running')}
  deviceHealth=[ordered]@{driverInventoryStable=$deviceStable;presentProblemCount=[int]$protected.device.problemCount;noNewProblems=([int]$protected.device.problemCount-le[int]$reference.problemCount)}
  limitations=@('The update check performs read-only Microsoft Store discovery; it does not install an update or change the tested package.','Packaged-app launch proof uses the Windows application activation manager returned process, requires that newly created exact signed executable instance to remain alive for consecutive polls, and treats classic MainWindowHandle presence and Responding as supplemental because packaged windows may be broker-owned.','This proves the installed HP application activation path and phase-specific HPSysInfoCap behavior; it does not prove that model, serial, warranty, BIOS, or other system-information fields were visibly rendered or correct.','The verifier holds one native handle for the identity-revalidated process returned by its activation request and terminates only through that handle. If another exact instance appears, cleanup proof fails without terminating that ambiguous instance. No process identifier, path, or creation time is persisted.','The post-rollback check is read-only and intentionally does not launch the app so exact restored service runtime remains the final state.','Application content, serial numbers, customer data, paths, and process identifiers are not recorded.')
}
