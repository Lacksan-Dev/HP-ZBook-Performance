Describe 'EXP-014 Edge demand-launch broker' {
  $script=Join-Path $PSScriptRoot 'Invoke-EdgeDemandLaunch.ps1'
  It 'contains all required modes' { $text=Get-Content $script -Raw; foreach($m in 'Check','DryRun','Apply','Verify','Rollback'){$text|Should -Match "'$m'"} }
  It 'uses ShouldProcess for launch and rollback' { (Get-Content $script -Raw)|Should -Match 'SupportsShouldProcess'; (Get-Content $script -Raw)|Should -Match 'ShouldProcess' }
  It 'writes structured JSONL evidence' { (Get-Content $script -Raw)|Should -Match 'ConvertTo-Json -Compress' }
  It 'limits rollback to the captured process id' { $text=Get-Content $script -Raw; $text|Should -Match 'processId'; $text|Should -Match 'Stop-Process -Id' }
  It 'does not modify persistent Windows configuration' { $text=Get-Content $script -Raw; $text|Should -Not -Match 'Set-ItemProperty|Set-Service|schtasks|Startup\\|CurrentVersion\\Run' }
}
