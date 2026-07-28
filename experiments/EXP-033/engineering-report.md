# EXP-033 Engineering Report

## Candidate
Remove one recognized current-user Logitech G Hub tray auto-launch registration from `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.

Eligibility requires all of the following:
- HP hardware running Windows 11
- exact value name `LGHUB`, `Logitech G HUB`, or `LogitechGHub`
- unexpanded command containing `lghub.exe`
- recognized background or minimized launch argument
- no updater-only or protected identity token
- no more than one eligible registration

## Engineering controls
- support detection
- exact path, value name, unexpanded command, value kind, machine, user SID, and capture time
- dry run with no registry write
- bounded removal through `ShouldProcess`
- immediate and reboot-persistence verification
- JSONL structured logging
- idempotent repeated application
- terminating failure records
- state identity checks
- exact rollback using the captured registry value kind and data
- rollback overwrite refusal
- Pester contract tests
- non-destructive parser and scope integration checks

## Safety boundary
The implementation changes one current-user Run registration only. It does not uninstall Logitech G Hub, disable its updater service, modify packages or files, change scheduled tasks or StartupTask registrations, remove devices or drivers, or alter Windows security, updates, recovery, credentials, enterprise management, networking, Omnissa, Windows App, Remote Desktop, or Tailscale.

## Physical validation handoff
Use at least five matched baseline and five candidate trials under controlled power, thermal, update, and network conditions. Record Windows build, BIOS, driver versions, G Hub version, power source, and instrumentation overhead.

Report medians for:
- sign-in to usable desktop
- CPU and disk activity during the first 120 seconds
- G Hub on-demand launch to usable interface
- Logitech device and profile readiness
- Omnissa, Windows App, Remote Desktop, and Tailscale readiness

After application, verify reboot persistence. Then execute exact rollback and verify the original value data and registry kind are restored. Confirm G Hub background auto-launch returns after the following sign-in.

## Evidence status
Repository engineering is complete for validation handoff. Physical application, repeated measurements, reboot verification, rollback execution, workflow checks, and median results remain `needs-evidence`. No responsiveness improvement is claimed. The experiment remains Experimental.
