# EXP-001 layer 3 - firmware boundary profile

- Cycle trigger: 2026-07-31T07:29:31Z
- Final passive capture: 2026-07-31T07:36:21Z to
  2026-07-31T07:36:34Z
- Layer: 3 - BIOS, UEFI, embedded-controller, and firmware interactions
- Outcome: implemented
- Evidence state: observation-only baseline; no BIOS setting instance,
  firmware variable, Secure Boot state, boot configuration, driver, registry
  value, policy, service, task, power setting, or Windows setting changed
- Implementation commit: `ab775c0e792722c34af173a0f8582850a071682a`
- Private raw evidence identifier:
  `20260731-073634-095-530d04f1-firmware-boundary-profile.json`

## Customer-visible interval and engineering responsibility

Layer 3 owns the pre-OS firmware boundary and the firmware contracts exposed to
Windows after boot. A slow power-button-to-sign-in interval may contain
firmware initialization, device discovery, boot-manager, kernel, and session
work. Windows cannot reconstruct the complete pre-OS duration from a normal
post-boot inventory, so this run does not pretend that a BIOS query measures
boot time.

The selected interval begins immediately before a documented firmware-type
query and bounded BIOS-provider query and ends when those queries return.
Separate timers cover the optional Secure Boot status attempt and HP BIOS WMI
class-metadata inventory. Windows owns `GetFirmwareType`, `Win32_BIOS`, the
Secure Boot PowerShell cmdlet, CIM, and the boot/security boundary. HP owns the
T76 firmware, embedded controller, supported update and recovery packages, and
its BIOS WMI provider. UX-ROM owns provider detection, bounds, timing,
redaction, structured evidence, and conservative interpretation.

Inputs are the documented kernel API, inbox BIOS provider, optional Secure
Boot cmdlet, optional HP BIOS WMI namespace, and a bounded calibration count.
Outputs are UEFI/legacy mode, BIOS and SMBIOS identity, raw embedded-controller
version fields, Secure Boot query availability, HP BIOS class names, query
cost, and an explicit baseline-only decision. No BIOS setting name or value,
password, serial number, UUID, asset tag, firmware variable, key, or
certificate is collected.

Failure is contained to a structured unavailable status. The capability does
not request elevation. It has no firmware write path, so rollback and reboot
persistence do not apply.

## Verified primary sources

Sources retrieved 2026-07-31:

- Microsoft Learn,
  [GetFirmwareType](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getfirmwaretype):
  documents the Windows 8-and-later API used to identify the boot firmware
  type.
- Microsoft Learn,
  [FIRMWARE_TYPE](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ne-winnt-firmware_type):
  documents the returned Unknown, BIOS, and UEFI values.
- Microsoft Learn,
  [Win32_BIOS](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-bios):
  documents the SMBIOS version, BIOS release date, embedded-controller raw
  fields, and status used by the redacted inventory.
