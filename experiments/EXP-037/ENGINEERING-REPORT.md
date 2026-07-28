# EXP-037 Engineering Report

## Candidate
Set only the documented recommended Microsoft Edge policy `HKLM\SOFTWARE\Policies\Microsoft\Edge\Recommended\BackgroundModeEnabled` to `REG_DWORD 0` on eligible unmanaged HP Windows 11 systems with supported Edge.

## Engineering controls
- HP Windows 11 and Edge support detection
- administrator and enterprise-management detection
- refusal when mandatory or recommended policy already exists
- exact registry key, value, type, data, Edge path/version, machine, and capture time
- dry run, bounded `ShouldProcess` application, immediate verification
- JSONL logging, idempotence, terminating failure records
- browser-restart and reboot-persistence verification
- exact rollback with post-application mutation refusal
- Pester contract tests and non-destructive integration checks

## Safety boundary
The implementation changes one recommended Edge policy value. It leaves Startup folders, Startup Boost, profiles, passwords, cookies, favorites, extensions, cache, SmartScreen, updates, mandatory policy, Windows security, recovery, enterprise management, services, tasks, packages, devices, drivers, Omnissa, Windows App, Remote Desktop, and Tailscale unchanged.

## Physical validation handoff
Run at least five matched baseline and five treatment trials under controlled power, thermal, network, update, and profile conditions. Report medians for prelaunch Edge process count and idle CPU, memory, disk and GPU cost, cold process launch, first visible window, first interactive window, first new-tab readiness, and first controlled navigation. Record Windows build, BIOS, drivers, Edge version, power source, thermal state, and instrumentation overhead.

Verify effective policy after closing all Edge processes, after browser restart, and after reboot. Execute rollback and confirm the exact original registry state. Validate profile data, security controls, updates, and protected remote-access applications.

## Evidence status
Repository engineering is ready for validation. Physical application, repeated measurements, browser restart, reboot persistence, rollback execution, and medians remain `needs-evidence`. No performance improvement is claimed. The experiment remains Experimental.