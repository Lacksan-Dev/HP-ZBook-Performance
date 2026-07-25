# EXP-001 Validation Protocol

## Status

- Version: draft 0.1
- Date: 2026-07-25
- Measurements: none recorded
- Decision-rule acceptance: pending lab-owner acceptance
- Issue disposition: retain `stage:research`

This document operationalizes all nine workflows. It defines what must be
validated; it does not report runs that have not happened.

## Common controls

Every raw run must record:

- tool/configuration state: current-state or candidate baseline;
- device model, CPU, memory, storage, graphics and driver versions;
- Windows edition, build, update state, BIOS, AC/DC state, active scheme, and
  Windows power mode;
- application variant/version/profile, extensions/add-ins, and test data;
- boot/session identifier, UTC/local timestamps, run order, operator, and
  instrumentation profile;
- ambient temperature, pre-run CPU package temperature if available from an
  already installed trusted sensor, battery percentage, and thermal/fan state;
- Wi-Fi adapter/driver, SSID class without credentials, link rate, and test
  endpoint;
- OneDrive/Teams/Outlook/Edge foreground and background state; and
- success, failure, invalidation, or inconclusive status with the reason.

Use AC power, the same dock/display/network topology, the same active power
scheme, display brightness, user account, application data, and room/location.
Pause user input, updates, installs, scans, indexing changes, and sync changes
unless that activity is the controlled condition. Security, management, update,
and OEM services remain enabled.

## Workflow definitions

| # | Workflow | Start event | Readiness/end event | Reset and controls |
|---:|---|---|---|---|
| 1 | Sign-in to usable desktop | Timestamp when Windows accepts the credential and begins the interactive logon, correlated with Winlogon/ETW. | Explorer desktop is present and a scripted Start-menu open/close plus a local test-window activation both succeed within two consecutive probes. Report the last satisfied timestamp. | Fresh reboot for every measured run; same account and startup set; wait five minutes powered off between thermal-sensitive sequences if pre-run temperature is outside the accepted band. Do not use automatic sign-in. |
| 2 | Outlook cold launch | Harness timestamp immediately before launching the recorded Outlook executable/URI. | Main window is visible, responsive, the agreed folder is selected, and the first known message-list item is exposed to UI Automation for two consecutive probes. | Outlook and child processes absent; first Outlook launch after reboot; fixed profile, cached/online mode, mailbox folder, add-ins, network, and sync state. If Outlook is not installed, retain the run as unsupported/inconclusive. |
| 3 | Outlook warm launch | Harness timestamp immediately before the second launch in the same session. | Same readiness probe as cold launch. | Complete one unmeasured priming launch, close Outlook normally, confirm its processes exit, wait 30 seconds, retain OS file cache, and do not reboot. Same profile/data/add-ins/network. |
| 4 | Outlook search readiness | Timestamp when the harness submits the fixed search string in the agreed folder. | First expected non-placeholder result is actionable through UI Automation and the result set remains unchanged for one second. | Fixed indexed item/query/folder; confirm item exists before the session; restore the folder and clear the search UI between runs; record Windows Search/Outlook indexing state. |
| 5 | Edge cold launch | Timestamp immediately before starting `msedge.exe` with the fixed profile and local test URL. | Browser frame is responsive and the local page's fixed DOM readiness marker is present. | First Edge launch after reboot; all Edge processes absent; same profile, extensions, startup boost/background mode, cache policy, and local page. “Cold” means process/session cold, not cleared user data. |
| 6 | Edge first-interaction readiness | Timestamp of the first synthetic click after workflow 5 page readiness. | Local page increments its visible and automation-readable response marker. | Fixed viewport/DPI/profile/page; same click target; one interaction per fresh cold-launch run; no Internet dependency. Report separately from launch readiness. |
| 7 | Windows Search response | Timestamp when the fixed query is submitted to the Windows Search UI. | The agreed local file or application result is visible and invokable through UI Automation. | Same known indexed target; verify target presence and index status before the run; close Search and clear the query between runs; do not rebuild the index during a session. |
| 8 | Wake to network-ready | Resume timestamp from Modern Standby ETW/power event. | The Wi-Fi interface is connected to the expected network and three consecutive probes, 250 ms apart, reach the fixed LAN endpoint. Internet reachability is recorded separately, not used as the primary endpoint. | Enter Modern Standby for a fixed 120 seconds with lid/action and wake source held constant; same AP/location/band/driver; no S3 substitution; record wake source and `SleepStudy` session when available. |
| 9 | Idle CPU, memory, and disk | Start after the desktop has had no operator input for ten minutes and the controlled foreground apps are closed. | End after a fixed five-minute observation; this workflow reports distributions rather than readiness latency. | Fresh sign-in, fixed post-sign-in wait, same background-app state; collect CPU utilization, committed/working-set memory, disk active time/bytes, and top contributors. Any update, scan, sync, index, or thermal event is retained and marked invalid/inconclusive. |

