# EXP-027 Engineering Report

## Candidate
The exact `HPSysInfoCap` service only. The executable command must identify an HP System Info capability component. Platform, service-name, executable, protected-identity, captured-state, or rollback identity mismatches cause refusal.

## Implemented lifecycle
- HP Windows 11 support detection
- Exact service name, display name, executable command, startup mode, running state, computer identity, and UTC capture
- Read-only check and dry-run plan
- `ShouldProcess`-gated application to Manual startup
- Immediate verification while preserving running state
- JSONL structured events
- Idempotent repeated application
- Terminating failure logging
- Reboot-persistence verification
- Exact startup-mode and running-state rollback
- Rollback identity and result verification

## Safety boundary
The experiment changes only the startup mode of the recognized service. It performs no package, executable, scheduled-task, startup-registration, device, driver, Windows platform service, security, update, recovery, enterprise-management, Omnissa, Windows App, Remote Desktop, or Tailscale modification.

## Repository checks
Pester contract tests cover exact identity, lifecycle completeness, state capture, structured logging, idempotence, protected identities, rollback, and absence of destructive actions. The integration script parses the implementation and performs non-destructive contract checks.

## Physical validation handoff
Run Check, Capture, DryRun, Apply, Verify, reboot, VerifyReboot, and Rollback on the HP ZBook. Confirm HP system-information and support workflows, demand-start behavior, Windows security and update health, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale readiness. Collect repeated sign-in-to-usable-desktop and first-120-second CPU and disk trials, qualify instrumentation overhead, and report medians.

Physical measurements remain `needs-evidence`. No performance result is claimed and the experiment remains Experimental.
