# EXP-039 Engineering Report

## Candidate
Enable Microsoft Edge Sleeping Tabs through the documented recommended policy `HKLM\SOFTWARE\Policies\Microsoft\Edge\Recommended\SleepingTabsEnabled=1`.

## Scope
The implementation changes one Edge recommended-policy value. It leaves Startup folders, Startup Boost, background mode, browser profiles, passwords, cookies, favorites, extensions, cache, SmartScreen, Edge Update, mandatory policy, Windows security, recovery, enterprise management, services, scheduled tasks, packages, devices, drivers, Omnissa, Windows App, Remote Desktop, and Tailscale unchanged.

## Controls
- HP Windows 11 and Edge 88+ support detection
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
Run at least five matched baseline and five treatment trials on the same HP ZBook, Windows build, BIOS, driver set, Edge version, power source, power mode, thermal condition, controlled tab set, and inactivity interval. Report medians for inactive-tab CPU, working set, commit, disk, GPU, and battery-discharge cost; tab wake-to-interactive latency; controlled navigation after wake; cold process launch; first visible window; first interactive window; first new-tab readiness; and prelaunch idle process cost. Verify browser restart behavior, reboot persistence, rollback, tab restoration, Edge profile integrity, security controls, update behavior, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale.

## Evidence status
Physical measurements remain `needs-evidence`. No responsiveness or resource improvement is claimed. Preserve `status:experimental`. Never assign Stable without explicit human approval.
