# EXP-036 Engineering Report

## Candidate
Set only `HKLM\SOFTWARE\Policies\Microsoft\Edge\HideFirstRunExperience` to `REG_DWORD 1` on eligible unmanaged HP Windows 11 systems with Microsoft Edge 80 or later.

Microsoft documents this mandatory Edge policy as suppressing the first-run experience and splash screen. It requires an Edge restart and has no recommended-policy path.

## Engineering controls
- HP Windows 11 and Edge 80+ support detection
- administrator detection
- refusal when Azure AD, domain, or workplace join indicators are present
- refusal when the policy value already exists
- exact key existence, value existence, type, data, Edge path, Edge version, machine, and capture time
- dry run without registry writes
- bounded application through `ShouldProcess`
- immediate and reboot-persistence verification
- JSONL structured logging
- idempotent verified state handling
- terminating failure records
- exact rollback with post-application mutation refusal
- cleanup of an empty experiment-created key only
- Pester contract tests
- non-destructive parser and scope integration checks

## Safety boundary
The implementation changes one documented Edge policy value only. It leaves the Startup folder, Startup Boost, background mode, profiles, passwords, cookies, favorites, extensions, cache, SmartScreen, updates, existing management policy, Windows security, recovery, drivers, Omnissa, Windows App, Remote Desktop, and Tailscale unchanged.

## Physical validation handoff
Use at least five matched baseline and five treatment trials under controlled power, thermal, update, network, and profile conditions. Record Windows build, BIOS, drivers, Edge version, power source, thermal state, profile state, first-run state, and instrumentation overhead.

Report medians for cold process launch, first visible window, first interactive window, first new-tab readiness, first controlled navigation, and prelaunch idle CPU, memory, disk, GPU, and Edge process cost. Verify the effective policy after closing all Edge processes, after reopening Edge, and after reboot.

Execute exact rollback and verify the value is absent again. Confirm profiles, passwords, cookies, favorites, extensions, security controls, updates, and protected remote-access applications remain functional.

## Evidence status
Repository engineering is complete for validation handoff. Physical application, repeated measurements, Edge restart verification, reboot verification, rollback execution, instrumentation-overhead qualification, and median results remain `needs-evidence`. No responsiveness improvement is claimed. The experiment remains Experimental.
