# EXP-081 Engineering Report

## Candidate
Remove one verified Logitech SetPoint Event Manager registration from an approved Windows Run key. Preserve SetPoint, files, services, tasks, devices, receiver pairing, drivers, firmware, and peripheral operation.

## Implemented controls
- HP Windows 11 support detection
- elevation requirement for HKLM state
- domain, MDM, PolicyManager, and ConfigMgr refusal
- exact single-candidate selection
- exact registry path, value name, value type, unexpanded data, executable, publisher, machine, and user-SID capture
- Logitech/Logi Authenticode publisher verification
- `SetPoint.exe` or `SetPointII.exe` identity under a Logitech SetPoint directory
- updater, firmware, driver, receiver, and protected-identity refusal
- dry run and `ShouldProcess`
- immediate and reboot-persistence verification
- structured JSONL logging
- idempotent repeated application
- terminating failure handling
- captured-state and current-value drift refusal
- rollback overwrite refusal
- exact value-type and unexpanded-data restoration with equality verification

## Mutation scope
The implementation may remove or restore one registry value only. It contains no package, file, service, scheduled-task, PnP, driver, firmware, network, security, update, recovery, enterprise-management, or protected remote-access mutation.

## Validation
Run Pester against `tests/Invoke-SetPointStartupCalibration.Tests.ps1`. Run `Test-Integration.ps1` on an HP Windows 11 test machine to confirm inventory and dry-run paths produce zero registry mutation.

Physical validation remains `needs-evidence`. Collect five matched baseline and five treatment sign-ins. Record Windows build, HP model, BIOS, storage and display drivers, SetPoint version, power source, thermal state, benchmark conditions, sign-in-to-usable-desktop time, first-120-second CPU and disk activity, SetPoint process activity, basic and advanced peripheral readiness, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale. Verify after reboot, execute rollback, and retain favorable, adverse, failed, and inconclusive evidence.

## Release state
Experimental. Stable assignment remains outside automated authority.
