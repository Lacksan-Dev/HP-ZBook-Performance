# EXP-001 layer 1 evidence: physical and thermal health

- Layer: 1, physical and thermal health
- Investigation date: 2026-07-27
- Source retrieval date: 2026-07-27
- Target: validated HP ZBook Firefly 14 inch G8 lab computer
- Outcome: **inconclusive**
- Live Windows changes: none
- Performance claim: none
- Raw observation:
  [layer-01-physical-thermal-2026-07-27.json](layer-01-physical-thermal-2026-07-27.json)

## Evidence question

Can supported, already available Windows and HP surfaces provide a trustworthy,
low-overhead CPU/package temperature, ambient-temperature, and fan-state gate
for unattended EXP-001 startup measurements?

## Decision

Not yet. The current inbox, non-elevated observation could not identify a
trustworthy CPU/package temperature, ambient temperature, or fan state. Do not
invent a thermal readiness band, translate an unidentified ACPI zone into a CPU
temperature, calculate battery health without design capacity, or change fan,
Intel Dynamic Tuning Technology (DTT), cooling, firmware, or power settings.

The layer is recorded as inconclusive and advances to layer 2. A later
instrumentation experiment must identify the sensor, units, sampling behavior,
access requirements, overhead, and relationship to throttling before thermal
data can accept or reject a performance run.

## Documented facts

- Microsoft describes Windows thermal management as a cooperative
  firmware/OS/driver system based on abstract ACPI thermal zones. A zone can
  contain several heat-generating or managed devices; a zone reading is not
  automatically a CPU package temperature.
- Microsoft's `Win32_TemperatureProbe` documentation says current WMI
  implementations do not populate `CurrentReading`; the property is reserved
  for future use.
- Microsoft's PwrTest thermal scenario monitors ACPI thermal-zone information
  only on systems that report thermal zones and temperature changes. PwrTest is
  a Windows Driver Kit test tool, not an inbox command guaranteed on customer
  Windows installations.
- HP documents a Fan Speed Test and a roughly 320-second Fan Thermal Test in HP
  PC Hardware Diagnostics. Those are interactive diagnostic tests and are not
  treated as unattended benchmark instrumentation.
- Intel documents DTT as an OEM-configured system that coordinates performance,
  power, acoustics, and thermals. Intel explicitly advises against disabling,
  removing, or uninstalling DTT because doing so can cause unexpected behavior
  or thermal/power violations.
- Microsoft documents full-charge capacity and cycle-count surfaces, but
  full-charge capacity must be compared with design capacity before battery
  wear can be estimated.

## Lab measurements

The observation ran without elevation and made no configuration change.

- System: HP ZBook Firefly 14 inch G8, Windows build 26200, BIOS T76
  01.24.02.
- Seven signed Microsoft `ACPI Thermal Zone` device instances were present,
  using `machine.inf` driver version `10.0.26100.1150`.
- Querying `MSAcpi_ThermalZoneTemperature` returned access denied in the
  non-elevated run. This does not prove that the firmware exposes no thermal
  zones.
- `Win32_TemperatureProbe`, `Win32_Fan`, and `BatteryTemperature` returned no
  instances/readings.
- PwrTest was not installed.
- HP PC Hardware Diagnostics Windows, HP Support Assistant, and an `HP_TOOLS`
  volume were not detected by the inspected Windows inventory surfaces. This
  does not prove that firmware diagnostics are unavailable.
- Signed Intel DTT Manager, two Generic Participants, and a Processor
  Participant were present at version `8.7.10802.26924`.
- The battery reported AC online, not charging or discharging, not critical,
  full/remaining capacity `41407`, cycle count `101`, and voltage `12560`.
  `BatteryStaticData` did not provide design capacity, so no wear percentage
  was calculated.

These are single read-only observations, not repeated benchmark measurements.

## Hypotheses

- An elevated ACPI query may expose zone data, but zone identity and relevance
  to CPU-package readiness would still need proof.
- A trusted vendor sensor already installed in a future configuration may
  provide package temperature and throttling evidence with measurable overhead.
- Manual HP fan diagnostics may establish hardware function, but they will not
  necessarily provide continuous, timestamped readiness telemetry.

## Compatibility limits and risks

- The inventory applies only to the recorded ZBook, Windows build, BIOS, and
  installed driver set.
- ACPI thermal-zone names and thresholds are firmware-defined and can change
  with BIOS or driver updates.
- Installing a sensor tool, WDK/PwrTest, HP diagnostics, or a driver would
  change the environment and requires a separate support, provenance, overhead,
  and rollback design.
- Running a fan or CPU stress diagnostic can heat the computer and contaminate
  the next performance run.
- Disabling DTT or forcing fan behavior is rejected for this layer.

## Unresolved questions

1. Which sensor can identify CPU/package temperature and throttling on this
   exact ZBook without unsupported drivers?
2. What elevation is required, and can collection run as a bounded,
   observation-only task?
3. What is the instrumentation overhead at the selected sample rate?
4. How will ambient temperature and fan state be recorded?
5. What pre-run thermal band and settling duration are repeatable?
6. Can HP diagnostics produce a supportable, exportable result without adding
   background components to the benchmark environment?

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: ACPI-defined devices and thermal zones](https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/acpi-defined-devices)
- [Microsoft: PC thermal-management design guide](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/design-guide)
- [Microsoft: Win32_TemperatureProbe](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-temperatureprobe)
- [Microsoft: PwrTest thermal scenario](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pwrtest-thermal-scenario)
- [Microsoft: battery WMI cycle count](https://learn.microsoft.com/en-us/windows/win32/api/batclass/ns-batclass-battery_wmi_cycle_count)
- [Microsoft: Win32_Battery](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-battery)
- [HP: Testing for hardware failures](https://support.hp.com/us-en/document/ish_2854458-2733239-16)
- [HP: ZBook Firefly 14 G8 support and maintenance guides](https://support.hp.com/ph-en/product/setup-user-guides/hp-zbook-firefly-14-inch-g8-mobile-workstation-pc/model/2100000210)
- [Intel: Dynamic Tuning Technology overview](https://www.intel.com/content/www/us/en/support/articles/000102775/processors.html)
- [Intel: Risks of disabling Dynamic Tuning Technology](https://www.intel.com/content/www/us/en/support/articles/000090464/graphics.html)
