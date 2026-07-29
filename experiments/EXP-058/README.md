# EXP-058: Microsoft 365 Startup-folder shortcut removal

## Status

Experimental. Physical measurements remain `needs-evidence`.

## Candidate

Delete one exact current-user Startup-folder `.lnk` whose resolved target is a supported Microsoft 365 desktop executable and whose arguments are empty. Refuse absent, ambiguous, unresolved, protected, or argument-bearing shortcuts.

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

Capture records the exact shortcut bytes through a backup file, SHA-256, timestamps, attributes, target path, arguments, working directory, icon location, description, and window style. Application refuses source or backup drift. Rollback refuses an occupied destination, restores the captured bytes and file metadata, then verifies the hash and resolved shortcut metadata.

## Non-destructive integration check

Run `Check`, `DryRun`, and `Apply -WhatIf` on Windows 11. Confirm that no Startup-folder file, Office installation, service, task, package, policy, driver, or protected remote-access registration changes.

## Physical validation

Use the same HP Windows 11 device, account, AC power source, power mode, Windows build, BIOS, storage and display drivers, Microsoft 365 version, network state, and controlled thermal state.

1. Capture the original shortcut and preserve the generated state, backup, and JSONL log.
2. Run five baseline sign-ins.
3. Apply the candidate and reboot.
4. Run five treatment sign-ins.
5. Compare medians for sign-in to usable desktop, first-120-second CPU, first-120-second disk activity, protected remote-access readiness, and first manual launch readiness of the affected Office application.
6. Execute rollback, reboot, verify exact restoration, and repeat one confirmation sign-in.
7. Preserve failed or inconclusive results. Make no performance claim until measurements exist.

Never assign Stable without explicit human approval.
