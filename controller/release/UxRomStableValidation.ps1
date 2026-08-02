#requires -Version 5.1

<#
.SYNOPSIS
    UX-ROM machine physical-validation and Stable-promotion surface.

.DESCRIPTION
    Discovers merged providers, experiment controllers, and reboot-aware harnesses;
    makes validation-ready treatments runnable from UX-ROM; records machine-local
    evidence; and recognizes the operator's explicit Stable approval.

    Stable in this surface means the implementation lifecycle was physically proven
    on this machine and approved for deployment. Performance-gain claims remain
    separately qualified by each experiment's repeated benchmark requirements.
#>

Set-StrictMode -Version 2.0

$script:StableValidationSchema = 2
$script:StableApprovalId = 'STABLE-APPROVAL-2026-08-02'
$script:StableRepo = 'Lacksan-Dev/HP-ZBook-Performance'
$script:StableRawRoot = 'https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main'
$script:StableApiRoot = 'https://api.github.com/repos/Lacksan-Dev/HP-ZBook-Performance'

function Get-UxRomStableRoot {
    param([string]$Root)
    $path = Join-Path $Root 'stable-validation'
    if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    foreach ($child in @('runtime','runs','ledger')) {
        $p = Join-Path $path $child
        if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    }
    return $path
}

function Write-UxRomStableJson {
    param([string]$Path,[object]$Value)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temporary = "$Path.tmp"
    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Get-UxRomStableLayer {
    param([string]$Name,[string]$Path)
    $text = "$Name $Path"
    if ($text -match '(?i)thermal|cooling') { return 1 }
    if ($text -match '(?i)hardware|storage|memory') { return 2 }
    if ($text -match '(?i)firmware|bios|uefi') { return 3 }
    if ($text -match '(?i)driver|dpc|isr') { return 4 }
    if ($text -match '(?i)kernel|scheduler|mmcss|ntfs') { return 5 }
    if ($text -match '(?i)power') { return 6 }
    if ($text -match '(?i)security|defender|firewall') { return 7 }
    if ($text -match '(?i)policy|mdm|enrollment|group') { return 9 }
    if ($text -match '(?i)shell|explorer|visual') { return 10 }
    if ($text -match '(?i)edge' -and $text -notmatch '(?i)startup|windowsstartup|run|task') { return 11 }
    if ($text -match '(?i)dependency|network|locality') { return 12 }
    if ($text -match '(?i)startup|runonce|run|signin|logon|task|service|touchpoint|hotkey|logi|teams|office|microsoft365|oneagent') { return 8 }
    return 8
}

function Get-UxRomGithubHeaders {
    return @{ 'User-Agent' = 'Lacksan-UX-ROM'; 'Accept' = 'application/vnd.github+json' }
}

function Get-UxRomMergedProviderCatalog {
    $uri = "$script:StableApiRoot/contents/controller/providers?ref=main"
    $items = @(Invoke-RestMethod -UseBasicParsing -Headers (Get-UxRomGithubHeaders) -Uri $uri -Method Get)
    $providers = @()
    foreach ($item in $items | Where-Object { $_.type -eq 'file' -and $_.name -like '*.ps1' }) {
        if ($item.name -match '(?i)test|integration') { continue }
        $providers += [pscustomobject][ordered]@{
            experiment = $null
            name = [IO.Path]::GetFileNameWithoutExtension([string]$item.name)
            layer = Get-UxRomStableLayer -Name ([string]$item.name) -Path ([string]$item.path)
            kind = 'Provider'
            path = [string]$item.path
            controller = $null
            sha = [string]$item.sha
            approval = $script:StableApprovalId
            releaseState = 'Stable approved / physical validation pending'
        }
    }
    return @($providers)
}

function Get-UxRomMergedExperimentCatalog {
    $uri = "$script:StableApiRoot/git/trees/main?recursive=1"
    $treeResult = Invoke-RestMethod -UseBasicParsing -Headers (Get-UxRomGithubHeaders) -Uri $uri -Method Get
    if ($treeResult.truncated) { throw 'GitHub returned a truncated repository tree; release discovery refused.' }
    $paths = @($treeResult.tree | Where-Object {
        $_.type -eq 'blob' -and
        $_.path -match '^experiments/EXP-\d{3}/.+\.ps1$' -and
        $_.path -notmatch '(?i)/tests?/|\.Tests\.ps1$|Integration\.Tests\.ps1$' -and
        ([IO.Path]::GetFileName([string]$_.path) -match '^Invoke-Exp.+\.ps1$')
    } | ForEach-Object { [string]$_.path })

    $entries = @()
    foreach ($path in $paths) {
        $match = [regex]::Match($path,'(?i)^experiments/(EXP-\d{3})/')
        if (-not $match.Success) { continue }
        $experiment = $match.Groups[1].Value.ToUpperInvariant()
        $leaf = [IO.Path]::GetFileNameWithoutExtension($path)
        $kind = if ($leaf -match '(?i)LabHarness|ValidationHarness|Harness') { 'Harness' } else { 'Controller' }
        $entries += [pscustomobject][ordered]@{
            experiment=$experiment
            name=$leaf
            layer=Get-UxRomStableLayer -Name $leaf -Path $path
            kind=$kind
            path=$path
            controller=$null
            approval=$script:StableApprovalId
            releaseState=if($kind -eq 'Harness'){'Physical benchmark harness'}else{'Merged experiment controller'}
        }
    }

    foreach ($harness in @($entries | Where-Object kind -eq 'Harness')) {
        $controller = @($entries | Where-Object {
            $_.experiment -eq $harness.experiment -and $_.kind -eq 'Controller'
        } | Sort-Object { ([string]$_.path).Length } | Select-Object -First 1)
        if ($controller.Count -eq 1) { $harness.controller = [string]$controller[0].path }
    }
    return @($entries)
}

function Get-UxRomStableCatalog {
    param([string]$Root,[switch]$Refresh)
    $stableRoot = Get-UxRomStableRoot -Root $Root
    $cachePath = Join-Path $stableRoot 'merged-release-catalog.json'
    if (-not $Refresh -and (Test-Path -LiteralPath $cachePath)) {
        try {
            $cached = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json
            if ([int]$cached.schemaVersion -eq $script:StableValidationSchema) {
                $captured=[datetime]$cached.capturedUtc
                if (((Get-Date).ToUniversalTime()-$captured.ToUniversalTime()).TotalMinutes -lt 30) { return @($cached.entries) }
            }
        } catch {}
    }

    # PowerShell unwraps a single pipeline result to a PSCustomObject. Build the
    # combined catalog by appending each result set to a real array so one-item
    # catalogs cannot invoke PSObject op_Addition.
    $entries = @()
    $entries += @(Get-UxRomMergedProviderCatalog)
    $entries += @(Get-UxRomMergedExperimentCatalog)
    $deduped = @($entries | Sort-Object path -Unique | Sort-Object layer,experiment,name,path)
    Write-UxRomStableJson -Path $cachePath -Value ([ordered]@{
        schemaVersion=$script:StableValidationSchema
        capturedUtc=[DateTime]::UtcNow.ToString('o')
        entries=$deduped
    })
    return $deduped
}

function Resolve-UxRomStableScript {
    param([string]$Root,[Parameter(Mandatory=$true)][object]$Entry,[switch]$Controller)
    $stableRoot = Get-UxRomStableRoot -Root $Root
    $hasController = $Entry.PSObject.Properties.Name -contains 'controller'
    $controllerPath = if ($hasController) { [string]$Entry.controller } else { $null }
    $relative = if ($Controller -and $controllerPath) { $controllerPath } else { [string]$Entry.path }
    if ([string]::IsNullOrWhiteSpace($relative)) { throw 'The selected release entry has no executable path.' }
    $safeName = ($relative -replace '[^A-Za-z0-9_.-]','_')
    $local = Join-Path (Join-Path $stableRoot 'runtime') $safeName
    $uri = "$script:StableRawRoot/$($relative.Replace('\','/'))"
    Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $local
    Unblock-File -LiteralPath $local -ErrorAction SilentlyContinue
    return $local
}

function Get-UxRomScriptContract {
    param([string]$Path)
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if (@($errors).Count -gt 0) { throw ('PowerShell parser rejected {0}: {1}' -f $Path,$errors[0].Message) }
    $parameterNames = @()
    if ($ast.ParamBlock) { $parameterNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }) }
    $source = Get-Content -LiteralPath $Path -Raw
    $actions = @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') | Where-Object { $source -match [regex]::Escape($_) }
    return [pscustomobject][ordered]@{
        parameters=$parameterNames
        lifecycleActions=$actions
        standardProvider=($parameterNames -contains 'Action' -and @($actions).Count -eq 7)
        harness=($parameterNames -contains 'Action' -and $source -match 'Start' -and $source -match 'Continue')
    }
}

