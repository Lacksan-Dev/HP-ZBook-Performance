$repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$sut = Join-Path $repoRoot 'controller\release\UxRomStableValidation.ps1'

Describe 'UX-ROM Stable release catalog' {
    BeforeEach {
        . $sut
        Mock Get-UxRomStableRoot { return $TestDrive }
        Mock Write-UxRomStableJson { }
    }

    It 'combines scalar provider and experiment results without PSObject op_Addition failure' {
        Mock Get-UxRomMergedProviderCatalog {
            [pscustomobject]@{ experiment=$null; name='ProviderOne'; layer=8; kind='Provider'; path='controller/providers/ProviderOne.ps1' }
        }
        Mock Get-UxRomMergedExperimentCatalog {
            [pscustomobject]@{ experiment='EXP-999'; name='ControllerOne'; layer=8; kind='Controller'; path='experiments/EXP-999/ControllerOne.ps1' }
        }

        $result = @(Get-UxRomStableCatalog -Root $TestDrive -Refresh)

        $result.Count | Should -Be 2
        @($result.name) | Should -Contain 'ProviderOne'
        @($result.name) | Should -Contain 'ControllerOne'
    }
}
