# EXP-002 Research Brief: Startup Registration Minimization

## Customer problem
Windows sign-in remains busy while user applications auto-launch, delaying the usable desktop and competing with remote-access tools.

## Objective
Remove unnecessary user-application startup registrations while preserving required remote-access applications and protected Windows components.

## Protected user-application allowlist
- Omnissa
- Windows App
- Remote Desktop
- Tailscale

Windows security, credential, accessibility, device-driver, recovery, update, and enterprise-management components remain protected.

## Priority targets
- Microsoft Teams auto-start
- Microsoft Office and Microsoft 365 quick-launch or startup registrations
- Logitech, Logi Options+, Logi Bolt, Logi Tune, and G Hub tray, telemetry, updater, and startup registrations
- Other non-allowlisted user applications discovered in Startup folders, Run keys, StartupTask registrations, and sign-in scheduled tasks

## Change boundary
Delete or disable startup registrations rather than uninstalling applications. Preserve Logitech device-critical HID, receiver, keyboard, mouse, Bluetooth, and driver components.

## Required engineering behavior
- Inventory every candidate and classify its owner and purpose
- Capture exact original state
- Support dry run
- Remove or disable only approved registrations
- Verify absence after sign-out and reboot
- Restore exact registrations during rollback
- Produce structured logs and hashes

## Benchmark
Use repeated runs and medians for sign-in to usable desktop, first-120-second CPU and disk activity, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale.

## Status
Experimental. No performance claim exists until repeated physical-machine results are recorded.
