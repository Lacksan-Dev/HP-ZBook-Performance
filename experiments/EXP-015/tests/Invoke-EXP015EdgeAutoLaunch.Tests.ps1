$scriptPath=Join-Path $PSScriptRoot '..\Invoke-EXP015EdgeAutoLaunch.ps1'
$source=Get-Content -LiteralPath $scriptPath -Raw
Describe 'EXP-015 contract' {
 It 'supports all lifecycle actions' { $source|Should -Match "ValidateSet\('Check','DryRun','Apply','Verify','VerifyReboot','Rollback'\)" }
 It 'limits scope to HKCU Run and RunOnce' { $source|Should -Match 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run';$source|Should -Not -Match 'HKLM:' }
 It 'requires Edge executable and auto-launch identity' { $source|Should -Match 'msedge\\\.exe';$source|Should -Match 'no-startup-window';$source|Should -Match 'auto-launch-at-startup' }
 It 'protects updater WebView2 and remote access' { foreach($m in @('edgeupdate','webview2','omnissa','tailscale','defender')){$source|Should -Match $m} }
 It 'captures and verifies exact state' { $source|Should -Match 'GetValueKind';$source|Should -Match 'Application verification failed';$source|Should -Match 'Rollback verification failed' }
 It 'uses ShouldProcess and JSONL logs' { $source|Should -Match 'SupportsShouldProcess=\$true';$source|Should -Match '\$PSCmdlet.ShouldProcess';$source|Should -Match 'events.jsonl' }
 It 'contains no destructive package service task or driver commands' { foreach($u in @('Uninstall-Package','Remove-AppxPackage','Remove-Service','Unregister-ScheduledTask','delete-driver')){$source|Should -Not -Match $u} }
}
