# EXP-001 layer 10 — shell control inventory and Explorer readiness profiler

- Cycle timestamp: 2026-07-29T05:29:21Z
- Layer: 10 — Windows shell, GUI, capture, notifications, and perceived responsiveness
- Outcome: implemented
- Evidence state: observation-only baseline; no Windows setting changed
- Implementation commit: `254bc8a6e3b6a1ca8dc5400c056e71ee85177d07`
- Private raw evidence identifier: `20260729-055337-shell-profile.json`

## Customer-visible interval and layer ownership

The selected interval begins when ZBookPerf asks the documented Shell automation
interface to open its private benchmark folder. It ends when the new matching
`IShellWindows` entry reports `Busy = false` and `ReadyState = Complete`.
This is a repeatable File Explorer readiness proxy. It does not claim to
measure Start-menu animation, pointer-to-pixel latency, or total user reaction
time.

Layer responsibilities and contracts:

- Windows owns Explorer, DWM, `UISettings`, the Shell automation interfaces,
  app-package registration, and the effective policy state.
- Group Policy or MDM can own the documented Widgets and Game DVR device
  policies. ZBookPerf inventories those locations but never changes them in
  this capability.
- ZBookPerf owns the benchmark folder, timing, bounded polling, evidence
  redaction, and cleanup of only the window that matches that folder.
- WPR/WPA remain the supported deeper trace path for UI delays, CPU, DWM, and
  critical-path analysis. Their availability is recorded but they are not
  silently installed.

Inputs are the current user UI settings, documented device-policy values,
package/tool availability, power state, and the Shell automation response.
Outputs are structured inventory plus raw readiness runs, probe-overhead
bounds, median, median absolute deviation, failures, and environmental
metadata. A timeout or COM failure is retained as a failed run; it does not
trigger a setting change or restart Explorer.

## Verified research delta

Primary sources retrieved 2026-07-29:

