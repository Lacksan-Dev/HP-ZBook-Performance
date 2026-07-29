# EXP-064 Logitech SetPoint removal

Status: Experimental, needs-evidence.

## Candidate

Remove one exact Logitech-published SetPoint uninstall identity on Windows 11. Preserve PnP devices, driver-store packages, USB, HID and Bluetooth drivers, receiver pairing, firmware, Windows protections, enterprise management, and Omnissa, Windows App, Remote Desktop, and Tailscale.

Application requires elevation, one matching product, absence of enterprise-management ownership signals, a safe user-space uninstall command, and a locally supplied installer for the captured version. The installer SHA-256 is captured before removal and checked before application and rollback.

## Commands

```powershell
$script = '.\LogitechSetPointRemoval.ps1'
$installer = 'C:\LacksanRollback\setpoint-installer.exe'
& $script -Action Check -OfflineInstaller $installer
& $script -Action Capture -OfflineInstaller $installer
& $script -Action DryRun -OfflineInstaller $installer
& $script -Action Apply -OfflineInstaller $installer -WhatIf
& $script -Action Apply -OfflineInstaller $installer -Confirm
& $script -Action Verify -OfflineInstaller $installer
# Reboot, then:
& $script -Action VerifyReboot -OfflineInstaller $installer
& $script -Action Rollback -OfflineInstaller $installer -Confirm
```

## Integration path

Run `Check`, `Capture`, `DryRun`, and `Apply -WhatIf` with a version-matched offline installer. Compare uninstall inventory, services, scheduled tasks, startup registrations, PnP devices, driver-store packages, and protected-application state before and after. The zero-mutation path must produce no changes beyond the selected state and JSONL log files.

## Physical validation

Use five matched baseline and five treatment sign-ins and report medians for sign-in to usable desktop and first-120-second CPU and disk activity. Record Windows build, device, BIOS, storage, display, HID and receiver drivers, SetPoint version, power source, power mode, thermal state, network state, and instrumentation.

Before application, after application, after reboot, and after rollback, verify:

- Basic keyboard and mouse input.
- Receiver and Bluetooth readiness where applicable.
- Device Manager has no newly introduced errors.
- No PnP device, driver-store package, firmware, or pairing mutation occurred.
- Defender, Firewall, BitLocker, Credential Guard, VBS, Windows Update, recovery, credentials, accessibility, and enterprise management remain unchanged.
- Omnissa, Windows App, Remote Desktop, and Tailscale remain ready.
- Exact captured SetPoint version and uninstall identity return after rollback.

Preserve failed or inconclusive outcomes. Physical measurements remain needs-evidence. Stable requires explicit human approval.