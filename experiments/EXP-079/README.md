# EXP-079: Enable Edge Startup Boost

## Candidate
Set only `HKLM\SOFTWARE\Policies\Microsoft\Edge\Recommended\StartupBoostEnabled` to `REG_DWORD 1` on an unmanaged HP Windows 11 system with exactly one Microsoft Edge 88 or later installation.

## Safety and reversibility
The provider captures mandatory and recommended policy state before mutation, refuses existing ownership, supports dry run and `-WhatIf`, verifies application and reboot persistence, records structured JSONL events, applies idempotently, refuses state or policy drift, and removes only the experiment-created value during rollback.

It changes no Edge profile data, credentials, cookies, favorites, extensions, SmartScreen settings, update components, packages, files, services, scheduled tasks, Startup-folder entries, Windows protections, enterprise-management state, device-critical drivers, or protected remote-access applications.

## Zero-mutation integration check
Run `Check` and `DryRun` with temporary state and log paths. Confirm that the recommended value, mandatory value, Edge files, Startup folders, services, tasks, security settings, update settings, drivers, Omnissa, Windows App, Remote Desktop, and Tailscale remain unchanged. A managed, unsupported, ambiguous, or preconfigured system must terminate before mutation.

## Physical validation
Use five matched baseline and five treatment trials under controlled AC power and thermal conditions. Record Windows build, HP model, BIOS, storage, display and network drivers, Edge version, power source, thermal state, and instrumentation overhead. Compare medians for sign-in to usable desktop, prelaunch Edge process count, CPU, memory, disk and GPU cost, first visible window, first interactive window, new-tab readiness, first navigation, and protected-application readiness.

After application, restart Edge and verify `edge://policy` behavior without collecting profile data. Reboot and run `VerifyReboot`. Execute exact rollback, confirm the value is absent, reboot again, and verify restoration. Preserve favorable, adverse, failed, and inconclusive evidence.

Physical measurements remain `needs-evidence`. Release state remains Experimental. Stable requires explicit human approval.
