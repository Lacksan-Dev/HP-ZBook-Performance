BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\Invoke-LogiTuneRunCalibration.ps1'
    $source = Get-Content -LiteralPath $scriptPath -Raw
}
Describe 'EXP-034 engineering contract' {
    It 'parses as PowerShell' {
        $tokens=$null;$errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
    }
    It 'uses ShouldProcess for removal and restoration' {
        $source | Should -Match 'SupportsShouldProcess=\$true'
        $source | Should -Match 'ShouldProcess'
    }
    It 'supports the complete reversible lifecycle' {
        foreach($action in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')){$source | Should -Match "'$action'"}
    }
    It 'captures unexpanded registry data and value kind' {
        $source | Should -Match 'DoNotExpandEnvironmentNames'
        $source | Should -Match 'GetValueKind'
    }
    It 'uses bounded Logi Tune identity checks' {
        $source | Should -Match 'Test-LogiTuneIdentity'
        $source | Should -Match 'LogiTune\\.exe'
        $source | Should -Match 'updater'
    }
    It 'logs structured JSONL records and failures' {
        $source | Should -Match 'ConvertTo-Json -Compress'
        $source | Should -Match "'failure' 'fail'"
    }
    It 'refuses rollback overwrite' {
        $source | Should -Match 'Rollback refused because the registration already exists'
    }
    It 'contains no destructive package, service, task, or driver operations' {
        foreach($token in @('Remove-AppxPackage','Uninstall-Package','Set-Service','Disable-ScheduledTask','Unregister-ScheduledTask','pnputil','devcon')){$source | Should -Not -Match ([regex]::Escape($token))}
    }
}
