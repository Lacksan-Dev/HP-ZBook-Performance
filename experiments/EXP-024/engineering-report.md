# EXP-024 Engineering Report

## Candidate
Change only `HPTouchpointAnalyticsService` from Automatic or Automatic (Delayed Start) to Manual. The script refuses any service whose executable identity does not identify HP Touchpoint Analytics Client.

## Controls
- HP Windows 11 support detection
- exact service name and executable-path identity
- original startup mode and running-state capture
- dry run through `ShouldProcess`
- verified application and reboot-persistence verification
- JSONL structured logging
- idempotent repeated application
- terminating failure handling
- exact rollback with computer, service, and executable identity checks

## Safety boundary
No service is deleted. No executable, package, scheduled task, registry startup entry, driver, HID component, security control, Windows Update component, recovery component, enterprise-management component, Omnissa component, Windows App component, Remote Desktop component, or Tailscale component is modified.

## Validation handoff
Run at least five alternating baseline and candidate sign-in trials under matched AC power, thermal, Windows build, BIOS, driver, and application conditions. Report medians for sign-in to usable desktop and first-120-second CPU and disk activity. Verify HP support workflows and protected remote-access readiness. Execute reboot verification and exact rollback. Record instrumentation overhead.

Physical evidence remains `needs-evidence`. No performance improvement is claimed.
