# EXP-018: Remove Office Sync Process current-user Run registration

## Hypothesis
Removing one strictly identified `OfficeSyncProcess.exe` current-user Run registration may reduce sign-in contention while preserving on-demand Office and OneDrive workflows.

## Controlled variable
`HKCU\Software\Microsoft\Windows\CurrentVersion\Run` values whose name matches `OfficeSyncProcess` and whose command resolves to `OfficeSyncProcess.exe`.

## Safety boundary
This experiment changes one registry startup value only. It leaves Office applications, OneDrive, Click-to-Run, services, scheduled tasks, packages, files, security controls, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale unchanged.

## Required evidence
Run at least five baseline and five calibrated sign-in trials under matched power, thermal, Windows build, Office version, and background-work conditions. Report medians for sign-in readiness and first-120-second CPU and disk activity. Verify Office document open, save, OneDrive synchronization, reboot persistence, exact rollback, and protected remote-access readiness.

## Status
Experimental. Physical evidence remains pending.
