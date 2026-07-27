# Layer 8: the entry remains, but its helper is missing

- Date: 2026-07-27
- Layer: boot path, services, scheduled tasks, background permissions, and startup applications
- Evidence state: **research-only**
- Live status: read-only inventory; nothing was applied on the lab machine
- Performance claim: none

## What was learned

Windows still exposes a machine-wide `Logitech Download Assistant` Run
registration on the HP ZBook lab system. Its launcher is Microsoft's signed
`rundll32.exe`, but the registered `LogiLDA.dll` payload was not present at that
path.

Logitech documents Download Assistant as notification software that helps
install Logi Options+ or G HUB for supported devices. Microsoft documents Run
entries as logon commands and identifies additional startup activity as a
possible contributor to the Post On/Off responsiveness phase.

The exact registration is now tracked as the one variable in
[EXP-007](https://github.com/Lacksan-Dev/HP-ZBook-Performance/issues/23).

## What this does not prove

The inventory did not establish that Windows currently enables or invokes the
entry. No matching Diagnostics-Performance boot event, WPR On/Off trace,
repeated raw run, median, or instrumentation-overhead measurement was
available. Microsoft's general startup guidance does not prove a performance
cost for this specific registration.

Zero related Logitech services, tasks, or currently present devices in the
bounded inventory does not prove that Logitech device support will never be
needed.

## Compatibility and protected boundary

The observation applies to the HP ZBook Firefly 14 inch G8 recorded in EXP-001,
running Windows 11 Pro build 26200 and BIOS T76 01.24.02.

Teams remains with EXP-006. Tailscale is a protected startup application.
Windows Security and the Realtek audio component are outside this removal
candidate. EXP-007 will not uninstall or modify Logitech software, services,
tasks, files, devices, or drivers.

## Change and rollback status

Nothing was changed. Future tooling must first confirm the exact registration
identity and effective startup state. It must capture the original registry
path, name, type, and value and provide support detection, dry-run, apply,
verification, structured logging, idempotence, exact rollback, rollback
verification, and reboot-persistence testing. Apply and rollback require a
supervised lab session.

## Next evidence

EXP-007 needs a WPR-attributed, repeated sign-in-to-usable baseline with
instrumentation-overhead qualification and protected-workflow readiness. Layer
9 next examines supported Group Policy, MDM-aware policy, registry, and
system-configuration surfaces.

## Primary sources

Retrieved 2026-07-27:

- [Logitech Download Assistant requirements and installation](https://support.logi.com/hc/en-au/articles/29870482393239-Logitech-Download-Assistant-2-0-Requirements-and-Installation)
- [Microsoft Run and RunOnce registry keys](https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys)
- [Microsoft `Win32_StartupCommand` class](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-startupcommand)
- [Microsoft Post On/Off duration](https://learn.microsoft.com/en-us/windows-hardware/test/assessments/post-on-off-duration)
- [Microsoft recording On/Off transitions](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/recording-onoff-transitions)
