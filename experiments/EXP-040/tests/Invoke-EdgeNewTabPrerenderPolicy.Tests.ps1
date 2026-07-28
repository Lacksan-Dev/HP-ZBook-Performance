BeforeAll {
    $scriptPath=Join-Path $PSScriptRoot '..\Invoke-EdgeNewTabPrerenderPolicy.ps1'
    $source=Get-Content -LiteralPath $scriptPath -Raw
}
Describe 'EXP-040 engineering contract' {
    It 'parses as PowerShell' {
        $tokens=$null;$errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)
        $errors.Count|Should -Be 0
    }
    It 'uses only the recommended NewTabPagePrerenderEnabled policy' {
        $source|Should -Match 'Recommended'
        $source|Should -Match 'NewTabPagePrerenderEnabled'
        $source|Should -Match 'PropertyType DWord -Value 1'
    }
    It 'requires Edge 85 or later' {$source|Should -Match 'version.Major -ge 85'}
    It 'implements the complete lifecycle' {
        foreach($token in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback','SupportsShouldProcess','ConvertTo-Json -Compress','Read-State','Write-ExpLog')){$source.Contains($token)|Should -BeTrue}
    }
    It 'refuses enterprise management and existing policy' {
        $source|Should -Match 'Enterprise management detected'
        $source|Should -Match 'Existing mandatory or recommended Edge policy detected'
    }
    It 'excludes destructive and protected-scope operations' {
        foreach($token in @('Remove-AppxPackage','Uninstall-Package','Set-Service','Stop-Service','Disable-ScheduledTask','Unregister-ScheduledTask','pnputil','devcon')){$source.Contains($token)|Should -BeFalse}
    }
    It 'verifies exact rollback and mutation refusal' {
        $source|Should -Match 'Rollback refused'
        $source|Should -Match 'Rollback verification failed'
    }
}
