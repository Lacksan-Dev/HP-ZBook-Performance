# EXP-031 Research Brief

## Candidate
Calibrate only `HPSupportSolutionsFrameworkService` from Automatic or Automatic (Delayed Start) to Manual when the installed service identity is conclusively HP Support Solutions Framework.

## Rationale
HP Support Solutions Framework is a vendor support and diagnostic helper rather than a Windows platform, security, recovery, credential, accessibility, driver, enterprise-management, or protected remote-access component. Manual startup is a reversible candidate for reducing sign-in and early-idle contention while retaining on-demand HP Support Assistant workflows.

## Measured hypothesis
Changing the recognized service startup mode to Manual may reduce sign-in-to-usable-desktop time or first-120-second CPU and disk activity. No gain is assumed until repeated physical trials produce medians.

## Support and identity detection
Proceed only when all conditions hold:

1. Windows 11 is installed.
2. The manufacturer identity indicates an HP device.
3. The exact service name is `HPSupportSolutionsFrameworkService`.
4. The display name and executable command identify HP Support Solutions Framework.
5. The executable path resolves to an existing file.
6. The service is outside all protected Windows and remote-access boundaries.

Any failed identity check produces a structured refusal and no change.

## Controlled variable
Change only the service startup mode to Manual. Preserve the current running state during application. Do not remove packages, files, tasks, registry entries, devices, drivers, networking components, or HP Support Assistant.

## Original-state capture
Capture at minimum:

- service name and display name;
- unexpanded executable command and resolved executable path;
- startup mode, delayed-auto-start state, and running state;
- process ID when present;
- Windows build, computer manufacturer and model, computer identity, capture time, and script version.

Store the state in a machine-readable file suitable for exact rollback.

## Engineering contract
The implementation must provide:

- support detection and strict identity refusal;
- dry run and `ShouldProcess` behavior;
- application with immediate verification;
- JSONL structured logging;
- idempotent repeated application;
- terminating failure handling with preserved evidence;
- reboot-persistence verification;
- exact restoration of startup mode, delayed-auto-start state, and prior running state;
- rollback identity checks and rollback verification;
- Pester contract tests and non-destructive integration checks.

## Benchmark
Use repeated controlled sign-in trials and medians for:

- sign-in to usable desktop;
- aggregate CPU and disk activity during the first 120 seconds;
- time until Omnissa, Windows App, Remote Desktop, and Tailscale are ready;
- HP Support Assistant launch and device-detection readiness;
- diagnostic workflow success;
- service demand-start behavior;
- reboot persistence and exact rollback.

Record Windows build, HP model, BIOS, drivers, power source, thermal state, service version, benchmark conditions, and instrumentation overhead.

## Safety boundary
Preserve Defender, Firewall, BitLocker, Credential Guard, VBS, Windows Update, recovery, credential providers, accessibility, enterprise management, device-critical drivers, HP Support Assistant content, Omnissa, Windows App, Remote Desktop, Tailscale, and required networking.

## Decision rule
Advance only when physical evidence shows a repeatable benefit without customer-function regression. Preserve failed or inconclusive measurements. Stable status requires explicit human approval.

## Evidence state
Repository research is complete. Implementation and physical HP ZBook measurements remain `needs-evidence`.