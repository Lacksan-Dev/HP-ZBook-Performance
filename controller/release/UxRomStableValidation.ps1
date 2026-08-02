#requires -Version 5.1

<#
.SYNOPSIS
    UX-ROM machine physical-validation and Stable-promotion surface.

.DESCRIPTION
    Discovers validation-ready providers merged to main, makes them runnable from
    UX-ROM, records machine-local evidence, and recognizes the operator's explicit
    Stable approval. The local ledger never claims a physical result before the
    corresponding provider or harness actually runs on this machine.
#>

Set-StrictMode -Version 2.0

$script:StableValidationSchema = 1
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
    if ($text -match '(?i)firmware|bios|uefi') { return 3 }
    if ($text -match '(?i)driver|dpc|isr') { return 4 }
    if ($text -match '(?i)power') { return 6 }
    if ($text -match '(?i)security|defender|firewall') { return 7 }
    if ($text -match '(?i)policy|mdm|enrollment|group') { return 9 }
    if ($text -match '(?i)edge' -and $text -notmatch '(?i)startup|windowsstartup|run|task') { return 11 }
    if ($text -match '(?i)startup|runonce|run|signin|logon|task|service|touchpoint|hotkey|logi|teams|office|microsoft365|oneagent') { return 8 }
    if ($text -match '(?i)shell|explorer|visual') { return 10 }
    return 8
}

function Get-UxRomKnownHarnessCatalog {
    return @(
        [pscustomobject][ordered]@{ experiment='EXP-024'; name='HP Touchpoint reboot-aware validation'; layer=8; kind='Harness'; path='experiments/EXP-024/Invoke-Exp024LabHarness.ps1'; controller='experiments/EXP-024/Invoke-Exp024HpTouchpoint.ps1' },
        [pscustomobject][ordered]@{ experiment='EXP-065'; name='HP System Info reboot-aware validation'; layer=8; kind='Harness'; path='experiments/EXP-065/Invoke-Exp065LabHarness.ps1'; controller='experiments/EXP-065/Invoke-Exp065HpSystemInfo.ps1' },
        [pscustomobject][ordered]@{ experiment='EXP-120'; name='HP Hotkey reboot-aware validation'; layer=8; kind='Harness'; path='experiments/EXP-120/Invoke-Exp120LabHarness.ps1'; controller='experiments/EXP-120/Invoke-Exp120HpHotkey.ps1' },
        [pscustomobject][ordered]@{ experiment='EXP-131'; name='HP Comm Recovery delayed-start controller'; layer=8; kind='Controller'; path='experiments/EXP-131/Invoke-Exp131HpCommRecovery.ps1'; controller=$null }
    )
}

function Get-UxRomMergedProviderCatalog {
    param([string]$Root,[switch]$Refresh)

    $stableRoot = Get-UxRomStableRoot -Root $Root
    $cachePath = Join-Path $stableRoot 'provider-catalog.json'
    if (-not $Refresh -and (Test-Path -LiteralPath $cachePath)) {
        try {
            $cached = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json
            $captured = [datetime]$cached.capturedUtc
            if (((Get-Date).ToUniversalTime() - $captured.ToUniversalTime()).TotalMinutes -lt 30) {
                return @($cached.providers)
            }
        } catch {}
    }

    $headers = @{ 'User-Agent' = 'Lacksan-UX-ROM'; 'Accept' = 'application/vnd.github+json' }
    $uri = "$script:StableApiRoot/contents/controller/providers?ref=main"
    $items = @(Invoke-RestMethod -UseBasicParsing -Headers $headers -Uri $uri -Method Get)
    $providers = @()
    foreach ($item in $items | Where-Object { $_.type -eq 'file' -and $_.name -like '*.ps1' }) {
        if ($item.name -match '(?i)test|integration') { continue }
        $providers += [pscustomobject][ordered]@{
            experiment = $null
            name = [IO.Path]::GetFileNameWithoutExtension([string]$item.name)
            layer = Get-UxRomStableLayer -Name ([string]$item.name) -Path ([string]$item.path)
            kind = 'Provider'
            path = [string]$item.path
            downloadUrl = [string]$item.download_url
            sha = [string]$item.sha
            approval = $script:StableApprovalId
            releaseState = 'Stable approved / physical validation pending'
        }
    }
    $record = [ordered]@{ schemaVersion=$script:StableValidationSchema; capturedUtc=[DateTime]::UtcNow.ToString('o'); providers=@($providers) }
    Write-UxRomStableJson -Path $cachePath -Value $record
    return @($providers)
}

