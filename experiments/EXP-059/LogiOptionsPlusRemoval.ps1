[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action = 'Check',
    [string]$StatePath = "$PSScriptRoot\state.json",
    [string]$LogPath = "$PSScriptRoot\events.jsonl",
    [string]$OfflineInstaller,
    [string]$InstallerArguments = '/S'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$experiment = 'EXP-059'
$productNamePattern = '^Logi(?:tech)? Options\+$'
$publisherPattern = '^(Logitech|Logi)(?:\s|$)'
$uninstallRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

function Write-Event {
    param([string]$Event,[string]$Result,[object]$Data)
    $record = [ordered]@{
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        experiment = $experiment
        action = $Action
        event = $Event
        result = $Result
        data = $Data
    }
    $directory = Split-Path -Parent $LogPath
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    Add-Content -LiteralPath $LogPath -Value ($record | ConvertTo-Json -Compress -Depth 12) -Encoding UTF8
}

function Test-Administrator {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-EnterpriseManaged {
    $signals = @(
        'HKLM:\SOFTWARE\Microsoft\Enrollments',
        'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts'
    )
    return [bool](@($signals | Where-Object { Test-Path -LiteralPath $_ }).Count)
}

function Get-LogiOptionsPlusProduct {
    $matches = foreach ($root in $uninstallRoots) {
        Get-ItemProperty -Path $root -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -match $productNamePattern -and
            $_.Publisher -match $publisherPattern -and
            ($_.UninstallString -or $_.QuietUninstallString)
        }
    }
    @($matches)
}

function Get-Support {
    $os = Get-CimInstance Win32_OperatingSystem
    $products = Get-LogiOptionsPlusProduct
    $installerExists = $OfflineInstaller -and (Test-Path -LiteralPath $OfflineInstaller -PathType Leaf)
    $installerHash = if ($installerExists) { (Get-FileHash -LiteralPath $OfflineInstaller -Algorithm SHA256).Hash } else { $null }
    $managed = Test-EnterpriseManaged
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $products.Count -eq 1 -and $installerExists -and -not $managed)
        Elevated = Test-Administrator
        EnterpriseManaged = $managed
        OS = $os.Caption
        Build = $os.BuildNumber
        ProductCount = $products.Count
        Product = if ($products.Count -eq 1) { $products[0] } else { $null }
        OfflineInstaller = $OfflineInstaller
        InstallerSha256 = $installerHash
    }
}

function Get-State {
    $support = Get-Support
    $product = $support.Product
    [ordered]@{
        schemaVersion = 1
        experiment = $experiment
        machine = $env:COMPUTERNAME
        userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        os = $support.OS
        build = $support.Build
        product = if ($product) {
            [ordered]@{
                displayName = $product.DisplayName
                displayVersion = $product.DisplayVersion
                publisher = $product.Publisher
                productCode = $product.PSChildName
                installLocation = $product.InstallLocation
                uninstallString = $product.UninstallString
                quietUninstallString = $product.QuietUninstallString
            }
        } else { $null }
        installer = [ordered]@{
            path = $support.OfflineInstaller
            sha256 = $support.InstallerSha256
            arguments = $InstallerArguments
        }
        expectedTradeoffs = @('Custom buttons','Application profiles','Flow','Smart Actions','Device-specific settings')
    }
}

function Save-State {
    $state = Get-State
    $directory = Split-Path -Parent $StatePath
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $state | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    $state
}

function Read-State {
    if (-not (Test-Path -LiteralPath $StatePath)) { throw "State file missing: $StatePath" }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($state.schemaVersion -ne 1 -or $state.experiment -ne $experiment -or $state.machine -ne $env:COMPUTERNAME) {
        throw 'State identity validation failed.'
    }
    $state
}

function Assert-Supported {
    param($Support)
    if (-not $Support.Elevated) { throw 'Elevation is required.' }
    if ($Support.EnterpriseManaged) { throw 'Enterprise-management ownership detected; application refused.' }
    if ($Support.ProductCount -ne 1) { throw 'Exactly one Logitech-published Logi Options+ uninstall product is required.' }
    if (-not $Support.OfflineInstaller -or -not (Test-Path -LiteralPath $Support.OfflineInstaller)) { throw 'A matching offline installer is required for exact rollback.' }
    if (-not ($Support.OS -match 'Windows 11')) { throw 'Windows 11 is required.' }
}

