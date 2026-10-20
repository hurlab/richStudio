---
id: SPEC-WORKSPACE-001
title: "Connected scientific workspace evolution"
version: "0.1.0"
status: draft
created: 2026-10-20
updated: 2026-10-20
author: workspace planning team
priority: P1
phase: "v0.1.7 target"
module: "R/"
lifecycle: spec-anchored
tags: "workspace, ux, scientific-transparency, reproducibility"
tier: L
---

# SPEC-WORKSPACE-001

## §A Context and outcome

Make richStudio a connected scientific analysis workspace while preserving its R/Shiny modules, public enrichment/clustering engines and existing valid results. This is the detailed planning response to the user's approval of all six improvement areas and explicit request for Hur Harness team structure. It authorizes planning artifacts; no runtime implementation, upstream change or production deployment is performed here.

The six outcomes are actionable Home, visible analysis context and next steps, truthful scientific setup, result-first linked exploration, understandable long-running work, and reproducible project saving. Consistent figures, clustering explanations, accessibility, security and usability are integral rather than separate cosmetic work.

Baseline source: deployed application commit `06206d050dcae02a2e773a709c5c6119d29f436e`, package version0.1.6. Release target is the next unreleased version label, not a version-bump/deployment instruction. Existing dependency-adoption specification is completed and remains historical; this initiative does not reopen its numerical policies implicitly.

## §B GEARS requirements

- **REQ-001** When users enter richStudio, Home shall offer gene lists, imported enrichment, saved analysis and a demo as independently usable entry routes.
- **REQ-002** While an analysis is selected, the workspace shall identify its dataset/run, organism, identifier type and status, showing missing metadata as not recorded.
- **REQ-003** The workflow shall permit imported enrichment to bypass enrichment and shall permit figures without clustering or a forced wizard.
- **REQ-004** When enrichment submission is requested, the scientific review shall display the effective query selection, mapped-count availability, annotation settings and actual background policy before dispatch.
- **REQ-005** When preview controls change, the workspace shall distinguish display/preview filtering from committed scientific input and preserve original uploaded values.
- **REQ-006** Where custom background is enabled, the exact installed public enrichment route shall reproduce independent raw/adjusted statistical and effective-universe oracles.
- **REQ-007** When results complete, the workspace shall prioritize readable results and valid next actions while retaining full-precision values and provider columns.
- **REQ-008** When users select terms/clusters, linked views shall maintain stable source identity and consistent dataset cues without mutating analysis results.
- **REQ-009** When data are absent from comparison, views shall distinguish not tested, not significant, not supplied and unknown only when the evidence supports that interpretation.
- **REQ-010** While a job is active, the workspace shall retain actual status, captured settings and elapsed time across navigation without fabricated progress.
- **REQ-011** When callbacks belong to cancelled, replaced, deleted, loaded-away or obsolete runs, they shall not mutate the current workspace or report current success.
- **REQ-012** Where Stop is enabled, it shall terminate only the owned computation and shall report cancelled only after backend acknowledgement; unsupported termination shall be described separately from detaching results.
- **REQ-013** When a project is saved/reopened, it shall preserve result identity, effective parameters, provenance availability, version information, typed missingness and data relationships without automatic recomputation.
- **REQ-014** When changed import/format rollout is evaluated, the application shall require representative version1.0 RDS and JSON analyses to be restorable without silent loss through an accepted safe compatibility bridge before enabling that rollout.
- **REQ-015** The application shall not execute uploaded recipes/scripts or present unrestricted RDS deserialization as safe interchange.
- **REQ-016** The supported figure controls and exports shall identify source runs, statistic meaning, transformations and display filters consistently.
- **REQ-017** When clustering runs are selected or compared, their distinct algorithm, input, threshold, background and provenance semantics shall be visible and prior runs shall remain immutable.
- **REQ-018** The interface shall support keyboard use, meaningful focus/status labels, non-color identity cues, zoom and narrow-screen primary tasks.
- **REQ-019** When release is evaluated, the candidate shall satisfy the linked acceptance criteria and canonical project gates using current installed-runtime, scientific, usability, accessibility and security evidence before publication.

## §C Completion contract

Umbrella acceptance.md and twelve leaf SPECs define the executable verification. All enabled capabilities need evidence; a source signature or design screenshot is not runtime proof. A disabled optional feature is explicitly unavailable, not passed functionality. Background support and safe legacy-format rollout each have scientific/security holds. No plan-phase test result is claimed.

## §D Constraints

Preserve existing module namespaces and public engine adapters, current legitimate default semantics, imported-only routes, unclustered plotting, exact raw results and legacy analysis data. New behavior uses stable IDs and immutable run/input snapshots. Job persistence means session and saved-project metadata, not a shared database. New queued/running records reopen as interrupted, not resumed workers.

Use existing Shiny components and CSS tokens. Keep resource limits configurable and justified through measured representative fixtures; numerical quality thresholds remain in canonical configuration. Read-only reviewer roles follow the repository's launcher contract. Full-suite gate runs belong in clean CI, scoped checks on the developer machine. Deployment remains a separate user-executed privileged operation.

## §E Exclusions

### Out of Scope — Product expansion

- Accounts, cloud storage, collaboration servers, distributed scheduling, GSEA, AI narratives, new analysis algorithms and framework rewrite.
- Automatic recipe execution, automatic statistical recomputation of old results or silent metadata inference.

### Out of Scope — Current planning turn

- Runtime implementation, package releases, production configuration changes, sudo execution or deployment.
- Drive-by cleanup of earlier SPEC-FIX items; historical issue prose is not fresh evidence of a current defect.

## §F Risks and release holds

Scientific background semantics require exact route tests even though public015 exposes universe arguments. Legacy RDS needs a proven security/usability bridge before changed format rollout. Unsupported worker cancellation must remain unavailable or honestly described as detach. Imported/old metadata cannot reliably establish what was tested. Large-table/graph memory and UI responsiveness require measurement, not assumed scalability. Accessibility and unfamiliar-user usability require direct observation, not team approval alone.

## §G Traceability

The plan maps REQ-001..019 to leaves and acceptance.md. Machine-readable dispatch.json is the exact file/logical lock registry. Research.md distinguishes observed source facts, inherited evidence, actual planning probes and unmeasured assumptions. Design.md records contracts to settle before code; leaf technical sections guide implementation without changing the observable requirement contract.

## §H HISTORY

- 2026-10-20: Planning-only Tier L umbrella and eleven initial leaf drafts created using Hur Harness hybrid team/dependency dispatch, with independent UX, QA and security consultation.

- 2026-10-20: Independent audit D1–D6 led to explicit direct-plot validation, complete gate-asset transport, early resource policy, typed browser configuration, GEARS corrections and a twelfth atomic legacy bridge contract that does not block additive exploration.
