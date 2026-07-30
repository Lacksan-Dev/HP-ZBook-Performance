# EXP-071: Edge background mode recommended policy

## Candidate
Set only `HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended\BackgroundModeEnabled` to `0` after support and safety checks. The provider captures the exact absence of the policy, supports dry run and `-WhatIf`, verifies application and reboot persistence, logs JSONL records, applies idempotently, refuses drift, and removes only the experiment-created value during rollback.

## Safety boundary
Preserve Edge installation, profiles, passwords, cookies, favorites, extensions, cache, update behavior, services, tasks, browser security controls, Windows security, Windows Update, recovery, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale. Refuse managed devices and any pre-existing mandatory or recommended value for the same policy.

## Integration sequence
Run from elevated Windows PowerShell on an eligible HP Windows 11 test device:

```powershell
$provider = '.\controller\providers\EdgeBackgroundModePolicy.ps1'
$state = '.\evidence\EXP-071-state.json'
$log = '.\evidence\EXP-071.jsonl'
& $provider -Action Check -StatePath $state -LogPath $log
& $provider -Action DryRun -StatePath $state -LogPath $log
& $provider -Action Apply -StatePath $state -LogPath $log -WhatIf
& $provider -Action Capture -StatePath $state -LogPath $log
& $provider -Action Apply -StatePath $state -LogPath $log -Confirm:$false
& $provider -Action Verify -StatePath $state -LogPath $log
& $provider -Action Apply -StatePath $state -LogPath $log -Confirm:$false
# Reboot, then:
& $provider -Action VerifyReboot -StatePath $state -LogPath $log
& $provider -Action Rollback -StatePath $state -LogPath $log -Confirm:$false
```

The second Apply must report zero mutations. Before physical application, close Edge and preserve all baseline evidence. After application, validate Edge launch, sign-in, navigation, extensions, updates, and protected remote-access readiness.

## Measurements
Collect five matched baseline and five treatment trials. Record Edge version, Windows build, device, BIOS, drivers, power source, thermal state, process count and working set after closing the final Edge window, first-120-second CPU and disk activity, cold launch, first interactive window, first navigation, new-tab readiness, and protected remote-access readiness. Report medians and preserve failed or inconclusive runs.

Physical measurements remain `needs-evidence`. Release state remains Experimental.
