# EXP-001 progress report: thermal telemetry is not ready

- Date: 2026-07-27
- Cycle layer: 1, physical and thermal health
- Evidence state: inconclusive
- Live Windows changes: none
- Performance claim: none
- Next layer: 2, hardware resources and bottlenecks

## What was investigated

The lab asked whether already available Windows and HP surfaces could provide a
trustworthy CPU/package temperature, ambient-temperature, and fan-state gate
for unattended startup measurements.

They cannot yet. Windows reported seven ACPI thermal-zone devices and the
installed Intel Dynamic Tuning components, but the non-elevated inbox
interfaces did not provide an identified CPU/package temperature or fan state.
The project will not relabel an abstract ACPI zone as a CPU sensor or invent a
thermal readiness threshold.

## Exact findings

- No `Win32_TemperatureProbe`, `Win32_Fan`, or `BatteryTemperature` reading was
  available.
- The non-elevated `MSAcpi_ThermalZoneTemperature` query returned access
  denied.
- PwrTest, HP PC Hardware Diagnostics Windows, HP Support Assistant, and an
  `HP_TOOLS` volume were not detected by the inspected Windows surfaces.
- Signed Intel DTT components were present at version `8.7.10802.26924`.
- Battery full-charge capacity and 101 cycles were readable, but design
  capacity was not. No battery-health percentage was calculated.

## Supported limits and safety

Microsoft defines ACPI thermal zones as firmware-described abstractions, not
guaranteed CPU-package sensors. HP provides manual fan diagnostics, including a
Fan Thermal Test, but that stress-oriented test is not unattended benchmark
instrumentation. Intel explicitly advises against disabling DTT.

No driver, service, policy, task, registry value, firmware option, fan behavior,
power setting, or Windows security/update control was changed. Installing new
diagnostics or sensor software requires a separate provenance, support,
overhead, logging, and rollback experiment.

## Evidence ledger

### Documented facts

- ACPI thermal zones require firmware, Windows, and driver cooperation.
- `Win32_TemperatureProbe.CurrentReading` is not populated by current WMI
  implementations.
- HP's fan diagnostics are explicit diagnostic runs.
- Intel DTT coordinates OEM thermal/power behavior and should not be disabled.

### Lab measurements

One observation-only inventory was captured. No repeated thermal samples,
ambient reading, stress test, or startup benchmark was run.

### Hypotheses

An elevated, identified ACPI or trusted vendor sensor may provide useful data,
but its identity, overhead, and relationship to throttling remain unproven.

### Unresolved questions

- Which trustworthy sensor is available for this exact ZBook?
- What elevation and sampling overhead does it require?
- How should ambient temperature, fan state, settling time, and a pre-run band
  be recorded?

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: ACPI-defined devices](https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/acpi-defined-devices)
- [Microsoft: Win32_TemperatureProbe](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-temperatureprobe)
- [Microsoft: PwrTest thermal scenario](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pwrtest-thermal-scenario)
- [HP: Testing for hardware failures](https://support.hp.com/us-en/document/ish_2854458-2733239-16)
- [Intel: Dynamic Tuning Technology overview](https://www.intel.com/content/www/us/en/support/articles/000102775/processors.html)
- [Intel: Risks of disabling DTT](https://www.intel.com/content/www/us/en/support/articles/000090464/graphics.html)
