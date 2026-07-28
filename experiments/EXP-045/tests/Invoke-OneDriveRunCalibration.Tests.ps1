BeforeAll{$scriptPath=Join-Path $PSScriptRoot '..\Invoke-OneDriveRunCalibration.ps1';$source=Get-Content -LiteralPath $scriptPath -Raw}
Describe 'EXP-045 engineering contract'{
 It 'parses as PowerShell'{$tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors);$errors.Count|Should -Be 0}
 It 'uses ShouldProcess for removal and restoration'{$source|Should -Match 'SupportsShouldProcess=\$true';$source|Should -Match 'ShouldProcess'}
 It 'supports the complete reversible lifecycle'{foreach($a in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')){$source|Should -Match "'$a'"}}
 It 'captures unexpanded registry data and value kind'{$source|Should -Match 'DoNotExpandEnvironmentNames';$source|Should -Match 'GetValueKind'}
 It 'uses bounded OneDrive identity checks'{$source|Should -Match 'Test-OneDriveIdentity';$source|Should -Match 'OneDrive\\.exe';$source|Should -Match '/background';$source|Should -Match 'OneDriveSetup';$source|Should -Match 'OneDriveStandaloneUpdater'}
 It 'logs JSONL records and failures'{$source|Should -Match 'ConvertTo-Json -Compress';$source|Should -Match "'failure' 'fail'"}
 It 'refuses rollback overwrite'{$source|Should -Match 'Rollback refused because the registration already exists'}
 It 'contains no destructive package, file, service, task, credential, or driver operations'{foreach($t in @('Remove-AppxPackage','Uninstall-Package','Remove-Item -Recurse','Set-Service','Disable-ScheduledTask','Unregister-ScheduledTask','cmdkey','pnputil','devcon')){$source|Should -Not -Match ([regex]::Escape($t))}}
}
