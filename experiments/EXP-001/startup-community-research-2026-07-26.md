# EXP-001 startup-performance community research

- Research and retrieval date: 2026-07-26
- Target: HP ZBook Firefly 14 inch G8 lab computer
- Evidence state: research and read-only inventory only
- Live changes made: none
- Performance claim: none

## Purpose

This review treats GitHub projects, videos, and blogs as sources of candidate
ideas. A community tweak is not accepted merely because it is popular. It must
also have a documented Windows or vendor interface, match the supported ZBook
and Windows build, affect the defined off-to-usable path, preserve security and
management, and provide exact-state rollback.

## Current lab observations

These are read-only observations collected on 2026-07-26. No setting was
changed.

- `HiberbootEnabled` is `1`, but `powercfg /a` reports that hibernation is not
  enabled and Fast Startup is unavailable. The selected registry value alone
  does not make Fast Startup operational.
- Seven startup commands were enumerated: Logitech Download Assistant,
  Microsoft Edge auto-launch, the Realtek audio user component, Windows
  Security, Send to OneNote, Tailscale, and Teams.
- No non-Microsoft scheduled task with a boot or logon trigger was found.
- Several Omnissa Horizon optional-redirection and client services are
  configured for automatic, non-delayed startup. Their boot-path cost and
  supported alternative startup states have not been established.
- The Diagnostics-Performance operational log contained no recent event 100
  record, so it cannot currently supply preserved boot medians.
- `DontDisplayLastUserName` is `0`; Windows is currently allowed to show the
  last signed-in user's full name and tile.
- The account-details-at-sign-in policy is not configured. Automatic sign-in
  and the Lacksan restart-resume task are inactive.

## Community-source findings

### Chris Titus Tech WinUtil

