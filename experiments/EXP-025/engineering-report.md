# EXP-025 Engineering Report

## Candidate

The implementation is bounded to the exact Windows service name `HPAppHelperCap`. The service executable command must identify the HP App Helper capability component. Any platform, service-name, executable, protected-identity, state-file, or rollback identity mismatch causes a terminating refusal.

## Change

Application changes only the recognized service startup mode to `Manual`. It preserves the current running state. It does not stop the service during application and does not remove or modify packages, executables, tasks, Run registrations, devices, drivers, Windows security, Windows Update, recovery, enterprise management, Omnissa, Windows App, Remote Desktop, or Tailscale.

## Reversible lifecycle

1. `Check` validates HP Windows 11 support and exact service identity.
2. `Capture` records machine identity, service name, display name, executable path, startup mode, running state, and UTC time.
3. `DryRun` emits a structured plan and writes no service configuration.
4. `Apply` captures state when required, uses `ShouldProcess`, changes startup mode to Manual, verifies the result, and refuses an unexpected running-state change.
5. `Verify` confirms the immediate state.
6. `VerifyReboot` confirms persistence after reboot.
7. `Rollback` revalidates the service and state identities, restores the exact startup mode and running state, and verifies both.

Every lifecycle action writes JSONL. Terminating failures also write a structured failure record. Repeated application is idempotent.

## Tests

The Pester contract suite checks exact identity, support boundaries, state capture, dry run, lifecycle coverage, structured logging, idempotence, failure handling, protected identities, running-state preservation, rollback, and absence of uninstall, file deletion, device-disable, or driver-removal commands.

## Physical validation handoff

Run from an elevated Windows PowerShell 5.1 session on the target HP ZBook:

```powershell
$exp = '.\experiments\EXP-025\Invoke-Exp025HpAppHelper.ps1'
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

Validate HP support application launch and observe whether the capability service demand-starts when its function is requested. Confirm Defender, Firewall, BitLocker, Windows Update, recovery, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale readiness. Execute repeated sign-in trials and report medians for sign-in to usable desktop and first-120-second CPU and disk activity.

Restore and verify:

```powershell
& $exp -Action Rollback
```

Physical application, reboot persistence, exact rollback execution, HP workflow validation, protected-application readiness, instrumentation-overhead qualification, repeated trials, and median results remain `needs-evidence`. No performance gain is claimed.
