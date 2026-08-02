#requires -Version 5.1

<#
.SYNOPSIS
    UX-ROM layer integration correction.

.DESCRIPTION
    Keeps assessment capability separate from treatment availability. In the
    interactive UX-ROM console, a layer with a working profiler remains runnable
    even when its older built-in candidate array is empty. Redirected automation
    keeps the legacy no-candidate behavior so scripted callers do not unexpectedly
    execute a read-only profile. Validation-ready treatments live under V.
#>

Set-StrictMode -Version 2.0

function Invoke-SelectedPerformanceLayer {
    param(
        [string]$Root,
        [ValidateRange(1, 12)][int]$LayerNumber,
        [hashtable]$Runtime
    )

    $state = Get-LayerWorkflowState -Root $Root
    if ($state.activeCandidate) {
        if ([int]$state.currentLayer -ne $LayerNumber) {
            Write-Host "Layer $($state.currentLayer) has an unfinished change. Finish its measurement or rollback before changing layers." -ForegroundColor DarkYellow
            return
        }
        Invoke-NextLayerWorkflowStep -Root $Root -State $state -Runtime $Runtime
        return
    }

    $layer = Get-PerformanceLayer -Number $LayerNumber
    $candidate = Get-NextLayerCandidate -State $state -Layer $LayerNumber
    Write-Host ''
    Write-Host "Layer $LayerNumber - $($layer.name)" -ForegroundColor Cyan
    Write-Host $layer.description

    $interactiveAssessment = $false
    if (Get-Command Test-UxRomAnimationEnabled -ErrorAction SilentlyContinue) {
        $interactiveAssessment = [bool](Test-UxRomAnimationEnabled)
    }

    # Preserve the established automation contract. The product UI takes the richer
    # path below, while redirected/scripted callers with no treatment still return.
    if (-not $candidate -and -not $interactiveAssessment) {
        Write-Host 'No legacy EXP-047 treatment is registered for this layer.' -ForegroundColor DarkGray
        Write-Host 'Use the Physical Validation / Stable Promotion surface for merged treatments.' -ForegroundColor DarkGray
        return
    }

    Set-LayerWorkflowCurrentLayer -Root $Root -State $state -Layer $LayerNumber

    if ([string]$layer.assessment -ne 'NotIntegrated') {
        Write-Host "Assessment: $($layer.assessmentLabel)" -ForegroundColor DarkGray
        Invoke-LayerAssessmentStep @Runtime -Root $Root -State $state
    } else {
        Write-Host "Assessment integration pending: $($layer.assessmentLabel)" -ForegroundColor DarkYellow
    }

    if (-not $candidate) {
        Write-Host ''
        if ([string]$layer.assessment -ne 'NotIntegrated') {
            Write-Host 'Assessment complete.' -ForegroundColor Green
        }
        Write-Host 'No legacy EXP-047 treatment is registered for this layer.' -ForegroundColor DarkGray
        Write-Host 'Press V from the main menu for merged Physical Validation / Stable Promotion providers.' -ForegroundColor Cyan
        return
    }

    Write-Host "Preparing legacy integrated treatment: $(Get-CandidateDisplayName -Name $candidate)" -ForegroundColor Cyan
    Write-Host 'The support checks and fresh cumulative baseline run automatically before the change.'
    Invoke-LayerEnhancementStep `
        -Root $Root `
        -State $state `
        -Seconds $Runtime.Seconds `
        -Interval $Runtime.Interval `
        -SkipTrace:$Runtime.SkipTrace `
        -DryRun:$Runtime.DryRun
}
