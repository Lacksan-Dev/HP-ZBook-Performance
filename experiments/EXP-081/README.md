# EXP-081: Logitech SetPoint Event Manager demand launch

## Status
Experimental, `stage: validation`, `needs-evidence`. Stable requires explicit human approval.

## Candidate
Remove one exact SetPoint Event Manager value from an approved HKCU or HKLM Run key. Preserve the SetPoint installation, executable, services, tasks, receiver pairing, devices, drivers, firmware, profiles, and advanced settings.

## Safety and support boundary
The provider requires HP Windows 11, valid Logitech or Logi Authenticode identity, one exact `SetPoint.exe` or `SetPointII.exe` registration under a SetPoint installation path, and absence of domain, MDM, PolicyManager, or Configuration Manager ownership. It refuses ambiguous candidates, updater, repair, uninstall, firmware, pairing, device, driver, protected-application, and protected-Windows identities.

Protected scope includes Defender, Firewall, BitLocker, Credential Guard, VBS, Windows Update, recovery, enterprise management, accessibility, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale.

## Lifecycle
1. Run `Check` and record support and candidate inventory.
2. Run `Capture` with a new protected state path. Capture exact path, value name, registry type, unexpanded command, executable path, SHA-256, version, signer, machine, and user SID.
3. Run `DryRun` or `Apply -WhatIf`. Confirm zero mutation.
4. Run `Apply`. The only permitted mutation is deleting the captured Run value.
5. Run `Verify` immediately.
6. Reboot and run `VerifyReboot`.
7. Validate SetPoint manual launch, basic keyboard and mouse input, receiver connectivity, advanced SetPoint features, and protected remote-access readiness.
8. Run `Rollback`. Exact restoration requires unchanged executable hash, signer, command identity, and an absent destination value.
9. Reboot and confirm the original launch behavior and protected scope.

## Integration procedure
Before and after every action, capture the two approved Run keys, services, scheduled tasks, installed packages, PnP devices, signed drivers, Defender state, Windows Update state, recovery configuration, enterprise-management indicators, and protected-application readiness. Compare snapshots. The Run value is the sole expected difference during treatment.

Exercise these zero-mutation cases: unsupported manufacturer, non-Windows 11, managed device, no candidate, multiple candidates, invalid signature, path mismatch, updater command, protected identity, existing state file, `DryRun`, and `-WhatIf`. Retain every refusal and failure log.

## Physical evidence request
Run five matched baseline sign-ins and five matched treatment sign-ins on the same HP Windows 11 system. Hold Windows build, BIOS, drivers, connected peripherals, AC power, power mode, thermal state, network, startup set, and instrumentation constant. Record raw runs and medians for sign-in to usable desktop, first-120-second CPU and disk activity, SetPoint process activity, peripheral readiness, advanced-feature readiness, and Omnissa, Windows App, Remote Desktop, and Tailscale readiness.

Physical application, reboot persistence, exact rollback execution, instrumentation overhead, medians, dispersion, adverse behavior, failures, and inconclusive outcomes remain `needs-evidence`.
