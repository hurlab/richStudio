# SPEC-DEPENDENCY-001 implementation plan

## §A Context

Use the isolated dependency-adoption worktree on WT-dependency-adoption. Project SPEC artifacts live in docs/specs. Primary harness configuration selects TDD; begin with executable consumer expectations before each compatibility change.

## §B Known issues and evidence limits

Inspected DESCRIPTION declares richR without a version floor, guokai8/richR as its remote, and optional richCluster without a version floor. Source inspection finds Reactome's `annot=` argument and single-dataset standalone-clustering bypasses. These observations identify test targets, not verified app failures. The richR handoff supplies a failing exact Reactome source-dispatch probe; installed app dispatch remains to be measured here.

The primary .moai/project/product.md, structure.md and tech.md context files are absent. Existing DESCRIPTION, session coordination and project rules supply the available context. Primary quality.yaml selects tdd; interview.decision_gate is off.

### Upstream patch dependency — implementation addendum

The coordinating richR maintainer reported installed-0.1.4 defects affecting namespace-only KEGG Level-column lookup and balanced/single-cluster result assembly, the latter also occurring with the full ORA schema and inherited from 0.0.40. These are supplied upstream execution findings, not new measurements by the SPEC author. AC-009 was blocked pending a reviewed immutable upstream patch release; preserve that historical failed baseline and do not close the criterion with an invalid fixture, cherry-picked upstream code or a private consumer workaround.

The initial addendum retained the exact 0.1.4 pin because no published replacement was then available. The orchestrator subsequently verified the GitHub tag v0.1.5 as commit 9be43abdae556d9f1df128149a70721f08ab7d25 and the release as neither draft nor prerelease. The contract now selects that official immutable 0.1.5 pin; standalone richCluster remains unchanged. Release asset: https://github.com/hurlab/richR/releases/download/v0.1.5/richR_0.1.5.tar.gz, SHA256 0fdca054567c3e6c0ef51512a11ba755ea3694126aa42cbbb051fed3f1b69abf, 2769042 bytes. Producer code/artifact review PASS and three-OS CI run 39442357829 (552 passes, zero failures/warnings/skips, check OK) are supplied upstream evidence; the orchestrator reports the release product/tests tree identical to reviewed 5903f44.

Obtain a new independent audit of this precise SPEC delta before accepting the changed contract. Install 0.1.5 in a separate task library that preserves the 0.1.4 baseline, verify the published identity and archive, and rerun all required installed consumer checks, including namespace-only KEGG Level columns, AC-009's union-background oracle and the retained balanced/single-cluster regressions. Upstream publication, review or CI does not satisfy consumer acceptance. AC-001–AC-010 remain required PASS gates under the new pin.

The retained-dataset mapping correction tracked as F7 remains within AC-007: after hierarchical filtering drops the first or a middle dataset, retained names and their GeneID/Pvalue metrics must still map to the original datasets. Test both positions explicitly; this clarifies the existing membership-preservation contract rather than adding new analysis behavior.

## §C Pre-flight

- Record worktree HEAD, status, R version, active library paths and installed dependency identity before treating any run as the integration baseline.
- Use a task-specific library and explicit startup/library resolution; inspect .Rprofile, renv activation and the old lockfile before choosing commands.
- Confirm exact dependency source commits; install compiled sources in isolation. Do not treat same-version sibling checkouts as exact release evidence.
- Capture current significance and output-shape expectations with deterministic, local fixtures.

## §D Constraints and decisions

Preserve method-specific significance policy. Hierarchical clustering filters EACH normalized input dataframe by `Pvalue < min_value` before merging, drops resulting empty dataframes, then calls public `cluster(filter_on="Pvalue", min_value=1)` to retain the existing second gate. Do not move the input filter after merging or inherit Padj. DAVID retains its existing absence of significance-threshold filtering; do not add `filter_on` or `min_value` to `david_cluster`. Keep richR::richCluster separate from richStudio's similarly named wrapper.

For richR clustering, use `gene=NULL`, which derives the union of comma-delimited GeneID values in merged input terms. The current app supplies no separate measured universe; introducing one is outside this task. A deterministic fixture must distinguish the chosen union background from logical TRUE and an explicit unrelated background through expected memberships or numeric results. No new user control is required. Qualify richR annotation/enrichment calls, including Reactome's `object=`, and verify actual runtime dispatch rather than asserting a masking failure.

