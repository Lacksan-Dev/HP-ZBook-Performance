# EXP-009: Send to OneNote startup shortcut

## Candidate

Remove only `Send to OneNote.lnk` from the current-user Startup folder. OneNote, Microsoft 365, notebooks, packages, services, scheduled tasks, print integration, and device drivers remain installed and unchanged.

## Safety boundary

The component requires HP hardware running Windows 11. It resolves the current-user Startup folder, requires the exact file name `Send to OneNote.lnk`, rejects reparse points and directories, records the full path, SHA-256 hash, size, and timestamps, and copies the shortcut into the experiment state directory before removal.

Omnissa, Windows App, Remote Desktop, Tailscale, Windows security, updates, recovery, enterprise management, accessibility, credential, and device-critical components remain outside scope.

## Operations

```powershell
Import-Module .\SendToOneNoteStartup.psm1 -Force
$state = 'C:\ProgramData\Lacksan\EXP-009\state.json'
$log = 'C:\ProgramData\Lacksan\EXP-009\activity.jsonl'

Invoke-Exp009DryRun
Save-Exp009State -StatePath $state
Remove-Exp009Shortcut -StatePath $state -LogPath $log -Confirm:$false
Test-Exp009Applied -StatePath $state
Test-Exp009RebootPersistence -StatePath $state
Restore-Exp009Shortcut -StatePath $state -LogPath $log -Confirm:$false
Test-Exp009Rollback -StatePath $state
```

## Engineering behavior

- HP Windows 11 support detection
- exact path, file name, size, timestamps, and SHA-256 capture
- backup before mutation
- dry run
- identity and hash recheck before removal
- JSONL logging
- idempotent repeated application
- fail-closed behavior for identity drift, reparse points, missing backup, or hash mismatch
- reboot-persistence verification
- exact restore and rollback verification

## Evidence status

Physical HP ZBook application, reboot persistence, rollback execution, protected remote-access readiness, OneNote on-demand launch, Send to OneNote workflow behavior, repeated startup measurements, instrumentation overhead, and median comparisons remain `needs-evidence`. No performance improvement is claimed.
