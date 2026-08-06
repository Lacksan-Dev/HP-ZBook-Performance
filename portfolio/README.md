# Codex two-hour experiment portfolio

The repository defines a project-scoped Codex custom agent at
`.codex/agents/experiment-discovery-portfolio.toml`. Its complete two-hour method
is `.codex/portfolio-agent.md`.

## Scheduled task

Create a local-project scheduled task in the Codex desktop app with a two-hour
cadence and this prompt:

```text
Use the experiment_discovery_portfolio custom agent. Run exactly one two-hour portfolio cycle for this repository and follow .codex/portfolio-agent.md in full. Perform useful work, run the guarded laptop validation entry point once, and report only concrete actions and exact needs-evidence requests.
```

The scheduled task must run against this local Git repository. The computer and
Codex app must be running. Physical validation also requires an elevated local
session and permission to access the HP laptop outside the checkout. The guarded
runner performs its own AC-power, local-idle, remote-session, pending-reboot,
servicing, protected-scope, harness-contract, and single-active-run checks before
allowing a reboot-aware experiment.

## Validation queue

`validation-queue.json` is an execution allowlist, not a research backlog. Add an
entry only after its Experimental implementation and reboot-aware harness have
merged and passed scope, sensitive-data, support-detection, original-state,
dry-run, verification, protected-scope, and exact-rollback review.

Each entry contains one experiment, one candidate, one benchmark, functional and
reboot verification, exact rollback, and the complete protected-scope declaration.
Only `state: ready` entries are eligible, and the runner executes at most one at a
time. After its sanitized evidence is merged, an entry moves to `state: completed`;
completed entries remain as queue history but are never selected again.

## Evidence boundary

Raw runs, machine-bound state, JSONL logs, and rollback artifacts stay under
`C:\ProgramData\Lacksan\PortfolioValidation`. On completion, the runner creates a
bounded package under
`C:\ProgramData\Lacksan\PortfolioValidation\sanitized-evidence`. It contains
aggregate metrics, lifecycle booleans, protected scope, and local-file digests. It
excludes machine and user identifiers, serials, paths, process IDs, credentials,
browser/profile data, and customer content. Staging outside the executor checkout
keeps `main` clean so the next scheduled validation can fast-forward and run.

The Codex agent copies only the reviewed sanitized package into its matching
`evidence/physical/` path on a fresh focused evidence branch, marks the completed
queue item non-ready in the same pull request, and links the EXP issue. Physical
evidence remains `Experimental`; the agent never assigns `Stable`. It never writes
publication files directly into the executor's `main` checkout.


## Laptop executor

Install the guarded laptop task from an elevated Windows PowerShell 5.1 console:

    .\ZBookPerf.ps1 -Action InstallLaptopCycle -RepositoryRoot $PWD -LaptopCycleIntervalHours 2 -AllowAutomaticReboot

Inspect it with `-Action LaptopCycleStatus` and remove it with
`-Action RemoveLaptopCycle`. The task runs at logon and every two hours. It
fast-forwards only a clean, inactive checkout to `origin/main`, then invokes the
existing guarded validation runner. Reboot continuation remains owned by the
experiment harness. Codex does not need to be a Windows startup application for
physical validation; the Windows task is the startup component.
