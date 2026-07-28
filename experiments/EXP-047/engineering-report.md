# EXP-047 engineering report

## Outcome

Implemented a Windows PowerShell 5.1 console analyzer and reversible experiment harness. The material improvement is the safety and evidence boundary: a user can record WPR/counter evidence, apply one supported candidate with captured state, verify it, re-measure, and restore it without accepting a bulk “optimization” recipe.

Evidence state: **implemented, not applied on the lab machine**.

## Documented facts

- Windows Performance Recorder (WPR) records Event Tracing for Windows data, and Windows Performance Analyzer (WPA) is the supported analysis surface for the resulting ETL. EXP-047 uses built-in WPR profiles and preserves the ETL.
- `powercfg` documents scheme selection, AC value indices, attribute visibility, and processor power-management aliases. Processor behavior can also be hardware autonomous; EXP-047 records that state when queryable and does not promise that every legacy index controls the silicon.
- The Multimedia Class Scheduler Service (MMCSS) temporarily prioritizes registered multimedia threads. `SystemResponsiveness` is the percentage reserved for low-priority work; values below 10 and above 100 are clamped to 20.
- Microsoft strongly recommends not disabling USB selective suspend globally.
- `fsutil behavior set disablelastaccess` supports numeric values 0 through 3. A restart can be required for changes to take effect.
- `Checkpoint-Computer` is available on Windows client and limits restore-point creation frequency. A restore point is attempted, but a Tier 2 external image/snapshot remains required.
- `SystemParametersInfo` is the documented API for the seven visual-effect values used here.
- Fast Startup is a hybrid shutdown mechanism. EXP-047 changes only `HiberbootEnabled` for a declared diagnostic experiment; it does not run `powercfg /hibernate off`.

## Implementation notes

- `changes.json` is the authoritative rollback journal. Writes use a temporary file followed by replacement.
- Machine candidates require elevation and `-LabTier2Confirmed`.
- Every application is preceded by support/original-state capture and `ShouldProcess`; `-WhatIf` stops before restore-point creation, journaling, or setting mutation.
- The script verifies applied state. On an error it attempts immediate rollback and preserves both apply and rollback status.
- `Revert` restores only the most recent active journal entry, making rollback order deterministic.
- Application is refused until a valid EXP-047 baseline is present. The journal retains that evidence path plus baseline and application-time environment metadata.
- Reboot-dependent candidates are marked in the journal and remain unaccepted until the operator reboots, checks `Status`, re-measures, verifies the exact setting, and preserves that evidence.
- WPR unavailability is not fatal. The evidence explicitly records the degraded counter-only mode.
- The analyzer avoids customer content and command lines, but an ETL can still contain sensitive system activity and must be handled as diagnostic data.

## Lab measurements

None. Development validation uses parser checks, Pester unit tests, a short counter-only capture, and `-WhatIf`. No candidate is applied, stopped, disabled, or rolled back on the active workstation.

## Hypotheses

- Trace-first classification will reduce random configuration changes by pointing a user toward the busiest resource or driver path.
- The documented visual-effect candidate may improve perceived response on animation-sensitive workflows even when throughput is unchanged.
- Each Tier 2 candidate may help a narrowly defined workload, but none is presumed beneficial before repeated controlled measurements.

## Unresolved questions

- Which exact HP services are installed and unnecessary for a specific supported ZBook model and managed workflow?
- Does the target processor expose autonomous performance control, and which power indices remain effective?
- What is the counter/WPR instrumentation overhead on each target generation?
- Do the NTFS and Fast Startup candidates persist and remain compatible after the target Windows build updates?
- What threshold and workflow should define “usable” boot/sign-in readiness for the target customer?

## Primary sources

Retrieved 2026-07-29:

- Microsoft Learn, [Windows Performance Toolkit](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/)
- Microsoft Learn, [WPR command-line options](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/wpr-command-line-options)
- Microsoft Learn, [Powercfg command-line options](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options)
- Microsoft Learn, [Configure processor power management options](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/configure-processor-power-management-options)
- Microsoft Learn, [Multimedia Class Scheduler Service](https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service)
- Microsoft Learn, [USB selective suspend](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-selective-suspend)
- Microsoft Learn, [fsutil behavior](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-behavior)
- Microsoft Learn, [Checkpoint-Computer](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/checkpoint-computer?view=powershell-5.1)
- Microsoft Learn, [SystemParametersInfo](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfoa)
- Microsoft Learn, [System power states](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states)
- Microsoft Learn, [Windows Search performance issues](https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/windows-search-performance-issues)
- HP Support, [HP Touchpoint Analytics Service – Potential Escalation of Privilege](https://support.hp.com/us-en/document/ish_12269975-12269997-16)
- Intel Support, [Warning: Installing This Graphics Driver From Intel May Overwrite Customizations From Your Computer Manufacturer](https://www.intel.com/content/www/us/en/support/articles/000058958/graphics.html)
