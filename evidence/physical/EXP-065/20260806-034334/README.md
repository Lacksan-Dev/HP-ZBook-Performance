# EXP-065 physical validation evidence

Release state: Experimental
Evidence status: physical-lifecycle-recorded
Performance claim: none

This package is a bounded, sanitized projection of machine-local raw evidence. It excludes machine and user identifiers, serials, paths, process IDs, credentials, browser/profile data, and customer content. Raw runs, exact original state, logs, and rollback artifacts remain on the operator-controlled lab machine.

The JSON summary records repeated benchmark aggregates, lifecycle gates, protected scope, and SHA-256 digests for local evidence integrity. It does not assign Stable.
