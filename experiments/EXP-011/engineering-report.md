# EXP-011 Engineering Report

## Candidate
Disable Microsoft Edge background mode through the recommended `BackgroundModeEnabled` policy while leaving the separate Startup Boost experiment unchanged.

## Implementation
`EdgeBackgroundModeExperiment.ps1` provides:

- Windows 11 and Edge support detection
- refusal when mandatory enterprise policy controls the same setting
- exact recommended-policy state capture
- check and dry-run modes
- verified application of DWORD value `0`
- JSONL event logging
- idempotent repeated application
- terminating failure handling
- reboot-persistence verification through the Verify mode after restart
- exact rollback to the captured value or absence state
- rollback verification

## Protected boundaries
The implementation changes one recommended Edge policy value only. It does not alter Edge profiles, passwords, cookies, favorites, extensions, SmartScreen, update behavior, Startup folders, services, packages, drivers, Windows security, recovery, enterprise management, Omnissa, Windows App, Remote Desktop, or Tailscale.

## Automated review
Pester contract tests cover required modes, recommended-policy scope, mandatory-policy refusal, state capture, structured logging, exact candidate identity, rollback, and prohibited command absence.

## Evidence status
Physical HP ZBook application, effective-policy confirmation, reboot verification, rollback execution, repeated launch measurements, idle process and memory measurements, instrumentation overhead, and median calculations remain `needs-evidence`. No performance improvement is claimed.
