# EXP-016 Engineering Report

## Candidate

Remove one or more current-user Microsoft Teams `Run` values only when both the value name and command identify Teams and the command contains `Teams.exe` or `ms-teams.exe`.

## Implemented controls

- HP Windows 11 support detection
- protected identity refusal for Omnissa, Windows App, Remote Desktop, Tailscale, Windows Security, and Defender
- exact registry path, name, unexpanded data, and value-kind capture
- dry-run inventory without state change
- `ShouldProcess` enforcement for apply and rollback
- verified removal
- JSONL structured logs
- idempotent repeated application
- exception logging and terminating failure behavior
- reboot-persistence verification mode
- exact rollback and rollback verification
- Pester contract tests

## Scope exclusions

The component does not uninstall Teams, modify packaged-app StartupTask internals, remove files, alter services or scheduled tasks, change policy, modify credentials, touch drivers, or change protected remote-access applications.

## Execution

```powershell
# Inventory
.\Invoke-TeamsRunCalibration.ps1 -Action Check

# Preview
.\Invoke-TeamsRunCalibration.ps1 -Action DryRun

# Capture and apply
.\Invoke-TeamsRunCalibration.ps1 -Action Capture
.\Invoke-TeamsRunCalibration.ps1 -Action Apply -Confirm:$false

# Verify before and after reboot
.\Invoke-TeamsRunCalibration.ps1 -Action Verify
.\Invoke-TeamsRunCalibration.ps1 -Action VerifyReboot

# Exact restoration
.\Invoke-TeamsRunCalibration.ps1 -Action Rollback -Confirm:$false
```

## Validation handoff

Physical HP ZBook evidence remains required. Run repeated control and treatment trials under fixed power, thermal, network, update, and background-workload conditions. Record Windows build, HP model, BIOS, Teams version, driver versions, power source and mode, thermal state, and benchmark conditions. Compare medians for sign-in readiness, first-120-second CPU and disk activity, protected remote-access readiness, Teams on-demand launch, and notification readiness. Execute rollback and repeat verification after reboot.

No baseline or result values are claimed.
