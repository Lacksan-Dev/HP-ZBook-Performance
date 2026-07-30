# EXP-066: HP Network HSA Manual demand-start

## Status

Experimental. Physical measurements remain `needs-evidence`. Stable assignment requires explicit human approval.

## Candidate

Change exactly one verified `HPNetworkCap` service from Automatic or Automatic Delayed Start to Manual. Preserve its running state during application. Change no second service and no network-stack object.

## Safety and refusal boundaries

The provider requires HP Windows 11, elevation, one exact service identity, `NetworkCap.exe`, a valid HP publisher signature, safe dependencies, and absence of enforced service policy. It inventories installed OMEN and HP network applications and refuses application when a continuous dependency is detected. It captures adapters, bindings, routes, DNS servers, proxy state, executable hash, dependencies, dependents, and service configuration before mutation.

The candidate changes no adapter, binding, route, DNS, DHCP, proxy, VPN, firewall, NDIS filter, device, driver, INF, package, firmware, DriverStore object, security control, update component, recovery component, enterprise-management setting, or protected remote-access application.

## Zero-mutation integration path

1. Run `Check` and retain the structured output.
2. Run `DryRun` with a new state and JSONL log path.
3. Confirm `WouldChange`, `PreserveRunningState`, and `NetworkMutationCount=0`.
4. Compare adapter, binding, route, DNS, proxy, service, package, and application inventories before and after the read-only path.
5. Confirm no service configuration or network-stack state changed.

## Physical validation

Use at least five matched baseline and five treatment boots or sign-ins. Record medians and raw results for usable-desktop latency, first-120-second CPU, first-120-second disk activity, DNS and HTTPS readiness, HP application demand-start, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale. Record Windows build, model, BIOS, storage and network drivers, executable version and SHA-256, power source, power mode, thermal state, and network conditions.

After application and reboot, verify Ethernet, Wi-Fi, DHCP, DNS, IPv4, IPv6, HTTPS, sleep and wake networking, HP application behavior, HP update behavior, Device Manager, protected applications, and unchanged adapters, bindings, routes, DNS, proxy, firewall, VPN, drivers, packages, and firmware.

## Rollback

Rollback validates experiment, machine, service, executable identity and SHA-256, dependencies, dependents, applied configuration, and captured network boundary. It restores the exact startup mode, delayed-start value, and original running state, then verifies the restored state. Preserve every failed or inconclusive result and execute rollback when demand-start or networking degrades.