function Get-UxRomStableLedger {
    param([string]$Root)
    $stableRoot=Get-UxRomStableRoot -Root $Root
    $path=Join-Path $stableRoot 'ledger\machine-stable.json'
    if (Test-Path -LiteralPath $path) { return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json }
    return [pscustomobject][ordered]@{ schemaVersion=2; machine=$env:COMPUTERNAME; approval=$script:StableApprovalId; entries=@() }
}

function Save-UxRomStableLedger {
    param([string]$Root,[object]$Ledger)
    $stableRoot=Get-UxRomStableRoot -Root $Root
    Write-UxRomStableJson -Path (Join-Path $stableRoot 'ledger\machine-stable.json') -Value $Ledger
}

function Add-UxRomStableLedgerEntry {
    param([string]$Root,[object]$Entry)
    $ledger=Get-UxRomStableLedger -Root $Root
    $existing=@($ledger.entries | Where-Object { $_.id -eq $Entry.id })
    if ($existing.Count -eq 0) { $ledger.entries=@($ledger.entries)+@($Entry) }
    else {
        $new=@();foreach($item in @($ledger.entries)){if($item.id -eq $Entry.id){$new+=$Entry}else{$new+=$item}};$ledger.entries=$new
    }
    Save-UxRomStableLedger -Root $Root -Ledger $ledger
}

