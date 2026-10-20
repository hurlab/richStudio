# SPEC-DEPENDENCY-001 acceptance

Each scenario is evaluated against this worktree and its isolated installed dependencies. Required cases cannot be closed by skips or upstream-only evidence.

## §D AC matrix

| Criterion | Requirement |
|---|---|
| AC-001 | REQ-001 |
| AC-002 | REQ-002 |
| AC-003 | REQ-003 |
| AC-004 | REQ-004 |
| AC-005 | REQ-005 |
| AC-006 | REQ-006 |
| AC-007 | REQ-007 |
| AC-008 | REQ-008 |
| AC-009 | REQ-009 |
| AC-010 | REQ-010 |

- **AC-001** Given the committed dependency configuration, When its richR and standalone richCluster origins are resolved, Then their versions and full commits match spec.md REQ-001 and no unrelated lockfile record changes are introduced without a documented dependency need.
- **AC-002** Given a task-specific installed library, When the scoped integration command starts a fresh R process, Then it records the R version, package paths, versions and source identities for both exact releases and loads neither dependency from a shared mutable installation.
- **AC-003** Given deterministic GO, KEGG and Reactome annotations, When the actual enrichment wrapper runs in the app process and the existing future-worker route, Then all three dispatch through installed richR and return expected retained term IDs without argument-dispatch errors.
- **AC-004** Given a valid enrichment fixture with no terms passing a valid strict cutoff, When enrichment reaches the app's result-handling path, Then zero biological rows remain, expected typed columns are retained and original input rows are not substituted.
- **AC-005** Given zero query genes after input filtering, invalid or unmapped-only input and a separately induced engine failure, When the current enrichment workflow processes each case, Then it exposes an explicit failure, does not restore unfiltered query genes and publishes no fabricated successful enrichment; any previously displayed results are not mislabeled as the failed run's results.
- **AC-006** Given a successful result with provider-specific columns and comma-delimited gene IDs, When the result passes through app transformation and supported save/reopen handling, Then standard columns retain their values and types, extra columns survive existing supported handling, gene membership is preserved and a legacy saved-session fixture remains readable.
- **AC-007** Given one-dataset and multi-dataset fixtures with known term memberships, including hierarchical cases where filtering removes the first or a middle dataset, When hierarchical and DAVID consumer wrappers run against compiled richCluster 2.0.1, Then supported public paths produce consistent merged term identities, valid cluster indices and correct dataset membership without relying on the historical single-dataset bypasses, and retained datasets keep their original names and corresponding metrics without positional reassignment.
- **AC-008** Given hierarchical fixtures where raw Pvalue and Padj disagree, raw Pvalue equals the chosen cutoff, per-dataset versus post-merge filtering would differ and one dataset becomes empty, When the wrapper processes one and multiple datasets, Then it applies strict raw-Pvalue filtering to each normalized dataset before merging, drops empties and uses the existing raw-Pvalue second gate of 1; Given DAVID fixtures containing terms that hierarchical filtering would exclude, When DAVID runs, Then those terms are not removed by an added significance threshold and no unsupported significance-filter arguments are supplied.
- **AC-009** Given a deterministic richR-clustering fixture whose expected union-background memberships or numeric results differ from logical TRUE and an explicit unrelated background, plus the retained balanced/single-cluster regression fixtures, When the richStudio richR wrapper runs against installed richR 0.1.5, Then its background is the union of comma-delimited GeneID values in merged input terms, its result matches that union-background oracle, it does not use either alternative background and valid regression fixtures complete without the historical result-assembly failure.
- **AC-010** Given separate fixtures for the three clustering identities, When scoped regression evidence is assembled, Then each engine is identified explicitly, asserted memberships refer to its own measured baseline and any corrected standalone numerical differences are recorded without asserting universal equality to old results.

## §D.1 Closure gates

AC-001 through AC-010 must all PASS with observed evidence before completion. A failed, skipped or unobserved required case keeps the migration incomplete; reporting that case as a gap does not permit closure. Related existing tests pass in the measured runtime. Independent review has no unresolved confirmed in-scope findings. Reports include command/output, baseline attribution, gaps and residual risks. Documentation states reproducible dependency setup and does not claim production verification.

## §D.2 Deployment boundary

Completion of this SPEC does not mean deployment. This home computer must not host a direct deployment; any later deployment requires the established gates and mechanically verified intended server identity through Tailscale.
