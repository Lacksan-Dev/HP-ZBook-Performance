# EXP-007 Engineering Record

## Candidate
Remove only the machine-wide `Logitech Download Assistant` value under:

`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`

The module refuses any value whose command does not contain `LogiLDA.dll`.

## Safety boundary

- HP systems running Windows 11 only
- no Logitech application, service, scheduled task, file, package, device, or driver removal
- no change to Omnissa, Windows App, Remote Desktop, Tailscale, Windows security, updates, recovery, credentials, accessibility, or enterprise management
- exact registry path, value name, type, and data are captured before application

## Operations

```powershell
Import-Module .\StaleLogitechDownloadAssistant.psm1 -Force
Invoke-Exp007DryRun
Save-Exp007State -StatePath .\exp007-state.json
Remove-Exp007Registration -StatePath .\exp007-state.json -LogPath .\exp007.jsonl
Restore-Exp007Registration -StatePath .\exp007-state.json -LogPath .\exp007.jsonl
```

`Remove-Exp007Registration` is idempotent. Repeated application returns `NoChange` after the value is absent. `Restore-Exp007Registration` restores the captured registry value and verifies the restored data.

## Reboot persistence

Before reboot, create an expectation file:

```json
{"expectedExists":false}
```

After reboot:

```powershell
Test-Exp007RebootPersistence -ExpectedStatePath .\expected.json
```

## Evidence status

Repository engineering is complete. Physical HP ZBook application, reboot persistence, rollback execution, protected remote-access readiness, WPR attribution, repeated startup runs, and median comparisons remain `needs-evidence`. No performance gain is claimed.