function Show-UxRomStableLedger {
    param([string]$Root)
    $ledger=Get-UxRomStableLedger -Root $Root
    Write-Host ''
    Write-Host 'Machine Stable ledger' -ForegroundColor Cyan
    Write-Host "Approval: $($ledger.approval)"
    if (@($ledger.entries).Count -eq 0) { Write-Host 'No completed machine physical validations are recorded yet.' -ForegroundColor DarkYellow; return }
    $ledger.entries | Select-Object experiment,name,status,completedUtc,deployedUtc,evidencePath | Format-Table -AutoSize | Out-Host
}

function Show-UxRomStableCatalog {
    param([string]$Root,[switch]$Refresh)
    $catalog=@(Get-UxRomStableCatalog -Root $Root -Refresh:$Refresh)
    Write-Host ''
    Write-Host 'Physical Validation / Stable Promotion' -ForegroundColor Cyan
    Write-Host "Human approval: $script:StableApprovalId" -ForegroundColor Green
    Write-Host 'Merged providers, experiment controllers, and benchmark harnesses are discovered from main.' -ForegroundColor DarkGray
    $index=0
    $rows=foreach($entry in $catalog){
        $index++
        [pscustomobject]@{ No=$index; Layer=$entry.layer; Experiment=if($entry.experiment){$entry.experiment}else{'auto'}; Type=$entry.kind; Name=$entry.name }
    }
    $rows | Format-Table -AutoSize | Out-Host
    return @($catalog)
}