No new metadata persistence or per-group status UX is required. Preserve explicit errors and valid empties through the current workflow. Zero query genes after input filtering require explicit rejection without restoring unfiltered input; this differs from a valid engine result retaining zero terms.

No installed dependency test or RED/GREEN measurement was performed during SPEC authoring. The implementation baseline and its evidence remain to be measured by the implementation owner.

## §E Self-verification

Use testthat fixtures with small deterministic annotations and enrichment tables. Exercise the actual consumer wrappers and the existing future execution route. Stub external annotation retrieval only at the provider boundary; keep the installed richR dispatch real. Use compiled standalone richCluster for clustering acceptance checks. Missing packages, skipped integration cases or provider-only probes are gaps, not successful acceptance.

Run the affected tests first. Broader checks belong to CI unless a new failure justifies additional local testing. Record command, verbatim bounded output, library identities and worktree attribution in the implementation report. Follow configured project quality gates without duplicating their thresholds here.

## §F Milestones

### High — Consumer semantics and regression fixtures

Own implementation touch points in R/deg_enrich.R, R/enrich_tab.R, R/rr_cluster.R and tests/testthat. Establish method-specific significance, empty/error and result-shape fixtures before edits. Cover one and multiple datasets; hierarchical-only conflicting raw/adjusted significance, cutoff equality and pre-merge per-dataset filtering; DAVID's absence of significance-threshold filtering; richR's term-union background; valid empty and malformed/unmapped query cases.

Expected outcome: testable acceptance boundaries before adopting changed numerical clustering behavior.

### High — Enrichment and clustering integration

Use namespaced richR::buildAnnot, richR::richGO, richR::richKEGG and richR::enrich; correct Reactome's object argument. Verify worker dispatch and error propagation. Remove standalone single-dataset internal bypasses only once public cluster/david_cluster paths pass equivalent consumer-contract tests. Keep necessary output adapters, gene separators and dataset membership handling.

Expected outcome: correct installed-engine behavior with preserved app policy.

### High — Reproducible dependency resolution

Update DESCRIPTION, targeted richR/richCluster records in renv.lock, and relevant install hints/runtime launch instructions under inst/application or scripts as needed. Record exact remote SHA, version and isolated-library resolution. Do not regenerate unrelated lock entries or force a broad historical restore.

Expected outcome: documented commands reproduce the verified dependency identities without changing global libraries.

### Medium — Scoped regression and handoff

Run related enrichment, clustering and session tests against the resolved installs; obtain independent review and correct confirmed in-scope findings. Update dependency guidance and session records through their designated owners. Report old-versus-new numerical differences with their measured baseline rather than promising exact historical clustering equivalence.

Expected outcome: reviewable migration with observed evidence and explicit remaining gaps; no deployment implied.

### Future deployment boundary — user-executed server script

Deployment is separate from this migration's acceptance. The user's protocol is to prepare a .sh script for their sudo execution, thoroughly review the completed script again, and upload it to the verified intended server over Tailscale. The agent must never run sudo. The orchestrator supplied the measured server identity: Tailscale 100.94.67.89, hostname Hurlab, application /home/juhur/shinyapps/richStudio, observed HEAD fc12497. Reverify the target identity and current checkout before upload rather than treating that observation as permanent.

The script must write its execution log and exit-status file in a server temporary directory. The handoff must provide the exact uploaded script path, the user's exact sudo command and both result paths. After the user executes it, retrieve and inspect those server-side results directly before making any deployment claim. Do not deploy on the home computer.

## §G Anti-patterns

Do not replace app orchestration wholesale with batchEnrich, assert that version equality proves fork identity, mock the engine while calling a test integration, infer success from source signatures, or delete adapters solely because an upstream issue was fixed.

## §H Cross-references

- spec.md: scope, requirements and exclusions.
- acceptance.md: AC-001–AC-010.
- progress.md: lifecycle evidence ownership.
- Primary harness guidance: .moai/config/sections/quality.yaml and .agents/skills/moai-workflow-{spec,tdd,testing}/SKILL.md.
