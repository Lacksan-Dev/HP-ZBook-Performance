# EXP-001 layer 7 evidence: protection status is not overhead evidence

- Layer: 7, security and isolation overhead without reducing protection
- Investigation date: 2026-07-27
- Source retrieval date: 2026-07-27
- Target: validated HP ZBook Firefly 14 inch G8 lab computer
- Outcome: **inconclusive**
- Evidence state: read-only protection inventory; not baseline-eligible
- Live Windows changes: none
- Performance claim: none
- Raw observation:
  [layer-07-security-isolation-2026-07-27.json](layer-07-security-isolation-2026-07-27.json)

## Evidence question

Does the current Defender, firewall, virtualization-based security, code
integrity, encryption, and Secure Boot inventory identify one supported
security-preserving change that improves startup or responsiveness?

## Decision

No. Microsoft Defender Antivirus reported its real-time protection components
and tamper protection enabled. The effective Windows Firewall `ActiveStore`
reported all three profiles enabled with inbound traffic blocked and outbound
traffic allowed by default. `Win32_DeviceGuard` reported VBS and Memory
Integrity running; it also reported Credential Guard running and kernel/user
mode code-integrity policy enforcement.

These are protection states, not latency or overhead measurements. No Defender
performance recording, WPR trace, startup/readiness workflow, repeated raw run,
median, or instrumentation-overhead qualification ran. BitLocker and Secure
Boot status checks returned access denied without elevation, so their state
remains unknown.

Do not disable Defender, add speculative exclusions, stop the firewall service,
disable a firewall profile, disable VBS, Memory Integrity, Credential Guard, or
code-integrity enforcement, suspend/decrypt BitLocker, or change Secure Boot
from this inventory. Preserve the result as inconclusive and advance to layer
8.

## Documented facts

- Microsoft documents `Get-MpComputerStatus` as the supported PowerShell check
  for tamper-protection and real-time-protection state.
- Microsoft Defender's performance analyzer records antimalware-engine events
  and reports scan duration by path, file, process, extension, and combinations.
  It requires a supported Defender platform, an appropriate PowerShell version,
  and an elevated recording.
- Microsoft warns that every Defender exclusion is a protection gap. An
  exclusion must address a demonstrated compatibility or performance problem,
  not a guessed future problem.
- Microsoft documents `Win32_DeviceGuard` as the VBS and Memory Integrity
  inventory surface. On that surface, status `2` means VBS is enabled and
  running; running-service code `1` means Credential Guard and code `2` means
  Memory Integrity.
- Memory Integrity uses VBS and the Windows hypervisor to isolate kernel-mode
  code-integrity decisions. Microsoft notes that it works better on processors
  with MBEC/GMET and that incompatible applications or drivers can malfunction.
  Compatibility must be tested before changing deployment state.
- Credential Guard isolates qualifying credentials with VBS. Microsoft lists
  licensing and application-compatibility boundaries and says Windows 11 Pro
  devices can still report VBS or Credential Guard after a prior eligible
  configuration. A running-state code does not establish the policy or license
  origin.
- The Windows Firewall `ActiveStore` is the resultant set of applicable local,
  service-hardening, CSP, and Group Policy stores. Microsoft recommends keeping
  default firewall settings and specifically says not to disable the firewall
  or stop the `MpsSvc` service for performance.
- `Get-BitLockerVolume` can report protection state and encryption method, but
  the non-elevated lab check was denied. Microsoft says BitLocker overhead is
  typically small and workload-dependent; this generic statement is not a
  measurement of the lab computer.

## Lab measurements

The observation was read-only and non-elevated on an AC-connected HP ZBook
Firefly 14 inch G8 running Windows 11 Pro build 26200 and BIOS T76 01.24.02.
No security trace, startup/readiness run, responsiveness workload, scan, or
performance benchmark ran.

### Microsoft Defender Antivirus

| Observation | State |
| --- | --- |
| Running mode | Normal |
| Antivirus / antispyware | Enabled / enabled |
| Real-time / on-access protection | Enabled / enabled |
| Behavior monitor / IOAV / network inspection | Enabled / enabled / enabled |
| Tamper protection | Enabled |
| Signatures out of date | No |
| Defender platform | 4.18.26060.3008 |
| Performance analyzer commands | Present; recording not run |

The raw evidence records the signature version and update timestamp. It does
not enumerate exclusions, because exclusion paths can reveal private data and
their presence alone would not prove performance impact.

### Firewall, VBS, and isolation

All Domain, Private, and Public firewall profiles were enabled in the effective
`ActiveStore`. Each reported default inbound `Block` and default outbound
`Allow`. Rules were not enumerated, and no network workflow was run.

`Win32_DeviceGuard` returned:

- VBS status `2`: enabled and running;
- configured service code `2`: Memory Integrity configured;
- running service codes `1` and `2`: Credential Guard and Memory Integrity
  running;
- kernel and user-mode code-integrity enforcement status `2`: enforced; and
- available-property codes for hypervisor support, Secure Boot, DMA protection,
  NX, SMM mitigations, MBEC/GMET, and APIC virtualization.

