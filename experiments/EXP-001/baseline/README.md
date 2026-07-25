# EXP-001 Observational Baseline Harness

This directory implements the collector authorized by `../experiment-protocol.md`.

## Scope

The harness observes and records system state. It performs no performance tuning and weakens no Windows, HP, security, update, recovery, encryption, or management control.

Formal benchmark evidence requires separately qualified deterministic start and readiness probes. Until that gate passes, `Capture` labels outputs as `screening` and sets `FormalEvidence` to `false`.

## Actions

```powershell
# Verify HP ZBook and Windows 11 support
.\Invoke-Exp001Baseline.ps1 -Action Check

# Produce the exact collection plan with zero system-state changes
.\Invoke-Exp001Baseline.ps1 -Action DryRun -Workflow Idle

# Capture inventory and screening evidence
.\Invoke-Exp001Baseline.ps1 -Action Capture -Workflow OutlookCold

# Verify required files and SHA-256 evidence hashes
.\Invoke-Exp001Baseline.ps1 -Action Verify -RunId <run-id>

# Compare temporary-resource state with the captured original state
.\Invoke-Exp001Baseline.ps1 -Action Rollback -RunId <run-id>
```

`-AllowNonHpLabHost` exists only for disposable CI and development hosts. Production collection without that switch requires Windows 11 on an HP ZBook.

## Output contract

Each run directory contains:

- `plan.json`
- `prerequisites.json`
- `events.jsonl`
- `manifest.json`
- `original-state.json` for capture runs
- `inventory.json` for capture runs
- `sample.json` for capture runs

The manifest records SHA-256 hashes for evidence files. `Verify` fails when a file is missing or its contents change.

## Safety and rollback

The current implementation creates no persistent scheduled tasks, services, firewall rules, registry values, certificates, or startup hooks. Original state is captured for the temporary-resource surfaces authorized by the protocol. `Rollback` compares the post-run state against that record and fails on unexplained differences.

## Validation boundary

Pester validates parsing, prohibited-command absence, support gating, dry-run behavior, screening classification, evidence hashing, tamper detection, and read-only rollback comparison. Physical-device validation, reboot persistence, instrumentation overhead, deterministic customer-workflow readiness, thermal control, and seven-run reproducibility remain Validation Lab requirements.
