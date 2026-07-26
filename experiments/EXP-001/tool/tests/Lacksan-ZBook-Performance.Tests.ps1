#requires -Version 5.1

$tool = (Resolve-Path (Join-Path $PSScriptRoot '..\Lacksan-ZBook-Performance.ps1')).Path
$tokens = $null
$parseErrors = $null
$toolAst = [Management.Automation.Language.Parser]::ParseFile($tool, [ref]$tokens, [ref]$parseErrors)
$sourceText = Get-Content -LiteralPath $tool -Raw

function Get-ToolFunctionText {
    param([Parameter(Mandatory = $true)][string]$Name)
    $definition = @(
        $toolAst.FindAll({
            param($node)
            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $Name
        }, $true)
    ) | Select-Object -First 1
    if ($null -eq $definition) {
        throw "Function '$Name' was not found."
    }
    return $definition.Extent.Text
}

Invoke-Expression (Get-ToolFunctionText -Name Test-SupportedSystem)
Invoke-Expression (Get-ToolFunctionText -Name Test-PrivacySupport)
Invoke-Expression (Get-ToolFunctionText -Name Request-ManagedDeviceDecision)
Invoke-Expression (Get-ToolFunctionText -Name Test-EquivalentValue)
Invoke-Expression (Get-ToolFunctionText -Name Get-PrivacyState)

function Write-LabEvent {
    param($Event, $Status, $Data)
}

function Get-RegistryState {
    param($Path, $Name)
}

function New-TestSnapshot {
    param(
        [bool]$Managed,
        [string]$Model = 'HP ZBook Firefly 14 inch G8 Mobile Workstation PC',
        [string]$OsCaption = 'Microsoft Windows 11 Pro'
    )
    [pscustomobject]@{
        Manufacturer = 'HP'
        Model = $Model
        Cpu = @('11th Gen Intel(R) Core(TM) i5-1145G7 @ 2.60GHz')
        OsCaption = $OsCaption
        OsBuild = '26200'
        BiosVersion = 'T76 Ver. 01.24.02'
        JoinState = [pscustomobject]@{
            ActiveManagementDetected = $Managed
        }
    }
}

$script:Expected = [ordered]@{
    Manufacturer = 'HP'
    Model = 'HP ZBook Firefly 14 inch G8 Mobile Workstation PC'
    CpuPattern = 'i5-1145G7'
    OsBuild = '26200'
    BiosVersion = 'T76 Ver. 01.24.02'
}
$script:PrivacySettings = @(
    [pscustomobject]@{
        Id = 'SignIn.HideAccountDetails'
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        Name = 'BlockUserFromShowingAccountDetailsOnSignin'
        Type = 'DWord'
        Desired = [int]1
    }
)

Describe 'Managed-device numeric authorization' {
    BeforeEach {
        $script:AllowManagedDeviceForRun = $false
        Mock Write-Host {}
        Mock Write-LabEvent {}
    }

    It 'does not prompt when no active management signal exists' {
        Mock Read-Host { throw 'Read-Host should not be called.' }
        $decision = Request-ManagedDeviceDecision -Snapshot (New-TestSnapshot -Managed $false) -RequestedAction Tune
        $decision | Should Be 'Proceed'
        Assert-MockCalled Read-Host -Times 0 -Scope It
    }

    It 'accepts numeric choice 1 for this run only' {
        Mock Read-Host { '1' }
        $decision = Request-ManagedDeviceDecision -Snapshot (New-TestSnapshot -Managed $true) -RequestedAction Tune
        $decision | Should Be 'Proceed'
        $script:AllowManagedDeviceForRun | Should Be $true
    }

    It 'returns exact rollback for numeric choice 2' {
        Mock Read-Host { '2' }
        $decision = Request-ManagedDeviceDecision -Snapshot (New-TestSnapshot -Managed $true) -RequestedAction FullTest
        $decision | Should Be 'Undo'
        $script:AllowManagedDeviceForRun | Should Be $false
    }

    It 'rejects words and accepts a later numeric cancellation' {
        $script:answers = New-Object Collections.Queue
        $script:answers.Enqueue('APPLY')
        $script:answers.Enqueue('3')
        Mock Read-Host { $script:answers.Dequeue() }
        $decision = Request-ManagedDeviceDecision -Snapshot (New-TestSnapshot -Managed $true) -RequestedAction RestartTest
        $decision | Should Be 'Cancel'
        Assert-MockCalled Read-Host -Times 2 -Scope It
    }

    It 'does not let the management prompt bypass the hardware support lock' {
        Mock Read-Host { '1' }
        { Request-ManagedDeviceDecision -Snapshot (New-TestSnapshot -Managed $true -Model 'Other PC') -RequestedAction Tune } |
            Should Throw
        Assert-MockCalled Read-Host -Times 0 -Scope It
    }
}

