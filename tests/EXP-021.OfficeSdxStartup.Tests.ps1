BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\experiments\EXP-021\OfficeSdxStartup.psm1'
    Import-Module $modulePath -Force
}

Describe 'EXP-021 Office SDX startup calibration contract' {
    It 'exports the required engineering functions' {
        $required = @(
            'Test-Exp021Support','Get-Exp021Candidate','Save-Exp021State',
            'Test-Exp021Applied','Invoke-Exp021Apply','Test-Exp021Rollback',
            'Invoke-Exp021Rollback','Test-Exp021RebootPersistence'
        )
        foreach ($name in $required) { Get-Command $name -ErrorAction Stop | Should -Not -BeNullOrEmpty }
    }

    It 'uses ShouldProcess for both change functions' {
        (Get-Command Invoke-Exp021Apply).Parameters.Keys | Should -Contain 'WhatIf'
        (Get-Command Invoke-Exp021Rollback).Parameters.Keys | Should -Contain 'WhatIf'
    }

    It 'contains strict candidate identity and protected boundaries' {
        $source = Get-Content (Join-Path $PSScriptRoot '..\experiments\EXP-021\OfficeSdxStartup.psm1') -Raw
        $source | Should -Match 'sdxhelper\\\.exe'
        $source | Should -Match 'Current candidate differs from captured state'
        $source | Should -Match 'different value now occupies the captured name'
        $source | Should -Not -Match 'Stop-Service|Set-Service|Disable-ScheduledTask|Remove-AppxPackage|Uninstall'
    }

    It 'provides exact state identity controls' {
        $source = Get-Content (Join-Path $PSScriptRoot '..\experiments\EXP-021\OfficeSdxStartup.psm1') -Raw
        $source | Should -Match 'experimentId'
        $source | Should -Match 'computerName'
        $source | Should -Match 'userSid'
        $source | Should -Match 'ValueKind'
        $source | Should -Match 'DoNotExpandEnvironmentNames'
    }

    It 'provides logging, idempotence, verification, and reboot evidence' {
        $source = Get-Content (Join-Path $PSScriptRoot '..\experiments\EXP-021\OfficeSdxStartup.psm1') -Raw
        $source | Should -Match 'ConvertTo-Json'
        $source | Should -Match 'AlreadyApplied'
        $source | Should -Match 'Application verification failed'
        $source | Should -Match 'Rollback verification failed'
        $source | Should -Match 'LastBootUpTime'
    }
}