The WMI result does not identify the responsible policy, management authority,
license history, or specific code-integrity policy. Those were not inferred.

### Unavailable state

`Get-BitLockerVolume` and `Confirm-SecureBootUEFI` returned access denied
without elevation. No elevation was attempted. BitLocker protection, cipher,
and Secure Boot enabled state therefore remain unknown; “access denied” does
not mean those protections are off.

## Hypotheses

- Defender scan activity may contribute to variability for a specific startup
  or application workflow, but only a bounded performance recording aligned to
  repeated synthetic runs can attribute it.
- VBS, Memory Integrity, Credential Guard, or code-integrity enforcement may
  affect some workloads, drivers, or authentication paths, but the current
  inventory contains no measured customer impact and does not justify
  weakening them.
- A security-related startup delay, if one exists, may be better addressed by a
  supported application, file-layout, driver, signing, or workflow correction
  than by changing protection.
- BitLocker could add storage-workload-dependent overhead, but its state and the
  target storage workload were not measured.

## Compatibility, dependency, and rollback limits

- The inventory applies only to the recorded model, Windows build, BIOS,
  Defender platform/signature state, firewall `ActiveStore`, and VBS state.
- A Defender performance recording requires elevation and can expose file and
  process paths. A future run needs synthetic data, approved output location,
  retention, redaction, explicit stop/cleanup, and an overhead comparison.
- VBS and Memory Integrity depend on compatible firmware, virtualization
  support, and drivers. Credential Guard has licensing and authentication
  compatibility limits. Code-integrity policy identity and origin must be known
  before proposing any configuration experiment.
- Firewall profile state and effective policy can be produced by multiple
  stores. No firewall change may override domain, Entra, MDM, CSP, service
  hardening, or application requirements.
- BitLocker work must preserve recovery readiness and never expose recovery
  material. Secure Boot, TPM, BitLocker, Windows Recovery, update, and
  management dependencies must be treated as one recovery boundary.
- No configuration changed, so rollback is not applicable. Any future
  modification still requires support detection, original-state capture, dry
  run, apply, verification, structured logging, idempotence, exact rollback,
  rollback verification, and reboot-persistence testing.
- Defender/EDR, firewall, VBS, Memory Integrity, Credential Guard, code
  integrity, BitLocker, Secure Boot, Windows Update, recovery, management,
  services, tasks, drivers, firmware, policy, and registry were untouched.

## Supported measurement path

1. Define one synthetic customer workflow with start, readiness, reset, timeout,
   and failure rules.
2. Record the protection state at every run boundary without enumerating
   exclusions, identities, recovery material, or customer content.
3. In a supervised elevated window, run
   `New-MpPerformanceRecording` only around the reproduction, then analyze the
   ETL with `Get-MpPerformanceReport`.
4. Qualify recording overhead with interleaved control runs while keeping every
   protection enabled.
5. Preserve raw runs, failed/inconclusive runs, medians, variability, thermal
   and power controls, and trace-to-workflow timestamps.
6. If a specific hotspot is demonstrated, prefer a vendor-supported
   application, driver, data-layout, or workload correction. An exclusion is
   not a default optimization and remains a protection reduction requiring a
   separate security review.

## Unresolved questions

1. What protected synthetic workflow is most likely to reproduce a reported
   delay, and what is its accepted readiness endpoint?
2. What overhead does the Defender performance recorder add to that workflow?
3. Which exact paths, files, extensions, or processes account for measured
   Defender scan duration, if any?
4. What policy, license history, or management authority explains the observed
   Credential Guard and code-integrity state?
5. What are the BitLocker protection method and Secure Boot state when checked
   in a supervised elevated window without exposing protectors?
6. Can WPR attribute a delay to security, filter, driver, storage, or
   authentication work while the protection configuration remains constant?
7. What reproducibility and customer-impact decision rule permits a supported
   non-security-reducing change?

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: tamper protection and `Get-MpComputerStatus`](https://learn.microsoft.com/en-us/defender-endpoint/prevent-changes-to-security-settings-with-tamper-protection)
- [Microsoft: Defender Antivirus performance analyzer](https://learn.microsoft.com/en-us/defender-endpoint/tune-performance-defender-antivirus)
- [Microsoft: Defender Antivirus exclusions](https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-antivirus-exclusions-overview)
- [Microsoft: enable and validate Memory Integrity/VBS](https://learn.microsoft.com/en-us/windows/security/hardware-security/enable-virtualization-based-protection-of-code-integrity)
- [Microsoft: Credential Guard overview and limits](https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/)
- [Microsoft: Windows Firewall overview](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/)
- [Microsoft: Windows Firewall rules and recommendations](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/rules)
- [Microsoft: `Get-NetFirewallProfile`](https://learn.microsoft.com/en-us/powershell/module/netsecurity/get-netfirewallprofile)
- [Microsoft: `Get-BitLockerVolume`](https://learn.microsoft.com/en-us/powershell/module/bitlocker/get-bitlockervolume)
- [Microsoft: BitLocker FAQ](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/faq)
