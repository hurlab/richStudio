# SPEC-WS-003 baseline Home assertion ownership

This amendment takes effect only after independent PASS and root acceptance of it together with the paired SPEC-WS-003 dispatch plan, and byte-identical publication at `docs/specs/SPEC-WORKSPACE-001/amendments/003-baseline-home-assertions.md`.

## Reason

SPEC-WS-003 replaces the static Home step cards with four entry actions. `tests/testthat/test-baseline-ui-workflows.R`, owned by the completed SPEC-WS-001, asserts two labels of the old step cards at lines 22–23: `Upload &amp; Enrich` and `Visualize &amp; Export`. Keeping those labels only to satisfy the old assertions would leave misleading Home content. The file has no active owner.

## Change

1. `docs/specs/SPEC-WORKSPACE-001/dispatch.json`, node `SPEC-WS-003`: append `tests/testthat/test-baseline-ui-workflows.R` to `target_files` and to `existing_target_files`. No other node, key or file in the registry changes.
2. `docs/specs/SPEC-WS-003.md`: under "Existing targets", add the bullet `` - `tests/testthat/test-baseline-ui-workflows.R` (two Home label assertions only; see [003 baseline Home assertions](SPEC-WORKSPACE-001/amendments/003-baseline-home-assertions.md)) `` after the `inst/application/app.R` bullet, so the leaf document and the registry agree; and append to HISTORY the bullet `- 2026-10-21: Baseline Home assertion ownership amendment adds tests/testthat/test-baseline-ui-workflows.R as an existing target limited to two Home label assertions.` No other line changes.

SPEC-WS-003 may change only the two Home label assertions in that test file (lines 22–23 at `b8eb759`) so that they assert labels of the new Home actions. Every other assertion in the file, including the Home tab id, version and logo assertions, stays unchanged. The `Welcome to richStudio` and `Quick Start` headings remain on Home, so the shared browser fixtures are unaffected.

After this amendment, `docs/specs/SPEC-WS-003.md` changes from SHA `457c7b909766458574cf24cc4eacfcff8d98c3f3782b9df7ff9de017a6918692` to SHA `bced8d75d4bd2ceab4774749f5875c4cf7c8f54bfdb1c506c70c12395938058e`, and `docs/specs/SPEC-WORKSPACE-001/dispatch.json` changes to SHA `443a7fb490349705b0512809cd3d860e5eb8f2799fded2159ff9a33dcb28a3a5`; requirements and acceptance criteria in the SPEC are byte-unchanged.

## Unchanged

REQs, ACs, dependency edges, quality thresholds, other nodes' ownership and all stopped histories.
