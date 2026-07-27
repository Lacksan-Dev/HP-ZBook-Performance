# EXP-003: Edge demand-launch Startup Boost calibration

## Candidate

Test Microsoft Edge Startup Boost as one reversible variable without creating or modifying an Edge Startup-folder entry.

Microsoft documents `StartupBoostEnabled` for Edge 88 and later on Windows. Startup Boost permits Edge processes to start at sign-in and restart in the background after the final window closes. The experiment compares faster demand launch against prelaunch memory and sign-in resource cost.

## Management-safe scope

The module writes only the recommended policy value:

`HKLM\SOFTWARE\Policies\Microsoft\Edge\Recommended\StartupBoostEnabled`

A mandatory `StartupBoostEnabled` policy causes support detection to refuse application. Existing enterprise policy therefore retains precedence.

## Safety boundary

- HP systems running Windows 11
- Microsoft Edge 88 or later
- preserves profiles, passwords, cookies, favorites, extensions, updates, security settings, and management policy
- preserves Omnissa, Windows App, Remote Desktop, Tailscale, Windows security, recovery, updates, enterprise management, and device-critical drivers
- changes one documented recommended Edge policy value
- captures and restores the exact prior existence, type, and value
- leaves Startup folders unchanged

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

Compare Startup Boost disabled and enabled as separate conditions while holding profile, extensions, cache procedure, network, power, and thermal state constant. Preserve repeated raw runs and report medians for:

- process launch to first visible window
- first interactive window
- first new-tab readiness
- first controlled navigation
- Edge process count and working-set memory before user launch
- sign-in to usable desktop and first-120-second CPU and disk activity
- Omnissa, Windows App, Remote Desktop, and Tailscale readiness

Record Windows build, HP model, BIOS, Edge version, drivers, power source, thermal state, network state, profile state, extensions, cache reset procedure, and instrumentation overhead.

## Evidence status

Repository engineering and Pester coverage are included. Physical HP ZBook application, effective policy behavior, reboot persistence, exact rollback execution, repeated Edge launch measurements, prelaunch resource cost, protected remote-access readiness, and median comparisons remain `needs-evidence`. No performance improvement is claimed.

## Primary source

- Microsoft Edge policy documentation, `StartupBoostEnabled`, retrieved 2026-07-27: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled
