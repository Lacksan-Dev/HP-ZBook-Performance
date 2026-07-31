# EXP-054 Edge true demand launch

Status: Experimental  
Stage: Validation  
Evidence: needs-evidence

## Candidate
Set the recommended Microsoft Edge policy `HKLM\SOFTWARE\Policies\Microsoft\Edge\Recommended\StartupBoostEnabled` to `REG_DWORD 0` through the Lacksan Controller profile `EdgeTrueDemandLaunch`.

This changes one policy value only. Edge remains absent from the Startup folder. Profiles, passwords, cookies, favorites, extensions, cache, SmartScreen, Edge Update, packages, files, services, tasks, Windows security, updates, recovery, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale remain outside mutation scope.

## Support and refusal boundary
Require an elevated HP Windows 11 system with one Microsoft-signed Edge installation at version 88 or later. Capture the exact Edge path, version, SHA-256, publisher, Windows build, HP model, machine identity, user SID, mandatory-policy state, recommended-policy state, and management signals.

Refuse domain membership, MDM enrollment, PolicyManager ownership, Configuration Manager ownership, an existing mandatory or recommended `StartupBoostEnabled` value, unsupported Edge identity, state-file mismatch, Edge executable identity drift, policy drift, or inability to prove exact rollback.

## Transaction contract
1. `Check` inventories support, elevation, Edge identity, management signals, and both policy locations without mutation.
2. `Capture` stores exact key existence, value existence, registry kind, raw data, Edge identity, machine identity, and user SID.
3. `DryRun` reports the exact proposed DWORD and required browser-restart and reboot-persistence checks.
4. `Apply` writes one `REG_DWORD 0` value, verifies it immediately, and returns idempotently when the captured treatment already exists.
5. `Verify` validates the captured Edge identity and exact policy value after Edge restart.
6. `VerifyReboot` validates identity and persistence and records the Windows boot time.
7. `Rollback` refuses drift, removes only the experiment-owned value, removes the policy key only when the experiment created it and it remains empty, and verifies the exact captured absence.

All actions emit structured JSONL records when `LogPath` is supplied. Failures terminate and retain the failure event.

## Pester and zero-mutation integration
Run the dedicated contract suite:

```powershell
Invoke-Pester .\controller\tests\EXP-054.EdgeStartupBoostPolicy.Tests.ps1
```

On an eligible Windows test machine, run `Check` and `DryRun` first and compare registry exports before and after. They must remain byte-equivalent. Confirm no process, service, task, package, file, profile, extension, device, driver, security setting, update setting, recovery setting, management setting, or protected remote-access registration changes.

For mutation validation, capture state, apply once, apply again to verify idempotence, restart every Edge process, run `Verify`, reboot, run `VerifyReboot`, execute `Rollback`, and confirm the exact captured policy state. Preserve every JSONL record and any failed or inconclusive observation.

## Benchmark handoff
Run at least five matched baseline and five treatment trials under the same power source, thermal state, Windows build, BIOS, drivers, Edge version, profile, extensions, network target, startup set, and instrumentation configuration. Report raw runs, medians, dispersion, and instrumentation overhead for:

- sign-in to usable desktop
- prelaunch Edge process count
- prelaunch CPU, memory, disk, and GPU cost
- process start to first visible window
- process start to first interactive window
- first new-tab readiness
- first controlled navigation
- Omnissa, Windows App, Remote Desktop, and Tailscale readiness

A neutral, adverse, failed, or inconclusive result remains valid evidence.

## Evidence state
Physical HP ZBook application, five baseline and five treatment runs, browser-restart verification, reboot persistence, protected-application checks, exact rollback execution, and median measurements remain `needs-evidence`. No performance claim is recorded. Stable remains unassigned.
