# EXP-018 Engineering Report

## Implemented candidate
Reversible removal of a single current-user Office Sync Process `Run` registration.

## Guardrails
- HP Windows 11 support detection
- exact `OfficeSyncProcess` value-name match
- exact `OfficeSyncProcess.exe` command identity
- refusal when the current value diverges from captured state
- current-user Run key only
- no package, service, scheduled task, file, driver, Office Click-to-Run, OneDrive, security, enterprise-management, or protected remote-access changes

## Engineering behavior
- detection
- exact state capture including value kind and unexpanded command
- dry run through `ShouldProcess`
- verified application
- JSONL event logging
- repeated application without broad deletion
- terminating failures on identity or state mismatch
- reboot-persistence verification entry point
- exact rollback and rollback verification
- Pester contract coverage

## Validation handoff
Physical HP ZBook execution remains required. Record Windows build, BIOS, device, Office version, power source, thermal state, and background conditions. Run at least five baseline and five calibrated startup trials. Compare medians for sign-in readiness and first-120-second CPU and disk activity. Verify Office document open and save, OneDrive synchronization, protected remote-access readiness, reboot persistence, and exact rollback.

## Release status
Experimental. No performance claim is established.
