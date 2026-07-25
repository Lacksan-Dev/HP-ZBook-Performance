# Lacksan ZBook Performance

Experimental standalone Windows PowerShell 5.1 utility for the validated HP
ZBook Firefly 14 G8 lab computer. It exposes only Audit, Preview, Apply, Verify,
Rollback, backup listing, and configuration viewing.

## Current support lock

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Intel Core i5-1145G7
- Windows 11 Pro build 26200
- BIOS T76 01.24.02

Audit and Preview are read-only. Apply refuses other hardware/build/BIOS
combinations and actively managed devices by default.

## Local use

Open Windows PowerShell 5.1 in the repository:

```powershell
# Read-only inventory
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 -Mode Audit

# Dry run
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 -Mode Preview

# Apply from an elevated Windows PowerShell session
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 `
  -Mode Apply `
  -AcceptExperimentalRisk `
  -AllowManagedDevice

# Verify
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 -Mode Verify

# Roll back the latest backup from an elevated session
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 -Mode Rollback
```

Run without parameters for the interactive menu. `-WhatIf` on Backup, Apply, or
Rollback is redirected to the read-only preview.

The current lab computer has a workplace registration and an elevated-only
Microsoft `MDMMaintenenceTask`, although it is not domain/Entra joined and
publishes no MDM URL. The authoritative elevated gate therefore requires
`-AllowManagedDevice`. This is a recorded lab-owner override, not permission to
alter the task or any policy. Other operators must obtain their own
administrator approval; the tool never changes management state.

Backups are stored in:

```text
%ProgramData%\Lacksan\ZBookPerformance\Backups
```

Each contains a typed state manifest, SHA-256 integrity value, registry exports,
active power-plan export, and restore-point result. Logs are JSON Lines under
the corresponding `Logs` folder (or the user's LocalAppData when the
ProgramData log folder cannot be written).

## One-line launch

After the repository version is published and reviewed, the interactive
utility can be launched in the WinUtil-style form:

```powershell
irm https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main/experiments/EXP-001/tool/Lacksan-ZBook-Performance.ps1 | iex
```

The current local file should be used until publishing is confirmed. Remote
execution should be pinned to a reviewed commit for managed/customer use; do
not assume a moving branch is unchanged.

## Important limits

- This is experimental and has no measured performance claim.
- The AC policy can increase temperature, fan noise, and power use.
- Battery/DC settings are not changed.
- System Restore is not a full disk or personal-file backup, can be disabled,
  and Windows rate-limits restore-point creation.
- The script's rollback covers every allow-listed setting and verifies the
  restored values, but no script can promise literal 100% recovery from disk
  failure, firmware failure, or unrelated later changes.
- Stable release requires explicit human approval.

See [the implementation design](../experiment-design.md) and
[validation protocol](../validation-protocol.md).
