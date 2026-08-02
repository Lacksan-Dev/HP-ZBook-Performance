# UX-ROM Stable promotion approval

Date: 2026-08-02
Scope: Lacksan UX-ROM validation-ready engineering merged to `main`

The operator explicitly approved promotion of validation-ready UX-ROM implementations to Stable for use on the operator-controlled HP lab computer after each implementation completes its physical lifecycle proof on that computer.

This approval satisfies the repository requirement for explicit human approval. A second approval is not required after a qualifying physical run.

## Stable implementation boundary

`Stable for this machine` means the implementation itself has physically completed its support detection, original-state capture, dry run, application, immediate verification, reboot verification where applicable, and exact rollback proof on that machine. After that lifecycle succeeds, UX-ROM may deploy the same machine-Stable treatment again from the retained evidence state.

This approval does not manufacture or substitute physical evidence. Until the machine executes that lifecycle, the product surface uses `Stable approved / physical validation pending`.

## Performance-claim boundary

Stable implementation status does not create a responsiveness-gain claim. Experiment-specific repeated benchmarks, medians, variability, side effects, and functional checks remain required before Lacksan publishes or labels a performance benefit as proven. The machine ledger records this distinction explicitly with a separate performance-claim field.

## Release behavior

- All merged providers, experiment controllers, and reboot-aware harnesses should be discoverable from the UX-ROM Physical Validation / Stable Promotion surface.
- Integrated read-only layer assessments should always run even when a layer has no mutation candidate.
- Research-only probes remain available as diagnostics and are not presented as proven performance treatments.
- Local evidence is retained under the UX-ROM data root.
- Machine-Stable promotion is machine-specific when eligibility or hardware behavior is machine-specific.
