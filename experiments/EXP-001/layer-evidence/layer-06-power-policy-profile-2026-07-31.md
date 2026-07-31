# EXP-001 layer 6 - power-policy truth map

- Cycle timestamp: 2026-07-31T13:41:50Z
- Layer: 6 - power management and performance policy
- Outcome: implemented
- Evidence state: observation-only baseline; no power plan, processor setting,
  OEM service, driver, registry value, policy, reboot state, or Windows setting
  changed
- Implementation commit: `10f8f7a1c0fa68485ce1ec10c77a5cb239430437`
- Private successful raw evidence identifier:
  `20260731-135717-440-861cd542-power-policy-profile.json`

## Customer-visible interval and engineering responsibility

This layer owns the path from a user's performance-versus-efficiency request
to the effective runtime policy presented to processor and platform power
management. The customer-visible interval begins when a workload needs more
performance and ends when the operating system, silicon, cooling system, and
OEM platform policy have coordinated a response that the workload can use.

Windows owns the base power scheme, separate AC and DC user preferences,
effective power-mode notification contract, processor power-management policy,
and power-source state. Intel owns the Dynamic Tuning driver and service
mechanism. HP chooses model-specific thermal, acoustic, firmware, and Dynamic
Tuning policy for the system. Applications own the workload and its timing
requirements. UX-ROM owns bounded observation, separation of those contracts,
structured evidence, observer qualification, and future controlled comparison.

Inputs are the active power scheme, user AC and DC votes, effective runtime
mode, five documented processor-policy settings, power source, Battery Saver,
exact platform metadata, and bounded Intel Dynamic Tuning ownership metadata.
Outputs are repeated raw snapshots, consistency checks, observer-duration
distributions, platform-ownership context, and a baseline-only decision.

The failure boundary is explicit. UX-ROM fails before writing a completed
profile if a required PowrProf call, immediate effective-mode callback, or
power-source query is unavailable. Optional ownership queries retain only an
exception type. Every effective-mode registration is unregistered. The profile
does not expose hidden controls in the UI, activate a scheme, change processor
policy, stop an OEM service, or install or remove a driver.

Recovery is source-code reversion because the capability changes no observed
state. State rollback and reboot-persistence testing do not apply.

## Verified primary sources

Sources retrieved 2026-07-31:

