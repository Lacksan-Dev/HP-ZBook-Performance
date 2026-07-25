# EXP-001 Engineering Validation Record

## Control

- Date: 2026-07-25
- Tool version initially validated: `0.1.0-experimental`
- Current tool version: `0.2.0-experimental`
- Device: HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- CPU: 11th Gen Intel Core i5-1145G7
- Memory: 31.7 GB observed
- Windows: Windows 11 Pro, build 26200
- BIOS: T76 01.24.02
- Graphics: Intel Iris Xe, driver 32.0.101.7085
- Power source: AC during apply/rollback validation
- Active plan at initial capture: Balanced
- Performance measurements: quick screening only; nine-workflow measurements remain pending
- Reboot-persistence result: pending

This began as configuration transaction validation. Version 0.2 adds a quick
process/CPU screening benchmark, but no ambient temperature, package
temperature, instrumentation-overhead result, customer application workflow, or
performance gain has been established.

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

### Version 0.2 usability and management fix

- Root cause of the `-AllowManagedDevice` bug: the elevated audit counted the
  generic Microsoft `MDMMaintenenceTask` as active enrollment while the
  non-elevated audit could not see it.
- The corrected gate treats that generic task as informational. Domain/Entra
  join, a published MDM URL, or enrollment-specific EnterpriseMgmt tasks still
  stop Tune by default.
- Elevated one-word `Tune` succeeded on the personal lab PC with no override
  flag. Because the selected state was already compliant, it made zero writes
  and created no backup.
- The user-facing actions are now `Check`, `Benchmark`, `Tune`, `FullTest`,
  `Compare`, `Undo`, and `RestartTest`; old `-Mode` commands remain compatible.
- `Check` now reports `READY TO TUNE: YES/NO` with a plain-language reason and
  tuning state rather than a vague `Supported: False`.
- Native AC-line detection replaced the ambiguous `Win32_Battery.BatteryStatus`
  interpretation. Before/after comparisons stop when the AC-only candidate is
  being evaluated on battery.

### Quick benchmark measurements

All files below remain under
`%ProgramData%\Lacksan\ZBookPerformance\Benchmarks`.

The first ordered seven-run comparison placed balanced `PERFEPP=33` first and
aggressive `PERFEPP=0` second. All 21 observations per configuration succeeded;
the second configuration was slower by 33.5% for PowerShell startup, 21.1% for
Command Prompt startup, and 6.4% for the CPU burst. This was preserved but
rejected as a decision result because order/background bias was uncontrolled.

A counterbalanced A-B-B-A session with 14 valid runs per metric/configuration
still placed value 0 in the middle B blocks. Value 0 was slower by 2.8%, 2.5%,
and 3.7%, respectively. A reversed session then placed value 33 in the middle B
blocks; value 33 was 2.5% slower for PowerShell, 1.7% faster for Command Prompt,
and 10.1% slower for the CPU burst. Every one of the 84 observations in that
session succeeded.

Combining both counterbalanced sessions by actual AC value produced 28 valid
runs per configuration and metric:

| Metric | `PERFEPP=0` median | `PERFEPP=33` median | Value 33 versus 0 |
|---|---:|---:|---:|
| PowerShell startup | 138.731 ms | 138.382 ms | 0.3% faster |
| Command Prompt startup | 22.869 ms | 22.452 ms | 1.8% faster |
| SHA-256 CPU burst | 107.576 ms | 115.752 ms | 7.6% slower |

The crossover is mixed: neither value improved every screening metric.
Process-start differences are small, while value 0 improved this synthetic CPU
burst at the cost of the documented heat/energy bias. The general Tune baseline
therefore retains the measured balanced value 33 rather than claiming that the
most aggressive value improves responsiveness.

Version 0.2 `FullTest` now runs both A-B-B-A and B-A-A-B orderings in one
command, waits for low CPU/disk activity before each block, aggregates 28 raw
runs per configuration/metric, and leaves Tune active.

The completed orchestration validation used three runs in each of eight blocks,
for 12 runs per configuration/metric and 72 successful observations overall.
There were no failed runs. In that short run the selected value 33 was 1.5%
slower for PowerShell startup, 3.9% slower for Command Prompt startup, and 0.7%
slower for the CPU burst. This conflicts with parts of the earlier crossover
and reinforces the unresolved conclusion: no reproducible general-performance
improvement has been demonstrated for either energy-preference value.

### One-time auto-login implementation

- Elevated read-only compilation and LSA-secret detection passed.
- `RestartTest` captures original Winlogon state, validates a masked password,
  stores it with `LsaStorePrivateData`, registers a one-time current-user resume
  task, and schedules restart.
- The resume path verifies a new boot, checks all 17 settings, runs a
  post-restart benchmark, clears the LSA secret, restores captured Winlogon
  values, and removes its task even when verification fails.
- Existing auto-login configuration is never overwritten.
- The state-changing restart path has not yet been executed; reboot persistence
  and cleanup remain pending until the user enters the password in the masked
  prompt.

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

- Setting AC energy-performance preference to 0 may improve sustained synthetic
  CPU work, but the crossover did not show a consistent process-start benefit.
- Any workload benefit may be small or absent because firmware, Intel/HP thermal
  policy, existing low-latency profiles, background activity, or workload
  bottlenecks can dominate.
- The aggressive candidate may increase package temperature, fan activity, and
  AC energy use.

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
