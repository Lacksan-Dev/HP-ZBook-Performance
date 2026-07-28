# EXP-035 Engineering Report

## Candidate
Remove one recognized current-user Logi Bolt tray auto-launch registration from `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.

Eligibility requires HP hardware running Windows 11, an exact Logi Bolt value-name identity, an unexpanded command containing `LogiBolt.exe` or `logi-bolt.exe`, a recognized background, minimized, startup, or tray argument, no updater-only command, no protected identity token, and no more than one eligible registration.

## Engineering controls
- support detection
- exact registry path, value name, unexpanded command, value kind, machine, user SID, and capture time
- dry run without registry writes
- bounded removal through `ShouldProcess`
- immediate and reboot-persistence verification
- JSONL structured logging
- idempotent repeated application
- terminating failure records
- state identity checks
- exact rollback using captured data and value kind
- rollback overwrite refusal
- Pester contract tests
- non-destructive parser and scope integration checks

## Safety boundary
The implementation changes one current-user Run registration only. It leaves Logi Bolt installed and leaves receiver pairing, packages, files, services, scheduled tasks, StartupTask registrations, updater components, HID devices, drivers, Defender, Firewall, BitLocker, Credential Guard, VBS, Windows Update, recovery, credentials, accessibility, enterprise management, networking, Omnissa, Windows App, Remote Desktop, and Tailscale unchanged.

## Physical validation handoff
Use at least five matched baseline and five candidate trials under controlled power, thermal, update, and network conditions. Record Windows build, BIOS, driver versions, Logi Bolt version, power source, and instrumentation overhead.

Report medians for sign-in to usable desktop, CPU and disk activity during the first 120 seconds, Logi Bolt on-demand launch to usable interface, receiver and paired-device readiness, update-check behavior, and protected remote-access application readiness.

After application, verify reboot persistence. Execute exact rollback and verify the original registry data and value kind. Confirm Logi Bolt background auto-launch returns after the following sign-in.

## Evidence status
Repository engineering is complete for validation handoff. Physical application, repeated measurements, reboot verification, rollback execution, workflow checks, and median results remain `needs-evidence`. No responsiveness improvement is claimed. The experiment remains Experimental.
