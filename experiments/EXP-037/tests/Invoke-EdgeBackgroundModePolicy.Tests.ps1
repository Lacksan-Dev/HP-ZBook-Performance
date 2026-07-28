BeforeAll{$scriptPath=Join-Path $PSScriptRoot '..\Invoke-EdgeBackgroundModePolicy.ps1';$source=Get-Content -LiteralPath $scriptPath -Raw}
Describe 'EXP-037 engineering contract'{
It 'parses as PowerShell'{$t=$null;$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$t,[ref]$e);$e.Count|Should -Be 0}
It 'uses the recommended BackgroundModeEnabled policy only'{$source|Should -Match 'Recommended';$source|Should -Match 'BackgroundModeEnabled';$source|Should -Match 'PropertyType DWord -Value 0'}
It 'implements complete lifecycle controls' {foreach($x in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback','SupportsShouldProcess','ConvertTo-Json -Compress','Read-State','Write-ExpLog')){$source.Contains($x)|Should -BeTrue}}
It 'refuses enterprise management and existing policy'{$source|Should -Match 'Enterprise management detected';$source|Should -Match 'Existing mandatory or recommended Edge policy detected'}
It 'excludes destructive and protected-scope operations'{foreach($x in @('Remove-AppxPackage','Uninstall-Package','Set-Service','Stop-Service','Disable-ScheduledTask','Unregister-ScheduledTask','pnputil','devcon')){$source.Contains($x)|Should -BeFalse}}
It 'verifies exact rollback'{$source|Should -Match 'Rollback refused';$source|Should -Match 'Rollback verification failed'}
}