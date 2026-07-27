# EXP-005 Research Brief: Lightweight User-Mode Replacements

## Objective
Identify user-mode Windows and vendor functions where a smaller Lacksan component can preserve the required customer function with lower startup and idle overhead.

## Initial replacement candidates
- Startup registration inventory, policy, sequencing, and rollback broker
- Demand-start launcher for optional vendor utilities
- Edge demand-launch measurement and configuration broker
- Vendor updater coordination that runs on demand or on a controlled schedule
- Tray and telemetry consolidation for approved noncritical vendor applications
- Network and remote-access readiness probe for Omnissa, Windows App, Remote Desktop, and Tailscale
- Scoped application-readiness and cache-warmup broker
- Lightweight benchmark, logging, and experiment-state service

## Core Windows boundaries
Do not replace or patch the Windows kernel, scheduler, memory manager, storage stack, networking kernel, security stack, credential providers, servicing stack, Windows Update, recovery, or device-critical drivers. Work through documented user-mode APIs and supported configuration surfaces.

## Implementation path
Prototype orchestration and detection in PowerShell. Move proven hot paths or persistent components to C# or Rust only after profiling shows PowerShell process startup or runtime overhead materially affects the customer workflow.

## Required evidence
Compare the original component with the replacement using repeated runs and medians for startup latency, idle CPU, working set, disk, network activity, reliability, recovery, and customer-function correctness. Preserve exact rollback.

## Status
Experimental.
