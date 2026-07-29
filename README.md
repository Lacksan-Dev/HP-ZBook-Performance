# HP ZBook Performance Lab

This repository develops measurable, reversible Windows responsiveness experiments for HP ZBook workstations. Experimental code is not a promise of a speed-up: capture a baseline, change one variable, repeat the same workload, and keep a change only when repeated evidence supports it.

## ZBookPerf console

`ZBookPerf.ps1` is the EXP-047 trace-first analyzer and reversible experiment harness. It runs on Windows PowerShell 5.1, records counters and optional Windows Performance Recorder (WPR) traces, shows compact console charts, and journals every applied candidate in `C:\ProgramData\ZBookPerf\changes.json`.

Open an **administrator Windows PowerShell 5.1** console, move to a normal working folder instead of `C:\Windows\System32`, download the current build, and run it:

```powershell
Set-Location $env:TEMP
Invoke-WebRequest https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main/ZBookPerf.ps1 -OutFile .\ZBookPerf.ps1
Set-ExecutionPolicy -Scope Process Bypass
.\ZBookPerf.ps1
```

`notepad .\ZBookPerf.ps1` is optional source inspection, not an execution step.
Double-clicking a `.ps1` file may also open it for editing; run
`.\ZBookPerf.ps1` from Windows PowerShell to execute it.

The saved-file route above is recommended because it lets you inspect the exact
script you are about to run. If you already trust the repository, this
convenience one-liner opens the same menu without saving a copy:

```powershell
irm https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main/ZBookPerf.ps1 | iex
```

ZBookPerf accepts `-Candidate` as before. Internally that parameter uses a
collision-resistant name so the convenience command also works in Windows
PowerShell 5.1.

The menu prints a product version so an already-running, older copy is easy to
spot. Downloading a new file does not replace code that is already loaded in an
open menu; quit that menu and start the downloaded file again. Menu choices 7
and 8 are read-only diagnostics. They add evidence to the product but do not
appear under `Enhance`, which is reserved for reversible Windows state changes.

Useful non-interactive examples:

```powershell
# Counter-only 30-second baseline; does not change Windows settings
.\ZBookPerf.ps1 -Action Analyze -DurationSeconds 30 -NoTrace

# Inventory Layer 10 controls and capture five Explorer readiness runs
.\ZBookPerf.ps1 -Action ShellProfile -ShellRunCount 5

# Profile one existing application workload for 30 seconds without changing it
.\ZBookPerf.ps1 -Action WorkloadProfile -WorkloadProcessName msedge.exe -DurationSeconds 30

# Show the exact proposed MMCSS change without applying it
.\ZBookPerf.ps1 -Action Enhance -Candidate MmcssResponsiveness -LabTier2Confirmed -WhatIf

# Apply one Tier 1 visual-effects experiment
.\ZBookPerf.ps1 -Action Enhance -Candidate VisualEffects

# Repeat the measurement and show a side-by-side comparison
.\ZBookPerf.ps1 -Action Remeasure -DurationSeconds 30

# Restore the most recently applied ZBookPerf entry
.\ZBookPerf.ps1 -Action Revert
```

Run `Analyze` before applying a candidate; ZBookPerf refuses an application without preserved baseline evidence. In the interactive menu, a machine-wide candidate asks one recovery confirmation instead of requiring a typed command-line flag. Selecting the explicitly labeled Fast Startup diagnostic option also records diagnostic intent; non-interactive runs still require `-Diagnostic`. Non-interactive machine-wide runs require `-LabTier2Confirmed`. Either route is an assertion that the machine is a disposable image or dedicated lab system with a tested snapshot/image recovery path. The script attempts a restore point, captures original state, applies one candidate, verifies it, and can restore it. Restore points are not a substitute for an external recovery image. Candidates marked as reboot-dependent remain experimental until the operator reboots, runs `Status` plus `Remeasure`, preserves the evidence, and verifies the setting manually.

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

`ShellProfile` is observation-only. It reads animations, transparency, notification duration, the documented Widgets and Game DVR policy locations, related app-package presence, and WPR/WPA availability. It then opens a private benchmark folder, measures when the new Explorer window reports ready through the documented Shell automation model, and closes only that benchmark window. Full readiness-probe overhead, raw runs, medians, variability, timeouts, power state, and Battery Saver state are retained. This is a baseline capability, not a performance-gain claim.

`WorkloadProfile` is also observation-only. It uses exact executable names, `System.Diagnostics.Process`, and the documented `GetProcessIoCounters` API to measure runtime CPU and I/O deltas by process ID plus start time, which prevents PID reuse from joining different processes. It retains working set, private memory, thread, handle, lifecycle, raw interval, access-error, and observer-cost data without collecting command lines, executable paths, window titles, user content, or network endpoints. It does not start, stop, suspend, reprioritize, or reconfigure the target application.

ZBookPerf does **not** disable Defender, Memory Integrity, Windows Update, BitLocker, Secure Boot, Windows Search, SysMain, USB selective suspend, HP Wolf/Sure security, authentication, recovery, networking, or update services. It does not install drivers or firmware.

See [experiments/EXP-047/README.md](experiments/EXP-047/README.md) for the candidate boundaries, evidence format, risks, and rejected tuning claims.

## Project controls

- [PROJECT.md](PROJECT.md) — experiment stages and validation gates
- [AGENTS.md](AGENTS.md) — repository engineering and safety rules
- [experiments](experiments) — protocols, raw evidence, engineering reports, and preserved inconclusive results
- [tests](tests) — non-destructive Pester coverage
