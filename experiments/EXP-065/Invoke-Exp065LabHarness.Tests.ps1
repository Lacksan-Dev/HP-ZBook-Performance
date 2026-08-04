Describe 'EXP-065 lab harness contract' {
  BeforeAll {$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp065LabHarness.ps1';$text=Get-Content -LiteralPath $scriptPath -Raw}
  It 'supports dry run and explicit automatic reboot gating' {$text | Should -Match 'SupportsShouldProcess=\$true';$text | Should -Match 'AllowAutomaticReboot';$text | Should -Match '\$WhatIfPreference'}
  It 'propagates automatic reboot authorization to every logon continuation' {$text | Should -Match '\$automaticRebootArgument=if\(\$AllowAutomaticReboot\)';$text | Should -Match "' -AllowAutomaticReboot'";$text | Should -Match '\$automaticRebootArgument"'}
  It 'suppresses confirmation prompts in scheduled continuations and nested provider actions' {$text | Should -Match '\$ControllerPath`" -Confirm:`\$false\$automaticRebootArgument';$text | Should -Match 'LogPath=\$p\.ControllerLog;Confirm=\$false';$text | Should -Not -Match '& \$ControllerPath @args -Confirm:\$true'}
  It 'persists reboot-aware state and rejects duplicate boot collection' {$text | Should -Match 'lastBootUtc';$text | Should -Match 'Duplicate collection from same boot refused';$text | Should -Match 'Get-BootUtc'}
  It 'compares each baseline boot with the captured provider state shape' {$text | Should -Match 'Assert-BaselineConfiguration';$text | Should -Match '\$OriginalState\.support\.Service';$text | Should -Match '\$CurrentSupport\.Service';$text | Should -Match '\$CurrentSupport\.Protected';$text | Should -Not -Match '\$cur\.StartMode';$text | Should -Not -Match '\$orig\.startMode'}
  It 'compares protected configuration but permits transient protected service state' {$text | Should -Match 'Get-ProtectedConfiguration';$projection=[regex]::Match($text,'function Get-ProtectedConfiguration\(\$Rows\)\{(?<body>.+?)\}\r?\n').Groups['body'].Value;$projection | Should -Match 'Name=';$projection | Should -Match 'StartMode=';$projection | Should -Match 'PathName=';$projection | Should -Not -Match 'State='}
  It 'alternates baseline then treatment and restores exact state on completion' {$text | Should -Match "phase='Baseline'";$text | Should -Match "phase='Treatment'";$text | Should -Match "Controller 'Apply'";$text | Should -Match "Controller 'Rollback'"}
  It 'uses five runs per arm by default' {$text | Should -Match '\[int\]\$RunsPerArm=5'}
  It 'samples first 120 seconds by default' {$text | Should -Match '\[int\]\$SampleSeconds=120'}
  It 'captures protected remote-access state' {$text | Should -Match 'Tailscale';$text | Should -Match 'TermService';$text | Should -Match 'msrdc\|windowsapp\|omnissa'}
  It 'captures service CPU and IO attribution' {$text | Should -Match 'cpuDeltaMs';$text | Should -Match 'readDeltaBytes';$text | Should -Match 'writeDeltaBytes'}
  It 'computes median and median absolute deviation' {$text | Should -Match 'Get-Median';$text | Should -Match 'Get-Mad';$text | Should -Match "mad="}
  It 'preserves raw per-run JSON evidence' {$text | Should -Match 'run-\{0\}-\{1:D2\}\.json';$text | Should -Match 'summary.json'}
  It 'uses one reversible current-user logon continuation task' {$text | Should -Match 'New-ScheduledTaskTrigger -AtLogOn';$text | Should -Match 'Unregister-ScheduledTask';$text | Should -Match 'LogonType Interactive'}
  It 'stores no autologon credentials' {$text | Should -Not -Match 'DefaultPassword|AutoAdminLogon|LogonType Password|ConvertTo-SecureString'}
}
