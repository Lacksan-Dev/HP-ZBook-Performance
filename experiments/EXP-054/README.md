# EXP-054 Edge true demand launch

## Candidate
Set the recommended Microsoft Edge policy `HKLM\SOFTWARE\Policies\Microsoft\Edge\Recommended\StartupBoostEnabled` to `REG_DWORD 0` through the Lacksan Controller profile `EdgeTrueDemandLaunch`.

## Safety and refusal boundary
The provider requires an elevated HP Windows 11 system with Microsoft Edge 88 or later. It refuses managed-device signals, an existing mandatory policy, an existing recommended policy, unsupported systems, state identity mismatches, and rollback when the experiment-owned value has changed.

The provider changes no Edge profile, password, cookie, favorite, extension, cache, update component, Startup-folder entry, service, scheduled task, package, file, device, or driver. Protected remote-access applications and Windows platform protections remain outside mutation scope.

## Transaction contract
1. `Check` records support, Edge version, elevation, management signals, and current mandatory and recommended policy state.
2. `Capture` records exact key existence, value existence, registry kind, and unexpanded data before mutation.
3. `DryRun` reports the exact policy value and required browser-restart and reboot-persistence checks.
4. `Apply` sets one `REG_DWORD 0` value and immediately verifies it.
5. `Verify` checks the exact value after Edge restart.
6. `VerifyReboot` checks persistence and records boot time.
7. `Rollback` removes the experiment value and removes the experiment-created empty key only when the captured state shows that the key was absent.

Every action emits JSONL records when `LogPath` is supplied. Repeated application is idempotent. Failures terminate and preserve the failure record.

## Benchmark handoff
Run at least five matched baseline and five treatment trials under the same power source, thermal state, Windows build, BIOS, drivers, Edge version, profile, extensions, network target, and instrumentation configuration. Report medians for sign-in to usable desktop, prelaunch Edge process count and resource cost, cold process launch, first visible window, first interactive window, first new-tab readiness, and first controlled navigation. Record instrumentation overhead and preserve failed or inconclusive runs.

## Evidence state
Physical HP ZBook application, browser-restart verification, reboot verification, exact rollback execution, and repeated benchmark measurements remain `needs-evidence`. No performance claim is recorded. Experimental status remains in force.
