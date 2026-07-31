$providerPath=Join-Path $PSScriptRoot '..\providers\LogitechGHubRun.ps1'
$manifestPath=Join-Path $PSScriptRoot '..\lacksan.manifest.json'
Describe 'EXP-053 Logitech G Hub Run provider contract' {
    BeforeAll {$text=Get-Content -LiteralPath $providerPath -Raw;$tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$errors);$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json}
    It 'parses without syntax errors' {$errors.Count|Should -Be 0}
    It 'implements the complete reversible lifecycle' {foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match ([regex]::Escape("'$a'"))}}
    It 'requires exact G Hub executable and background identity' {foreach($t in 'LGHUB','Logitech G HUB','lghub_agent','--background','--startup','--tray','--silent'){$text|Should -Match ([regex]::Escape($t))}}
    It 'refuses updater pairing firmware driver and protected identities' {foreach($t in 'lghub_updater','updater','pairing','firmware','driver','omnissa','tailscale','receiver','bluetooth'){$text|Should -Match $t}}
    It 'requires HP Windows 11 and refuses enterprise management' {foreach($t in 'Windows 11','Hewlett-Packard','Microsoft\Enrollments','PolicyManager','CcmExec','mutation is refused'){$text|Should -Match ([regex]::Escape($t))}}
    It 'captures exact registry executable publisher and user identity' {foreach($t in 'DoNotExpandEnvironmentNames','GetValueKind','ExecutableHash','ExecutableVersion','PublisherSubject','userSid','machine'){$text|Should -Match $t}}
    It 'supports dry run ShouldProcess idempotence logging and terminating failures' {foreach($t in 'SupportsShouldProcess','ShouldProcess','WouldChange','idempotent','ConvertTo-Json -Compress','ErrorActionPreference=''Stop''','catch{Write-ProviderLog'){$text|Should -Match ([regex]::Escape($t))}}
    It 'verifies immediate and reboot persistence' {foreach($t in 'Test-Removed','VerifyReboot','LastBootUpTime','Reboot persistence verification failed'){$text|Should -Match $t}}
    It 'provides drift-safe exact rollback' {foreach($t in 'Assert-EntryIdentity','Rollback refused because the registration already exists','Rollback publisher identity validation failed','Rollback executable hash validation failed','Test-Restored'){$text|Should -Match ([regex]::Escape($t))}}
    It 'limits mutation to one Run value' {$text|Should -Match 'Remove-ItemProperty';$text|Should -Match '\.SetValue\(';$text|Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Set-Service|Stop-Service|Disable-ScheduledTask|pnputil|Set-MpPreference|Disable-NetAdapter'}
    It 'is registered with every protected scope' {$manifest.profiles.id|Should -Contain 'LogitechGHubDemandLaunch';$entry=$manifest.providers|Where-Object id -eq 'logitech-ghub-run';$entry.mode|Should -Be 'Reversible';foreach($s in 'WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale'){$entry.protectedScopes|Should -Contain $s}}
}