Describe 'Managed-device regression guards' {
    It 'parses without PowerShell errors' {
        @($parseErrors).Count | Should Be 0
    }

    It 'does not classify the generic maintenance task as active management' {
        $joinState = @(
            $toolAst.FindAll({
                param($node)
                $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq 'Get-JoinState'
            }, $true)
        )[0].Extent.Text
        $joinState | Should Match '\$values\.EnrollmentSpecificTaskCount -gt 0'
        $joinState | Should Not Match '\$values\.EnterpriseMgmtTaskCount -gt 0'
    }

    It 'forwards approval through the administrator relaunch' {
        $sourceText | Should Match "\`$argumentLine \+= ' -AllowManagedDevice'"
        $sourceText | Should Match "\`$argumentLine \+= ' -InteractiveManagedApproval'"
    }

    It 'renders live current, selected, and evidence state' {
        $sourceText | Should Match 'function Show-Configuration'
        $sourceText | Should Match '\$states = @\(Get-ConfigurationState\)'
        $sourceText | Should Match "'CURRENT', 'SELECTED', 'EXPECTED EFFECT'"
        $sourceText | Should Match 'PERFORMANCE GAIN: NOT ESTABLISHED'
    }
}

Describe 'Low-friction sign-in privacy' {
    BeforeEach {
        Mock Get-RegistryState {
            [pscustomobject]@{
                KeyExists = $true
                ValueExists = $true
                Type = 'DWord'
                Value = [int]1
            }
        }
    }

    It 'recognizes the documented policy value as compliant' {
        $state = @(Get-PrivacyState)
        $state.Count | Should Be 1
        $state[0].Compliant | Should Be $true
        $state[0].Effect | Should Match 'display name remains visible'
    }

    It 'does not confuse an absent policy with hidden details' {
        Mock Get-RegistryState {
            [pscustomobject]@{
                KeyExists = $true
                ValueExists = $false
                Type = $null
                Value = $null
            }
        }
        $state = @(Get-PrivacyState)
        $state[0].Compliant | Should Be $false
        $state[0].Current | Should Be '<not configured>'
    }

    It 'keeps full last-user hiding out of the low-friction action' {
        $sourceText | Should Match 'BlockUserFromShowingAccountDetailsOnSignin'
        $sourceText | Should Not Match "Name = 'DontDisplayLastUserName'"
    }

    It 'accepts the documented Windows Pro edition on the validated ZBook' {
        $support = Test-PrivacySupport -Snapshot (New-TestSnapshot -Managed $false)
        $support.Supported | Should Be $true
        $support.Policy | Should Match 'BlockUserFromShowingAccountDetailsOnSignin'
    }

    It 'rejects an edition outside the documented policy support list' {
        $support = Test-PrivacySupport -Snapshot (New-TestSnapshot -Managed $false -OsCaption 'Microsoft Windows 11 Home')
        $support.Supported | Should Be $false
        @($support.Reasons) -join ' ' | Should Match 'outside the documented policy support list'
    }

    It 'includes backup, verification, idempotence, and exact rollback paths' {
        $sourceText | Should Match 'function New-PrivacyBackup'
        $sourceText | Should Match 'function Invoke-PrivacyApply'
        $sourceText | Should Match 'PrivacyApplyIdempotent'
        $sourceText | Should Match 'PrivacyApplyVerification'
        $sourceText | Should Match 'Restore-RegistryState -Entry'
        $sourceText | Should Match 'PrivacyRollbackVerification'
    }
}
