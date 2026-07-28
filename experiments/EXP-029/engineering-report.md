# EXP-029 Engineering Report

## Candidate
The current-user Microsoft Office 16.0 `DisableAnimations` graphics value only. The experimental condition sets DWORD `1`. Existing HKCU or HKLM Office policy control causes refusal so enterprise management retains precedence.

## Implemented lifecycle
- HP Windows 11 and installed Outlook support detection
- Mandatory Office policy detection and refusal
- Exact registry-key existence, value existence, value kind, and unexpanded data capture
- Computer, user SID, Outlook executable, and UTC capture
- Read-only check and dry-run plan
- `ShouldProcess`-gated application
- Immediate verification
- JSONL structured events
- Idempotent repeated application
- Terminating failure logging
- Reboot-persistence verification
- Exact captured-state rollback and rollback verification

## Safety boundary
The experiment changes one current-user Office graphics value. It changes no Outlook profile, mailbox, OST/PST, credential, add-in, Office package, file, service, scheduled task, startup registration, update component, security control, recovery component, enterprise-management component, device, driver, Omnissa component, Windows App component, Remote Desktop component, or Tailscale component.

## Repository checks
Pester contract tests cover exact identity, policy precedence, platform and Outlook detection, lifecycle completeness, state capture, structured logging, idempotence, verification, rollback, and absence of destructive system actions. The integration script parses the implementation and performs non-destructive contract checks.

## Physical validation handoff
Run Check, Capture, DryRun, Apply, Verify, reboot, VerifyReboot, and Rollback on the HP ZBook. Confirm Outlook profile loading, mailbox readiness, search, compose/send, attachment handling, add-ins, Office update health, Windows security and update health, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale readiness. Collect repeated Outlook cold-process launch trials and report medians for process creation, first visible window, first interactive window, mailbox readiness, and controlled navigation. Record instrumentation overhead, Windows build, BIOS, drivers, Office version, power source, and thermal state. Preserve failed and inconclusive evidence.

Physical measurements remain `needs-evidence`. No responsiveness result is claimed. Stable assignment remains outside this experiment.
