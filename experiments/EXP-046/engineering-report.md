# EXP-046 Engineering Report

## Purpose
Create the first integrated Lacksan Controller entry point so individual experiments can become manifest-driven providers inside one scan, recommendation, dry-run, apply, verify, report, and rollback workflow.

## Implemented mechanism
- schema-one JSON manifest
- profile and provider resolution
- dependency and conflict validation
- mandatory protected-scope declarations
- transaction identity and original-state directory
- capture-before-apply orchestration
- JSONL logging
- idempotent read-only initial provider
- reverse-order rollback on failure and explicit rollback
- reboot-verification action contract
- sensitive-data-minimized JSON report
- Pester contract tests
- non-destructive integration test

## Initial profile
`InventoryOnly` contains one read-only provider. It checks HP Windows 11 support and inventories the presence of Omnissa, Windows App, Remote Desktop, and Tailscale without changing startup registrations, services, tasks, policies, packages, files, devices, drivers, or protected Windows components.

## Validation status
Static and runtime tests are supplied for a Windows runner. Physical HP ZBook execution, reboot persistence, combined-profile application, exact rollback, instrumentation overhead, repeated benchmark runs, and medians remain `needs-evidence`.

## Release status
Experimental. Stable requires explicit human approval.