function Invoke-UxRomStableProviderStart {
    param([string]$Root,[object]$Entry)
    if ($Entry.kind -eq 'Harness') { throw 'Use the reboot-harness action for a Harness entry.' }
    $scriptPath=Resolve-UxRomStableScript -Root $Root -Entry $Entry
    $contract=Get-UxRomScriptContract -Path $scriptPath
    if (-not $contract.standardProvider) { throw "The selected script is merged engineering but does not expose the seven-action treatment lifecycle: $($Entry.path)" }

    $stableRoot=Get-UxRomStableRoot -Root $Root
    $activePath=Join-Path $stableRoot 'active.json'
    if (Test-Path -LiteralPath $activePath) { throw 'Another provider validation is awaiting reboot/rollback. Resume it before starting another treatment.' }
    $stamp=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
    $slug=([IO.Path]::GetFileNameWithoutExtension([string]$Entry.path) -replace '[^A-Za-z0-9_.-]','-')
    $runDir=Join-Path (Join-Path $stableRoot 'runs') "$stamp-$slug"
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    $state=Join-Path $runDir 'provider-state.json'
    $log=Join-Path $runDir 'provider-events.jsonl'

    Write-Progress -Activity "Physical validation: $($Entry.name)" -Status 'Checking machine eligibility' -PercentComplete 5
    $check=& $scriptPath -Action Check -StatePath $state -LogPath $log
    $experiment=if($Entry.experiment){[string]$Entry.experiment}else{$null}
    if (-not $experiment) {
        $source=Get-Content -LiteralPath $scriptPath -Raw
        $m=[regex]::Match($source,'(?i)EXP-\d{3}')
        if ($m.Success) { $experiment=$m.Value.ToUpperInvariant() }
    }

    Write-Progress -Activity "Physical validation: $($Entry.name)" -Status 'Capturing exact original state' -PercentComplete 20
    & $scriptPath -Action Capture -StatePath $state -LogPath $log | Out-Null
    Write-Progress -Activity "Physical validation: $($Entry.name)" -Status 'Checking dry-run contract' -PercentComplete 35
    & $scriptPath -Action DryRun -StatePath $state -LogPath $log | Out-Null
    Write-Progress -Activity "Physical validation: $($Entry.name)" -Status 'Applying one reversible treatment' -PercentComplete 55
    & $scriptPath -Action Apply -StatePath $state -LogPath $log -Confirm:$false | Out-Null
    Write-Progress -Activity "Physical validation: $($Entry.name)" -Status 'Verifying treatment state' -PercentComplete 75
    & $scriptPath -Action Verify -StatePath $state -LogPath $log | Out-Null

    $active=[ordered]@{
        schemaVersion=2; id=[guid]::NewGuid().ToString(); experiment=$experiment; name=[string]$Entry.name; providerPath=[string]$Entry.path
        localScript=$scriptPath; statePath=$state; logPath=$log; runDirectory=$runDir; approval=$script:StableApprovalId
        capturedBootUtc=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
        status='TreatmentVerifiedAwaitingReboot'; startedUtc=[DateTime]::UtcNow.ToString('o')
    }
    Write-UxRomStableJson -Path $activePath -Value $active
    Write-Progress -Activity "Physical validation: $($Entry.name)" -Completed
    Write-Host ''
    Write-Host 'Treatment applied and immediately verified.' -ForegroundColor Green
    Write-Host 'A later Windows boot is the remaining implementation-mechanics gate.' -ForegroundColor Yellow
    Write-Host 'After reboot: reopen UX-ROM, choose V, then Resume pending validation.' -ForegroundColor DarkGray
    Write-Host "Evidence: $runDir" -ForegroundColor DarkGray
}

