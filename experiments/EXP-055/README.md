# EXP-055 Logitech G Hub updater demand start

## Candidate
Use the `LogitechGHubUpdaterDemandStart` controller profile to change only `LGHUBUpdaterService` from Automatic or Automatic Delayed Start to Manual. Application preserves the service running state.

## Safety boundary
The provider requires an elevated HP Windows 11 system, the exact service name, a Logitech or G HUB display identity, and an `lghub_updater.exe` binary identity. It refuses unsupported or mismatched services and changes no other service, process, task, package, file, device, driver, security control, update component, recovery setting, enterprise-management setting, or protected remote-access application.

## Transaction contract
`Check`, `Capture`, `DryRun`, `Apply`, `Verify`, `VerifyReboot`, and `Rollback` are supported. State includes exact service name, display name, binary path, start mode, delayed-auto-start value, running state, machine identity, and timestamp. JSONL logging is available for every action. Repeated application is idempotent. Rollback refuses configuration drift and restores startup, delayed-start, and running state exactly.

## Integration check
Run the provider with `-Action Check` and `-Action DryRun` on an eligible lab device and confirm zero mutation before applying. Run Pester against `controller/tests/EXP-055.LogitechGHubUpdaterService.Tests.ps1`.

## Benchmark and evidence
Perform at least five matched baseline and five treatment sign-ins. Record Windows build, HP model, BIOS, drivers, G Hub version, power source, thermal state, and instrumentation. Report medians for sign-in to usable desktop and first-120-second CPU and disk activity. Verify G Hub demand launch, device detection, configuration persistence, update-check behavior, Logitech HID readiness, Omnissa, Windows App, Remote Desktop, Tailscale, reboot persistence, and exact rollback.

Physical application and measurements remain `needs-evidence`. Preserve failed or inconclusive results. Release status remains Experimental.
