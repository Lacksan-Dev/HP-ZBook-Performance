# EXP-057: Logi Tune user-space removal

Status: Experimental

This candidate removes the exact Logitech-published `Logi Tune` user-space product only when a matching offline installer is supplied and hashed before application. The provider refuses ambiguous products, missing rollback media, non-Windows 11 systems, non-elevated sessions, and executable uninstallers without a vendor quiet-uninstall command.

## Safety boundary

The experiment does not call PnP, driver-store, firmware, device, Windows security, Windows Update, recovery, credential, accessibility, enterprise-management, or network configuration commands. Logitech HID, USB, Bluetooth, receiver, camera, audio, and other device-critical drivers remain in place.

## Zero-mutation checks

Run `Check`, `Capture`, and `DryRun` first. Confirm the product name, version, publisher, uninstall identity, offline installer path, installer SHA-256, and rollback arguments. Review the JSONL log and state file for sensitive paths before sharing.

## Physical validation

Use the same Windows build, BIOS, drivers, Logi Tune version, power source, thermal state, peripherals, and benchmark procedure for five baseline and five treatment trials. Report medians for sign-in to usable desktop and CPU and disk activity during the first 120 seconds. Verify camera, microphone, speaker, headset, Bluetooth/USB receiver, Omnissa, Windows App, Remote Desktop, and Tailscale readiness.

After reboot, run `VerifyReboot`. Then run `Rollback` and confirm that the captured Logi Tune version is restored from the matching hashed installer. Repeat functional checks and preserve failed or inconclusive evidence.

No performance claim or Stable designation is authorized until physical evidence and human approval exist.
