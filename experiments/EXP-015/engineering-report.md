# EXP-015 Engineering Report

## Candidate
Remove only current-user Edge auto-launch `Run` or `RunOnce` values whose name and command identify `msedge.exe` plus a bounded auto-launch argument.

## Controls
The implementation detects HP hardware, Windows 11, and Edge; captures registry path, name, data, and value kind; provides Check, DryRun, Apply, Verify, VerifyReboot, and Rollback; uses ShouldProcess and JSONL logging; verifies removal; and restores exact captured values.

## Preserved surfaces
Edge Update, WebView2, Startup Boost policy, profiles, passwords, cookies, favorites, extensions, SmartScreen, services, scheduled tasks, packages, files, drivers, Windows security, updates, recovery, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale remain unchanged.

## Automated tests
Pester contract tests cover lifecycle actions, HKCU-only scope, strict candidate identity, protected identities, exact state capture, verification, rollback, structured logging, and absence of package, service, task, or driver removal commands.

## Physical validation request
Run Check and DryRun, apply on the HP ZBook, verify, reboot, run VerifyReboot, confirm Edge and protected applications, collect repeated baseline and treatment startup runs with medians, then execute Rollback and verify exact restoration after another reboot.

No benchmark result or performance gain is claimed. Physical measurements remain `needs-evidence`.
