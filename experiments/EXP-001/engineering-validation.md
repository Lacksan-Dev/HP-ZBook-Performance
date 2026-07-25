# EXP-001 Engineering Validation Record

## Control

- Date: 2026-07-25
- Tool version: `0.1.0-experimental`
- Device: HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- CPU: 11th Gen Intel Core i5-1145G7
- Memory: 31.7 GB observed
- Windows: Windows 11 Pro, build 26200
- BIOS: T76 01.24.02
- Graphics: Intel Iris Xe, driver 32.0.101.7085
- Power source: AC during apply/rollback validation
- Active plan at initial capture: Balanced
- Performance measurements: none
- Reboot-persistence result: pending

This is configuration transaction validation, not a responsiveness benchmark.
No ambient temperature, package temperature, instrumentation-overhead result,
application workload result, or performance gain was measured.

## Documented facts used by the run

- Windows exposes processor power-policy indices through `powrprof.dll` and
  `powercfg`.
- `Checkpoint-Computer` supports a `MODIFY_SETTINGS` restore point on Windows
  client.
- Microsoft documents the selected processor settings and their Windows 11 x64
  compatibility, while advising that processor policy is normally tuned with
  silicon-vendor guidance.
- System Restore protects monitored system state and registry data; it is not a
  full disk or personal-file backup.

Sources and retrieval dates are in
[experiment-design.md](experiment-design.md).

## Lab observations

### Support and management detection

- Non-elevated inventory matched the exact manufacturer, model, CPU, Windows
  build, and BIOS support lock.
- `dsregcmd /status` reported no domain, Entra, or enterprise join; workplace
  registration was present and no MDM URL was published.
- Elevated Task Scheduler visibility found one enabled Microsoft
  `\Microsoft\Windows\EnterpriseMgmt\MDMMaintenenceTask` invoking
  `MDMAgent.exe`. No enrollment-specific EnterpriseMgmt subfolder was observed.
- The default elevated backup correctly stopped before writing because of this
  signal. The lab owner-authorized `-AllowManagedDevice` override was then used.
  No task, policy, management, or security setting was modified.

### Read-only and dry-run validation

- PowerShell AST parsing passed.
- Built-in self-test passed for 17 unique allow-listed definitions.
- Audit passed the exact hardware/build/BIOS checks.
- Preview reported 1 of 17 settings pending and made no configuration write.
- `Apply -WhatIf` redirected to Preview and reported that no backup or setting
  would be written.
- The full static/read-only test runner passed after the final code change.

### Initial transaction

- The initial elevated apply created backup
  `20260725T095346455Z-be67b918`.
- The manifest contained 12 typed registry states and 5 AC/DC power states.
- All affected registry-key exports succeeded.
- Active power-plan export succeeded.
- Manifest SHA-256 verification succeeded.
- Windows restore-point creation succeeded.
- Sixteen settings were already compliant.
- The only write changed the AC processor energy-performance preference from 33
  to 0. Its DC value remained 50.
- Immediate apply verification passed for all 17 settings.

### Exact rollback

- The first rollback launch was canceled at UAC. It made no change and is
  retained as an incomplete run.
- The second elevated rollback restored all captured typed registry states, all
  original AC/DC power indices, and the original active scheme.
- Post-rollback verification passed.
- A read-only preview after rollback reported exactly 1 of 17 settings pending,
  matching the original pre-apply state.

### Controlled reapply and idempotence

- The final elevated apply created backup
  `20260725T095708448Z-34e3098d`.
- Registry exports, power-plan export, manifest SHA-256 verification, and a
  Windows restore point all succeeded.
- The same single AC preference changed from 33 to 0; DC remained 50.
- Immediate apply verification and a separate Verify run passed 17 of 17.
- A second elevated Apply on the compliant state exited successfully, created
  no backup, and performed no write. Backup count remained 2 before and after.

## Preserved failures and inconclusive events

1. An elevated Backup run stopped at the active-management safety gate before
   creating a backup or changing state. Cause: the scheduled-task signal is
   visible only when elevated.
2. The first standalone Verify displayed 17 compliant rows but exited 1 while
   serializing an empty failure list under strict mode. The logging defect was
   corrected; subsequent Verify and the full test runner pass.
3. The first rollback elevation was canceled by the user. No rollback action
   began. The next authorized rollback completed and verified.
4. Reboot persistence has not been tested.
5. Instrumentation overhead, repeated raw workflow runs, medians, thermal
   behavior, battery impact, and responsiveness benefit have not been measured.

Machine-local JSONL logs and protected backups remain under
`%ProgramData%\Lacksan\ZBookPerformance`. They are intentionally not committed
because they contain machine-local metadata.

## Hypotheses

- Setting AC energy-performance preference to 0 may reduce response latency for
  bursty plugged-in workloads on this device.
- Any benefit may be small or absent because firmware, Intel/HP thermal policy,
  existing low-latency profiles, or workload bottlenecks can dominate.
- The candidate may increase package temperature, fan activity, and AC energy
  use.

These are untested hypotheses, not findings.

## Unresolved questions and disposition

- Does the configuration persist and remain compliant after a controlled
  reboot?
- What is the measurement harness/WPR overhead?
- Do all supported workflow probes meet the validation protocol?
- Are current-state medians reproducible across sessions?
- Does the candidate improve any workflow without unacceptable thermal, energy,
  reliability, security, update, or management tradeoffs?

The issue must remain `stage:research`. The engineering transaction is working,
but the research-to-design evidence rule in
[validation-protocol.md](validation-protocol.md) is not yet satisfied.
