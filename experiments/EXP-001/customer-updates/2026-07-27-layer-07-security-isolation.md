# Layer 7: protection status is not overhead evidence

- Date: 2026-07-27
- Layer: security and isolation overhead without reducing protection
- Evidence state: **inconclusive**
- Live status: read-only protection inventory; no setting was applied
- Performance claim: none

## What was investigated

The lab read Microsoft Defender Antivirus, effective Windows Firewall, and
Windows virtualization-based security status. Defender reported antivirus,
real-time, behavior, on-access, IOAV, network inspection, and tamper protection
enabled. All Domain, Private, and Public firewall profiles were enabled with
effective inbound-block and outbound-allow defaults.

Windows reported VBS and Memory Integrity running. The same supported WMI
surface reported Credential Guard running and kernel/user-mode code-integrity
policy enforcement. The responsible policy and management origin were not
identified.

BitLocker and Secure Boot status checks were denied without elevation. Their
state is unknown, not off.

## Why no tweak was selected

Protection state is not a measurement of startup or responsiveness overhead.
No Defender performance recording, WPR trace, customer workflow, repeated raw
run, median, or instrumentation-overhead qualification ran.

Microsoft provides a Defender performance analyzer for diagnosing scan cost.
Microsoft also warns that every Defender exclusion is a protection gap and
recommends keeping Windows Firewall enabled. The experiment therefore did not
disable Defender, add exclusions, stop the firewall, disable VBS/Memory
Integrity/Credential Guard, change code-integrity policy, suspend BitLocker, or
change Secure Boot.

## Supported system and limits

The observation applies to the HP ZBook Firefly 14 inch G8 recorded in EXP-001,
running Windows 11 Pro build 26200, BIOS T76 01.24.02, and Defender platform
4.18.26060.3008.

The Defender analyzer commands are present, but their elevated ETL recording
was not run. Such a recording can include file and process paths, so it needs a
synthetic workflow, approved storage/retention, redaction, and measured
instrumentation overhead.

## Change and rollback status

No protection, exclusion, scan, firewall profile/rule/service, VBS, Memory
Integrity, Credential Guard, code integrity, BitLocker, Secure Boot, update,
recovery, management, driver, service, task, policy, registry, firmware, or OEM
setting changed. Rollback is not applicable.

## Next evidence

Layer 8 examines the boot path, services, scheduled tasks, background
permissions, and startup applications. Every item remains required until
vendor documentation, dependency analysis, and boot-trace evidence establish a
safe narrower state.

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: tamper protection](https://learn.microsoft.com/en-us/defender-endpoint/prevent-changes-to-security-settings-with-tamper-protection)
- [Microsoft: Defender performance analyzer](https://learn.microsoft.com/en-us/defender-endpoint/tune-performance-defender-antivirus)
- [Microsoft: Defender exclusions](https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-antivirus-exclusions-overview)
- [Microsoft: Memory Integrity and VBS](https://learn.microsoft.com/en-us/windows/security/hardware-security/enable-virtualization-based-protection-of-code-integrity)
- [Microsoft: Credential Guard](https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/)
- [Microsoft: Windows Firewall](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/)
- [Microsoft: `Get-BitLockerVolume`](https://learn.microsoft.com/en-us/powershell/module/bitlocker/get-bitlockervolume)
- [Microsoft: BitLocker FAQ](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/faq)
