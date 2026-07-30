# EXP-080 Engineering Report

## Candidate

Remove one verified Logitech Download Assistant auto-launch value from an approved current-user or machine-wide `Run` registry location. The experiment changes only the exact captured registry value.

## Safety boundary

The provider preserves the Logitech executable, installed applications, services, scheduled tasks, StartupTask registrations, PnP devices, driver packages, firmware, receiver pairing, keyboard and mouse function, Windows security, Windows Update, recovery, credentials, accessibility, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale.

Mutation is refused when:

- the host falls outside HP Windows 11
- enterprise-management signals are present
- zero or multiple eligible registrations are found
- the executable cannot be resolved
- the executable signature lacks a valid Logitech or Logi publisher identity
- the candidate resembles a protected application, updater, driver, receiver, firmware, Options+, G Hub, Bolt, or Tune component
- machine-wide mutation lacks elevation
- captured identity, registry data, value kind, executable, or publisher state drifts
- rollback would overwrite an existing value

## Actions

```powershell
$script = '.\Invoke-LogitechDownloadAssistantCalibration.ps1'

& $script -Action Check
& $script -Action Capture
& $script -Action DryRun
& $script -Action Apply -Confirm:$false
& $script -Action Verify
# Reboot, then:
& $script -Action VerifyReboot
# Exact restore:
& $script -Action Rollback -Confirm:$false
```

`-WhatIf` is available for mutation actions through `ShouldProcess`.

## Captured state

The state document records:

- registry path and scope
- exact value name
- exact registry value kind
- exact unexpanded value data
- resolved executable path
- Authenticode status and publisher subject
- machine identity
- current user SID
- UTC capture timestamp

Structured events are appended as JSONL and include support detection, enterprise-management detection, inventory, capture, dry run, apply, verification, reboot verification, rollback, and failures.

## Static and integration validation

Run Pester from the repository root:

```powershell
Invoke-Pester .\experiments\EXP-080\tests\Invoke-LogitechDownloadAssistantCalibration.Tests.ps1
```

Run the zero-mutation integration procedure on an HP Windows 11 test host:

```powershell
.\experiments\EXP-080\Test-Integration.ps1
```

The integration procedure invokes only `Check` and `DryRun`. It records its output without applying or rolling back a registry change.

## Physical validation handoff

Evidence remains `needs-evidence`. Preserve every baseline, treatment, failed, and inconclusive run.

Complete five matched baseline sign-in trials and five matched treatment trials under controlled AC power and comparable thermal conditions. Record:

- Windows build and update state
- HP model, BIOS, and relevant driver versions
- Logitech executable version and SHA-256
- power source and thermal state
- observer and instrumentation overhead
- sign-in to usable-desktop time
- first-120-second CPU and disk activity
- Logitech Download Assistant process presence
- Omnissa, Windows App, Remote Desktop, and Tailscale readiness
- basic Logitech keyboard, mouse, and receiver function

Use medians. Avoid inferred or invented values.

After treatment, verify the exact registration remains absent immediately and after reboot. Confirm no service, task, package, file, device, driver, firmware, security, update, recovery, management, or protected-application state changed.

Execute exact rollback, verify registry value equality, reboot, confirm the original launch behavior returns, and repeat peripheral and protected-application checks.

## Release state

Experimental. Physical measurements, reboot execution, peripheral checks, protected-application readiness, rollback execution, and median results remain `needs-evidence`. Stable requires explicit human approval.