function Resume-UxRomStableProvider {
    param([string]$Root)
    $stableRoot=Get-UxRomStableRoot -Root $Root
    $activePath=Join-Path $stableRoot 'active.json'
    if (-not (Test-Path -LiteralPath $activePath)) { Write-Host 'No pending provider validation exists.' -ForegroundColor DarkYellow; return }
    $active=Get-Content -LiteralPath $activePath -Raw | ConvertFrom-Json
    $currentBoot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
    if ($currentBoot -eq [string]$active.capturedBootUtc) { throw 'A later Windows boot is required before reboot verification.' }
    $scriptPath=[string]$active.localScript
    if (-not (Test-Path -LiteralPath $scriptPath)) { throw 'The cached provider script for the active validation is missing.' }

    Write-Progress -Activity "Physical validation: $($active.name)" -Status 'Verifying treatment after reboot' -PercentComplete 25
    & $scriptPath -Action VerifyReboot -StatePath ([string]$active.statePath) -LogPath ([string]$active.logPath) | Out-Null
    Write-Progress -Activity "Physical validation: $($active.name)" -Status 'Executing exact rollback proof' -PercentComplete 55
    & $scriptPath -Action Rollback -StatePath ([string]$active.statePath) -LogPath ([string]$active.logPath) -Confirm:$false | Out-Null
    Write-Progress -Activity "Physical validation: $($active.name)" -Status 'Promoting implementation to machine Stable' -PercentComplete 85

    $record=[ordered]@{
        schemaVersion=2; id=[string]$active.id; experiment=[string]$active.experiment; name=[string]$active.name
        status='Stable for this machine / performance effect unqualified'; approval=$script:StableApprovalId
        completedUtc=[DateTime]::UtcNow.ToString('o'); deployedUtc=$null; evidencePath=[string]$active.runDirectory
        providerPath=[string]$active.providerPath; localScript=[string]$active.localScript; statePath=[string]$active.statePath; logPath=[string]$active.logPath
        rebootVerified=$true; rollbackExecuted=$true; stableClaim=$true; performanceClaim=$false
        stableScope='Implementation lifecycle on this machine'
        qualification='Support, capture, dry run, apply, immediate verification, reboot verification, and exact rollback executed on this machine. Stable approves this implementation for machine deployment. Any responsiveness-gain claim still requires the experiment-specific repeated benchmark and functional evidence.'
    }
    Add-UxRomStableLedgerEntry -Root $Root -Entry ([pscustomobject]$record)
    Remove-Item -LiteralPath $activePath -Force
    Write-Progress -Activity "Physical validation: $($active.name)" -Completed
    Write-Host 'Physical implementation lifecycle passed. Machine Stable promotion recorded.' -ForegroundColor Green
    Write-Host 'Performance effect remains separately qualified until its benchmark evidence is complete.' -ForegroundColor DarkGray
}

function Deploy-UxRomMachineStableProvider {
    param([string]$Root)
    $ledger=Get-UxRomStableLedger -Root $Root
    $eligible=@($ledger.entries | Where-Object { $_.stableClaim -eq $true -and $_.providerPath -and $_.statePath })
    if ($eligible.Count -eq 0) { Write-Host 'No machine-Stable provider is available for deployment yet.' -ForegroundColor DarkYellow; return }
    for($i=0;$i-lt$eligible.Count;$i++){Write-Host ("{0}. {1}  {2}" -f ($i+1),$eligible[$i].experiment,$eligible[$i].name)}
    $selection=Read-Host 'Stable treatment number'
    $number=0
    if (-not [int]::TryParse($selection,[ref]$number) -or $number -lt 1 -or $number -gt $eligible.Count) { Write-Warning 'Choose a displayed Stable treatment number.'; return }
    $entry=$eligible[$number-1]
    $scriptPath=[string]$entry.localScript
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        $catalogEntry=[pscustomobject]@{path=[string]$entry.providerPath;controller=$null}
        $scriptPath=Resolve-UxRomStableScript -Root $Root -Entry $catalogEntry
    }
    Write-Progress -Activity "Deploying Stable treatment: $($entry.name)" -Status 'Applying validated treatment' -PercentComplete 45
    & $scriptPath -Action Apply -StatePath ([string]$entry.statePath) -LogPath ([string]$entry.logPath) -Confirm:$false | Out-Null
    Write-Progress -Activity "Deploying Stable treatment: $($entry.name)" -Status 'Verifying deployed state' -PercentComplete 85
    & $scriptPath -Action Verify -StatePath ([string]$entry.statePath) -LogPath ([string]$entry.logPath) | Out-Null
    $entry.status='Stable deployed on this machine / performance effect unqualified'
    $entry.deployedUtc=[DateTime]::UtcNow.ToString('o')
    Add-UxRomStableLedgerEntry -Root $Root -Entry $entry
    Write-Progress -Activity "Deploying Stable treatment: $($entry.name)" -Completed
    Write-Host 'Machine-Stable treatment applied and verified.' -ForegroundColor Green
}

