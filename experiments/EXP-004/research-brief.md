# EXP-004 Research Brief: Service Suspension, Demand-Start, and Replacement Candidates

## Customer problem
Vendor and helper services can consume startup time, CPU, memory, disk, and network resources even when their customer function is unused.

## Objective
Find one reversible service candidate at a time that can be delayed, suspended, demand-started, consolidated, or replaced by a smaller Lacksan user-mode component.

## Candidate priority
1. Vendor telemetry services
2. Vendor update agents
3. Tray and helper services
4. Redundant launch brokers
5. OEM utilities with measurable startup cost
6. Windows user-mode convenience functions where a supported smaller replacement can preserve the required function

## Protected boundaries
Preserve Defender, Firewall, BitLocker, Credential Guard, VBS, Windows Update, recovery, credential providers, accessibility, device-critical drivers, enterprise management, and networking required by Omnissa, Windows App, Remote Desktop, and Tailscale.

## Required comparison
For each service compare supported states such as Automatic, Automatic Delayed Start, Manual, demand-start, temporary suspension, or a measured replacement. Record dependencies, triggers, recovery actions, management ownership, user impact, and rollback.

## Replacement requirements
A replacement must preserve the required customer function and provide support detection, health checks, structured logs, idempotence, verification, and exact rollback.

## Benchmark
Use repeated runs and medians for sign-in readiness, target application readiness, idle CPU, memory, disk, network activity, and any service-specific customer function.

## Status
Experimental. No performance claim exists until repeated physical-machine results are recorded.
