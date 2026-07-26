# EXP-001 progress report: low-friction sign-in privacy

- Date: 2026-07-27
- Performance-layer category: 9, Group Policy, registry, and system configuration
- Cycle effect: direct owner-requested work; hourly cursor not advanced
- Evidence state: implemented but not applied on the lab machine
- Performance claim: none

## What changed

The experimental ZBook utility adds two short commands:

- `Privacy` hides extra account details at Windows sign-in.
- `UndoPrivacy` restores the exact policy state captured before `Privacy`.

This is a separate privacy control, not part of the general Tune profile.

## Documented fact

Microsoft documents the ADMX-backed policy **Block user from showing account
details on sign-in** for Windows 11 Pro, Enterprise, Education, and IoT
Enterprise. The documented mapping is:

- Key:
  `HKLM\SOFTWARE\Policies\Microsoft\Windows\System`
- Value: `BlockUserFromShowingAccountDetailsOnSignin`
- Type: `REG_DWORD`
- Enabled data: `1`

Enabling it prevents users from showing extra sign-in details such as an email
address or user name. Microsoft separately documents that the display name is
still shown. This update does not configure
`DontDisplayLastUserName`, so it does not remove the display name or normal
sign-in tile.

Primary sources, retrieved 2026-07-26:

- [Microsoft Policy CSP - ADMX_Logon](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-logon)
- [Microsoft: Interactive logon display information while locked](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/security-policy-settings/interactive-logon-display-user-information-when-the-session-is-locked)

## Support and compatibility

The implementation remains locked to the validated EXP-001 system:

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Intel Core i5-1145G7
- Windows 11 Pro build 26200
- HP BIOS T76 01.24.02

It refuses an unsupported model, build, BIOS, or actively managed computer
unless the existing explicit managed-device authorization is supplied. It does
not alter domain, Entra, MDM, Windows Hello, passwordless sign-in, automatic
sign-in, services, scheduled tasks, security, Windows Update, drivers, or
firmware.

## Safety and rollback

Before a live write, the tool captures whether the registry key and value
exist, the exact registry type, and the original data. It stores that state in
an integrity-protected privacy backup. The action provides:

- support detection;
- dry-run preview;
- one controlled registry-policy modification;
- immediate apply verification;
- timestamped JSON Lines logs;
- idempotent repeat behavior;
- automatic exact-state rollback if apply verification fails;
- explicit `UndoPrivacy` rollback and rollback verification; and
- a pending reboot-persistence marker.

## Lab measurements

No live registry value was changed, no sign-out or reboot was performed, and no
startup or responsiveness benchmark was run for this privacy control.

## Hypotheses

None. The behavior is documented as a privacy setting, not a performance
optimization.

## Unresolved questions

- Does the sign-in screen visually hide the expected account details after
  sign-out or reboot on build 26200?
- Does the policy remain enabled after reboot?
- Will the owner later prefer full display-name privacy despite the additional
  sign-in typing and compatibility cost?