- Microsoft Learn, [UISettings class](https://learn.microsoft.com/en-us/uwp/api/windows.ui.viewmanagement.uisettings?view=winrt-26100): documents `AnimationsEnabled`, `AdvancedEffectsEnabled`, and `MessageDuration`; `AdvancedEffectsEnabled` reports the Transparency effects setting.
- Microsoft Learn, [UISettings.MessageDuration](https://learn.microsoft.com/en-us/uwp/api/windows.ui.viewmanagement.uisettings.messageduration?view=winrt-26100): documents that the returned unit is seconds.
- Microsoft Learn, [SystemParametersInfoW](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfow): documents the visual-effect query APIs already used by ZBookPerf.
- Microsoft Learn, [GetSystemPowerStatus](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getsystempowerstatus) and [SYSTEM_POWER_STATUS](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-system_power_status): document the AC-line and Battery Saver state included with the benchmark conditions.
- Microsoft Learn, [NewsAndInterests Policy CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests): documents the Windows 11 Widgets policy, default `1`, and Group Policy mapping `SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests`.
- Microsoft Learn, [ApplicationManagement Policy CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-applicationmanagement): documents the Game DVR policy, default `1`, and Group Policy mapping `Software\Policies\Microsoft\Windows\GameDVR\AllowGameDVR`. The page still says enforcement is limited to Windows 10 desktop, so this cycle inventories but does not propose a Windows 11 mutation.
- Microsoft Learn, [Shell.Explore](https://learn.microsoft.com/en-us/windows/win32/shell/shell-explore), [ShellWindows](https://learn.microsoft.com/en-us/windows/win32/shell/shellwindows), and [Developing with Windows Explorer](https://learn.microsoft.com/en-us/windows/win32/shell/developing-with-windows-explorer): document opening, discovering, and controlling Explorer windows through the Shell automation model.
- Microsoft Learn, [Optimizing performance and responsiveness](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/optimizing-performance-and-responsiveness) and [WPA graphs](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/list-of-wpa-graphs): document WPR/WPA and the UI Delays analysis surface.

The Claude intake was used only as a private question list. Every interface
implemented here was rechecked against the Microsoft sources above. Community
registry values for transparency, animation, Game Bar user preferences, and
menu timing were not used.

## Candidate scoring and selection

Scores use a 0–5 scale for evidence, expected user-visible impact,
reversibility, support, measurability, and engineering leverage.

| Candidate | Evidence | Impact | Reversible | Support | Measurable | Leverage | Total | Decision |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Layer 10 inventory plus Explorer readiness profiler | 5 | 4 | 5 | 5 | 5 | 5 | 29 | Selected |
| Animation-effects A/B | 5 | 3 | 5 | 5 | 4 | 3 | 25 | Not selected; current state was already off |
| Transparency-effects A/B | 5 | 2 | 5 | 5 | 4 | 3 | 24 | Not selected; current state was already off |
| Widgets device-policy A/B | 5 | 2 | 4 | 5 | 3 | 2 | 21 | Not selected; functional removal and delivery authority require a separate Tier 2 design |
| Game DVR device-policy A/B | 3 | 3 | 4 | 2 | 3 | 2 | 17 | Rejected for mutation; current Microsoft page preserves a Windows 10 enforcement limitation |

The profiler won because it satisfies the prerequisite for later one-variable
work and remains useful when a candidate is already at the proposed state.

## Engineering artifact

`ZBookPerf.ps1` now exposes `-Action ShellProfile`, a `-ShellProfile` switch,
interactive menu option 7, bounded run/warmup/timeout/calibration parameters,
and JSON evidence under the configured data root. The capability:

1. reads `UISettings`, documented visual-effect APIs, two documented policy
   mappings, relevant app packages, WPR/WPA/WPA Exporter availability, RSoP,
   join context booleans, AC power, and Battery Saver;
2. creates an idempotent private benchmark folder below the evidence root;
3. snapshots existing Explorer window handles;
4. calibrates Shell-window enumeration overhead;
5. opens the private folder through `Shell.Explore`;
6. waits for only the new matching window to report ready;
7. closes only the matching benchmark window; and
8. records raw results, conservative overhead bounds, variability, and
   failures without storing Explorer location URLs, tenant IDs, or command
   lines. The configured evidence-output path is retained so the raw record
   can be located.

## Lab validation

Target:

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Windows 11 Pro 10.0.26200
- BIOS T76 01.24.02
- AC line: online
- Battery Saver: off

Validation:

- PowerShell parser: 0 errors.
- Focused Pester 5.6.1: 23 passed, 0 failed.
- Combined EXP-001 baseline plus ZBookPerf CI suite: 31 passed, 0 failed.
  The non-elevated baseline run emitted BitLocker CIM access warnings while
  preserving passing read-only assertions; no BitLocker state was changed.
- Integration: 1 warmup plus 5 measured runs; all 5 measured runs reached
  ready state before the 5,000 ms timeout.
- Measured raw durations: 573.463, 617.153, 594.678, 1068.767, and
  323.116 ms.
- Median: 594.678 ms.
- Median absolute deviation: 22.475 ms.
- Range: 323.116–1068.767 ms.
- Full readiness-probe median: 2.158 ms.
- Full readiness-probe p95: 2.963 ms.
- Estimated per-run p95 observer budget: 11.852–14.815 ms for four
  to five probes.
- Current inventory: animations off, transparency effects off, notification
  duration 5 seconds, neither documented Widgets nor Game DVR Group Policy
  mapping configured, WPR available, WPA and WPA Exporter not on `PATH`.

The 1068.767 ms run is retained; it is not discarded as an outlier. The run
spread is why no optimization claim is made from this baseline.

## Decision, rollback, and next cycle

Decision: accept the PowerShell engineering capability as an Experimental
observation tool. Performance decision: baseline only, no before/after
candidate and no gain claim.

Rollback is source-code reversion. Runtime cleanup closes the matching
benchmark window; no Windows configuration rollback or reboot-persistence
test applies because no setting was changed.

Next cycle: Layer 11 — application/runtime efficiency and workload profiles.
Use the new profiler only when a Layer 11 workload includes Explorer readiness;
do not convert the current disabled animation/transparency states into a
fictional optimization.
