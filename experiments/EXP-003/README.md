# EXP-003: Edge demand-launch Startup Boost calibration

## Candidate

Test Microsoft Edge Startup Boost as one reversible variable while explicitly disabling visible Edge launch at Windows startup.

Microsoft documents `StartupBoostEnabled` under `SOFTWARE\Policies\Microsoft\Edge` for Edge 88 and later on Windows. Startup Boost permits Edge processes to start at sign-in and restart in the background after the final window closes. This experiment records that prelaunch resource cost and compares it with true cold launch.

The component also sets `LaunchEdgeOnWindowsStartupEnabled=0` so Edge does not open visibly when Windows starts. It does not create or modify a Startup-folder entry.

## Safety boundary

- HP systems running Windows 11
- Microsoft Edge 88 or later
- preserves Edge profiles, passwords, cookies, favorites, extensions, updates, security settings, and management policy
- preserves Omnissa, Windows App, Remote Desktop, Tailscale, Windows security, recovery, updates, enterprise management, and device-critical drivers
- changes only two documented Edge policy values
- captures and restores the exact prior existence, type, and value of each policy

## Operations

```powershell
Import-Module .\EdgeStartupBoost.psm1 -Force

$state = 'C:\ProgramData\Lacksan\EXP-003\state.json'
$log = 'C:\ProgramData\Lacksan\EXP-003\activity.jsonl'

Invoke-Exp003DryRun -StartupBoost Enable
Save-Exp003State -StatePath $state
Set-Exp003StartupBoost -StartupBoost Enable -StatePath $state -LogPath $log -Confirm:$false
Test-Exp003Configuration -ExpectedStartupBoost 1
```

After reboot:

```powershell
Test-Exp003RebootPersistence -ExpectedStartupBoost 1
```

Rollback:

```powershell
Restore-Exp003State -StatePath $state -LogPath $log -Confirm:$false
```

## Measurement protocol

Compare at least these conditions independently:

1. Startup Boost disabled and visible startup disabled.
2. Startup Boost enabled and visible startup disabled.

For each condition, preserve repeated raw runs and report medians for:

- Edge process launch to first visible window
- first interactive window
- first new-tab readiness
- first controlled navigation
- Edge process count and working-set memory before user launch
- sign-in to usable desktop and first-120-second CPU and disk activity
- Omnissa, Windows App, Remote Desktop, and Tailscale readiness

Record Windows build, HP model, BIOS, Edge version, drivers, power source, thermal state, network state, profile state, extensions, cache reset procedure, and benchmark instrumentation overhead.

## Evidence status

Repository engineering and Pester coverage are included. Physical HP ZBook application, policy precedence, reboot persistence, exact rollback execution, repeated Edge launch measurements, startup-resource cost, protected remote-access readiness, and median comparisons remain `needs-evidence`. No performance improvement is claimed.

## Primary source

- Microsoft Edge policy documentation, `StartupBoostEnabled`, retrieved 2026-07-27: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled
- Microsoft Edge policy documentation, `LaunchEdgeOnWindowsStartupEnabled`, retrieved 2026-07-27: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/launchedgeonwindowsstartupenabled
