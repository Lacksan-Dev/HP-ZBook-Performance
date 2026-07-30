# EXP-049: Classic Teams demand launch

## Candidate

Remove exactly one current-user `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` value named `com.squirrel.Teams.Teams` when its unexpanded command resolves to the classic Teams Squirrel `Update.exe` launcher and contains both `--processStart Teams.exe` and `--process-start-args --system-initiated`.

The provider refuses new Teams MSIX identities, `ms-teams.exe`, WindowsApps paths, updater-only commands, protected identities, invalid Microsoft publisher signatures, absent executables, ambiguous candidates, enterprise-management ownership, unsupported devices, and state drift.

## Reversible lifecycle

The `ClassicTeamsDemandLaunch` controller profile provides `Check`, `Capture`, `DryRun`, `Apply`, `Verify`, `VerifyReboot`, and `Rollback`.

Capture records the exact Run path, value name, registry kind, unexpanded command, resolved executable, executable SHA-256 and version, Microsoft publisher identity, machine identity, current-user SID, and UTC timestamp. Apply removes one registry value through `ShouldProcess`, verifies removal, and treats a repeated application as idempotent. Reboot verification records the boot time and confirms persistence.

Rollback refuses overwrite, command drift, publisher drift, and executable hash drift. It restores the exact registry kind and unexpanded command and verifies equality.

## Safety boundary

The candidate changes one current-user Run value only. It changes no Teams package, executable, profile, credential, cache, meeting data, service, scheduled task, StartupTask registration, Windows security control, Windows Update component, recovery setting, enterprise-management state, device-critical driver, Omnissa component, Windows App component, Remote Desktop component, or Tailscale component.

## Static and integration validation

Run:

```powershell
Invoke-Pester .\controller\tests\EXP-049.ClassicTeamsRun.Tests.ps1
```

On an eligible unmanaged HP Windows 11 test machine, run `Check` and `DryRun` with temporary state and JSONL paths. Snapshot the Run value before and after. The exact value name, kind, and unexpanded data must remain unchanged. `Apply -WhatIf` must also produce zero mutation.

For the controlled mutation phase, run `Capture`, `Apply`, `Verify`, reboot, `VerifyReboot`, validate Teams manual launch, sign-in, meeting readiness, update behavior, and protected remote-access readiness, then execute `Rollback` and verify exact restoration.

## Physical evidence

Physical measurements remain `needs-evidence`. Complete at least five matched baseline and five treatment sign-in trials under controlled power and thermal conditions. Record Windows build, HP model, BIOS, storage, display and network drivers, classic Teams version, executable hash, power source, thermal state, instrumentation overhead, sign-in to usable desktop, first-120-second CPU and disk activity, Teams process activity, Teams manual-launch and meeting readiness, update behavior, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale.

Report medians and preserve favorable, adverse, failed, and inconclusive evidence. The experiment remains Experimental. Stable requires explicit human approval.
