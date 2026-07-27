# Layer 9: reject the global startup-delay registry shortcut

- Date: 2026-07-27
- Layer: Group Policy, MDM-aware policy, registry, and system configuration
- Outcome: **rejected**
- Live status: read-only research and inventory; nothing was applied
- Performance claim: none

## Question

Should the baseline add the community-recommended
`HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize`
`StartupDelayInMSec=0` registry value to make startup applications launch
sooner?

## Decision

No. Reject this value for the current baseline.

The key and value are absent on the selected ZBook. A bounded current search of
Microsoft Learn, Microsoft Support, Microsoft Windows logon Policy CSP
documentation, and Microsoft startup-app guidance found no public
primary-source definition, supported build or edition boundary, documented
default, compatibility contract, management precedence, or rollback guidance
for `StartupDelayInMSec`.

The exact name appeared in community advice, including Microsoft Q&A, but Q&A
answers are not Windows product support documentation. This negative search is
bounded: it does not prove that no historical, private, future, or undocumented
implementation exists.

## Documented facts

- Microsoft Support documents per-app startup control through Settings and Task
  Manager. Task Manager measures each enabled app's startup CPU and disk impact.
  Microsoft cautions that registry changes can have unintended consequences and
  recommends backing up before changing documented startup registrations.
  [Configure startup applications][S01]
- Microsoft's compatibility guidance says background startup apps can affect
  responsiveness. It recommends reducing duplicate launchers and using boot
  assessment and WPA attribution. [Desktop startup apps][S02]
- Microsoft documents specific Group Policy and MDM/CSP settings with scope,
  supported editions and builds, defaults, registry mappings, and management
  semantics. The reviewed ADMX Logon and WindowsLogon pages do not list
  `StartupDelayInMSec`. [ADMX Logon Policy CSP][S03],
  [WindowsLogon Policy CSP][S04]
- Microsoft recommends attributing the Run-key commands and processes that load
  during startup and using delayed or on-demand techniques when appropriate.
  It does not equate launching all startup work sooner with reaching an
  interactive state sooner. [Great startup and shutdown experience][S05]
- WPR supplies On/Off profiles for boot attribution and normally records three
  reboot iterations by default. [Recording On/Off transitions][S06]

## Lab measurements

Read-only observations on the HP ZBook Firefly 14 inch G8, Windows 11 Pro build
26200, BIOS T76 01.24.02, while connected to AC:

- The `Explorer\Serialize` key does not exist for the current user.
- The `StartupDelayInMSec` value is absent.
- The utility's read-only audit reported a connected work account
  (`WorkplaceJoined`) but no active management endpoint under its bounded
  rules.
- The audit reported no MDM URL and no EnterpriseMgmt task, but its task view
  was non-elevated and explicitly limited.
- No matching Group Policy or CSP mapping was established for the candidate.

These are configuration observations, not performance measurements. No WPR
trace, off-to-usable benchmark, treatment, repeated raw run, median,
variability calculation, or instrumentation-overhead qualification ran.

## Hypothesis

Writing zero might cause some shell-managed startup applications to be launched
earlier. If so, it could also concentrate CPU and storage work in the
foreground-readiness interval, delaying the responsive shell, protected
network access, or workload launch. Neither effect was measured.

## Supported alternative

Use Microsoft's documented Settings or Task Manager controls to test one
nonessential startup registration at a time. Preserve the original enablement
and command, attribute work with a supervised WPR On/Off trace, and define
usable desktop as:

- successful sign-in and responsive shell;
- required network and device readiness;
- Omnissa, Windows App, Remote Desktop, and Tailscale readiness; and
- the selected workload's launch readiness.

The benchmark must preserve repeated control and treatment runs, medians,
variability, failed and inconclusive runs, thermal/power/network state, and
instrumentation overhead.

## Compatibility and rollback

No compatibility boundary is claimed because no primary-source contract was
found for the value. The finding applies to the recorded ZBook model, Windows
build, BIOS, user registry state, and bounded management signals only.

Nothing changed, so rollback is not applicable. If a future supported contract
emerges, a prototype still requires support and management detection, exact
key/value/type capture, dry run, one-variable apply, configuration and workflow
verification, structured logging, idempotence, exact rollback, rollback
verification, and reboot-persistence testing. It must refuse to override
applicable Group Policy or MDM.

## Unresolved questions

- Does Microsoft publish a current support contract for this value elsewhere?
- Which process and event actually implement the observed staging behavior on
  build 26200?
- Is any required protected application late in a trace because of shell
  staging rather than its own work or dependencies?
- What is the treatment's effect on first-120-second CPU, storage, protected
  network readiness, and foreground responsiveness?

## Sources

Retrieved 2026-07-27:

- [S01: Microsoft Support - Configure Startup applications in Windows](https://support.microsoft.com/en-US/Windows/Experience/Startup-Boot/configure-startup-applications-in-windows)
- [S02: Microsoft - Desktop Startup apps](https://learn.microsoft.com/en-us/windows/compatibility/startup-apps)
- [S03: Microsoft - ADMX_Logon Policy CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-logon)
- [S04: Microsoft - WindowsLogon Policy CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowslogon)
- [S05: Microsoft - Delivering a great startup and shutdown experience](https://learn.microsoft.com/en-us/windows-hardware/test/weg/delivering-a-great-startup-and-shutdown-experience)
- [S06: Microsoft - Recording On/Off transitions](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/recording-onoff-transitions)
- [Discovery source: Atlas commit inspected by the community research](https://github.com/Atlas-OS/Atlas/tree/1ed9630616b29f0c7974e8bd76a94fc06f60388c)
- [Community evidence only: Microsoft Q&A discussion](https://learn.microsoft.com/en-us/answers/questions/4059183/startup-apps-artificially-delayed-on-windows-11)