function Get-UxRomStableCatalog {
    param([string]$Root,[switch]$Refresh)
    $providers = @(Get-UxRomMergedProviderCatalog -Root $Root -Refresh:$Refresh)
    $known = @(Get-UxRomKnownHarnessCatalog)
    return @($providers + $known | Sort-Object layer,experiment,name,path)
}

function Resolve-UxRomStableScript {
    param([string]$Root,[Parameter(Mandatory=$true)][object]$Entry,[switch]$Controller)
    $stableRoot = Get-UxRomStableRoot -Root $Root
    $relative = if ($Controller -and $Entry.controller) { [string]$Entry.controller } else { [string]$Entry.path }
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
    if (@($errors).Count -gt 0) { throw "PowerShell parser rejected $Path: $($errors[0].Message)" }
    $parameterNames = @()
    if ($ast.ParamBlock) { $parameterNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }) }
    $source = Get-Content -LiteralPath $Path -Raw
    $actions = @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') | Where-Object { $source -match "['\"]$_['\"]" }
    return [pscustomobject][ordered]@{
        parameters=$parameterNames
        lifecycleActions=$actions
        standardProvider=($parameterNames -contains 'Action' -and @($actions).Count -eq 7)
        harness=($parameterNames -contains 'Action' -and $source -match "['\"]Start['\"]" -and $source -match "['\"]Continue['\"]")
    }
}

function Get-UxRomStableLedger {
    param([string]$Root)
    $stableRoot=Get-UxRomStableRoot -Root $Root
    $path=Join-Path $stableRoot 'ledger\machine-stable.json'
    if (Test-Path -LiteralPath $path) { return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json }
    return [pscustomobject][ordered]@{ schemaVersion=1; machine=$env:COMPUTERNAME; approval=$script:StableApprovalId; entries=@() }
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
    $ledger.entries | Select-Object experiment,name,status,completedUtc,evidencePath | Format-Table -AutoSize | Out-Host
}

function Show-UxRomStableCatalog {
    param([string]$Root,[switch]$Refresh)
    $catalog=@(Get-UxRomStableCatalog -Root $Root -Refresh:$Refresh)
    Write-Host ''
    Write-Host 'Physical Validation / Stable Promotion' -ForegroundColor Cyan
    Write-Host "Human approval: $script:StableApprovalId" -ForegroundColor Green
    Write-Host 'Merged validation-ready engineering is runnable here. Physical status is recorded from this machine.' -ForegroundColor DarkGray
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
    $scriptPath=Resolve-UxRomStableScript -Root $Root -Entry $Entry
    $contract=Get-UxRomScriptContract -Path $scriptPath
    if (-not $contract.standardProvider) { throw "The selected script does not expose the standard seven-action provider lifecycle: $($Entry.path)" }

    $stableRoot=Get-UxRomStableRoot -Root $Root
    $stamp=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
    $slug=([IO.Path]::GetFileNameWithoutExtension([string]$Entry.path) -replace '[^A-Za-z0-9_.-]','-')
    $runDir=Join-Path (Join-Path $stableRoot 'runs') "$stamp-$slug"
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    $state=Join-Path $runDir 'provider-state.json'
    $log=Join-Path $runDir 'provider-events.jsonl'

    Write-Progress -Activity "Physical validation: $($Entry.name)" -Status 'Checking machine eligibility' -PercentComplete 5
    $check=& $scriptPath -Action Check -StatePath $state -LogPath $log
    $experiment=$null
    try { if ($check.PSObject.Properties.Name -contains 'Experiment') { $experiment=[string]$check.Experiment } } catch {}
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
        schemaVersion=1; id=[guid]::NewGuid().ToString(); experiment=$experiment; name=[string]$Entry.name; providerPath=[string]$Entry.path
        localScript=$scriptPath; statePath=$state; logPath=$log; runDirectory=$runDir; approval=$script:StableApprovalId
        capturedBootUtc=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
        status='TreatmentVerifiedAwaitingReboot'; startedUtc=[DateTime]::UtcNow.ToString('o')
    }
    Write-UxRomStableJson -Path (Join-Path $stableRoot 'active.json') -Value $active
    Write-Progress -Activity "Physical validation: $($Entry.name)" -Status 'Reboot verification required' -PercentComplete 100
    Write-Progress -Activity "Physical validation: $($Entry.name)" -Completed
    Write-Host ''
    Write-Host 'Treatment applied and immediately verified.' -ForegroundColor Green
    Write-Host 'Reboot Windows, reopen UX-ROM, choose V, then choose Resume pending validation.' -ForegroundColor Yellow
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
    Write-Progress -Activity "Physical validation: $($active.name)" -Status 'Recording machine evidence' -PercentComplete 85

    $record=[ordered]@{
        schemaVersion=1; id=[string]$active.id; experiment=[string]$active.experiment; name=[string]$active.name
        status='Physical mechanics validated / performance evidence may still be required'; approval=$script:StableApprovalId
        completedUtc=[DateTime]::UtcNow.ToString('o'); evidencePath=[string]$active.runDirectory
        providerPath=[string]$active.providerPath; rebootVerified=$true; rollbackExecuted=$true
        stableClaim=$false
        qualification='Support, capture, dry run, apply, immediate verification, reboot verification, and exact rollback executed on this machine. Experiment-specific repeated benchmark and functional gates remain authoritative before a performance treatment is labeled Stable.'
    }
    Add-UxRomStableLedgerEntry -Root $Root -Entry ([pscustomobject]$record)
    Remove-Item -LiteralPath $activePath -Force
    Write-Progress -Activity "Physical validation: $($active.name)" -Completed
    Write-Host 'Physical provider lifecycle completed and rollback verified.' -ForegroundColor Green
    Write-Host 'The result is in the machine ledger. Performance Stable status waits for that experiment''s repeated benchmark/functional gate.' -ForegroundColor DarkYellow
}

