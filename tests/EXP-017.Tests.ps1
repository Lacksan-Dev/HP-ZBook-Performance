BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\experiments\EXP-017\Set-LogiOptionsUpdaterDemandStart.ps1'
    $source = Get-Content -LiteralPath $scriptPath -Raw
}
Describe 'EXP-017 engineering contract' {
    It 'uses SupportsShouldProcess' { $source | Should -Match 'SupportsShouldProcess=\$true' }
    It 'supports all required modes' { foreach($mode in 'Check','DryRun','Apply','Verify','Rollback','VerifyRollback'){ $source | Should -Match "'$mode'" } }
    It 'captures exact service identity and original state' { foreach($term in 'serviceName','pathName','startMode','state','capturedUtc'){ $source | Should -Match $term } }
    It 'restricts candidate service names' { $source | Should -Match 'logioptionsplus_updater'; $source | Should -Match 'LogiOptionsPlusUpdaterService' }
    It 'requires Logi Options updater image identity' { $source | Should -Match 'logi\.\*options\.\*updat' }
    It 'protects remote access and Windows identities' { foreach($term in 'tailscale','omnissa','remote desktop','windowsapp','defender'){ $source | Should -Match $term } }
    It 'writes structured JSONL records' { $source | Should -Match 'ConvertTo-Json -Compress'; $source | Should -Match 'Add-Content' }
    It 'implements idempotent application' { $source | Should -Match 'AlreadyCompliant' }
    It 'verifies application and rollback' { $source | Should -Match 'Verification failed after application'; $source | Should -Match 'Rollback verification failed' }
    It 'does not stop or remove the service' { $source | Should -Not -Match 'Remove-Service|sc\.exe\s+delete|Stop-Service' }
}
