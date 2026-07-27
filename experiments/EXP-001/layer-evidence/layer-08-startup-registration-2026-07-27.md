# Layer 8: a stale startup-registration candidate

- Date: 2026-07-27
- Layer: boot path, services, scheduled tasks, background permissions, and startup applications
- Outcome: **research-only**
- Focused experiment: [EXP-007](https://github.com/Lacksan-Dev/HP-ZBook-Performance/issues/23)
- Live status: read-only inventory; no setting was applied
- Performance claim: none

## Question

Does the lab system contain a specific, non-protected startup registration that
vendor documentation, dependency inspection, and boot evidence justify testing
as one reversible variable?

## Decision

Select the exact machine-wide `Logitech Download Assistant` Run registration for
EXP-007 research. Do not remove it yet.

The registered `LogiLDA.dll` payload was not present at its recorded path, but
the registration remained visible in the registry and through
`Win32_StartupCommand`. This is sufficient to select a stale-registration
candidate. It does not prove that the entry is enabled, invoked, costly, or safe
to remove for every Logitech workflow.

## Documented facts

- Microsoft documents `Run` values as commands that run at user logon. Their
  execution order is indeterminate. [Run and RunOnce registry keys][S01]
- Microsoft documents `Win32_StartupCommand` as a read-only inventory surface
  for commands configured to start automatically at logon. [Startup command
  class][S02]
- Logitech describes Logi Download Assistant as notification software that
  helps install Logi Options+ or G HUB for supported Logitech devices. Its
  currently documented device compatibility is limited. [Logitech Download
  Assistant][S03]
- Microsoft's Post On/Off metric covers background CPU and storage activity
  after the visible shell appears. Microsoft states that additional startup
  applications usually have a negative effect and recommends process-level
  attribution. That general statement is not evidence that this registration
  executes or affects this ZBook. [Post On/Off duration][S04]
- Microsoft provides WPR On/Off profiles for repeatable boot recording. Default
  reboot profiles usually perform three iterations, but EXP-001 still requires
  its declared readiness endpoints and accepted decision rule. [Recording
  On/Off transitions][S05]

## Lab measurements

Read-only observations on the HP ZBook Firefly 14 inch G8, Windows 11 Pro build
26200, BIOS T76 01.24.02, while connected to AC:

- Four Run registrations were inventoried: Teams, SecurityHealth,
  RtkAudUService, and Logitech Download Assistant.
- The Logitech value was a machine-wide String value launching Microsoft's
  signed `rundll32.exe` with the `LogiFetch` entry point.
- The referenced `LogiLDA.dll` file was not present. The registration was still
  returned by `Win32_StartupCommand`.
- No related Logitech service, scheduled task, or currently present Logitech
  device was found by the bounded inventory.
- The common startup folder contained protected Tailscale. The current-user
  folder contained Send to OneNote, which was not selected.
- A Diagnostics-Performance Event 100 query returned no matching events.

These are configuration observations, not startup-time measurements. No WPR
trace, boot assessment, off-to-usable run, repeated raw run, median, variability
calculation, thermal control, or instrumentation-overhead qualification ran.

## Candidate and protected boundary

| Item | Disposition | Reason |
| --- | --- | --- |
| Logitech Download Assistant Run value | EXP-007 research candidate | Registered payload was missing; exact one-value rollback is possible |
| Teams Run value | Existing EXP-006 | Avoid duplicate experimental scope |
| Tailscale startup link | Protected | Required user startup application |
| SecurityHealth Run value | Protected | Windows security component |
| RtkAudUService Run value | Preserve | Audio and device-function boundary |
| Send to OneNote startup link | Unresolved | Not enough evidence to select |

Absence of a currently present Logitech device does not establish that no such
device will be connected later. EXP-007 must not uninstall or alter any
Logitech application, service, scheduled task, file, device, or driver.

## Hypothesis

If the registration is effectively enabled and Windows attempts to invoke the
missing payload at logon, removing that exact value may avoid a failed launch
attempt and reduce post-logon work. This remains unverified.

## Compatibility, engineering, and rollback

Support is limited to the detected HP ZBook model and Windows build until
EXP-007 records broader evidence. Before applying anything, tooling must confirm
the exact registry path, value name, type, launcher, entry point, and absent
payload. Any identity mismatch must produce an unsupported result.

The PowerShell contract must capture the original path, name, type, and value;
provide support detection, dry-run, one-value apply, verification, structured
logging, idempotence, exact restoration, rollback verification, and reboot-
persistence testing. Apply and rollback require a supervised lab session.

The benchmark must preserve repeated control and treatment runs, medians,
variability, thermal/power/network controls, failed and inconclusive runs, and
instrumentation-overhead results. The usable endpoint must include sign-in,
responsive shell, required network and device readiness, and protected Omnissa,
Windows App, Remote Desktop, and Tailscale workflow readiness.

## Unresolved questions

- Is the registration effectively enabled, and does Windows attempt it at
  logon?
- Does a boot trace attribute CPU, storage, delay, or error activity to it?
- Could Logitech software repair or update legitimately recreate the payload
  and registration?
- Does any current or planned Logitech device workflow depend on the
  notification helper?
- Does a supervised one-variable treatment satisfy the EXP-001 decision rule
  without readiness regression?

## Primary sources

Retrieved 2026-07-27:

- [S01: Microsoft Run and RunOnce registry keys](https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys)
- [S02: Microsoft `Win32_StartupCommand` class](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-startupcommand)
- [S03: Logitech Download Assistant requirements and installation](https://support.logi.com/hc/en-au/articles/29870482393239-Logitech-Download-Assistant-2-0-Requirements-and-Installation)
- [S04: Microsoft Post On/Off duration](https://learn.microsoft.com/en-us/windows-hardware/test/assessments/post-on-off-duration)
- [S05: Microsoft recording On/Off transitions](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/recording-onoff-transitions)
