# EXP-001 Experimental Implementation Design

## Control

- Experiment: `EXP-001`
- Status: Experimental
- Document date: 2026-07-25
- Research issue stage: `stage:research`
- Engineering authorization: direct user instruction on 2026-07-25
- Validated machine: HP ZBook Firefly 14 inch G8 Mobile Workstation PC,
  Intel Core i5-1145G7, Windows 11 Pro build 26200, BIOS T76 01.24.02

This design does not claim that EXP-001 has passed the research-to-design gate.
The issue remains in research until the measurement protocol is exercised,
instrumentation overhead is measured, repeated raw runs are retained, and the
decision rule in [validation-protocol.md](validation-protocol.md) is accepted.
The utility is an experimental engineering artifact authorized by the lab owner.

## Goal

Create one standalone Windows PowerShell 5.1 script that safely evaluates and
applies a narrow, reversible, model-specific responsiveness baseline. The tool
borrows the useful "Tweaks" and "Configuration" concept from Chris Titus Tech's
WinUtil without incorporating its application installer, Windows Update, ISO,
or broader debloat functions.

No performance improvement is claimed. The baseline is a candidate
configuration whose effect must be measured.

## Safety boundary

The script applies only allow-listed per-user visual/capture values and
documented, AC-only processor power values. It does not:

- install or remove software;
- disable services or scheduled tasks;
- modify Windows Update, Microsoft Defender, firewall, BitLocker, VBS, UAC,
  telemetry, management, or security policy;
- delete application data, caches, Explorer bags, or packages;
- change BIOS, firmware, driver, sleep-state, network, or OEM settings;
- create or modify Windows installation media; or
- change battery/DC processor values.

Apply is rejected unless manufacturer, model, CPU, OS build, and BIOS match the
single validated lab system. Domain, Entra, MDM, or EnterpriseMgmt detection
also rejects apply by default. Workplace registration without an MDM endpoint
does not, by itself, identify active device management.

## Configuration model

### Per-user responsiveness preferences

The allow-list contains transparency, window/list/taskbar animation, menu delay,
drag contents, keyboard delay, Aero Peek, visual-effects selection, and
per-user game/app capture preferences. Each entry specifies a registry path,
value name, value type, desired value, restart boundary, and provenance.

The script deliberately excludes WinUtil's opaque `UserPreferencesMask` write,
taskbar-content preferences, service changes, package removal, telemetry
controls, update controls, and destructive Explorer discovery resets.

### AC processor policy

The active scheme is retained. Only its AC indices are candidates:

| Setting | Candidate | Compatibility meaning |
|---|---:|---|
| `PERFEPP` | 33 | Retains the measured balanced AC value; value 0 remains a rejected/inconclusive screening candidate. |
| `CPMINCORES` | 100% | Disables core parking for the applicable policy. |
| `PROCTHROTTLEMAX` | 100% | Permits the maximum processor performance state. |
| `PERFBOOSTMODE` | 2 | Aggressive boost for applicable P-state/CPPC behavior. |
| `SYSCOOLPOL` | 1 | Active cooling policy. |

Microsoft documents these interfaces and Windows 11 x64 support, but also notes
that processor power policy is normally tuned by silicon vendors. Initial and
counterbalanced quick screening did not show a consistent responsiveness
benefit from forcing `PERFEPP=0`; the implementation therefore retains the
measured balanced value 33. Firmware, Intel Dynamic Tuning, thermal limits, and
HP policy may cap or override requested behavior. Battery/DC values are
captured and preserved.

## Benchmark and restart design

The customer surface uses simple actions:

- `Check`: friendly support and tuning state;
- `Benchmark`: seven raw runs and a median for each quick screening metric;
- `Tune`: automatic elevation, backup, apply, and verification;
- `FullTest`: A-B-B-A plus B-A-A-B blocks, 28 raw runs per configuration and
  metric, median comparison, and final tuned state;
- `Undo`: exact latest-backup rollback; and
- `RestartTest`: one-time automatic sign-in, persistence verification,
  post-restart benchmark, and automatic credential/task cleanup.

The quick metrics measure PowerShell process startup, Command Prompt process
startup, and a fixed SHA-256 CPU burst. Low CPU/disk readiness samples,
warm-ups, every raw run, failures, medians, environment, and comparison are
saved. They screen implementation candidates but do not substitute for the nine
customer-facing workflows.

