# HP ZBook Performance Lab

This repository develops measurable, reversible Windows responsiveness experiments for HP ZBook workstations. Experimental code is not a promise of a speed-up: capture a baseline, change one variable, repeat the same workload, and keep a change only when repeated evidence supports it.

## Lacksan UX-ROM console

**Lacksan UX-ROM** is the user-facing model name of `ZBookPerf.ps1`, the
EXP-047 performance-layer controller and reversible experiment harness. The
filename remains stable for existing download commands and automation. It runs
on Windows PowerShell 5.1, records bounded counters, shows compact console
charts, and journals every applied candidate in
`C:\ProgramData\ZBookPerf\changes.json`. Optional Windows Performance Recorder
(WPR) collection now uses its memory-mode default. UX-ROM deletes the temporary
ETL before the test returns and never creates a retained trace CSV.

UX means **user experience**. ROM means
[**read-only memory**](https://www.ibm.com/think/topics/primary-storage) in
computer hardware: nonvolatile storage traditionally used for built-in
instructions. The name is a respectful reference to Mine's VX-ROM and its
[factory-computer reprogramming approach](https://rpmgen.com/inside-mines/).
UX-ROM is not literally firmware or ROM; it is a PowerShell controller that
applies measured, reversible Windows configuration.

Open **Windows PowerShell 5.1 as Administrator** and paste this one line:

```powershell
irm https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main/ZBookPerf.ps1 | iex
```

No separate execution-policy command, Desktop copy, `Unblock-File`, or Notepad
step is required. The bootstrap authorizes only the current PowerShell process
while it loads the downloaded UX-ROM components, then restores the prior process
policy when UX-ROM exits. It never changes the `CurrentUser` or `LocalMachine`
execution policy. A policy enforced through Group Policy still takes precedence
and is reported instead of bypassed.

ZBookPerf accepts `-Candidate` as before. Internally that parameter uses a
collision-resistant name so the convenience command also works in Windows
PowerShell 5.1.

On startup, the console prints one compact Lacksan ASCII mark in gray with red
UX-ROM and version accents. It does not redraw the banner whenever the menu
returns. Downloading a new file does not replace code that is already loaded in
an open menu; quit that menu and start the downloaded file again.

The first screen is a deployment dashboard instead of twelve layer submenus. It
lists every built-in tweak as **READY**, **APPLIED**, **ALREADY SET**, **LAB
ONLY**, or **UNAVAILABLE**, followed by a short explanation. Only READY numbers
can be selected from this screen. **Apply all remaining READY tweaks** skips
controls that are already applied, already configured, unsupported, or reserved
for reboot validation. Diagnostics, the twelve-layer research map, physical
validation, and enrollment maintenance live under one Advanced entry.

Choosing a READY tweak runs its required layer baseline internally before the
change. The workflow persists at
`C:\ProgramData\ZBookPerf\layer-workflow.json`, so a reboot-dependent experiment
can resume after restart. Accepted earlier changes remain in place while the
next experiment gets a fresh baseline; this measures cumulative interactions
without hiding which change produced an interaction. Missing layer integrations
remain visible product gaps rather than becoming more diagnostic menu entries.

The synergy batch includes only supported controls that do not require a
reboot-specific validation path. It currently considers MMCSS responsiveness,
the AC performance policy when the built-in plan exists, and documented
per-user visual effects. It excludes NTFS last-access and Fast Startup
experiments because those require isolated reboot testing. The batch gets one
before/after measurement, one confirmation for its eligible scope, individual
original-state journal entries, and a batch rollback record. It is an explicit
cumulative interaction experiment, not proof that every included control is a
performance gain.

### Test-result privacy and storage

Completed UX-ROM tests do not remain in `C:\ProgramData\ZBookPerf`. UX-ROM sends
a small sanitized summary to the Lacksan Updates site, then removes the local
baseline, after-measurement, detailed profile files, and session pointer even if
the website handoff fails. The public summary can include aggregate medians,
the HP model, Windows build, power context, test decision, and plain-language
limitations. It excludes ETL, CSV, raw samples, process lists, command lines,
file paths, credentials, and customer content.

Publishing uses an authenticated GitHub CLI session to send a bounded
`repository_dispatch` event to the private website repository. If `gh` is not
installed or authenticated, UX-ROM says the post was not queued but still
honors local zero retention. The website validates and escapes every accepted
field, creates an idempotent reader-friendly update, and deploys it through the
existing Azure Static Web Apps workflow.

Original-state and rollback records are safety state, not test results, so
`changes.json`, `latest-synergy-batch.json`, `layer-workflow.json`, and the
structured event log remain. An unfinished multi-step or reboot experiment may
temporarily retain its current baseline until it is measured or reverted; a
completed test does not.

Useful non-interactive examples:

```powershell
# Run the single read-only diagnostic entry point
.\ZBookPerf.ps1 -Action FullDiagnostics -DurationSeconds 30

# Preview the whole eligible synergy batch without changing Windows
.\ZBookPerf.ps1 -Action ApplyAll -WhatIf

# Display all twelve layers, current integration coverage, and next experiments
.\ZBookPerf.ps1 -Action LayerMap

# Open or resume the persisted sequential layer workflow
.\ZBookPerf.ps1 -Action LayerWorkflow

# Counter-only 30-second baseline; publishes a diagnostic summary and removes the local result
.\ZBookPerf.ps1 -Action Analyze -DurationSeconds 30 -NoTrace

# Inventory Layer 10 controls and capture five Explorer readiness runs
.\ZBookPerf.ps1 -Action ShellProfile -ShellRunCount 5

# Map Layer 4 signed packages, Plug and Play health, and driver-service ownership
.\ZBookPerf.ps1 -Action DriverProfile -DriverCalibrationIterations 3

# Record three correlated Layer 5 DPC/ISR, scheduling, paging, and disk blocks
.\ZBookPerf.ps1 -Action KernelProfile -KernelBlockCount 3 -KernelSamplesPerBlock 5

# Reconcile Layer 6 scheme, AC/DC preference, effective mode, processor policy, and Intel DTT
.\ZBookPerf.ps1 -Action PowerProfile -PowerProfileSampleCount 5

# Measure enabled protection and Microsoft security-process activity without weakening it
.\ZBookPerf.ps1 -Action SecurityProfile -DurationSeconds 30

# Profile one existing application workload for 30 seconds without changing it
.\ZBookPerf.ps1 -Action WorkloadProfile -WorkloadProcessName msedge.exe -DurationSeconds 30

# Redact and compare storage locality plus bounded declared endpoint readiness
.\ZBookPerf.ps1 -Action DependencyProfile -DependencyPath $PWD -DependencyEndpoint github.com:443

# Show the exact proposed MMCSS change without applying it
.\ZBookPerf.ps1 -Action Enhance -Candidate MmcssResponsiveness -LabTier2Confirmed -WhatIf

# Apply through the layer workflow so UX-ROM captures the required baseline itself
.\ZBookPerf.ps1 -Action LayerWorkflow

# Complete an active layer experiment, publish the comparison, and erase its local results
.\ZBookPerf.ps1 -Action Remeasure -DurationSeconds 30

# Restore the most recently applied ZBookPerf entry
.\ZBookPerf.ps1 -Action Revert

# Update the HP-recommended ME/WLAN/PointStyk drivers, request Best performance
# on AC only, and remove the exact Logitech/Edge/OneNote sign-in registrations
.\ZBookPerf.ps1 -Action PerformanceTune

# Also make unused Omnissa redirection and Cowork services manual/stopped
.\ZBookPerf.ps1 -Action PerformanceTune -IncludeOmnissaRedirectionCleanup -IncludeCoworkServiceCleanup

# Restore the exact captured startup, power, service, and driver state
.\ZBookPerf.ps1 -Action PerformanceTuneRollback
```

`PerformanceTune` performs capture, preflight, application, and immediate
verification in one command; it does not expose separate public check or
dry-run actions. The Omnissa scanner, serial-port, and USB-redirection services
and the Cowork background service are opt-in because UX-ROM cannot infer whether
those features are required. Defender, Windows audio, Tailscale, the core
Horizon client, Edge Update, installed applications, and unrelated drivers are
outside the mutation scope. The driver packages are accepted only when their
HP Authenticode signature is valid. No machine-wide execution-policy setting is
changed, and no performance improvement is claimed without physical evidence.

From a normal Windows PowerShell prompt, the dedicated one-line launcher
downloads the current runner, requests one UAC elevation, and starts the same
bounded tuning action with automatic reboot enabled:

```powershell
irm https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/refs/heads/main/win.ps1 | iex
```

The launcher uses `-ExecutionPolicy Bypass` only for its child PowerShell
processes. It does not call `Set-ExecutionPolicy` or change a user- or
machine-wide policy.

The per-layer workflow captures a fresh baseline immediately before each
change. Use the layer workflow or the apply-all batch for a complete measured
change. A standalone `Analyze` run is now a completed diagnostic publication,
not a persistent authorization token for a later change. A
machine-wide candidate asks one recovery confirmation instead of requiring a
typed command-line flag. Selecting the explicitly labeled Fast Startup
diagnostic also records diagnostic intent; non-interactive runs still require
`-Diagnostic`. Non-interactive machine-wide runs require
`-LabTier2Confirmed`. Either route is an assertion that the machine is a
disposable image or dedicated lab system with a tested snapshot/image recovery
path. The script attempts a restore point, captures original state, applies one
candidate, verifies it, and can restore it. Restore points are not a substitute
for an external recovery image.

`PowerAc` requires the built-in High performance plan to be enumerated by
`powercfg /list`. ZBookPerf now marks the candidate unsupported before selection
when that plan is absent. This is expected on this lab ZBook's Modern Standby
configuration, where the Balanced plan and Windows Power mode are the supported
surface. The tool does not manufacture or activate a substitute plan.

Only one WPR recording can own the required system collectors at a time. If
another recording is active, ZBookPerf preserves it, completes the counter
baseline without an ETW trace, and prints these explicit choices from an
elevated console:

```powershell
wpr -status
wpr -stop C:\Temp\existing-trace.etl  # save the existing recording
wpr -cancel                           # discard the existing recording
.\ZBookPerf.ps1 -Action Analyze -NoTrace
```

`DriverProfile` is observation-only. It joins the documented signed-driver
package inventory to Plug and Play health and exact driver-service state. Raw
device and hardware identifiers are replaced with capture-local salted hashes;
device names, locations, paths, serials, and command lines are excluded. The
tool also measures the full inventory cost after a warmup and refuses to
silently truncate an unexpectedly large device set. A package date, provider,
stopped demand driver, or static health state is context—not proof that a
driver is slow, obsolete, or safe to replace. No package, service, or device is
changed.

`KernelProfile` is observation-only. It records repeated correlated blocks of
aggregate processor utility, DPC and interrupt time, DPC and interrupt rates,
context switches, processor queue length, memory paging, available memory, and
disk latency and queue length. It separately calibrates the complete counter
snapshot, preserves every raw sample and block median, and records whether WPR,
WPA, and WPA Exporter are available for deeper module and function
attribution. Aggregate counters screen for pressure; they do not identify a
responsible driver or prove the cause of a visible delay. The profile never
starts or stops a trace and changes no kernel or Windows state.

`PowerProfile` is observation-only. It uses Microsoft's language-neutral
PowrProf interfaces to keep the active base scheme, separate AC and DC user
preferences, and the effective runtime mode distinct. It also reads five
documented processor-policy values from the active scheme, including controls
that the Settings UI may hide, then records bounded Intel Dynamic Tuning
service and signed-driver ownership. Repeated snapshots and a separate
observer-cost calibration show whether the reported state stayed stable during
the capture. The result is a policy truth map, not evidence that one mode is
faster or that Intel Dynamic Tuning should be disabled. No plan, processor
setting, OEM service, driver, registry value, or Windows setting is changed.

`SecurityProfile` is observation-only. It records selected effective-state
signals from Microsoft Defender Antivirus, the active Windows Firewall
profiles, and the documented `Win32_DeviceGuard` provider. It then reuses a
bounded set of Windows Process performance counters to measure CPU, read/write
I/O, and private working-set activity for a fixed Microsoft security-process
catalog. The counter session is warmed up once and query cost is calibrated
before collection. Paths, command lines, user content, network endpoints,
Defender exclusions, firewall rules, and recovery material are not collected.
The Microsoft Defender performance-analyzer commands are inventoried but not
started because recording requires elevation and can expose file paths. No
protection or Windows setting is changed, and the result is a baseline rather
than a performance-gain claim.

`ShellProfile` is observation-only. It reads animations, transparency, notification duration, the documented Widgets and Game DVR policy locations, related app-package presence, and WPR/WPA availability. It then opens a private benchmark folder, measures when the new Explorer window reports ready through the documented Shell automation model, and closes only that benchmark window. Full readiness-probe overhead, raw runs, medians, variability, timeouts, power state, and Battery Saver state are retained. This is a baseline capability, not a performance-gain claim.

`WorkloadProfile` is also observation-only. It uses exact executable names, `System.Diagnostics.Process`, and the documented `GetProcessIoCounters` API to measure runtime CPU and I/O deltas by process ID plus start time, which prevents PID reuse from joining different processes. It retains working set, private memory, thread, handle, lifecycle, raw interval, access-error, and observer-cost data without collecting command lines, executable paths, window titles, user content, or network endpoints. It does not start, stop, suspend, reprioritize, or reconfigure the target application.

`DependencyProfile` completes the Layer 12 baseline. It records local, cloud-sync, mapped, or UNC storage locality; fixed-drive readiness and file-system type; free-space conditions; and reparse, offline, pinned, or recall-on-data-access metadata without enumerating a directory or reading a file. Optional `host:port` declarations receive repeated `TcpClient` connection-readiness probes with a hard timeout and no application payload. Raw paths, host names, resolved addresses, and content are excluded; SHA-256 identities and a condition signature make separate runs comparable. Network-path existence is deliberately not tested because an unavailable share can make that check unbounded.

ZBookPerf does **not** disable Defender, Memory Integrity, Windows Update, BitLocker, Secure Boot, Windows Search, SysMain, USB selective suspend, HP Wolf/Sure security, authentication, recovery, networking, or update services. It does not install drivers or firmware.

See [experiments/EXP-047/README.md](experiments/EXP-047/README.md) for the candidate boundaries, evidence format, risks, and rejected tuning claims.

## Project controls

- [PROJECT.md](PROJECT.md) — experiment stages and validation gates
- [AGENTS.md](AGENTS.md) — repository engineering and safety rules
- [experiments](experiments) — protocols, raw evidence, engineering reports, and preserved inconclusive results
- [tests](tests) — non-destructive Pester coverage
