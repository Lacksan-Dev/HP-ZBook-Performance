# EXP-012 Engineering Report

## Candidate
Enable Microsoft Edge Sleeping Tabs through the recommended policy value `HKLM\SOFTWARE\Policies\Microsoft\Edge\Recommended\SleepingTabsEnabled`.

## Implementation
`Invoke-Exp012EdgeSleepingTabs.ps1` provides:

- HP Windows 11 and Edge 88+ support detection
- mandatory enterprise-policy refusal
- exact current-state capture including key existence, value existence, registry type, and data
- dry-run behavior through `ShouldProcess`
- idempotent application of `REG_DWORD 1`
- post-application verification
- JSONL structured logging
- terminating failure handling
- reboot verification mode
- exact original-state rollback and rollback verification

## Safety review
The implementation changes one recommended Edge policy value. It does not change Startup folders, profiles, passwords, cookies, favorites, extensions, SmartScreen, Edge Update, mandatory management policy, Windows security, recovery, services, packages, devices, drivers, Omnissa, Windows App, Remote Desktop, or Tailscale.

## Automated tests
Pester contract tests verify candidate scope, support detection, mandatory-policy refusal, modification-contract coverage, exact rollback fields, and protected-surface exclusions.

## Evidence status
Repository implementation is complete. Physical HP ZBook application, effective-policy confirmation, reboot persistence, rollback execution, repeated demand-launch and tab-wake trials, background CPU and memory measurements, instrumentation-overhead qualification, and median results remain `needs-evidence`.

No performance result is claimed.