function Invoke-UxRomKnownHarness {
    param([string]$Root,[object]$Entry)
    if ($Entry.kind -ne 'Harness') { throw 'Choose a Harness entry for full reboot-aware benchmark execution.' }
    $harness=Resolve-UxRomStableScript -Root $Root -Entry $Entry
    $controller=Resolve-UxRomStableScript -Root $Root -Entry $Entry -Controller
    $stableRoot=Get-UxRomStableRoot -Root $Root
    $evidence=Join-Path (Join-Path $stableRoot 'runs') ([string]$Entry.experiment)
    Write-Host "Starting $($Entry.experiment) with five baseline and five treatment runs." -ForegroundColor Cyan
    Write-Host 'The harness persists across logon and uses its own exact rollback path.' -ForegroundColor DarkGray
    & $harness -Action Start -RunsPerArm 5 -EvidenceRoot $evidence -ControllerPath $controller -AllowAutomaticReboot -Confirm:$false
}

function Show-UxRomStableValidationMenu {
    param([string]$Root)
    do {
        Write-Host ''
        Write-Host 'Physical Validation / Stable Promotion' -ForegroundColor Cyan
        Write-Host "Human Stable approval: $script:StableApprovalId" -ForegroundColor Green
        Write-Host '1. Show every merged validation-ready provider'
        Write-Host '2. Run one provider through apply + immediate verification'
        Write-Host '3. Resume pending provider after reboot + prove rollback'
        Write-Host '4. Run a full five-baseline / five-treatment reboot harness'
        Write-Host '5. Show this machine''s validation / Stable ledger'
        Write-Host 'R. Refresh merged-provider catalog from main'
        Write-Host 'B. Back'
        $choice=Read-Host 'Choose validation action'
        switch($choice){
            '1' { [void](Show-UxRomStableCatalog -Root $Root) }
            '2' {
                $catalog=@(Show-UxRomStableCatalog -Root $Root)
                $selection=Read-Host 'Provider number'
                $number=0
                if (-not [int]::TryParse($selection,[ref]$number) -or $number -lt 1 -or $number -gt $catalog.Count) { Write-Warning 'Choose a displayed provider number.'; continue }
                $entry=$catalog[$number-1]
                if ($entry.kind -eq 'Harness') { Write-Warning 'Use option 4 for a reboot-aware Harness entry.'; continue }
                Invoke-UxRomStableProviderStart -Root $Root -Entry $entry
            }
            '3' { Resume-UxRomStableProvider -Root $Root }
            '4' {
                $harnesses=@(Get-UxRomKnownHarnessCatalog | Where-Object kind -eq 'Harness')
                for($i=0;$i-lt$harnesses.Count;$i++){Write-Host ("{0}. {1}  {2}" -f ($i+1),$harnesses[$i].experiment,$harnesses[$i].name)}
                $selection=Read-Host 'Harness number'
                $number=0
                if (-not [int]::TryParse($selection,[ref]$number) -or $number -lt 1 -or $number -gt $harnesses.Count) { Write-Warning 'Choose a displayed harness number.'; continue }
                Invoke-UxRomKnownHarness -Root $Root -Entry $harnesses[$number-1]
            }
            '5' { Show-UxRomStableLedger -Root $Root }
            'r' { [void](Show-UxRomStableCatalog -Root $Root -Refresh) }
            'R' { [void](Show-UxRomStableCatalog -Root $Root -Refresh) }
            'b' { return }
            'B' { return }
            default { Write-Warning 'Unknown validation choice.' }
        }
    } while($true)
}