Probe frequency, timeout, UI Automation selectors, local Edge page, Outlook
test item, Search target, and LAN endpoint must be version-controlled before the
first formal run. Timeout results are failed observations, not deleted outliers.

## Instrumentation profile and overhead

Use three named profiles:

1. `HarnessOnly`: monotonic timestamp, process lifecycle, UI Automation probes,
   network probe, and structured run log.
2. `WPR-Light`: `HarnessOnly` plus a file-mode WPR profile containing only the
   providers required for CPU, disk, process/thread, power, network, and the
   selected application scenario.
3. `WPR-Diagnostic`: higher-detail tracing used only after a failed or
   anomalous run; diagnostic runs do not enter headline medians.

Before baseline collection, measure overhead with at least five randomized
paired `HarnessOnly`/`WPR-Light` runs for Edge launch and idle observation.
Record trace size, lost events, harness CPU time, total CPU, disk bytes, and
workflow elapsed time. Preserve every pair.

The proposed acceptance limit is:

- zero reported lost ETW events;
- median WPR-Light elapsed-time delta no greater than the larger of 2% or 50 ms
  for Edge launch;
- median CPU-utilization delta no greater than 1 percentage point and disk-write
  delta no greater than 5 MB/min during idle; and
- no readiness-state change caused by instrumentation.

If any limit fails, use `HarnessOnly` for primary timings and reserve WPR for
separate attribution runs. These thresholds are proposed and must be explicitly
accepted or revised before the issue advances.

## Repetition, raw data, and medians

- Run at least seven valid repetitions per workflow and configuration.
- Use two sessions separated by a reboot; for sign-in and cold-launch workflows,
  every measured repetition begins with the required reboot.
- Randomize baseline/candidate order where a paired comparison is possible; use
  an ABBA block across sessions to reduce drift.
- Store one immutable JSON record per run plus referenced ETL/CSV artifacts.
- Preserve warm-ups, timeouts, probe failures, operator mistakes, thermal
  excursions, update/index/sync interference, and unsupported workflows. Mark
  their disposition and reason; never overwrite or delete them.
- Compute the median only from runs that satisfy the predeclared validity rules.
  Also report count, minimum, maximum, median absolute deviation, and all raw
  values. Never manufacture a replacement observation.

## Reproducibility and design decision rule

The protocol is design-ready only when all of the following are true:

1. All nine start, readiness/end, reset, timeout, and control definitions have
   passed one witnessed dry run; an unavailable application is explicitly
   removed from the supported environment rather than silently skipped.
2. Instrumentation overhead meets the accepted limits or the primary profile is
   revised and remeasured.
3. At least seven valid current-state runs exist for every supported workflow,
   with raw data, medians, dispersion, and failed/inconclusive runs preserved.
4. A second session reproduces each workflow median within the larger of 10% or
   100 ms for latency workflows; idle resource medians must be within 10%
   relative or one percentage point CPU / 250 MB memory / 1 MB/s disk,
   whichever bound is larger.
5. The exact script commit, Windows/build/BIOS/drivers/apps, power/network/
   thermal conditions, and rollback result are recorded.
6. The lab owner explicitly accepts the endpoint definitions, overhead limit,
   validity rules, and reproducibility bounds in the issue.

Failure of this rule keeps `stage:research`. It is evidence of a protocol or
environment gap, not permission to discard the run. Passing the rule permits
handoff to `stage:design`; it does not prove that a tweak improves performance.
