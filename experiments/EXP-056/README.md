# EXP-056: Cross-OEM Windows 11 inventory

## Status
Experimental. Physical non-HP execution remains `needs-evidence`. Never assign Stable automatically.

## Candidate
Generalize only the read-only `system-inventory` provider from HP Windows 11 to Windows 11 across OEMs. The provider records explicit `hpReferencePlatform` eligibility so HP-specific mutation providers can retain their own support boundary.

## Safety and rollback
This candidate performs zero mutations. `DryRun`, `Apply`, `Verify`, `VerifyReboot`, and `Rollback` retain a mutation count of zero. Exact rollback is therefore an identity operation verified by unchanged system state and a successful zero-mutation rollback record.

Preserved scopes include Windows security, Windows Update, recovery, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale.

## Integration validation
1. Run the scoped Pester suites for the controller and EXP-056.
2. Run `InventoryOnly` with `Scan`, `DryRun`, `Apply`, `Verify`, `VerifyReboot`, `Report`, and `Rollback` on an HP Windows 11 machine.
3. Repeat on one non-HP Windows 11 machine.
4. Confirm manufacturer, model, architecture, BIOS, processor, protected applications, support fields, JSONL logs, and mutation count zero.
5. Compare pre-run and post-rollback registry, service, task, package, device, driver, and protected-application state. Any drift fails the experiment.

## Benchmark
Record at least five inventory runs per system. Report median execution time and failures, while treating performance as secondary to correctness. Record Windows build, manufacturer, model, BIOS, processor, architecture, power source, thermal state, management state, and instrumentation conditions.

## Failure thresholds
Fail or mark inconclusive when inventory mutates state, support detection accepts a non-Windows 11 system, OEM identity is absent, protected-application inventory fails, structured logging fails, repeated runs produce inconsistent eligibility, or rollback comparison detects drift.
