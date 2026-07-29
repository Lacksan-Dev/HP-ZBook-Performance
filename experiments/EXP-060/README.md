# EXP-060 Logi Bolt user-space removal

Status: Experimental, needs-evidence.

## Candidate

Remove one exact Logitech or Logi-published Logi Bolt uninstall identity on Windows 11. Preserve all PnP devices, driver-store packages, firmware, Bolt receiver pairing, Bluetooth pairing, Windows protections, enterprise management, and Omnissa, Windows App, Remote Desktop, and Tailscale.

Application requires elevation, a single matching product, absence of enterprise-management ownership signals, and a locally supplied installer for the captured version. The installer SHA-256 is captured before removal and checked again before application and rollback.

## Commands

```powershell
$script = '.\LogiBoltRemoval.ps1'
$installer = 'C:\LacksanRollback\logi-bolt-installer.exe'
& $script -Action Check -OfflineInstaller $installer
& $script -Action Capture -OfflineInstaller $installer
& $script -Action DryRun -OfflineInstaller $installer
& $script -Action Apply -OfflineInstaller $installer -WhatIf
& $script -Action Apply -OfflineInstaller $installer -Confirm
& $script -Action Verify -OfflineInstaller $installer
& $script -Action VerifyReboot -OfflineInstaller $installer
& $script -Action Rollback -OfflineInstaller $installer -Confirm
```

## Validation

Run five matched baseline and five treatment sign-ins. Report medians for usable-desktop latency, aggregate CPU and disk activity during the first 120 seconds, and readiness of the protected remote-access applications. Record Windows build, HP model, BIOS, Logitech driver and Logi Bolt versions, power source, power mode, thermal state, and benchmark conditions.

Before removal, after removal, after reboot, and after rollback verify basic keyboard and mouse input, Bolt receiver and Bluetooth connectivity, preserved pairing, and absence of newly introduced Device Manager errors. Record loss of pairing management, device-management UI, or the ability to pair new Bolt devices without reinstalling as expected user-function tradeoffs.

## Integration path

`Check`, `DryRun`, and `Apply -WhatIf` form the zero-mutation integration path. Confirm the state and JSONL files contain no credentials, usernames beyond the captured SID, installer contents, receiver identifiers, Bluetooth addresses, or private application data before sharing.

## Rollback

Rollback refuses missing or hash-drifted media. It reinstalls the captured package and verifies the original version and uninstall identity. Physical rollback execution remains needs-evidence. Failed and inconclusive results remain part of the experiment record. No Stable designation is permitted without human approval.
