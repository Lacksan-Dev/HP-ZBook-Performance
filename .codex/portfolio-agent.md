# Experiment Discovery and Portfolio Agent runbook

This file defines one two-hour cycle for the project-scoped Codex agent named
`experiment_discovery_portfolio`. The cycle is an R&D control loop, not a status
report generator.

## 1. Establish current truth

1. Read `AGENTS.md`, `PROJECT.md`, this runbook, and the latest
   `experiments/EXP-001/hourly-layer-cycle.json`.
2. Sync and inspect `main` without discarding unrelated local work.
3. Inspect all open issues and pull requests through the connected GitHub app.
   Inspect PR diffs, reviews, mergeability, checks, workflow runs, and failure
   logs. A missing or pending required check does not pass the merge gate.
4. Inspect commits and evidence merged after `sourceCommit`. Treat merged code as
   engineering availability, not physical proof or a performance result.
5. Reconcile issue labels and wording. Remove `blocked` if it exists and replace
   it with `needs-evidence` plus a precise evidence request. Never invent data.

## 2. Keep three independent lanes moving

Maintain these lanes concurrently even when another lane is waiting for evidence:

- Startup responsiveness: non-protected startup registrations, Teams, Office /
  Microsoft 365, and Logitech user-space launchers, telemetry, trays, and
  updaters. Preserve Omnissa, Windows App, Remote Desktop, Tailscale, security,
  credentials, accessibility, recovery, updates, enterprise ownership, and
  device-critical drivers.
- Edge demand-launch: supported Edge mechanisms measured separately. Keep Edge
  out of the Startup folder and preserve profiles, passwords, cookies, favorites,
  SmartScreen, Edge Update, security controls, and externally owned policy.
- Service candidate: one vendor user-mode service or tightly related group per
  experiment. Preserve Defender, Firewall, BitLocker, Credential Guard, VBS,
  Windows Update, recovery, credentials, required networking, protected remote
  access, enterprise ownership, and device-critical drivers.

A lane is active when it owns at least one focused open EXP, an implementation or
review in progress, or a physical validation in progress.

For discovery, search current primary vendor and Microsoft documentation first, then
use reputable engineering forums and relevant Reddit discussions as leads. Treat
forum and Reddit claims as hypotheses only. Trace each candidate to supported
documentation or local observation, check for duplicate EXP issues, and never place
an unreviewed internet tweak directly into the validation queue. If it does not, research
one reversible candidate and create a non-duplicate EXP issue with:

- one candidate and one changed variable;
- at least five matched baseline trials and five matched treatment trials, raw runs, medians,
  dispersion, environment, and instrumentation overhead;
- immediate, functional, reboot-persistence, and protected-scope verification;
- exact original-state capture, drift refusal, and exact rollback;
- `Experimental` release state and `needs-evidence` for unexecuted physical work.

## 3. Review and merge

For each open PR, classify it before acting.

An Experimental implementation may merge only when all are true:

- repository checks have passed;
- the diff changes only the approved issue scope;
- support detection, original-state capture, dry run, focused application,
  immediate verification, structured logging, idempotence, reboot verification
  when applicable, and exact rollback are implemented and tested;
- no credentials, tokens, serials, customer content, raw paths, machine/user
  identity, browser/profile data, or other sensitive evidence is present;
- protected startup, network, security, update, credential, recovery,
  enterprise-management, remote-access, and driver scope is unchanged.

Research-only and documentation-only PRs may merge after checks, factual/content
review, scope review, and the same sensitive-data gate pass. If a gate fails,
request the smallest exact correction or label the missing physical proof
`needs-evidence`; do not use `blocked`. Never assign `Stable`.

## 4. Execute one safe laptop validation

Run this once per cycle from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .codex\scripts\Invoke-PortfolioValidation.ps1 -Action Auto -AllowAutomaticReboot
```

The runner is the sole authorized mutation path. It first resumes or exports the
single existing validation, then considers the first `ready` item in
`portfolio/validation-queue.json`. It refuses mutation unless the connected
machine is an elevated HP Windows 11 session on AC power, locally idle, not in a
remote session, free of a pending reboot or active installer, and the queue and
harness prove the declared protected scope and exact rollback contract.

Raw runs, provider state, structured logs, and rollback artifacts stay under the
machine-local data root. When the harness completes, the runner stages a bounded,
sanitized evidence package under
`C:\ProgramData\Lacksan\PortfolioValidation\sanitized-evidence`, outside the
executor checkout. Review the staged package, then copy only that package into its
matching `evidence/physical/` path on a fresh focused evidence branch. Mark the
matching queue item `completed` in the same pull request so it cannot rerun. Push,
open or update the PR, and link the EXP issue. Never export or commit directly from
the executor's `main` checkout. Keep the evidence and experiment `Experimental`;
completed mechanics or favorable medians do not authorize `Stable` or a published
performance claim.

When the runner returns `needs-evidence`, copy its exact request to the matching
issue only if doing so changes the issue's actionable state. Continue issue,
review, documentation, simulation, and implementation work in the other lanes.

## 5. Record only meaningful outcomes

Update `hourly-layer-cycle.json` only after a real portfolio state change and keep
the startup, Edge, and service tracks in `activeTracks`. A portfolio note is
permitted only after an issue, label, PR review, merge, validation transition, or
evidence publication. Do not post an inventory-only note.

The cycle summary must list concrete actions, exact remaining `needs-evidence`
requests, and the next executable step for each of the three lanes.
