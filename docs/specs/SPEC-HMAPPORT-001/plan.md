# Plan — SPEC-HMAPPORT-001 v0.1.0

## Scope and targets

High priority: prove byte-identical output before accepting the representation fix.
Use ASCII-only base R intToUtf8 with integer8230L for the ellipsis and8211L for
each range dash. Preserve evaluation context and every existing surrounding
expression. No literal escape sequences or ASCII punctuation substitutions.

| File | Authorized edit |
|---|---|
|R/cluster_hmap.R|Only the ellipsis at baseline line165 and range dash at line197.|
|R/clus_visualize_tab.R|Only the row-window choice range dash at baseline line432.|
|docs/specs/SPEC-HMAPPORT-001/|Plan artifacts and owner-specific progress evidence.|

Only these three source-expression substitutions are authorized. Preserve CRLF
using byte-safe targeted replacements; do not rewrite/reformat whole R files.
The R5 hashes may change only under this new authorization; SPEC-HMAPCI-001's
application freeze was correct for its earlier scope.

## Ordered execution

1. **High — Plan review and baseline.** Obtain independent approval; enter a fresh
   root-coordinated isolated worktree. Read the actual hosted R-check warning log
   under .moai/reports/heatmap-ci-stability/hosted-41065823052/full/workspace-quality-artifacts/R-check/richStudio.Rcheck/00check.log.
   Capture all CI-harness/QA hashes and original product bytes/CRLF counts.
2. **High — Minimal correction and equivalence.** Substitute exactly three
   expressions. Use the existing native R ASCII checker before/after and compare
   immutable installed R5 with a freshly loaded candidate namespace, including
   truncated labels, full/partial row-window title and native UI choices.
3. **High — Review and hosted verification.** Run focused existing tests and four
   scientific goldens, matrix portability checks and byte/hash comparison.
   Independent review must confirm only authorized representation edits.
   Root publishes the new candidate for all seven hosted jobs.

## Validation and risks

R CMD check is the permanent regression gate; do not add tests mirroring the three
constructors. A small existing-helper assertion is permitted only if it verifies
meaningful Unicode equivalence not already covered. No new product/test source
file is necessary. Preserve all four CI-harness source files and focused QA
source byte-for-byte; record actual paths/digests from the integration baseline.

Compare UTF-8 byte output, not merely visual appearance. Check each source's line
endings and exact diff to prevent accidental CRLF normalization. Keep previously
unobserved canary/exec causes as gaps; fresh all-seven verification cannot be
replaced by retrying the old known-warning full job. An unchanged browser
bootstrap failure does not authorize timeout or native-interaction changes.

Rollback only the three substitutions if equivalence fails; no migration,
dependency or scientific-result rollback is needed. Root owns commits and logs.
