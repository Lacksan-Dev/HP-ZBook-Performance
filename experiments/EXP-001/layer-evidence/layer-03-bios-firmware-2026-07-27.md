# EXP-001 layer 3 evidence: firmware inventory is not a startup tweak

- Layer: 3, BIOS, UEFI, embedded-controller, and firmware interactions
- Investigation date: 2026-07-27
- Source retrieval date: 2026-07-27
- Target: validated HP ZBook Firefly 14 inch G8 lab computer
- Outcome: **inconclusive**
- Live Windows or firmware changes: none
- Performance claim: none
- Raw observation:
  [layer-03-bios-firmware-2026-07-27.json](layer-03-bios-firmware-2026-07-27.json)

## Evidence question

Can documented and inbox firmware surfaces identify a supported, reversible
BIOS or firmware change that improves startup on the exact lab ZBook without
installing firmware, rebooting, or weakening security and recovery?

## Decision

No. The read-only inventory establishes the platform's reported BIOS,
embedded-controller, boot mode, and Windows firmware-device identity. It does
not establish that firmware is a startup bottleneck or identify a supported
performance setting.

Do not change Fast Boot, boot order, Secure Boot, thermal, fan, power, or other
BIOS settings; do not install or downgrade firmware. The exact T76 package,
release notes, setting prerequisites, current Secure Boot state, downgrade
boundary, and firmware-time measurements remain unresolved. The layer is
preserved as inconclusive and advances to layer 4.

## Documented facts

- Microsoft documents `Win32_BIOS` as a read-only representation of installed
  BIOS attributes, including SMBIOS version, release date, and embedded-
  controller version. Inventory is not a performance measurement.
- Microsoft documents `Confirm-SecureBootUEFI` as requiring an administrator
  PowerShell session. Its documented non-administrator result is access denied;
  that error does not reveal whether Secure Boot is enabled.
- Windows supports OEM firmware delivery through driver packages using the UEFI
  UpdateCapsule path. The existence of a Windows firmware device therefore does
  not itself prove that a newer or applicable package is available.
- HP documents the `root\HP\InstrumentedBIOS` classes used to enumerate setting
  names, values, allowed values, read-only status, physical-presence
  requirements, prerequisites, and boot-order lists. HP also exposes supported
  query/update functions through its Client Management Script Library.
- HP says a business-notebook BIOS update must come from HP, match the computer,
  remain connected to external power, and be compatible with the management
  environment.
- HP documents model-dependent BIOS recovery limits. HP Sure Start systems do
  not use the same manual USB/key recovery methods as systems without Sure
  Start.
- HP explicitly documented a 2021 T76-family release for this ZBook family that
  did not allow BIOS rollback after successful installation. That historical
  boundary means exact rollback cannot be assumed for the current firmware.
- HP's March 2024 notice identifies the ZBook Firefly 14 G8 family with BIOS
  family T76 version 01.16.00. It does not document the observed 01.24.02
  package, so it is not used as proof that the lab version is latest or
  downgrade-capable.

## Lab measurements

The observation was read-only and non-elevated.

- System: HP ZBook Firefly 14 inch G8 Mobile Workstation PC, SKU
  `4P803UT#ABA`, board `880D`.
- Boot path: Windows reported UEFI firmware mode and a GPT boot/system disk.
- BIOS: HP `T76 Ver. 01.24.02`, release date 2026-05-04, SMBIOS 3.3.
- Embedded controller: SMBIOS major/minor values 48/87; the board inventory
  reported KBC version `30.57.00`. These are consistent decimal/hexadecimal
  representations, not a performance result.
- Windows firmware device: `HP T76 System Firmware`, status `OK`, provider HP,
  driver version `1.24.2.0`, driver date 2026-05-04, INF `oem100.inf`.
  Three other generic Microsoft firmware devices reported `OK`.
