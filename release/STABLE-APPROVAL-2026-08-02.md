# UX-ROM Stable promotion approval

Date: 2026-08-02
Scope: Lacksan UX-ROM validation-ready experiments merged to `main`

The operator explicitly approved promotion of validation-ready UX-ROM work to Stable for use on the operator-controlled HP lab computer once each experiment completes its declared physical verification on that computer.

This approval satisfies the repository requirement for explicit human approval. A second approval is not required after a qualifying physical run.

## Evidence boundary

This approval does not manufacture or substitute physical evidence. UX-ROM may display `Stable` for an experiment only after the local validation workflow records the required support checks, treatment verification, reboot verification where applicable, rollback or retained-state decision, and any experiment-specific benchmark or functional evidence required by that experiment.

Until those checks complete, the product surface uses `Stable approved / physical validation pending` so validation-ready engineering is runnable without falsely claiming an unexecuted physical result.

## Release behavior

- All merged, validation-ready providers should be discoverable from the UX-ROM Physical Validation / Stable Promotion surface.
- Integrated read-only layer assessments should always run even when a layer has no mutation candidate.
- Research-only probes remain available as diagnostics and are not presented as proven performance treatments.
- Local evidence is retained under the UX-ROM data root.
- Stable promotion is machine-specific when eligibility or hardware behavior is machine-specific.
