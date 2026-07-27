# EXP-008 Logitech user-space auto-launch cleanup

## Purpose

Remove recognized Logitech user-space startup registrations for Logi Options+, Logi Bolt, Logi Tune, and G Hub while preserving applications, services, scheduled tasks, packages, files, devices, and drivers.

## Safety boundary

The module only acts on:

- approved HKCU and HKLM Run or RunOnce values whose combined name and command identify both a Logitech product and a user-space launcher, tray, agent, updater, assistant, or telemetry role
- Startup-folder files whose identity matches the same bounded patterns

The module rejects Omnissa, Windows App, Remote Desktop, Tailscale, Windows Security, credential, and accessibility identities. Logitech HID, keyboard, mouse, receiver, Bluetooth, and driver-only identities remain outside scope.

## Commands

```powershell
Import-Module .\LogitechAutoLaunch.psm1 -Force

Test-Exp008Support
Get-Exp008Inventory
Invoke-Exp008Apply -StatePath .\evidence\state.json -LogPath .\evidence\run.jsonl -DryRun
Invoke-Exp008Apply -StatePath .\evidence\state.json -LogPath .\evidence\run.jsonl
Test-Exp008Applied -StatePath .\evidence\state.json
Invoke-Exp008Rollback -StatePath .\evidence\state.json -LogPath .\evidence\run.jsonl
Test-Exp008Rollback -StatePath .\evidence\state.json
```

## Engineering behavior

- HP Windows 11 support detection
- exact registry path, value name, value type, and value data capture
- Startup-file backup before removal
- dry-run planning
- candidate identity recheck immediately before mutation
- JSONL logging
- idempotent repeated application when no candidates remain
- fail-closed behavior when identity changes
- exact rollback and rollback verification
- post-reboot verification through `Test-Exp008Applied`

## Physical validation required

Record Windows build, HP model, BIOS, drivers, Logitech application versions, power source, thermal state, network state, and background workload. Run repeated baseline and treatment sign-in trials and report medians. Confirm Omnissa, Windows App, Remote Desktop, and Tailscale readiness. Verify application after reboot, execute rollback, reboot again, and verify exact restoration.

No performance improvement is claimed until those measurements exist.