function Get-UninstallInvocation {
    param($Product)
    $command = if ($Product.QuietUninstallString) { $Product.QuietUninstallString } else { $Product.UninstallString }
    if ($command -match '(?i)msiexec(?:\.exe)?\s+.*?({[0-9A-F-]{36}})') {
        return [pscustomobject]@{ FilePath = 'msiexec.exe'; Arguments = "/x $($Matches[1]) /qn /norestart" }
    }
    if (-not $Product.QuietUninstallString) { throw 'Non-MSI removal requires a vendor-provided QuietUninstallString.' }
    if ($command -match '^\s*"([^"]+)"\s*(.*)$') {
        return [pscustomobject]@{ FilePath = $Matches[1]; Arguments = $Matches[2] }
    }
    $parts = $command -split '\s+',2
    [pscustomobject]@{ FilePath = $parts[0]; Arguments = if ($parts.Count -gt 1) { $parts[1] } else { '' } }
}

function Test-Removed { return (Get-LogiOptionsPlusProduct).Count -eq 0 }

try {
    $support = Get-Support
    Write-Event 'support-detection' 'ok' $support
    switch ($Action) {
        'Check' { $support }
        'Capture' {
            Assert-Supported $support
            $state = Save-State
            Write-Event 'capture' 'ok' $state
            $state
        }
        'DryRun' {
            Assert-Supported $support
            $preview = [ordered]@{ remove = $support.Product.DisplayName; version = $support.Product.DisplayVersion; preserveDrivers = $true; rollbackInstallerSha256 = $support.InstallerSha256 }
            Write-Event 'dry-run' 'ok' $preview
            $preview
        }
        'Apply' {
            if (Test-Removed) {
                if (-not (Test-Path -LiteralPath $StatePath)) { throw 'Product is absent and no captured state exists to prove prior application.' }
                [void](Read-State)
                Write-Event 'apply' 'already-applied' $null
                break
            }
            Assert-Supported $support
            $state = if (Test-Path -LiteralPath $StatePath) { Read-State } else { Save-State }
            if ((Get-FileHash -LiteralPath $state.installer.path -Algorithm SHA256).Hash -ne $state.installer.sha256) { throw 'Rollback installer hash drift detected.' }
            $invocation = Get-UninstallInvocation $support.Product
            if ($PSCmdlet.ShouldProcess("$($support.Product.DisplayName) $($support.Product.DisplayVersion)",'Remove user-space product')) {
                $process = Start-Process -FilePath $invocation.FilePath -ArgumentList $invocation.Arguments -Wait -PassThru
                if ($process.ExitCode -notin 0,1641,3010) { throw "Uninstaller exited with code $($process.ExitCode)." }
                if (-not (Test-Removed)) { throw 'Removal verification failed.' }
                Write-Event 'apply' 'ok' @{ exitCode = $process.ExitCode }
            }
        }
        'Verify' { $result = Test-Removed; Write-Event 'verify' $(if($result){'ok'}else{'failed'}) @{ removed = $result }; $result }
        'VerifyReboot' { $result = Test-Removed; Write-Event 'verify-reboot' $(if($result){'ok'}else{'failed'}) @{ removed = $result }; $result }
        'Rollback' {
            $state = Read-State
            if (-not (Test-Removed)) { Write-Event 'rollback' 'already-restored' $null; break }
            if (-not (Test-Path -LiteralPath $state.installer.path)) { throw 'Captured rollback installer is missing.' }
            if ((Get-FileHash -LiteralPath $state.installer.path -Algorithm SHA256).Hash -ne $state.installer.sha256) { throw 'Rollback installer hash mismatch.' }
            if ($PSCmdlet.ShouldProcess($state.product.displayName,'Reinstall exact captured product')) {
                $process = Start-Process -FilePath $state.installer.path -ArgumentList $state.installer.arguments -Wait -PassThru
                if ($process.ExitCode -notin 0,1641,3010) { throw "Installer exited with code $($process.ExitCode)." }
                $restored = Get-LogiOptionsPlusProduct
                if ($restored.Count -ne 1 -or $restored[0].DisplayVersion -ne $state.product.displayVersion -or $restored[0].PSChildName -ne $state.product.productCode) { throw 'Exact-version rollback verification failed.' }
                Write-Event 'rollback' 'ok' @{ exitCode = $process.ExitCode; version = $restored[0].DisplayVersion; productCode = $restored[0].PSChildName }
            }
        }
    }
}
catch {
    Write-Event 'failure' 'error' @{ message = $_.Exception.Message; type = $_.Exception.GetType().FullName }
    throw
}
