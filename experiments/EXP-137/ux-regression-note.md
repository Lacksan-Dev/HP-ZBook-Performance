# EXP-137 UX regression correction

The first EXP-137 integration moved the original UX-ROM controller behind a bootstrap entrypoint and exposed enrollment cleanup primarily as a direct action. Although the original ASCII controller remained in `controller/core/ZBookPerf.Core.ps1`, that design made the new maintenance workflow feel separate from the UX-ROM interface.

This correction keeps the original ASCII splash, twelve-layer menu, diagnostics, synergy batch, status, and maintenance tools as the normal UX-ROM experience. EXP-137 now appears as `E. Self-managed enrollment cleanup` inside that same menu while retaining direct automation actions.

The regression is preserved here as engineering history rather than hidden. No Windows performance claim is associated with this UI correction.