- HP's Instrumented BIOS namespace and relevant classes were present. Reading
  `HP_BIOSEnumeration`, `HP_BIOSOrderedList`, and `HP_BIOSInteger` instances
  returned access denied. The unattended run did not elevate.
- `Confirm-SecureBootUEFI` returned its documented non-administrator access-
  denied result. Secure Boot state is recorded as unknown.

These are static inventory observations. No firmware time, Windows startup
interval, usable-state timestamp, trace, benchmark, repeated run, or control
run was captured.

## Hypotheses

- A firmware or embedded-controller phase may contribute to power-button-to-
  usable time, but only a controlled startup protocol that separates firmware
  time from Windows initialization can test that claim.
- An applicable HP firmware release may contain reliability, compatibility, or
  security fixes. That is not evidence of a startup improvement and requires
  exact package applicability and release-note review.
- One or more HP BIOS settings may affect startup behavior. Their actual names,
  current values, allowed values, prerequisites, security effects, and reboot
  behavior must be enumerated before any experiment can be proposed.

## Compatibility, security, and rollback limits

- This inventory applies only to the recorded model, SKU, board, T76 BIOS,
  embedded-controller version, Windows firmware-device state, and collection
  conditions.
- A BIOS setting is not supported merely because a similar name appears on
  another HP model. The exact platform must expose the setting and its allowed
  values through a supported interface.
- Any future firmware change needs external power, exact HP package/model/board
  matching, signature and version validation, BitLocker recovery planning,
  management approval where applicable, a documented recovery path, and post-
  reboot verification.
- Firmware recovery is not equivalent to guaranteed downgrade. HP has published
  no-rollback firmware for this product family, so the project's usual promise
  of exact script-level rollback cannot be made without package-specific proof.
- Secure Boot, BitLocker, HP Sure Start/recovery, Windows Update, and management
  controls remain unchanged.

## Unresolved questions

1. Which exact HP SoftPaq or Windows Update package installed T76 01.24.02, and
   what models, boards, prerequisites, fixes, and downgrade rules does it list?
2. Is HP Sure Start active on this exact system, and which recovery method does
   HP support for the installed firmware?
3. What are the actual HP BIOS setting names, current values, allowed values,
   prerequisites, physical-presence requirements, and read-only flags in an
   approved elevated inventory?
4. Is Secure Boot enabled, and what BitLocker protector/recovery readiness would
   a future firmware experiment require?
5. What is the repeated power-button-to-firmware-handoff interval under the
   accepted startup protocol, and what is the instrumentation overhead?
6. Does any documented, reversible setting improve the declared usable-state
   median without harming security, recovery, device readiness, or reliability?

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: Win32_BIOS class](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-bios)
- [Microsoft: Confirm-SecureBootUEFI](https://learn.microsoft.com/en-us/powershell/module/secureboot/confirm-securebootuefi?view=windowsserver2025-ps)
- [Microsoft: Windows UEFI firmware update platform](https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/windows-uefi-firmware-update-platform)
- [HP: BIOS and Device management interfaces](https://developers.hp.com/hp-client-management/doc/bios-and-device)
- [HP: Understanding HP BIOS settings](https://developers.hp.com/hp-client-management/doc/understanding-hp-bios-settings)
- [HP: Business notebook BIOS update guidance](https://support.hp.com/emea_africa-en/document/ish_4208192-2358829-16)
- [HP: Notebook BIOS recovery guidance](https://support.hp.com/us-en/document/ish_3932413-2337994-16)
- [HP: ZBook Firefly 14 G8 support page](https://support.hp.com/us-en/product/setup-user-guides/hp-zbook-firefly-14-inch-g8-mobile-workstation-pc/2100000206)
- [HP: September 2021 commercial BIOS release - no rollback](https://support.hp.com/gb-en/document/ish_4784771-4784815-16)
- [HP: March 2024 BIOS refresh for 2021 notebooks](https://support.hp.com/us-en/document/ish_10322031-10322082-16)
