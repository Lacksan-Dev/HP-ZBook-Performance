BeforeAll {
    $scriptPath=Join-Path $PSScriptRoot '..\Invoke-EdgeFirstRunPolicy.ps1'
    $source=Get-Content -LiteralPath $scriptPath -Raw
}
Describe 'EXP-036 engineering contract' {
    It 'parses as PowerShell' {
        $tokens=$null;$errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)
        $errors.Count|Should -Be 0
    }
    It 'uses ShouldProcess and the complete lifecycle' {
        $source|Should -Match 'SupportsShouldProcess=\$true'
        foreach($action in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')){$source|Should -Match "'$action'"}
    }
    It 'targets only the documented Edge policy value' {
        $source|Should -Match 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge'
        $source|Should -Match 'HideFirstRunExperience'
        $source|Should -Match 'PropertyType DWord -Value 1'
    }
    It 'detects Edge version and enterprise management' {
        $source|Should -Match 'ProductVersion'
        $source|Should -Match 'AzureAdJoined'
        $source|Should -Match 'DomainJoined'
        $source|Should -Match 'WorkplaceJoined'
        $source|Should -Match 'refusing to override management'
    }
    It 'captures exact state and logs JSONL failures' {
        $source|Should -Match 'DoNotExpandEnvironmentNames'
        $source|Should -Match 'GetValueKind'
        $source|Should -Match 'ConvertTo-Json -Compress'
        $source|Should -Match "'failure' 'fail'"
    }
    It 'contains no profile, cache, startup, service, task, package, or driver mutation' {
        foreach($token in @('Remove-AppxPackage','Uninstall-Package','Set-Service','Disable-ScheduledTask','Unregister-ScheduledTask','Clear-BrowsingData','User Data','Startup\\','pnputil','devcon')){$source|Should -Not -Match ([regex]::Escape($token))}
    }
}
