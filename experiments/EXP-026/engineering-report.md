# EXP-026 Engineering Report

## Candidate

The implementation is bounded to the exact Windows service name `HPDiagsCap`. The executable command must identify an HP diagnostics capability component. Any platform, service-name, executable, protected-identity, state-file, or rollback identity mismatch causes a terminating refusal.

## Change

Application changes only the recognized service startup mode to `Manual` and preserves its running state. It leaves packages, executables, scheduled tasks, startup registrations, devices, drivers, Windows platform services, security controls, Windows Update, recovery, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale unchanged.

## Reversible lifecycle

1. `Check` validates HP Windows 11 support and exact service identity.
2. `Capture` records machine identity, service name, display name, executable command, startup mode, running state, and UTC time.
3. `DryRun` emits a structured plan without changing service configuration.
4. `Apply` captures state when required, uses `ShouldProcess`, changes startup mode to Manual, verifies the result, and refuses an unexpected running-state change.
5. `Verify` confirms immediate state.
6. `VerifyReboot` confirms persistence after reboot.
7. `Rollback` revalidates service and state identities, restores the exact startup mode and running state, and verifies both.

Every lifecycle action writes JSONL. Terminating failures also write a structured record. Repeated application is idempotent.

## Tests

The Pester contract suite covers exact identity, support boundaries, state capture, dry run, lifecycle coverage, structured logging, idempotence, failure handling, protected identities, running-state preservation, rollback, and absence of destructive package, file, device, or driver commands.

## Physical validation handoff

Run from elevated Windows PowerShell 5.1 on the target HP ZBook:

```powershell
$exp = '.\experiments\EXP-026\Invoke-Exp026HpDiags.ps1'
& $exp -Action Check
& $exp -Action Capture
& $exp -Action DryRun
& $exp -Action Apply
& $exp -Action Verify
```

Reboot, then run:

```powershell
& $exp -Action VerifyReboot
```

Launch the HP diagnostics application and execute a basic health check. Confirm the capability service demand-starts where required. Confirm Defender, Firewall, BitLocker, Windows Update, recovery, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale readiness. Execute repeated sign-in trials and report medians for sign-in to usable desktop and first-120-second CPU and disk activity.

Restore and verify:

```powershell
& $exp -Action Rollback
```

Physical application, reboot persistence, exact rollback execution, HP diagnostics workflow validation, protected-application readiness, instrumentation-overhead qualification, repeated trials, and median results remain `needs-evidence`. No performance gain is claimed.