function Invoke-UxRomStableHarness {
    param([string]$Root,[object]$Entry)
    if ($Entry.kind -ne 'Harness') { throw 'Choose a Harness entry for reboot-aware benchmark execution.' }
    $harness=Resolve-UxRomStableScript -Root $Root -Entry $Entry
    $contract=Get-UxRomScriptContract -Path $harness
    if (-not $contract.harness) { throw 'The selected script does not expose a Start/Continue harness contract.' }
    $stableRoot=Get-UxRomStableRoot -Root $Root
    $evidence=Join-Path (Join-Path $stableRoot 'runs') ([string]$Entry.experiment)
    $arguments=@{Action='Start'}
    if ($contract.parameters -contains 'RunsPerArm') { $arguments.RunsPerArm=5 }
    if ($contract.parameters -contains 'EvidenceRoot') { $arguments.EvidenceRoot=$evidence }
    if ($contract.parameters -contains 'AllowAutomaticReboot') { $arguments.AllowAutomaticReboot=$true }
    if ($contract.parameters -contains 'ControllerPath') {
        if (-not $Entry.controller) { throw 'The harness requires ControllerPath but no sibling controller was discovered.' }
        $arguments.ControllerPath=Resolve-UxRomStableScript -Root $Root -Entry $Entry -Controller
    }
    Write-Host "Starting $($Entry.experiment) physical benchmark harness." -ForegroundColor Cyan
    Write-Host 'Five baseline and five treatment runs are requested when the harness exposes RunsPerArm.' -ForegroundColor DarkGray
    & $harness @arguments
}

function Show-UxRomStableValidationMenu {
    param([string]$Root)
    do {
        Write-Host ''
        Write-Host 'Physical Validation / Stable Promotion' -ForegroundColor Cyan
        Write-Host "Human Stable approval: $script:StableApprovalId" -ForegroundColor Green
        Write-Host '1. Show all merged providers, experiment controllers, and harnesses'
        Write-Host '2. Start physical validation for one treatment provider/controller'
        Write-Host '3. Resume after reboot, prove rollback, and promote implementation to Stable'
        Write-Host '4. Run a full reboot-aware benchmark harness'
        Write-Host '5. Show this machine''s validation / Stable ledger'
        Write-Host '6. Deploy a machine-Stable treatment'
        Write-Host 'R. Refresh merged release catalog from main'
        Write-Host 'B. Back'
        $choice=Read-Host 'Choose validation action'
        switch($choice){
            '1' { [void](Show-UxRomStableCatalog -Root $Root) }
            '2' {
                $catalog=@(Show-UxRomStableCatalog -Root $Root)
                $selection=Read-Host 'Treatment number'
                $number=0
                if (-not [int]::TryParse($selection,[ref]$number) -or $number -lt 1 -or $number -gt $catalog.Count) { Write-Warning 'Choose a displayed treatment number.'; continue }
                $entry=$catalog[$number-1]
                Invoke-UxRomStableProviderStart -Root $Root -Entry $entry
            }
            '3' { Resume-UxRomStableProvider -Root $Root }
            '4' {
                $harnesses=@(Get-UxRomStableCatalog -Root $Root | Where-Object kind -eq 'Harness')
                if($harnesses.Count -eq 0){Write-Host 'No merged reboot harnesses were discovered.' -ForegroundColor DarkYellow;continue}
                for($i=0;$i-lt$harnesses.Count;$i++){Write-Host ("{0}. {1}  {2}" -f ($i+1),$harnesses[$i].experiment,$harnesses[$i].name)}
                $selection=Read-Host 'Harness number'
                $number=0
                if (-not [int]::TryParse($selection,[ref]$number) -or $number -lt 1 -or $number -gt $harnesses.Count) { Write-Warning 'Choose a displayed harness number.'; continue }
                Invoke-UxRomStableHarness -Root $Root -Entry $harnesses[$number-1]
            }
            '5' { Show-UxRomStableLedger -Root $Root }
            '6' { Deploy-UxRomMachineStableProvider -Root $Root }
            'r' { [void](Show-UxRomStableCatalog -Root $Root -Refresh) }
            'R' { [void](Show-UxRomStableCatalog -Root $Root -Refresh) }
            'b' { return }
            'B' { return }
            default { Write-Warning 'Unknown validation choice.' }
        }
    } while($true)
}
