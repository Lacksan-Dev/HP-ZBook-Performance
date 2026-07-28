# EXP-045 Engineering Report

## Candidate
Remove one exact current-user OneDrive background `Run` registration while retaining OneDrive, sync roots, files, credentials, services, tasks, updater behavior, and all protected components.

## Supported identity
The implementation accepts only `OneDrive` or `Microsoft OneDrive` under `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, with a command resolving to `OneDrive.exe` and containing `/background`. Setup and updater identities are refused. More than one eligible registration is refused.

## Lifecycle
`Check`, `Capture`, `DryRun`, `Apply`, `Verify`, `VerifyReboot`, and `Rollback` are supported. State records the exact unexpanded command, registry value kind, computer identity, user SID, and capture time. Rollback refuses to overwrite an existing value and verifies exact restoration.

## Safety
The code changes one registry value only. It performs no package, executable, file, sync-root, credential, service, task, StartupTask, device, driver, security, update, recovery, management, or protected remote-access modification.

## Validation handoff
Physical evidence remains `needs-evidence`. Run at least five matched baseline and five treatment sign-in trials on the same HP Windows 11 device, power source, thermal condition, BIOS, drivers, and OneDrive version. Report medians for sign-in to usable desktop, first-120-second CPU and disk activity, protected remote-access readiness, OneDrive on-demand launch, signed-in sync readiness, a controlled upload/download round trip, and update-check behavior. Execute `VerifyReboot`, then `Rollback`, reboot again, and verify exact registration restoration and normal automatic sync behavior. Preserve failed and inconclusive trials. No performance claim is authorized before physical results exist.