- Microsoft Learn, [PowerGetActiveScheme](https://learn.microsoft.com/en-us/windows/win32/api/powersetting/nf-powersetting-powergetactivescheme):
  documents the language-neutral API used to obtain the active scheme GUID.
- Microsoft Learn, [PowerGetUserConfiguredACPowerMode](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powergetuserconfiguredacpowermode)
  and [PowerGetUserConfiguredDCPowerMode](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powergetuserconfigureddcpowermode):
  document separate Windows 11 user preferences for AC and DC operation.
- Microsoft Learn, [PowerRegisterForEffectivePowerModeNotifications](https://learn.microsoft.com/en-us/windows/win32/api/powersetting/nf-powersetting-powerregisterforeffectivepowermodenotifications)
  and [EFFECTIVE_POWER_MODE](https://learn.microsoft.com/en-us/windows/win32/api/powersetting/ne-powersetting-effective_power_mode):
  document the immediate callback used to read the current effective runtime
  mode and the V1 mode enumeration.
- Microsoft Learn, [PowerReadACValue](https://learn.microsoft.com/en-us/windows/win32/api/powersetting/nf-powersetting-powerreadacvalue):
  documents the language-neutral power-policy value API. UX-ROM uses the
  corresponding documented DC function for the same five setting GUIDs.
- Microsoft Learn, [GetSystemPowerStatus](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getsystempowerstatus):
  documents the AC-line, battery, and Battery Saver state used beside every
  snapshot.
- Microsoft Learn, [processor power-management options](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/configure-processor-power-management-options),
  [minimum performance](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-minperformance),
  [maximum performance](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-maxperformance),
  [boost mode](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-perfboostmode),
  [energy-performance preference](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-perfenergypreference),
  and [performance increase policy](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-perfincreasepolicy):
  document the five processor-policy controls and warn that platform and
  processor vendors define important support and tuning boundaries.
- Microsoft Learn, [powercfg command-line options](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options):
  documents base schemes, queries, and overlay limitations. It was used for
  cross-checking only; the profiler does not invoke a mutating powercfg command.
- HP Support, [HP Power Manager features and settings](https://support.hp.com/us-en/document/ish_5180936-5180983-16):
  documents that HP System Control can affect Windows power-mode behavior on
  supported models. The page does not establish that every described feature
  or setting applies to this G8, so UX-ROM makes no model-wide HP mode claim.
- Intel Support, [What Is Intel Dynamic Tuning Technology?](https://www.intel.com/content/www/us/en/support/articles/000102775/processors.html)
  and [Intel Dynamic Tuning Technology troubleshooting](https://www.intel.com/content/www/us/en/support/articles/000090464/graphics.html):
  document the adaptive OEM-defined performance, power, and thermal layer and
  advise against disabling or removing it.
- Microsoft Learn, [Stopwatch](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.stopwatch?view=netframework-4.8.1):
  documents the monotonic timer used for query-duration qualification.

No community registry value, undocumented Windows contract, proprietary binary
modification, service stop, driver change, or firmware operation is used.

## Layer design map

| Concern | Contract and owner |
|---|---|
| User input | Windows stores distinct AC and DC performance-versus-efficiency preferences. |
| Base policy | Windows active scheme contains AC/DC processor-policy values. |
| Runtime output | Windows reports the effective mode through the documented notification callback. |
| Silicon response | Processor hardware and Windows PPM translate policy into performance-state requests. |
| Platform arbitration | Intel Dynamic Tuning and HP model policy may coordinate power, thermal, and acoustic limits. |
| Timing path | Workload demand -> Windows policy -> platform/silicon arbitration -> usable frequency and latency response. |
| Failure behavior | Unsupported API, callback timeout, query failure, power-source transition, or platform override can invalidate an interpretation. |
| Recovery | No state is changed; unregister callbacks and revert source code if the observer is removed. |
| Security boundary | Read local system policy and signed-driver metadata only; do not change security, management, drivers, firmware, or services. |

## Candidate scoring and selection

Scores use a 0-5 scale for verified evidence, expected customer-interval
relevance, reversibility, exact-system support, measurability, and engineering
leverage. Risk is 1 for lowest risk and 5 for highest risk.

| Candidate | Evidence | Relevance | Reversible | Support | Measurable | Leverage | Risk | Decision |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| PowrProf power-policy truth map with DTT ownership | 5 | 5 | 5 | 5 | 5 | 5 | 1 | Selected |
| Controlled Windows user-mode A/B | 5 | 4 | 5 | 5 | 4 | 4 | 2 | Deferred; AC already requested Best Performance and no workflow baseline is registered |
| Force the legacy High performance scheme | 5 | 3 | 4 | 0 | 3 | 2 | 3 | Rejected; the scheme is unavailable on this Modern Standby configuration |
| Force energy preference or response policy values | 5 | 4 | 4 | 2 | 4 | 3 | 4 | Deferred; requires vendor boundary, isolated Tier 2 target, and workflow evidence |
| Disable Intel Dynamic Tuning | 5 | 3 | 2 | 0 | 3 | 1 | 5 | Rejected; Intel advises against disabling or removing it |
| Patch or replace the Windows/OEM governor | 0 | 4 | 0 | 0 | 2 | 1 | 5 | Rejected; closed and unsupported contract |

The selected observer closes the specific evidence gap left by the previous
Layer 6 run: it records the effective mode and observer cost instead of
inferring runtime behavior from a base scheme or user preference.

## Pre-registered experiment design

Hypothesis: the active scheme alone is an incomplete description of the power
path. Repeated direct API snapshots, hidden-but-documented processor-setting
reads, and Intel Dynamic Tuning ownership can distinguish user intent,
effective runtime policy, and OEM platform ownership well enough to make a
future workload A/B experiment valid.

Controlled variable: observation implementation only. No workload, power mode,
plan, processor setting, driver, service, registry value, policy, or firmware
state changed.

Benchmark:

1. prove that active scheme, AC vote, DC vote, effective-mode callback, and
   system power status are supported;
2. warm up the full mode-snapshot path once;
3. calibrate the full mode snapshot five times;
4. collect five raw snapshots 500 ms apart with a 1,000 ms callback timeout;
5. read AC and DC values for five documented processor-policy settings;
6. inventory exact Intel Dynamic Tuning service and grouped signed-driver roles
   with bounded local CIM queries; and
7. preserve exact environment and benchmark conditions.

Engineering decision rule:

1. the PowerShell parser reports zero errors;
2. focused and full relevant non-destructive test suites pass;
3. active scheme, AC vote, DC vote, effective mode, and power source return
   successfully;
4. exactly five final snapshots are retained;
5. all five processor settings return both AC and DC values;
6. raw snapshot and calibration durations are retained without subtraction;
7. ownership queries are bounded and collect no device identifier or path;
8. no Windows state changes; and
9. the result makes no performance-gain claim.

Stop conditions were any missing required API, callback timeout, source-state
change during the series, unsupported processor value, mutation, or failed
test. Rollback is source-code reversion. Runtime rollback and reboot testing do
not apply.

## PowerShell engineering result

`ZBookPerf.ps1` now exposes `-Action PowerProfile`, `-PowerProfile`, bounded
sample, interval, callback-timeout, and calibration parameters, Layer 6
workflow routing, and full-diagnostic integration.

The implementation:

1. calls documented PowrProf functions through a small in-process C# interop
   boundary;
2. always unregisters the effective-mode callback;
3. keeps active scheme, AC vote, DC vote, and effective mode separate;
4. reads AC and DC values directly for five processor settings, including
   settings hidden from ordinary powercfg output on this machine;
5. retains every raw snapshot and its complete query duration;
6. calibrates the complete snapshot observer after one warmup;
7. records bounded Intel Dynamic Tuning service and grouped signed-driver
   ownership without device identifiers or paths;
8. records model, Windows build, BIOS, processor, Edge version, power source,
   Battery Saver, available thermal readings, and aggregate physical-network
   status;
9. writes unique structured evidence and a bounded event summary; and
10. explicitly labels the result `BaselineOnlyNoPerformanceClaim`.

Automated tests cover public routing, layer routing, documented GUID and enum
mapping, all ten AC/DC processor-value reads, repeated-summary behavior,
structured evidence, full-diagnostic integration, and mutation exclusions.

## Lab measurements

Target and controlled conditions:

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Windows 11 Pro build 26200
- BIOS T76 01.24.02
- AC online; Battery Saver off
- passive foreground capture; no workload launched
- five final snapshots at 500 ms spacing
- five observer-calibration iterations after one warmup
- effective-mode callback timeout: 1,000 ms
- no UAC elevation, reboot, power-state change, or Windows mutation

Observed state:

- Active base scheme: `381b4222-f694-41f0-9685-ff5bb260df2e` (Balanced).
- User AC preference: Best Performance.
- User DC preference: Best Efficiency.
- Effective runtime mode: Max Performance.
- All five snapshots reported the same scheme, preferences, effective mode,
  AC source, and Battery Saver state.
- Minimum performance: AC 5%, DC 5%.
- Maximum performance: AC 100%, DC 100%.
- Boost mode: AC 2, DC 2.
- Energy-performance preference: AC 33, DC 50.
- Performance increase policy: AC 0, DC 0.
- Intel Dynamic Tuning service: Running, automatic start.
- Intel Dynamic Tuning signed-driver role groups: 3.
- Full snapshot calibration median: 1.2007 ms.
- Full snapshot calibration p95: 1.6947 ms.
- Final raw snapshot median: 2.0440 ms.
- Final raw snapshot p95: 2.8582 ms.
- Bounded Intel Dynamic Tuning ownership query: 3208.8567 ms.
- Full relevant Pester 5.7.1 suite: 122 passed, 0 failed, 0 skipped.

The base scheme, user preference, and effective mode are not contradictory:
they are separate Windows contracts. The measurements do not prove how quickly
the processor responded, how much thermal headroom existed, or that Max
Performance improved a customer workflow.

## Documented facts, hypothesis, and unknowns

Documented facts:

- Windows 11 exposes separate user-configured AC and DC mode APIs.
- Windows exposes a separate effective runtime mode through a documented
  notification callback.
- the five processor settings are documented power-policy surfaces;
- Intel Dynamic Tuning is an OEM-defined adaptive platform layer; and
- Intel advises against disabling or removing Dynamic Tuning.

Lab measurements are the exact values and timing distributions above.

Hypothesis: a future single-variable application-readiness A/B can use this
truth map to prove that the requested and effective power states held during
each run instead of assuming that from a plan name.

Unknowns:

- whether AC Best Performance reduces any defined customer-visible interval on
  this system;
- whether effective Max Performance persisted under a sustained workload;
- whether Intel Dynamic Tuning imposed or avoided a thermal limit during that
  workload;
- whether HP exposes a supported model-specific power control for this exact G8
  software image; and
- whether any safe policy change can beat the current configuration without a
  thermal, battery, acoustic, or stability regression.

## Decision and next layer

Accept the power-policy truth map as an Experimental observation capability.
All engineering decision gates passed. Performance decision: baseline only; no
optimization claim, validated-result email, or immediate website post.

This is the third completed layer since the most recent four-layer digest, so
the next digest is not due yet.

Next cycle: Layer 7 - security and isolation overhead without reducing
protection. Preserve Defender, firewall, BitLocker, Secure Boot, Credential
Guard, VBS, Memory Integrity, code integrity, updates, recovery, and management
while building one measured diagnostic capability.
