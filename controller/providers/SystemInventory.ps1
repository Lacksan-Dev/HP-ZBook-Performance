[CmdletBinding()]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action = 'Check',
    [string]$StatePath,
    [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ProtectedApplicationInventory {
    $tokens = @(
        @{ Id='Omnissa'; Patterns=@('Omnissa','VMware Horizon') },
        @{ Id='WindowsApp'; Patterns=@('Windows App') },
        @{ Id='RemoteDesktop'; Patterns=@('Remote Desktop','mstsc.exe') },
        @{ Id='Tailscale'; Patterns=@('Tailscale') }
    )
    $uninstallRoots = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $installed = foreach ($root in $uninstallRoots) {
        Get-ItemProperty -Path $root -ErrorAction SilentlyContinue | Where-Object DisplayName
    }
    foreach ($token in $tokens) {
        $matches = @($installed | Where-Object {
            $name = [string]$_.DisplayName
            @($token.Patterns | Where-Object { $name -like "*$_*" }).Count -gt 0
        } | Select-Object -ExpandProperty DisplayName -Unique)
        [pscustomobject]@{ Id=$token.Id; Detected=($matches.Count -gt 0); Matches=$matches }
    }
}

function Get-SystemInventory {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    [ordered]@{
        schemaVersion = 1
        provider = 'system-inventory'
        capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        supported = ([version]$os.Version).Major -ge 10 -and $os.Caption -match 'Windows 11' -and $computer.Manufacturer -match 'HP|Hewlett-Packard'
        system = [ordered]@{
            os = $os.Caption
            build = $os.BuildNumber
            manufacturer = $computer.Manufacturer
            model = $computer.Model
            biosVersion = @($bios.SMBIOSBIOSVersion)[0]
        }
        protectedApplications = @(Get-ProtectedApplicationInventory)
        mutationCount = 0
        rebootRequired = $false
    }
}

function Write-ProviderLog([string]$Event,[string]$Result,[object]$Data) {
    if ([string]::IsNullOrWhiteSpace($LogPath)) { return }
    $record = [ordered]@{
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        experiment = 'EXP-046'
        provider = 'system-inventory'
        action = $Action
        event = $Event
        result = $Result
        data = $Data
    }
    Add-Content -LiteralPath $LogPath -Value ($record | ConvertTo-Json -Compress -Depth 10) -Encoding UTF8
}

try {
    $inventory = Get-SystemInventory
    if (-not $inventory.supported) { throw 'System inventory provider supports HP systems running Windows 11 only.' }
    switch ($Action) {
        'Check' { Write-ProviderLog 'support-detection' 'pass' $inventory.system; [pscustomobject]$inventory }
        'Capture' { $inventory | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StatePath -Encoding UTF8; Write-ProviderLog 'capture' 'pass' @{statePath=$StatePath}; [pscustomobject]$inventory }
        'DryRun' { Write-ProviderLog 'dry-run' 'pass' @{mutationCount=0}; [pscustomobject]@{Provider='system-inventory';WouldChange=@();RebootRequired=$false} }
        'Apply' { Write-ProviderLog 'apply' 'pass' @{mutationCount=0}; [pscustomobject]@{Provider='system-inventory';Applied=$true;MutationCount=0;RebootRequired=$false} }
        'Verify' { Write-ProviderLog 'verify' 'pass' @{mutationCount=0}; $true }
        'VerifyReboot' { Write-ProviderLog 'verify-reboot' 'pass' @{mutationCount=0}; $true }
        'Rollback' { Write-ProviderLog 'rollback' 'pass' @{mutationCount=0}; [pscustomobject]@{Provider='system-inventory';RolledBack=$true;MutationCount=0} }
    }
} catch {
    Write-ProviderLog 'failure' 'fail' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName}
    throw
}
