# EXP-049: Classic Teams demand launch

Status: Experimental  
Stage: validation  
Evidence: needs-evidence

## Hypothesis

Removing the exact current-user classic Microsoft Teams Squirrel Run registration may reduce sign-in contention while preserving manual classic Teams launch, sign-in, meeting readiness, update behavior, and the new Teams MSIX startup mechanism.

## Candidate boundary

The `ClassicTeamsDemandLaunch` provider may remove exactly one value:

- Path: `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- Name: `com.squirrel.Teams.Teams`
- Command: the classic Teams Squirrel `Update.exe` launcher with `--processStart Teams.exe` and `--process-start-args --system-initiated`

The provider refuses broad matches, updater-only commands, new Teams `ms-teams.exe` identities, multiple eligible entries, invalid signatures, non-Microsoft publishers, management ownership, existing state artifacts, and identity or protected-scope drift.

## Reversible lifecycle

1. `Check` detects HP Windows 11 support, management ownership, the exact Run registration, signed Microsoft launcher and application binaries, and protected scope.
2. `Capture` records the exact unexpanded value data, registry kind, key owner and SDDL, executable paths, SHA-256 hashes, versions, publisher thumbprints, machine, user SID, boot time, and protected-scope hash.
3. `DryRun` reports the one planned mutation and exact rollback with zero configuration change.
4. `Apply` removes the captured value through `ShouldProcess`, verifies removal and binary preservation, and supports an idempotent repeat.
5. `Verify` confirms immediate removal and preserved executable identities.
6. `VerifyReboot` requires an observed later boot and confirms persistence.
7. `Rollback` refuses destination overwrite and drift, then restores the exact captured value name, registry kind, and unexpanded command before verifying equality.

Every lifecycle action writes append-only JSONL records. Terminating failures preserve the stage, error type, message, and state path. Failed, adverse, rejected, and inconclusive evidence remains retained.

## Safety boundary

The experiment changes no package, executable, credential, profile, cache, service, scheduled task, firewall rule, update component, recovery setting, enterprise-management state, device, driver, firmware, or new Teams StartupTask. Windows security, Windows Update, recovery, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale remain protected.

## Test coverage

```powershell
Invoke-Pester .\controller\tests\ClassicTeamsDemandLaunch.Tests.ps1
```

Opt-in integration coverage snapshots the entire current-user Run key before and after `Check`, `Capture`, `DryRun`, and `Apply -WhatIf`:

```powershell
$env:LACKSAN_RUN_WINDOWS_INTEGRATION = '1'
Invoke-Pester .\controller\tests\ClassicTeamsDemandLaunch.Integration.Tests.ps1
```

## Physical validation plan

Use the same HP Windows 11 device, account, power source, network, servicing state, driver versions, startup workload, and instrumentation for every matched trial.

1. Qualify instrumentation overhead.
2. Capture at least five baseline sign-in trials.
3. Apply the candidate and verify immediate state.
4. Reboot and execute at least five matched treatment trials.
5. Measure sign-in readiness and first-120-second CPU, disk active time, disk bytes, memory, and classic Teams process activity.
6. Verify classic Teams manual launch, sign-in, chat, meeting join, audio and video device readiness, and update discovery.
7. Verify new Teams launch and its existing StartupTask state.
8. Verify Outlook and Edge readiness plus Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
9. Execute exact rollback, reboot, and confirm restored startup behavior and protected scope.
10. Report every trial, medians, dispersion, adverse observations, failures, and inconclusive evidence.

Physical HP execution, five matched baseline and treatment trials, first-120-second CPU and disk measurements, protected remote-access readiness, Teams launch and meeting checks, update validation, reboot persistence, exact rollback execution, instrumentation qualification, medians, and dispersion remain `needs-evidence`.

Stable remains unassigned.