- Microsoft Learn,
  [Confirm-SecureBootUEFI](https://learn.microsoft.com/en-us/powershell/module/secureboot/confirm-securebootuefi):
  documents the read-only UEFI Secure Boot query and that access can require
  administrator rights. UX-ROM records an unavailable status rather than
  prompting for elevation.
- HP,
  [HP BIOS Configuration Utility FAQ](https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/HP_BCU_FAQ.pdf):
  documents HP's InstrumentedBIOS WMI namespace and provider availability
  boundary. UX-ROM enumerates class metadata only and does not use BCU or call
  a setting interface.
- HP,
  [HP Tools for PC Deployment](https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/HP_Tools_for_PC_Deployment.pdf):
  describes supported HP management tooling and deployment ownership.
- Microsoft Learn,
  [Stopwatch](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.stopwatch?view=netframework-4.8.1):
  documents the monotonic elapsed-time source used for observer qualification.

No community registry value, undocumented firmware contract, BIOS setting
change, firmware package, Secure Boot change, or performance claim is used.

## Candidate scoring and selection

Scores use a 0-5 scale for verified evidence, expected relevance,
reversibility, exact-system support, measurability, and engineering leverage.

| Candidate | Evidence | Relevance | Reversible | Support | Measurable | Leverage | Total | Decision |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Redacted firmware boundary and provider-cost profile | 5 | 5 | 5 | 5 | 5 | 5 | 30 | Selected |
| Read every HP BIOS setting instance | 4 | 4 | 5 | 4 | 3 | 3 | 23 | Rejected; unnecessary setting and privacy exposure |
| Change a BIOS performance setting | 3 | 5 | 1 | 2 | 3 | 3 | 17 | Rejected; no Tier 3 recovery evidence or selected supported control |
| Install or flash a firmware package | 4 | 4 | 1 | 1 | 3 | 2 | 15 | Rejected; no disposable target or external recovery gate |
| Infer pre-OS duration from undocumented registry data | 1 | 5 | 5 | 1 | 1 | 1 | 14 | Rejected; unsupported and not a valid interval |

## Pre-registered experiment design

Hypothesis: documented Windows and HP discovery interfaces can give UX-ROM a
bounded, redacted map of the firmware boundary and its observer cost without
reading settings or changing firmware, making later boot-path experiments
safer and more precise.

Controlled variable: instrumentation implementation only. Firmware, Windows,
and workload state remain unchanged.

Benchmark:

1. verify `GetFirmwareType` and every required `Win32_BIOS` field;
2. warm the combined firmware-type and BIOS query once;
3. time three calibration queries and retain a distribution;
4. make one final bounded core query;
5. attempt the documented Secure Boot status query without elevation;
6. enumerate only HP BIOS WMI class metadata with a five-second timeout;
7. save unique structured evidence; and
8. make no boot-time or performance decision from this inventory.

Engineering decision rule:

1. the PowerShell parser reports zero errors;
2. focused and full required Pester suites pass;
3. the core query p95 is below one second;
4. optional probes terminate within five seconds;
5. evidence says HP setting instances were not read and no write interface was
   invoked;
6. source and tests contain no reachable firmware-mutation command;
7. the result contains no sensitive identifier or firmware setting value; and
8. the result makes no performance-gain or firmware-recommendation claim.

Risks are provider delay, unavailable Secure Boot status without elevation,
and misreading SMBIOS raw fields as tuning advice. Five-second CIM timeouts,
explicit unavailable states, raw-field labels, and a baseline-only decision
bound those risks.

## Engineering result

`ZBookPerf.ps1` now exposes `-Action FirmwareProfile`, the equivalent
`-FirmwareProfile` switch, bounded calibration, Layer 3 workflow routing, and
single full-diagnostics integration. UX-ROM version is `2026.07.31.1`.

The capability:

1. identifies the boot firmware through `GetFirmwareType`;
2. verifies and reads a redacted `Win32_BIOS` projection;
3. preserves SMBIOS and embedded-controller fields as raw identity data;
4. attempts the documented Secure Boot status query without UAC elevation;
5. enumerates only HP BIOS WMI class names, not setting instances;
6. warms and calibrates the complete core observer;
7. bounds CIM calls to five seconds;
8. writes unique structured JSON while preserving primary evidence if the
   optional event journal fails; and
9. explicitly states that the profile cannot measure pre-OS duration or prove
   a BIOS setting is optimal.

## Final lab validation

Target and controlled conditions:

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Windows 11 Pro build 26200
- BIOS T76 01.24.02, reported release date 2026-05-04
- Intel Core i5-1145G7, 4 cores / 8 logical processors
- AC online; Battery Saver off; Balanced power scheme
- no setting change, elevation request, reboot, firmware variable access, BIOS
  instance read, or firmware package execution

Final observation:

- PowerShell parser: 0 errors.
- Focused Pester 5.7.1 suite: 92 passed, 0 failed.
- Full repository-required EXP-001 Pester suite: 100 passed, 0 failed.
- Firmware type: UEFI.
- BIOS status: OK; SMBIOS 3.3.
- Embedded-controller raw fields: 48.87. No semantic or performance meaning is
  inferred.
- Observer calibration: 3 iterations; 20.319 ms median and 27.465 ms p95.
- Final core query: 20.778 ms.
- Secure Boot query: unavailable with `UnauthorizedAccessException` in
  121.779 ms; the tool did not elevate.
- HP BIOS interface: 12 matching class names found from metadata in 107.48 ms.
- HP BIOS setting instances read: false.
- HP BIOS write interface invoked: false.
- Decision: `BaselineOnlyNoPerformanceClaim`.

The live capture and complete required test suite passed the pre-registered
timing, redaction, and no-mutation gates. The baseline security inventory emits
expected non-elevated BitLocker access diagnostics on this host while its
tests pass; the new firmware profiler did not request elevation. It establishes
the supported firmware observation boundary. It does not measure
power-button-to-sign-in duration, compare a BIOS setting, establish firmware
optimality, or validate a performance improvement.

## Decision and next layer

Accept the observation-only firmware-boundary profiler as an Experimental
Layer 3 capability, subject to the GitHub merge gates.

No validated performance improvement occurred, so this run does not qualify
for email, YouTube, or website publication.

Next cycle: Layer 4 - platform drivers and OEM components. Start with a
redacted, bounded driver/OEM ownership and compatibility profiler before any
package or device-power change.
