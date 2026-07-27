# Layer 9: a popular registry shortcut is rejected

- Date: 2026-07-27
- Layer: Group Policy, MDM-aware policy, registry, and system configuration
- Evidence state: **rejected**
- Live status: research-only; nothing was implemented or applied on the lab machine
- Performance claim: none

## What was investigated

Community performance projects recommend creating:

- Path:
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize`
- Value: `StartupDelayInMSec`
- Proposed type: `REG_DWORD`
- Proposed data: `0`

The key and value are absent on this HP ZBook.

## Why it was rejected

A bounded search of current Microsoft Learn, Microsoft Support, Windows logon
Policy CSP documentation, and Microsoft startup-app guidance found no
primary-source definition, supported Windows boundary, documented default,
compatibility contract, management precedence, or rollback guidance for this
value. The exact name appeared in community advice, not in the reviewed
Microsoft product documentation.

Microsoft documents safer per-app startup controls and startup-impact
measurement. It also documents that startup applications consume CPU and disk
resources. Launching every staged item sooner could move more work into the
foreground-readiness interval rather than shorten it.

## Lab and management limits

The observation applies to the recorded HP ZBook Firefly 14 inch G8, Windows 11
Pro build 26200, BIOS T76 01.24.02, and current-user registry state.

The utility's read-only audit found a connected work account but no active
management endpoint under its bounded rules. Its EnterpriseMgmt task visibility
was non-elevated and limited. That does not authorize overriding present or
future Group Policy or MDM.

No WPR trace, off-to-usable run, repeated raw run, median, or
instrumentation-overhead measurement ran.

## Change and rollback status

No registry, policy, MDM, startup, service, task, security, update, recovery,
driver, firmware, or OEM setting changed. Rollback is not applicable.

The project will use documented per-app startup controls and WPR attribution
when a specific required application is late. Any future registry experiment
still needs the complete support-detection, original-state, dry-run, apply,
verification, logging, idempotence, exact rollback, rollback verification, and
reboot-persistence contract.

## Next layer

Layer 10 examines the Windows shell, GUI, capture, notifications, and perceived
responsiveness.

## Sources

Retrieved 2026-07-27:

- [Microsoft Support: Configure Startup applications in Windows](https://support.microsoft.com/en-US/Windows/Experience/Startup-Boot/configure-startup-applications-in-windows)
- [Microsoft: Desktop Startup apps](https://learn.microsoft.com/en-us/windows/compatibility/startup-apps)
- [Microsoft: ADMX_Logon Policy CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-logon)
- [Microsoft: WindowsLogon Policy CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowslogon)
- [Microsoft: Delivering a great startup and shutdown experience](https://learn.microsoft.com/en-us/windows-hardware/test/weg/delivering-a-great-startup-and-shutdown-experience)
- [Microsoft: Recording On/Off transitions](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/recording-onoff-transitions)
