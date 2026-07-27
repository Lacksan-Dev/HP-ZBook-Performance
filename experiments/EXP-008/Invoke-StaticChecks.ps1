$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $PSScriptRoot 'LogitechAutoLaunch.psm1'
$testPath = Join-Path $root '..\tests\EXP-008.LogitechAutoLaunch.Tests.ps1'

$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($modulePath,[ref]$null,[ref]$errors) | Out-Null
if ($errors.Count -gt 0) { throw ($errors | Out-String) }

Import-Module $modulePath -Force
$required = @('Test-Exp008Support','Test-Exp008Candidate','Get-Exp008Inventory','Save-Exp008State','Invoke-Exp008Apply','Test-Exp008Applied','Invoke-Exp008Rollback','Test-Exp008Rollback')
foreach ($command in $required) { Get-Command $command -ErrorAction Stop | Out-Null }

if (-not (Test-Exp008Candidate -Name 'Logi Options+' -Command 'C:\Program Files\LogiOptionsPlus\logioptionsplus_agent.exe --background')) { throw 'Expected Options+ candidate rejected.' }
if (Test-Exp008Candidate -Name 'Tailscale' -Command 'C:\Program Files\Tailscale\tailscale-ipn.exe') { throw 'Protected Tailscale candidate accepted.' }
if (Test-Exp008Candidate -Name 'Logitech HID Driver' -Command 'C:\Windows\System32\drivers\logi_hid.sys') { throw 'Driver-only identity accepted.' }

if (-not (Test-Path -LiteralPath $testPath)) { throw 'Pester test file missing.' }
Write-Output 'EXP-008 static checks passed.'
