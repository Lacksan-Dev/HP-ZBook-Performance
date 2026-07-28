# EXP-030 Engineering Report

## Candidate
Change only `HPPrintScanDoctorService` to Manual startup when the exact service and HP Print and Scan Doctor executable identity are present.

## Implemented controls
- HP Windows 11 support detection
- exact service-name and executable-command identity checks
- original startup mode, running state, display name, executable command, process ID, machine, and timestamp capture
- dry run and `ShouldProcess`
- verified application to Manual startup
- JSONL structured logging
- idempotent repeated application
- terminating failure logging
- reboot-persistence verification
- exact startup-mode and running-state rollback
- rollback identity and result verification
- Pester contract tests
- non-destructive syntax and safety checks

## Preserved boundary
No printer driver, print spooler, device, package, executable, scheduled task, registry startup entry, Windows platform service, Windows security control, Windows Update component, recovery component, enterprise-management component, Omnissa component, Windows App component, Remote Desktop component, or Tailscale component is changed.

## Physical validation handoff
1. Capture device, Windows build, BIOS, driver versions, power source, thermal state, and HP Print and Scan Doctor version.
2. Run `Check`, `Capture`, and `DryRun`.
3. Record at least five baseline sign-in trials, sign-in-to-usable-desktop time, and CPU/disk activity for the first 120 seconds.
4. Apply the candidate and verify immediately.
5. Reboot, run `VerifyReboot`, then repeat at least five trials under equivalent conditions.
6. Launch HP Print and Scan Doctor and verify the diagnostic workflow plus any service demand-start behavior.
7. Confirm Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
8. Roll back, verify exact restoration, reboot, and confirm restored state.
9. Report medians and preserve failed or inconclusive runs.

## Evidence status
Physical HP ZBook application, repeated measurements, reboot validation, rollback execution, workflow validation, and instrumentation-overhead qualification remain `needs-evidence`. No performance improvement is claimed.
