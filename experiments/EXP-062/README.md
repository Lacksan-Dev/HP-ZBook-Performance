# EXP-062 Logitech Unifying Software removal

Status: Experimental, needs-evidence.

## Candidate

Remove one exact Logitech-published Logitech Unifying Software uninstall identity on Windows 11. Preserve the Unifying receiver, existing receiver pairings, PnP devices, driver-store packages, USB and HID drivers, firmware, Windows protections, enterprise management, and Omnissa, Windows App, Remote Desktop, and Tailscale.

Application requires elevation, a single matching product, absence of enterprise-management ownership signals, a safe user-space uninstall command, and a locally supplied installer for the captured version. The installer SHA-256 is captured before removal and checked before application and rollback.

## Commands

```powershell
$script = '.\LogitechUnifyingRemoval.ps1'
$installer = 'C:\LacksanRollback\logitech-unifying-installer.exe'
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

Run five matched baseline and five treatment sign-ins. Report medians for usable-desktop latency, aggregate CPU and disk activity during the first 120 seconds, and readiness of protected remote-access applications. Record Windows build, HP model, BIOS, USB and HID driver versions, Logitech Unifying Software version, power source, power mode, thermal state, and benchmark conditions.

Before removal, after removal, after reboot, and after rollback verify receiver connectivity, existing pairing, keyboard input, mouse input, and Device Manager status. Confirm no newly introduced receiver, USB, or HID errors. Record loss of pairing or re-pairing through the Unifying utility as an expected customer-function tradeoff.

## Integration path

`Check`, `DryRun`, and `Apply -WhatIf` form the zero-mutation integration path. Confirm state and JSONL files contain no credentials, receiver identifiers, device serial numbers, hardware addresses, or private application data before sharing.

## Rollback

Rollback refuses missing or hash-drifted media. It reinstalls the captured package and verifies the original version and uninstall identity. Physical rollback execution remains needs-evidence. Failed and inconclusive results remain part of the experiment record. Stable designation requires human approval.
