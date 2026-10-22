# Amendment 004 — SPEC-WS-004 ownership and intake interpretations (draft r6)

**Status: takes effect only through step 3 of `ws004-dispatch-plan-r6.md` after root acceptance.** Supersedes r5 (`ws004-registry-amendment-draft-r5.md`, sha256 `c25fbcb25b3dcc41443ecf4cd35a04098e572ca77cb68e391509cca45261a5d4`), r4, r3, r2 and r1. The published bytes are unchanged from r2. Decisions 1 and 3 read as in r2; decision 2 is the owner's decision as made, with its measured reason corrected in r4 (1163 bytes). Decision 4 is new in r6. How the plan enforces the decisions is listed separately under "Mechanism".

## Owner decisions (2026-10-22)

1. SPEC-WS-004 owns `R/deg_enrich.R`, so an explicit raw-versus-adjusted p-value choice on the review card is forwarded to the enrichment worker. Not chosen: display-only with explicit choice deferred to SPEC-WS-005; dropping explicit raw selection.
2. For gene-membership columns of imported enrichment results, the installed `string_bytes` limit (1030) applies to each delimited identifier, not to the whole membership cell. All other cells, column names and labels keep the limit as written. Reason: the bundled demo `inst/extdata/go2.txt` has 2 membership cells over 1030 bytes (max 1163 excluding the line terminator, measured with `LC_ALL=C` awk at `9fc6b21`); every GO term with roughly 140+ member genes would otherwise be refused. Not chosen: re-measuring the 001 envelope; enforcing the limit per cell.
3. Result-file uploads whose present roles all match canonical column names exactly are validated and imported immediately (today's single step); other uploads wait for explicit confirmation of the mapping. Not chosen: always confirm before import (would require changing SPEC-WS-003-owned tests).
4. Text uploads are refused before parsing when any line exceeds 256 KB (262,144 bytes), because `read.delim` time grows quadratically with cell length (audit r5 S26: 0.17 s, 0.66 s, 2.70 s at 125, 250, 500 KB). The bound is a SPEC-WS-004 constant, held for adoption into the 001 resource policy. Not chosen: deriving it from the policy (24 × 1030 bytes, which would refuse GO terms with roughly 3,000+ genes); leaving it as residual risk.

## Mechanism (plan `ws004-dispatch-plan-r6.md` items 1e, 1f and 6; not an owner decision)

Until the membership column is known (at admission), every character column of a result file is checked per identifier as a provisional bound. A file in which a column other than an exact `GeneID` passes only per identifier waits for mapping instead of importing immediately. Once the mapping is fixed, every column other than the mapped membership column is re-checked per cell before publication.

## Changes (exact bytes: `ws004-dispatch-json-expected.json` sha256 `6e708ee9c0321509827a6e7da238e9b618e5af5873464a0f745003b5abd1ff73`, `ws004-spec-ws004-expected.md` sha256 `6444bc418382c612b420d3d7b2755252ab103909e46e23f4ef3cf2905b044634`)

1. `docs/specs/SPEC-WORKSPACE-001/dispatch.json`, node `SPEC-WS-004` only, two hunks: `"R/deg_enrich.R",` added to `target_files` after `"R/file_handling.R",`; in `existing_target_files` the last entry `"R/file_handling.R"` gains a comma and `"R/deg_enrich.R"` follows (three lines added, one modified). No other node, field or ordering changes. `R/deg_enrich.R` stays a target of SPEC-WS-005; locks are exclusive and sequential (005 depends on 004 and 006).
2. `docs/specs/SPEC-WS-004.md`: front matter `updated: "2026-10-22"`; `R/deg_enrich.R` under "Existing targets"; technical plan item 1 gains the explicit query-rule sentence and the statement that the default resolution reproduces the current rule exactly (exact case-insensitive `padj`, else `pvalue`, else no filter), other recognized names being explicit choices only; the security section gains the per-identifier string-limit sentence; one HISTORY line. No REQ or AC text changes.

## Boundaries kept

Background/universe semantics, annotation-dependent counts and statistical defaults stay with SPEC-WS-005; job admission, cancellation, generation and run records stay with SPEC-WS-006/007. SPEC-WS-004 does not change annotation building, universe or richR call arguments in `shiny_enrich()`.

## Recorded design deviations (root acceptance records them; the SPEC-WS-011 human-review hold covers them)

- **D-A04-1 Run without commit.** Design A04 (`workspace-screens.md:43`) puts **Commit input revision** before a separate **Run**. SPEC-WS-004 keeps Run available without a commit: the default rule (identical to today's rule) is resolved at Run with the live default cutoff and labeled **Default rule (not customized)** on the review card.
- **D-A04-2 Import without explicit confirmation.** A04 asks for explicit column mappings. Under decision 3, uploads whose roles all match canonical names exactly import without a confirmation step; the Imported results card shows the mapping afterwards.
- **D-AC002 Explanation location.** AC-002's explanation of the incompatible clustering option is shown in both upload tabs' Imported results cards for every result, not on the clustering method control, because `R/cluster_tab.R` is not a 004 target.
