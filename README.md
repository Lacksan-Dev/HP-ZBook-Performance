# HP ZBook Performance Lab

This repository develops measurable, reversible Windows responsiveness experiments for HP ZBook workstations. Experimental code is not a promise of a speed-up: capture a baseline, change one variable, repeat the same workload, and keep a change only when repeated evidence supports it.

## ZBookPerf console

`ZBookPerf.ps1` is the EXP-047 trace-first analyzer and reversible experiment harness. It runs on Windows PowerShell 5.1, records counters and optional Windows Performance Recorder (WPR) traces, shows compact console charts, and journals every applied candidate in `C:\ProgramData\ZBookPerf\changes.json`.

Open an **administrator Windows PowerShell 5.1** console, inspect the script, and run it:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main/ZBookPerf.ps1 -OutFile .\ZBookPerf.ps1
notepad .\ZBookPerf.ps1
Set-ExecutionPolicy -Scope Process Bypass
.\ZBookPerf.ps1
```

Convenience one-liner (only after you trust the repository and understand that this executes downloaded code):

```powershell
irm https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main/ZBookPerf.ps1 | iex
```

Useful non-interactive examples:

```powershell
# Counter-only 30-second baseline; does not change Windows settings
.\ZBookPerf.ps1 -Action Analyze -DurationSeconds 30 -NoTrace

# Show the exact proposed MMCSS change without applying it
.\ZBookPerf.ps1 -Action Enhance -Candidate MmcssResponsiveness -LabTier2Confirmed -WhatIf

# Apply one Tier 1 visual-effects experiment
.\ZBookPerf.ps1 -Action Enhance -Candidate VisualEffects

# Repeat the measurement and show a side-by-side comparison
.\ZBookPerf.ps1 -Action Remeasure -DurationSeconds 30

# Restore the most recently applied ZBookPerf entry
.\ZBookPerf.ps1 -Action Revert
```

Run `Analyze` before applying a candidate; ZBookPerf refuses an application without preserved baseline evidence. Machine-wide candidates require elevation and `-LabTier2Confirmed`. That switch is an assertion that the machine is a disposable image or dedicated lab system with a tested snapshot/image recovery path. The script attempts a restore point, captures original state, applies one candidate, verifies it, and can restore it. Restore points are not a substitute for an external recovery image. Candidates marked as reboot-dependent remain experimental until the operator reboots, runs `Status` plus `Remeasure`, preserves the evidence, and verifies the setting manually.

ZBookPerf does **not** disable Defender, Memory Integrity, Windows Update, BitLocker, Secure Boot, Windows Search, SysMain, USB selective suspend, HP Wolf/Sure security, authentication, recovery, networking, or update services. It does not install drivers or firmware.

See [experiments/EXP-047/README.md](experiments/EXP-047/README.md) for the candidate boundaries, evidence format, risks, and rejected tuning claims.

## Project controls

- [PROJECT.md](PROJECT.md) — experiment stages and validation gates
- [AGENTS.md](AGENTS.md) — repository engineering and safety rules
- [experiments](experiments) — protocols, raw evidence, engineering reports, and preserved inconclusive results
- [tests](tests) — non-destructive Pester coverage
