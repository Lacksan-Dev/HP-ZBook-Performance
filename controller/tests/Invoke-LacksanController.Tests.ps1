$controllerPath = Join-Path $PSScriptRoot '..\Invoke-LacksanController.ps1'
$manifestPath = Join-Path $PSScriptRoot '..\lacksan.manifest.json'
$providerPath = Join-Path $PSScriptRoot '..\providers\SystemInventory.ps1'

Describe 'EXP-046 Lacksan Controller contracts' {
    It 'declares every required controller action' {
        $text = Get-Content -LiteralPath $controllerPath -Raw
        foreach ($action in @('Scan','Recommend','DryRun','Apply','Verify','VerifyReboot','Report','Rollback')) {
            $text | Should Match ([regex]::Escape("'$action'"))
        }
    }

    It 'uses ShouldProcess for apply and rollback' {
        $text = Get-Content -LiteralPath $controllerPath -Raw
        $text | Should Match 'SupportsShouldProcess'
        $text | Should Match '\$PSCmdlet\.ShouldProcess'
    }

    It 'validates dependencies conflicts and protected scopes' {
        $text = Get-Content -LiteralPath $controllerPath -Raw
        $text | Should Match 'requires'
        $text | Should Match 'conflicts'
        foreach ($scope in @('WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale')) {
            $text | Should Match $scope
        }
    }

    It 'captures transaction identity and performs reverse rollback' {
        $text = Get-Content -LiteralPath $controllerPath -Raw
        $text | Should Match 'userSid'
        $text | Should Match 'machine'
        $text | Should Match 'Get-Reversed'
        $text | Should Match "Invoke-Provider.*'Rollback'"
    }

    It 'ships a valid schema-one manifest and read-only initial profile' {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.schemaVersion | Should Be 1
        @($manifest.profiles | Where-Object id -eq 'InventoryOnly').Count | Should Be 1
        @($manifest.providers | Where-Object id -eq 'system-inventory' | Where-Object mode -eq 'ReadOnly').Count | Should Be 1
    }

    It 'keeps the initial provider mutation-free and reversible by contract' {
        $text = Get-Content -LiteralPath $providerPath -Raw
        $text | Should Match 'mutationCount = 0'
        $text | Should Match "'DryRun'"
        $text | Should Match "'Apply'"
        $text | Should Match "'VerifyReboot'"
        $text | Should Match "'Rollback'"
        $text | Should Not Match 'Remove-ItemProperty|Set-ItemProperty|New-Service|Set-Service|Disable-ScheduledTask'
    }
}