Inspected commit:
[`50be7390e586f664df76d7fed41fc3c39252288c`](https://github.com/ChrisTitusTech/winutil/tree/50be7390e586f664df76d7fed41fc3c39252288c).

The inspected Services preset disables `CscService`, `DiagTrack`, and
`SharedAccess`, sets `MapsBroker` and `StorSvc` to Manual, and changes
`SvcHostSplitThresholdInKB`. Its service writer checks that a service exists and
avoids rewriting an already matching startup type, but the preset supplies
fixed "original" service types rather than capturing this computer's actual
pre-change configuration.

Disposition: **reject the preset as a baseline**. It combines unrelated
privacy, feature, and process-count changes; it does not prove that these
services delay this ZBook's usable state; and disabling SharedAccess or Offline
Files can remove supported Windows functionality. Individual ideas can be
reconsidered only after dependency and boot-trace evidence.

Chris Titus Tech's 2022 Explorer CPU article proposes
`IsInputAppPreloadEnabled=0` and `IsPrelaunchEnabled=0` for a reported
Widgets/Input Experience CPU condition. These raw registry interfaces are not
supported by a current primary-source contract found in this review.

Disposition: **hypothesis only**. Do not add unless the exact post-logon CPU
condition is reproduced and a current supported interface and rollback are
established.

### Sophia Script

Inspected commit:
[`14a1753b6275616001e6139c6a8d647fd37da984`](https://github.com/farag2/Sophia-Script-for-Windows/tree/14a1753b6275616001e6139c6a8d647fd37da984).

The inspected Windows 11 module can disable `DiagTrack`, block its firewall
group, disable Windows Error Reporting and its task, and present a selectable
list of scheduled tasks. The source itself warns that disabling `DiagTrack` can
affect Feedback Hub and Xbox achievements.

Disposition: **reject for the Lacksan baseline**. Removing diagnostics conflicts
with the experiment's evidence and support requirements and has no demonstrated
startup benefit on this system.

### Atlas

Inspected commit:
[`1ed9630616b29f0c7974e8bd76a94fc06f60388c`](https://github.com/Atlas-OS/Atlas/tree/1ed9630616b29f0c7974e8bd76a94fc06f60388c).

The inspected playbook includes:

- `StartupDelayInMSec=0`;
- global background-app registry controls;
- per-service `SvcHostSplitDisable=1`; and
- two-second application, service, and hung-application shutdown timeouts.

Microsoft reports that moderating startup-app launches reduces contention,
prioritizes foreground work, and can allow background apps to finish sooner.
Therefore, removing the startup delay globally is not equivalent to improving
off-to-usable responsiveness. It can move more load into the critical post-logon
interval. The shutdown timeouts affect shutdown rather than startup and can
force termination before work completes. Service-host merging reduces process
isolation and is not evidence of reduced boot latency.

Disposition:

- `StartupDelayInMSec=0`: **controlled hypothesis only**, limited to a workflow
  where a delayed startup app is itself part of the readiness definition.
- Global background-app disable: **reject**; use supported per-app permissions
  and preserve notifications and background work required by the workflow.
- Service-host merging: **reject**; no startup evidence and an isolation
  tradeoff.
- Forced shutdown timeouts: **reject**; wrong endpoint and data-loss/recovery
  risk.

### Blog and video-derived candidates

Recent consumer startup articles commonly recommend Fast Startup and disabling
high-impact startup applications. Both ideas have supported Windows surfaces,
but neither establishes a gain on this ZBook without measurements. Microsoft's
own engineering report supports moderating startup-app launches rather than
starting everything simultaneously.

Disposition:

- Fast Startup: **supported measurement candidate**. Measure hybrid shutdown
  separately from Restart and full cold boot. Enabling hibernation creates a
  hibernation file and changes driver/service initialization semantics.
- Per-app startup control: **supported measurement candidate**. Disable only a
  nonessential app's automatic launch, preserve its exact prior enablement
  record, and test one candidate at a time.
- Third-party "boot time cut in half" claims: **not transferable evidence**.

## Candidate queue shown to the user

| Candidate | Current disposition | Exact boundary |
| --- | --- | --- |
| Teams automatic launch | Test candidate | Disable autostart only; do not uninstall or alter updates |
| Send to OneNote automatic launch | Test candidate | Disable its startup shortcut only |
| Edge auto-launch | Test candidate | Distinguish Windows logon autolaunch from Edge Startup Boost and browser launch readiness |
| Logitech Download Assistant | Test candidate | Disable/remove only the installation reminder; preserve Logitech device functionality |
| Tailscale tray/startup | Hold | Immediate network availability may be part of the usable-state definition |
| Realtek audio user component | Keep | Audio-device functionality and control surface are unresolved dependencies |
| Windows Security startup item | Keep | Security status and protection are not optimization targets |
| Omnissa Horizon redirection services | Research candidate | Vendor-supported state, dependencies, and required Horizon features are unresolved |
| Fast Startup | Test candidate | Currently unavailable because hibernation is disabled; separate hybrid and cold-start evidence |
| Service delayed/trigger start | Design pattern only | Apply only to a documented noncritical service after dependency and trace proof |
| WPR/WPA boot trace | Instrumentation candidate | Qualify overhead and preserve ETL handling/cleanup |
| Sysinternals Autoruns export | Inventory candidate | Read-only export before changing any startup surface |

## Sign-in privacy finding

Microsoft documents three different controls:

1. **Show account details on the sign-in screen** controls extra information
   such as the email address. Turning this off does not promise to hide the
   display name.
2. **Block user from showing account details on sign-in** prevents users from
   enabling those extra details. The documented policy maps to
   `Software\Policies\Microsoft\Windows\System` value
   `BlockUserFromShowingAccountDetailsOnSignin`.
3. **Interactive logon: Don't display last signed-in** removes the last user's
   full name and sign-in tile. The documented security policy maps to
   `SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System` value
   `DontDisplayLastUserName`.

The third control satisfies the request to remove the name. Microsoft also
documents its usability cost: the user must enter a qualified account name (or
local username) and password, and related name-hiding policy can be incompatible
with autologon, multi-factor unlock, and passwordless/Windows Hello
experiences. That conflicts with EXP-001's optional one-time automatic-sign-in
restart workflow.

Disposition: **supported security option requiring an explicit usability
choice**. Do not silently include it in the general performance profile. If
selected, implement it as a separate privacy action with support detection,
capture of value existence/type/data, preview, apply, verification, logging,
exact rollback, and a restart-workflow compatibility block.

## Accepted next measurements

1. Define "off to usable" for this owner's normal workflow.
2. Capture an Autoruns inventory and a WPR/WPA boot trace; measure
   instrumentation overhead.
3. Preserve seven raw control runs with firmware, main-path, sign-in, shell, and
   required-application readiness markers.
4. Test one startup entry at a time, starting with Logitech Download Assistant
   or Send to OneNote because neither is currently documented as required for
   Windows security, audio, or network readiness.
5. Keep successful, failed, rejected, and inconclusive runs and compare medians
   using the EXP-001 decision rule.

## Documented facts

- Windows supports per-app startup control and reports CPU/disk-based startup
  impact in Task Manager.
- Autoruns enumerates a wider set of boot and logon extensibility points than
  the Settings startup list.
- Windows supports delayed automatic service startup and service trigger
  events, but a delayed client call can fail and dependencies remain binding.
- Fast Startup restores the kernel and loaded driver state from a hibernation
  file; Restart performs a full shutdown.
- Windows supports policies that hide account details or the entire last-user
  identity, with different usability and compatibility consequences.

## Lab measurements

Only the read-only inventory listed under **Current lab observations** was
collected. No timed startup run was performed, no service or startup item was
changed, and no performance improvement was measured.

## Hypotheses

- Reducing optional per-user autostart contention may shorten the interval from
  sign-in to a responsive required application.
- Fast Startup may shorten shutdown-to-sign-in time on this SSD system, but its
  benefit may be small and it cannot substitute for full-restart driver
  validation.
- One or more optional Horizon redirection services may be deferrable when their
  features are not used, but vendor support and dependency evidence are absent.

## Unresolved questions

- Must Tailscale and Teams be ready for the owner's normal "usable" state?
- Which Omnissa Horizon redirection features are actually used?
- Does the owner prefer full name privacy enough to type the username and
  password and disable the one-time automatic-sign-in test?
- What is the WPR boot-trace overhead on this system?
- Which startup entry contributes measurable critical-path CPU or storage
  contention?

## Sources

Primary sources, retrieved 2026-07-26:

- [Microsoft: Configure Startup Applications in Windows](https://support.microsoft.com/en-au/windows/set-apps-to-run-automatically-when-you-start-your-device-a5b64b3e-4483-4dad-abc7-027a863e1c2e)
- [Microsoft Sysinternals: Autoruns](https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns)
- [Microsoft: WPR and WPA](https://learn.microsoft.com/en-us/troubleshoot/windows-server/support-tools/support-tools-xperf-wpa-wpr)
- [Microsoft: Evaluate Fast Startup with WPT](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/optimizing-performance-and-responsiveness-exercise-2)
- [Microsoft: System power states](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states)
- [Microsoft: Delayed automatic service startup](https://learn.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_delayed_auto_start_info)
- [Microsoft: Service trigger events](https://learn.microsoft.com/en-us/windows/win32/services/service-trigger-events)
- [Microsoft: Startup-app moderation engineering](https://blogs.windows.com/windowsdeveloper/2023/05/26/delivering-delightful-performance-for-more-than-one-billion-users-worldwide/)
- [Microsoft: Sign-in options](https://support.microsoft.com/en-us/accounts-billing/security/sign-in-options-in-windows)
- [Microsoft: Block account details policy](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-logon)
- [Microsoft: Don't display last signed-in](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/security-policy-settings/interactive-logon-do-not-display-last-user-name)
- [Microsoft: Don't display username during sign-in](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/security-policy-settings/interactive-logon-dont-display-username-at-sign-in)
- [Microsoft: Display information while locked](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/security-policy-settings/interactive-logon-display-user-information-when-the-session-is-locked)
- [Logitech: Download Assistant purpose](https://support.logi.com/hc/en-my/articles/29870482393239-Logitech-Download-Assistant-2-0-Requirements-and-Installation)

Community sources, retrieved and pinned 2026-07-26:

- [WinUtil commit `50be7390e586f664df76d7fed41fc3c39252288c`](https://github.com/ChrisTitusTech/winutil/tree/50be7390e586f664df76d7fed41fc3c39252288c)
- [WinUtil Services preset documentation](https://github.com/ChrisTitusTech/winutil/blob/50be7390e586f664df76d7fed41fc3c39252288c/docs/content/dev/tweaks/Essential-Tweaks/Services.md)
- [Sophia Script commit `14a1753b6275616001e6139c6a8d647fd37da984`](https://github.com/farag2/Sophia-Script-for-Windows/tree/14a1753b6275616001e6139c6a8d647fd37da984)
- [Atlas commit `1ed9630616b29f0c7974e8bd76a94fc06f60388c`](https://github.com/Atlas-OS/Atlas/tree/1ed9630616b29f0c7974e8bd76a94fc06f60388c)
- [Chris Titus Tech: Windows Explorer Stealing CPU](https://christitus.com/windows-explorer-stealing-cpu/)
- [Tom's Guide: consumer Fast Startup and startup-app report](https://www.tomsguide.com/computing/windows-operating-systems/pc-taking-forever-to-boot-heres-how-to-speed-it-up)
