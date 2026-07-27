# EXP-019 Engineering Report

## Implemented candidate
Reversible disabling of only `\Microsoft\Office\Office Background Task Handler Logon`.

## Guardrails
- HP Windows 11 support detection
- exact task path and task name
- Office Background Task Handler executable identity
- exact task XML capture and SHA-256
- normalized task-definition identity that permits only the controlled Enabled field to differ
- refusal when the task action, definition, or state-file identity diverges
- no changes to Office Automatic Updates, Click-to-Run, packages, files, services, registry startup values, devices, drivers, security, management, Omnissa, Windows App, Remote Desktop, or Tailscale

## Engineering behavior
- detection
- original-state capture
- dry run through `ShouldProcess`
- verified application
- JSONL event logging
- idempotent repeated application
- terminating failure handling
- reboot-persistence verification entry point
- exact original enabled-state rollback
- rollback verification
- Pester contract coverage

## Validation handoff
On the physical HP ZBook, record Windows build, BIOS, device, Office version, driver set, AC power, thermal state, network state, and background conditions. Run at least five baseline and five calibrated reboot trials. Compare medians for sign-in readiness and first-120-second CPU and disk activity. Verify Office document open/save, OneDrive synchronization, Office update readiness, Omnissa, Windows App, Remote Desktop, Tailscale, reboot persistence, and exact rollback.

## Release status
Experimental with `needs-evidence`. No performance claim is established.