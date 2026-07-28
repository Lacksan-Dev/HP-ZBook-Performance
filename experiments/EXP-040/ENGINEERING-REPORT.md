# EXP-040 Engineering Report

## Candidate
Enable Microsoft Edge new-tab prerendering through `HKLM\SOFTWARE\Policies\Microsoft\Edge\Recommended\NewTabPagePrerenderEnabled=1`.

## Scope
The implementation changes one Edge recommended-policy value. It leaves Startup folders, Startup Boost, background mode, Sleeping Tabs, profiles, passwords, cookies, favorites, extensions, cache contents, SmartScreen, Edge Update, mandatory policy, Windows security, recovery, enterprise management, services, scheduled tasks, packages, devices, drivers, Omnissa, Windows App, Remote Desktop, and Tailscale unchanged.

## Controls
- HP Windows 11 and Edge 85+ support detection
- Enterprise-management refusal
- Mandatory and recommended policy collision refusal
- Exact original-state capture
- `ShouldProcess` dry run and application
- Immediate and reboot-persistence verification
- JSONL logging
- Idempotent application
- Terminating failure logging
- Exact rollback with mutation refusal
- Pester contract tests
- Non-destructive integration check

## Physical validation handoff
Run at least five matched baseline and five treatment trials on the same HP ZBook, Windows build, BIOS, driver set, Edge version, power source, power mode, and thermal condition. Report medians for cold process launch, first visible window, first interactive window, first new-tab readiness, first controlled navigation, and prelaunch idle Edge CPU, memory, disk, GPU, and process cost. Verify browser restart behavior, reboot persistence, rollback, profile integrity, security controls, update behavior, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale.

## Evidence status
Physical measurements remain `needs-evidence`. No responsiveness improvement is claimed. Preserve `status:experimental`. Never assign Stable without explicit human approval.
