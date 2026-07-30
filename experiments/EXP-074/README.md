# EXP-074 Edge efficiency mode

## Candidate
Set the supported recommended Microsoft Edge policy `EfficiencyModeEnabled` to `REG_DWORD 1` on elevated HP Windows 11 systems running Edge 106 or later.

## Safety boundary
The provider changes one recommended policy value only. It preserves Edge profiles, credentials, cookies, favorites, extensions, packages, services, tasks, files, Windows security, Windows Update, recovery, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale. Existing mandatory or recommended policy ownership and enterprise-management signals cause refusal.

## Integration sequence
Run `Check`, `Capture`, and `DryRun` first. Confirm zero mutation during Check and DryRun. Apply on a dedicated HP lab system, restart Edge, run `Verify`, reboot, run `VerifyReboot`, then execute `Rollback` and verify exact removal of the experiment-created value. Repeat Apply and Rollback to confirm idempotence.

## Physical evidence request
Collect five matched baseline and five treatment runs. Preserve raw and failed runs. Report medians for Edge CPU, working set, tab-reactivation latency, first navigation, available battery discharge, Outlook responsiveness, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale. Record Windows build, HP model, BIOS, Edge version, power source, thermal state, and benchmark conditions.

Physical execution and performance measurements remain `needs-evidence`. Keep Experimental. Never assign Stable.
