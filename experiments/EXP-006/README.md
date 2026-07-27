# EXP-006: Teams and Office startup registration cleanup

## Scope

This experimental component inventories and removes or disables Microsoft Teams and Microsoft Office or Microsoft 365 user-application startup registrations while preserving protected remote-access and Windows components.

Protected applications:

- Omnissa
- Windows App
- Remote Desktop
- Tailscale

The component does not uninstall applications, remove drivers, disable Windows security, change update policy, or alter enterprise-management components.

## Surfaces

- Current-user and local-machine `Run` and `RunOnce` values
- Per-user and common Startup folders
- Sign-in scheduled tasks

## Operation

```powershell
Import-Module .\StartupRegistrationCleanup.psm1 -Force

$state = 'C:\ProgramData\Lacksan\EXP-006\state.json'
$log = 'C:\ProgramData\Lacksan\EXP-006\activity.jsonl'

Invoke-StartupRegistrationCleanup -Mode DryRun -StatePath $state -LogPath $log
Invoke-StartupRegistrationCleanup -Mode Apply -StatePath $state -LogPath $log -Confirm:$false
Invoke-StartupRegistrationCleanup -Mode Verify -StatePath $state -LogPath $log
```

Run verification again after sign-out and after reboot to detect registrations recreated by application self-healing or update behavior.

## Rollback

```powershell
Invoke-StartupRegistrationCleanup -Mode Rollback -StatePath $state -LogPath $log
```

Rollback restores registry values, Startup-folder files from captured copies, and the prior enabled state of targeted scheduled tasks.

## Safety behavior

- Protected-name matching takes precedence over target matching.
- Only registrations matching Teams or Office target patterns are changed.
- Startup-folder files are copied before deletion.
- Existing state is captured before application.
- Repeated application is safe because absent entries produce no additional modification.
- JSONL records each dry-run, apply, verification, and rollback operation.

## Evidence status

Automated classification and state-handling tests are included. Physical HP ZBook startup timing, first-120-second CPU and disk activity, protected application readiness, reboot persistence, and median comparison remain pending and are tracked with `needs-evidence`.
