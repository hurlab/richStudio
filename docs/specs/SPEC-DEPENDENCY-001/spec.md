---
id: SPEC-DEPENDENCY-001
title: "Adopt current enrichment and clustering dependencies"
version: "0.1.0"
status: in-progress
created: 2026-10-20
updated: 2026-10-20
author: manager-spec
priority: P1
phase: "v0.1.7 target"
module: "R/"
lifecycle: spec-anchored
tags: "dependencies, enrichment, clustering, compatibility"
tier: M
---

# SPEC-DEPENDENCY-001

## §A Context

Adopt the released hurlab richR 0.1.5 and standalone richCluster 2.0.1 in richStudio without silently changing the app's significance policy. The user authorized this dependency migration through the coordinating richR session on 2026-10-20. The home computer is for implementation and verification; deployment is a separate gated operation.

Tier M: bounded dependency, runtime-resolution and consumer integration work. The release target is the next patch after the inspected DESCRIPTION version 0.1.6; this SPEC does not require a package-version bump.

## §B Requirements

- **REQ-001** The dependency configuration shall identify hurlab/richR 0.1.5 at commit `9be43abdae556d9f1df128149a70721f08ab7d25` and standalone richCluster 2.0.1 at commit `a0d1f630fbe64089ab38516116b78962672e6349` reproducibly.
- **REQ-002** When the scoped verification runs, the runtime shall load the specified installed dependency versions from an isolated library and record their origins, paths and R version.
- **REQ-003** When users run GO, KEGG or Reactome enrichment, the application shall dispatch to the intended released enrichment engine in both the application process and its existing worker execution path.
- **REQ-004** When valid enrichment retains no terms, the application shall preserve the valid empty result and its typed table structure without substituting input rows.
- **REQ-005** When input filtering leaves no query genes, enrichment input is invalid or its engine fails, the application shall retain an explicit failure outcome and shall not restore the unfiltered query or report fabricated successful enrichment.
- **REQ-006** When enrichment succeeds, the application shall retain the existing result-column meaning, additional provider columns, comma-delimited gene identifiers and supported save/reopen behavior.
- **REQ-007** When users select hierarchical or DAVID clustering for one or multiple datasets, the application shall consume standalone richCluster 2.0.1 results through tested supported entry points and preserve downstream term-to-cluster and dataset membership.
- **REQ-008** When hierarchical clustering applies the significance threshold, the application shall filter each normalized input dataset by strict raw-p-value inequality before merging and discard empty datasets, without inheriting an adjusted-p-value default; when DAVID clustering runs, the application shall preserve its existing absence of significance-threshold filtering.
- **REQ-009** When the richR clustering option runs, the application shall use the union of gene identifiers in the merged input terms as its background, interpreting those identifiers with the existing comma delimiter rather than using a logical flag or a separate unrelated universe.
- **REQ-010** The migration verification shall distinguish the richR clustering engine, standalone richCluster and richStudio's own clustering implementation, and shall report numerical changes against the appropriate baseline.

## §C Acceptance and completion

The binary acceptance scenarios are in acceptance.md. Completion requires AC-001 through AC-010 all to pass in executable consumer tests against the exact installed dependencies, scoped regression checks, independent review, and a report identifying commands, observed output, measured tree and unobserved integration/deployment surfaces. Failed, skipped or unobserved required cases keep the migration incomplete. Source inspection and upstream CI alone do not establish consumer compatibility.

## §D Constraints

Preserve current UI defaults and the existing orchestration unless a compatibility correction requires a scoped change. Do not restore the entire historical lockfile or update unrelated dependencies merely to adopt these releases. Installation and verification must not modify shared runtime libraries. Older clustering results are historical results; do not silently recompute or relabel them.

## §E Exclusions

### Out of Scope — New analysis features

- GSEA, ranked-input UI, explicit-background UI, backend/RNG controls, new diagnostics dashboards and new batch-status UX.
- New provenance/session-format features beyond preserving existing supported save/reopen behavior.

### Out of Scope — Unrelated work and deployment

- General B3–B8 cleanup, performance redesign, vendored clustering modernization and broad dependency refresh.
- Local deployment on the home computer or deployment before the established gates and intended server's Tailscale identity are verified.

## §F Risks

Standalone richCluster 2.0.0 corrected numerical behavior; equivalence to old numerical outputs is not a valid universal acceptance condition. Upstream release evidence is supplied context, not an installed richStudio baseline. Annotation providers may require unavailable resources; deterministic annotation fixtures shall isolate consumer dispatch from provider-network availability.

## §G Traceability

Requirements map one-to-one to AC-001 through AC-010. Implementation details and source touch points belong to plan.md. Dependency coordination inputs: richStudio coordination report dated 2026-10-20 and the richR integration handoff, both read during this plan phase.

## §H HISTORY

- 2026-10-20: Drafted bounded dependency-adoption SPEC following explicit implementation authorization; no product verification claimed.
- 2026-10-20: Corrected plan-audit D1–D3: require every AC to pass, settle the richR term-union background, and distinguish hierarchical per-dataset filtering from unfiltered DAVID significance behavior.
- 2026-10-20: Replaced richR 0.1.4 commit 22b4376fb510d553af325a5bfc3208231a33cc47 with official reviewed 0.1.5 commit 9be43abdae556d9f1df128149a70721f08ab7d25 after the retained 0.1.4 installed regressions. New pin requires independent SPEC-delta audit and fresh installed consumer evidence; no implementation completion claimed.
