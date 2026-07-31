# EXP-058: Microsoft 365 Startup-folder shortcut removal

## Status

Experimental. Physical measurements remain `needs-evidence`.

## Candidate

Delete one exact current-user Startup-folder `.lnk` whose resolved target is a supported Microsoft 365 desktop executable, whose arguments are empty, whose target resides in a Microsoft Office or Microsoft 365 application directory, and whose Authenticode signature is valid for Microsoft Corporation.

The provider requires HP Windows 11 and refuses domain-joined, MDM-enrolled, PolicyManager-controlled, Configuration Manager-controlled, or Office-policy-owned systems. It also refuses absent, ambiguous, unresolved, protected, argument-bearing, unsigned, publisher-mismatched, path-mismatched, missing-target, or multiple shortcuts.

The implementation preserves the installed Microsoft 365 applications, Click-to-Run servicing, activation, documents, add-ins, profiles, credentials, scheduled tasks, services, packages, Windows protections, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale.

## Commands

```powershell
.\OfficeStartupShortcut.ps1 -Action Check
.\OfficeStartupShortcut.ps1 -Action Capture
.\OfficeStartupShortcut.ps1 -Action DryRun
.\OfficeStartupShortcut.ps1 -Action Apply -WhatIf
.\OfficeStartupShortcut.ps1 -Action Apply
.\OfficeStartupShortcut.ps1 -Action Verify
.\OfficeStartupShortcut.ps1 -Action VerifyReboot
.\OfficeStartupShortcut.ps1 -Action Rollback
```

## State and rollback

Capture records the exact shortcut bytes through a backup file, SHA-256, timestamps, attributes, owner, SDDL, target path, arguments, working directory, icon location, description, window style, and target executable path, hash, version, product name, signature status, and publisher. The schema-versioned state is bound to the experiment, machine, and user SID.

Capture refuses an existing state artifact or rollback backup. Application refuses management ownership, source drift, backup drift, executable hash drift, signature drift, publisher drift, or version drift. Verification fails terminatively when the shortcut reappears or the target executable identity changes.

Rollback refuses management drift, executable identity drift, an occupied destination, a missing backup, or backup hash drift. It restores the captured bytes, timestamps, attributes, and SDDL, then verifies the shortcut hash, resolved metadata, ACL, and target executable identity.

## Non-destructive integration check

Run `Check`, `DryRun`, and `Apply -WhatIf` on an HP Windows 11 test system. Capture before-and-after inventories for the Startup folder, Microsoft 365 installation, services, scheduled tasks, packages, Office policy locations, device and driver state, Windows security, Windows Update, recovery, enterprise management, and the protected remote-access registrations. Confirm zero mutation.

Run Pester against `tests/EXP-058/OfficeStartupShortcut.Tests.ps1`. Preserve parser, contract, refusal, idempotence, failure-handling, persistence, and rollback evidence even when a case fails or remains inconclusive.

## Physical validation

Use the same HP Windows 11 device, account, AC power source, power mode, Windows build, BIOS, storage and display drivers, Microsoft 365 version, target executable hash, display topology, network state, and controlled thermal state.

1. Confirm support detection and preserve the generated state, backup, and JSONL log.
2. Run five baseline sign-ins.
3. Apply the candidate and verify immediate removal.
4. Reboot and verify persistence.
5. Run five treatment sign-ins.
6. Compare medians and dispersion for sign-in to usable desktop, first-120-second CPU, first-120-second disk activity, protected remote-access readiness, and first manual launch readiness of the affected Office application.
7. Execute exact rollback, reboot, verify restoration, and repeat one confirmation sign-in.
8. Preserve favorable, adverse, failed, rejected, and inconclusive evidence. Make no performance claim until measurements exist.

Never assign Stable without explicit human approval.
