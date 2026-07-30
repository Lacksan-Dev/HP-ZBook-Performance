# EXP-083 Engineering Report

## Candidate
Set `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search\EnableDynamicContentInWSB` to `REG_DWORD 0` on an eligible unmanaged Windows 11 system.

## Mutation boundary
The implementation changes one registry policy value. It changes no Search service, index, package, executable, scheduled task, firewall rule, DNS setting, browser setting, security control, update component, recovery component, enterprise-management state, device-critical driver, Omnissa component, Windows App component, Remote Desktop component, or Tailscale component.

## Controls
The provider detects Windows edition, build, elevation, manufacturer, and model; refuses domain, MDM, PolicyManager, and Configuration Manager ownership; captures exact key and value existence, registry type, and data; supports dry run and `ShouldProcess`; verifies the applied identity; logs JSONL events; treats a repeated application as idempotent; terminates on ambiguity or drift; verifies persistence after reboot; and restores the exact captured state. When the key was created by the experiment, rollback removes it only when empty.

## Static and integration validation
Run:

```powershell
Invoke-Pester .\experiments\EXP-083\tests\Invoke-WindowsSearchHighlightsPolicyCalibration.Tests.ps1
.\experiments\EXP-083\Test-Integration.ps1
```

The integration script performs `Check` and `DryRun` only.

## Physical validation
On an eligible unmanaged HP Windows 11 lab system, preserve all raw output and run `Capture`, `Apply`, `Verify`, reboot, `VerifyReboot`, local application/setting/file searches, Outlook readiness checks, protected remote-access readiness checks, and `Rollback`. Complete five matched baseline and five matched treatment trials. Record Search-home readiness, local-result readiness, SearchHost CPU, disk, memory, and network activity, sign-in readiness, Windows build and edition, device, BIOS, graphics and storage drivers, power source and mode, thermal state, network state, index state, query set, and instrumentation overhead.

Missing physical measurements remain `needs-evidence`. Neutral, adverse, failed, and inconclusive evidence must remain preserved. The experiment remains Experimental and receives no Stable assignment.
