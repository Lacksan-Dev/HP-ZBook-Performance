# EXP-131 HP Comm Recovery delayed-start validation

Release state: Experimental
Evidence state: needs-evidence

This experiment evaluates one reversible treatment only: change a locally verified HP Comm Recovery service from Automatic to Automatic (Delayed Start), without stopping its current instance.

## Mutation boundary

The machine harness must refuse mutation unless it can establish Windows 11 on HP hardware, elevation, exactly one Comm Recovery service, `HPCommRecovery.exe` identity, a valid HP publisher signature, captured executable SHA-256 and version, unambiguous HP package ownership, absence of enterprise policy ownership, and absence of protected dependencies.

Manual and Disabled startup remain outside this experiment. Adapter, NDIS, route, DNS, proxy, VPN, firewall, PnP, driver, firmware, INF, DriverStore, Windows security, Windows Update, credentials, recovery, accessibility, enterprise-management, Omnissa, Windows App, Remote Desktop, and Tailscale configuration are immutable protected scope.

## Required provider lifecycle

`Check -> Capture -> DryRun -> Apply -> Verify -> VerifyReboot -> Rollback`

Capture must retain exact startup mode, DelayedAutoStart value, running state, account, binary path, dependencies/dependents, recovery actions, triggers, package identity, executable signature/hash/version, protected configuration fingerprint, network inventory fingerprint, Windows build, HP model, BIOS, machine identity, and user SID. Apply changes startup configuration only and preserves running state. Rollback restores the captured startup and delayed-start values and restores captured running state only after identity and protected-scope drift checks pass.

All actions emit structured JSONL. Repeated Apply and Rollback calls must be idempotent. Any identity, package, dependency, management, executable, or protected-network drift terminates the mutation path.

## Physical harness contract

Use the portfolio runner only after this experiment has a `ready` queue entry. Collect five matched baseline cold boots and five matched delayed-start cold boots. Preserve raw per-boot runs and compute median and MAD for first-120-second CPU activity, disk activity, usable-desktop proxy, HPCommRecovery process attribution, protected-network readiness, and service start timing. Also retain five matched sleep/wake observations before classification.

Classification values are `favorable`, `zero-benefit`, `failed`, `rejected`, or `inconclusive`. A protected-network regression, failed rollback, service-health regression, or customer-function regression yields failed or inconclusive evidence and exact rollback. Physical completion remains Experimental and never promotes this experiment to Stable automatically.
