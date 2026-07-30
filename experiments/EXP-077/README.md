# EXP-077: Edge network prediction disabled

## Variable
Set only `HKLM\SOFTWARE\Policies\Microsoft\Edge\Recommended\NetworkPredictionOptions` to `REG_DWORD 2` on eligible HP Windows 11 systems with Microsoft Edge 77 or later.

## Supported policy basis
Microsoft Edge policy documentation identifies value `2` as `NetworkPredictionNever`. The policy supports recommended configuration and dynamic refresh. It controls DNS prefetching, TCP and SSL preconnection, and page prerendering.

## Safety and refusal boundary
The provider requires elevation, HP Windows 11, exactly one supported Edge installation, and absence of enterprise-management signals. It refuses existing mandatory or recommended ownership. It changes no profile data, security control, update component, package, file, service, task, device, driver, recovery setting, enterprise-management setting, network configuration, or protected remote-access application.

## Zero-mutation integration check
1. Run `Check` and retain the returned support, Edge version, management, mandatory-policy, and recommended-policy inventory.
2. Run `DryRun` with temporary state and JSONL log paths.
3. Run `Apply -WhatIf` and verify the registry remains byte-for-byte unchanged.
4. Parse every JSONL record and verify the experiment and provider identities.
5. Confirm Omnissa, Windows App, Remote Desktop, and Tailscale registrations and files remain unchanged.

## Physical validation
Use five matched baseline and five treatment trials under the same Windows build, BIOS, Edge version, power source, thermal state, network, profile, extensions, and controlled destination. Record medians for background Edge process count, CPU, working set, disk and network activity, cold launch, first visible and interactive window, new-tab readiness, first controlled navigation, Outlook responsiveness, and protected-application readiness.

After application, restart Edge and run `Verify`. Reboot and run `VerifyReboot`. Execute `Rollback`, confirm the experiment-created value is absent, restart Edge, reboot, and confirm the original state remains restored.

## Evidence status
Physical measurements, browser-restart verification, reboot persistence, protected-application readiness, rollback execution, and medians remain `needs-evidence`. Preserve favorable, adverse, failed, and inconclusive results. This experiment remains Experimental and receives no Stable assignment.
