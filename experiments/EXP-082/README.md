# EXP-082: Disable Windows Search web results

Status: Experimental  
Stage: validation  
Evidence: needs-evidence

## Focused candidate

Apply one atomic policy pair under `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search`:

- `DisableWebSearch` as `REG_DWORD 1`
- `ConnectedSearchUseWeb` as `REG_DWORD 0`

The provider changes these two values only. It changes no Search service, index, indexed scope, package, executable, task, firewall rule, DNS setting, browser configuration, security control, update component, recovery setting, enterprise-management state, device, or driver.

## Lifecycle

```powershell
$provider = '.\controller\providers\WindowsSearchWebResultsPolicy.ps1'
$state = '.\artifacts\EXP-082\state.json'
$log = '.\artifacts\EXP-082\events.jsonl'

& $provider -Action Check -StatePath $state -LogPath $log
& $provider -Action Capture -StatePath $state -LogPath $log
& $provider -Action DryRun -StatePath $state -LogPath $log
& $provider -Action Apply -StatePath $state -LogPath $log -WhatIf
& $provider -Action Apply -StatePath $state -LogPath $log -Confirm:$false
& $provider -Action Verify -StatePath $state -LogPath $log
# Restart Search through sign-out or reboot before treatment measurement.
& $provider -Action VerifyReboot -StatePath $state -LogPath $log
& $provider -Action Rollback -StatePath $state -LogPath $log -Confirm:$false
```

## Zero-mutation integration checks

Run `Check`, `Capture`, `DryRun`, and `Apply -WhatIf` on an eligible HP Windows 11 test machine. Capture before-and-after snapshots of:

- both target registry values and the policy-key existence state
- Windows Search service configuration and running state
- Search index location, indexed scope, and index database metadata
- SearchHost package and executable identity
- Defender, Firewall, BitLocker, Credential Guard, and VBS state
- Windows Update and recovery state
- domain, MDM, PolicyManager, and Configuration Manager indicators
- device and driver inventory hashes
- Omnissa, Windows App, Remote Desktop, and Tailscale startup registrations and readiness

The snapshots must show zero mutation. Managed systems, existing target values, unsupported editions, missing elevation, and non-HP systems must terminate with a refusal and structured failure log.

Run Pester:

```powershell
Invoke-Pester .\controller\tests\EXP-082.WindowsSearchWebResultsPolicy.Tests.ps1
```

## Physical validation

Use the same HP Windows 11 system, build, BIOS, storage and graphics drivers, Search index state, network state, AC power, power mode, thermal state, query set, and instrumentation for all runs.

1. Capture five baseline restart trials with the original policy state.
2. Apply the atomic pair and verify both values immediately.
3. Restart Windows and run `VerifyReboot`.
4. Capture five treatment trials.
5. For every trial record sign-in to usable desktop, Search invocation to first rendered local result, keyboard-selectable local result, launched local application, SearchHost CPU time, disk I/O, working set, network activity, Outlook readiness, and protected remote-access readiness.
6. Verify local application, setting, file, and indexed-content search with a fixed query set.
7. Report raw trials, medians, dispersion, failures, and instrumentation overhead.
8. Execute exact rollback, restart, verify both values are absent and the experiment-created key is removed only when empty, then repeat local-search and protected-application checks.

Retain favorable, adverse, failed, rejected, and inconclusive evidence. Physical measurements, reboot execution, functional verification, and rollback execution remain `needs-evidence`. Stable requires explicit human approval.
