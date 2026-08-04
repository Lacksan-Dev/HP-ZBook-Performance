# Two-hour scheduled Codex prompt

Use this as one local-project scheduled task in Codex:

```text
Use the experiment_discovery_portfolio custom agent and follow AGENTS.md and
.codex/portfolio-agent.md. Run one two-hour portfolio cycle. Inspect current
issues, pull requests, checks, merged evidence, and the validation queue. Continue
the startup, Edge demand-launch, and vendor-service lanes without duplicating an
existing experiment.

Find candidate performance improvements in current Microsoft and vendor
documentation. You may use reputable engineering forums and relevant Reddit
threads as leads, but treat every community claim as an unproven hypothesis.
Require support detection, one changed variable, repeated baseline and treatment
runs, verification, idempotence, protected-scope checks, reboot persistence, and
exact rollback. Never put an unreviewed internet tweak directly into the ready
validation queue and never invent performance results.

Implement or refine one useful repository change, run the relevant tests, and
publish it through a focused pull request. Run the guarded laptop validation entry
point once; do not edit Windows directly or bypass its queue. If sanitized physical
evidence is produced, publish it on a focused evidence branch and link the EXP
issue. Report only concrete changes, measured outcomes, and exact needs-evidence
requests.
```

The separate Windows task installed by `InstallLaptopCycle` handles pulling
approved `main` code, guarded physical validation, and reboot continuation. The
Codex scheduled task researches and writes code; it is not the machine-mutation
path.
