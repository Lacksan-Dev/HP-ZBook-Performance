# EXP-043 Engineering Report

## Candidate
Remove one exact classic Microsoft Teams Squirrel Run registration for the current user. The implementation accepts only `com.squirrel.Teams.Teams` with an `Update.exe --processStart Teams.exe --process-start-args --system-initiated` command chain.

## Reversibility and safety
The script captures the unexpanded command, registry value kind, machine identity, user SID, and capture time before application. Application removes only the captured Run value. Rollback refuses overwrite, validates the saved identity, restores the original value and kind, and verifies exact restoration. New Teams MSIX StartupTask registrations, packages, files, services, scheduled tasks, security controls, enterprise management, device drivers, and protected remote-access applications remain outside scope.

## Operations
Run `Check`, `Capture`, and `DryRun` before `Apply`. Run `Verify` immediately, then `VerifyReboot` after a reboot. Use `Rollback` to restore the exact captured registration. Each operation writes JSONL events and terminates on detection, identity, verification, or restoration failures. Repeated application is idempotent because an already removed captured entry produces zero additional changes while verification continues against the saved state.

## Tests
The Pester suite checks the support, identity, capture, dry-run, verification, logging, idempotence, reboot, rollback, protected-identity, and failure-handling contracts. `Test-Integration.ps1` parses the script and performs read-only destructive-operation screening.

## Physical validation handoff
Physical evidence remains `needs-evidence`. On an eligible HP ZBook running Windows 11, collect at least five matched baseline and five treatment sign-in trials. Report medians for sign-in to usable desktop, first-120-second CPU and disk activity, Teams on-demand launch, Teams sign-in and meeting readiness, update checks, and Omnissa, Windows App, Remote Desktop, and Tailscale readiness. Record Windows build, BIOS, drivers, Teams version, power source, thermal state, and instrumentation overhead. Execute reboot verification and exact rollback. Preserve failed and inconclusive runs.

No performance result is claimed and the experiment remains Experimental.
