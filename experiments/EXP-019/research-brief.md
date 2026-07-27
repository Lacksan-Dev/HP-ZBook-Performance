# EXP-019 Research Brief

## Customer problem
Microsoft Office may start background work at user sign-in, competing with the desktop and requested applications for CPU and storage access.

## Controlled variable
Disable only `\Microsoft\Office\Office Background Task Handler Logon`.

## Hypothesis
Disabling this single logon-triggered task may reduce sign-in-to-usable-desktop latency and first-120-second CPU or disk activity while preserving normal on-demand Office use.

## Control conditions
Use the same HP ZBook, Windows build, BIOS, Office build, driver set, AC power state, thermal range, network state, account, and background workload. Reboot before each trial. Run at least five baseline and five calibrated trials and compare medians.

## Success threshold
At least 5 percent improvement in median sign-in readiness or a measurable reduction in first-120-second CPU or disk activity with no Office, OneDrive, update, security, management, or protected remote-access regression.

## Failure threshold
Any failure of Office document open/save, OneDrive synchronization, Office update readiness, Omnissa, Windows App, Remote Desktop, or Tailscale; any state mismatch; or no repeatable median improvement.

## Safety and rollback
Capture exact task XML, enabled state, task path, task name, action identity, and XML SHA-256 before change. Refuse any identity mismatch. Rollback restores the original enabled state and verifies the captured identity.

## Release status
Experimental. Physical evidence remains `needs-evidence`.