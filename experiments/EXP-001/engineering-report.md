# EXP-001 PowerShell Engineering Report

## Implemented scope

Engineering implemented the protocol-authorized observational baseline collector only.

Branch: `exp-001-observational-baseline`

Pull request: `#4`

## Delivered controls

- HP ZBook and Windows 11 support detection
- explicit disposable-lab override for CI
- current-state inventory capture
- original temporary-resource state capture
- dry-run plan with zero formal benchmark execution
- screening capture with explicit evidence classification
- structured JSONL logging
- JSON run manifests
- SHA-256 evidence hashes
- evidence verification and tamper detection
- idempotent read-only execution
- rollback comparison for authorized temporary-resource surfaces
- failure exit codes and structured error output
- Windows Pester CI

## Security and management behavior

The collector does not disable, weaken, or reconfigure Defender, firewall, Windows Update, BitLocker, Secure Boot, recovery, HP controls, domain state, Entra state, MDM, services, scheduled tasks, power settings, application settings, or registry policy.

## Automated validation

GitHub Actions workflow `EXP-001 Baseline Pester`, run 6, passed on Windows Server 2025.

The suite verifies:

- PowerShell parsing
- absence of prohibited tuning commands
- supported actions
- dry-run behavior
- production support rejection on non-ZBook hardware
- screening evidence classification
- manifest and SHA-256 verification
- rollback comparison
- tamper detection

## Evidence boundary

The collector deliberately classifies current workflow captures as `screening` with `FormalEvidence=false`. Deterministic workflow readiness probes, instrumentation-overhead qualification, physical HP ZBook execution, thermal controls, reboot behavior, and seven-run reproducibility remain Validation Lab work.

## Engineering decision

Implementation and automated tests are complete. Pull request #4 is ready for independent Validation Lab review. No merge was performed.