For the personally owned lab PC, `RestartTest` stores the supplied password as
a Windows LSA private-data secret, never as a plaintext Winlogon
`DefaultPassword`. It captures original Winlogon values and refuses to overwrite
existing auto-login configuration. A one-time highest-privilege task for the
current interactive user verifies after reboot and then clears the secret,
restores original state, and unregisters itself. A masked password entry is
unavoidable because Windows cannot derive an account password from Windows
Hello.

## Transaction and rollback design

Before the first write, the script:

1. captures the actual existence, type, and data of every registry value;
2. captures the active power scheme and actual AC/DC index for every power
   setting;
3. exports each affected registry key;
4. exports the active power plan;
5. writes a versioned JSON manifest and SHA-256 integrity file;
6. attempts a `MODIFY_SETTINGS` System Restore point; and
7. stops without applying if restore-point creation fails, unless the operator
   explicitly supplies `-AllowNoRestorePoint`.

Rollback verifies the manifest hash, confirms the same model and Windows user
SID, restores existing values with their original types, removes values that
were originally absent, restores both AC and DC power indices and the original
active scheme, and verifies the result. Backups and failed/inconclusive logs are
never automatically deleted.

This is strong transactional rollback for the settings in the allow-list, not a
literal 100% machine-image guarantee. System Restore is not a full personal-file
backup, restore-point creation is rate-limited by Windows, storage/media
failure remains possible, and unrelated changes made after capture cannot be
indiscriminately reverted by this script.

## Required engineering behaviors

| Requirement | Implementation |
|---|---|
| Support detection | Exact device/build/BIOS check and active-management gate. |
| Original-state capture | Typed registry state, active scheme, AC/DC indices, exports. |
| Dry run | `Preview` and `-WhatIf` perform no backup or setting writes. |
| Apply | Allow-listed, idempotent registry and power writers. |
| Verify | Typed value comparison and power index reread. |
| Structured logging | Per-run UTF-8 JSON Lines with UTC, run ID, status, and state transitions. |
| Idempotence | A compliant system produces no backup and no writes. |
| Rollback | Hash-verified exact-state restore with post-restore verification. |
| Reboot persistence | Immediate verification implemented; reboot verification remains a lab gate. |

## Sources

All sources were retrieved 2026-07-25.

- [ChrisTitusTech/winutil repository](https://github.com/ChrisTitusTech/winutil)
  and inspected commit
  [`50be7390e586f664df76d7fed41fc3c39252288c`](https://github.com/ChrisTitusTech/winutil/tree/50be7390e586f664df76d7fed41fc3c39252288c)
- [WinUtil MIT license](https://github.com/ChrisTitusTech/winutil/blob/50be7390e586f664df76d7fed41fc3c39252288c/LICENSE)
- [Microsoft `powercfg` command-line options](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options)
- [Microsoft processor power management overview](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/configure-processor-power-management-options)
- [Microsoft `PerfEnergyPreference`](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-perfenergypreference)
- [Microsoft `CPMinCores`](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-core-parking-cpmincores)
- [Microsoft `MaxPerformance`](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-maxperformance)
- [Microsoft `PERFBOOSTMODE`](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-perfboostmode)
- [Microsoft `PowerReadACValueIndex`](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreadacvalueindex)
- [Microsoft `Checkpoint-Computer`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/checkpoint-computer?view=powershell-5.1)
- [Microsoft System Restore behavior](https://learn.microsoft.com/en-us/windows/win32/sr/restoring-the-system)
- [Microsoft Sysinternals Autologon](https://learn.microsoft.com/en-us/sysinternals/downloads/autologon)
- [Microsoft protecting the automatic-logon password](https://learn.microsoft.com/en-us/windows/win32/secauthn/protecting-the-automatic-logon-password)
- [Microsoft automatic logon configuration and risks](https://learn.microsoft.com/en-us/troubleshoot/windows-server/user-profiles-and-logon/turn-on-automatic-logon)
- [HP ZBook Firefly 14 G8 support page](https://support.hp.com/us-en/product/product-specs/hp-zbook-firefly-14-inch-g8-mobile-workstation-pc/model/2100000209)
