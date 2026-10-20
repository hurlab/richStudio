# Acceptance and verification — SPEC-WORKSPACE-001

All scenarios below are future implementation criteria. None is marked passed by writing this plan. Leaf documents add concrete examples and REQ/AC traceability. Enabled scientific features need actual installed public-route oracles; source references, screenshots and inherited tests cannot substitute.

## Binary end-to-end scenarios

**AC-001 — Entry and context (REQ-001,002).** Given a new or populated workspace, when each Home action is activated, then the corresponding route opens, explicit demo is the only automatic example-data action, and selected dataset/run/organism/keytype/status are shown or marked not recorded. Navigating away/back preserves valid settings without launching work.

**AC-002 — Optional paths (REQ-003).** Given imported enrichment with no DEG inputs or clusters, when the user validates it and chooses Create figure, then a supported plot/data export is produced without enrichment/clustering. Given a gene-list analysis, the user can stop at enrichment/figures without visiting clustering.

**AC-003 — Truthful query review (REQ-004,005).** Given different Padj and Pvalue memberships, blank/unmapped/duplicate IDs and preview versus committed filters, when inputs are reviewed and submitted, then the displayed effective rule/count/settings match the actual immutable worker input. Ambiguous or invalid inputs block with field diagnostics and no old-state mutation; unavailable mapping totals are not presented as measured.

**AC-004 — Explicit background science (REQ-004,006).** Given independent annotated fixtures with known N,K,n,k and adjustment family, when all supported GO/KEGG/Reactome public routes run with default/explicit backgrounds, then effective universes, query containment, size filtering, raw probability and adjusted probability match declared independent expectations/tolerance. Duplicates/unmapped IDs are accounted for, incompatible pairs fail and no DEG-only list silently substitutes for the measured universe. Until this passes,005 stays unresolved even if the control is safely hidden.

**AC-005 — Result identity and missingness (REQ-007,008,009).** Given duplicate term labels, multiple datasets and known/unknown test-family coverage, when tables are sorted/filtered and linked selection is used, then the same stable source term/cluster/gene is selected in each view, consistent dataset cues persist, exact result values/provider columns remain unchanged and absent rows are not falsely called nonsignificant or zero.

**AC-006 — Lifecycle and history (REQ-002,010,011).** Given a real delayed owned worker and an older successful result, when the user navigates, retries, deletes/replaces input, loads another project or closes the session, then the panel shows actual lifecycle/elapsed time and captured settings, retry has a new identity, old valid data survive failure, and late callbacks cannot modify the new/current workspace or emit current success. Restored active job records show interrupted, not resumed computation.

**AC-007 — Actual cancellation (REQ-012).** Given two sessions with separately owned active workers on a supported backend, when one requests Stop, then only its owned computation terminates, backend acknowledgement precedes cancelled status, and late results cannot publish. On unsupported backends the UI truthfully distinguishes detach and does not claim Stop works; the desired termination capability remains unresolved or requires an explicit scope disposition.

**AC-008 — Reproducible and safe projects (REQ-009,011,013,014,015).** Given current results plus a controlled version1.0 RDS/JSON analysis, when supported save/open or the accepted legacy bridge is used, then numeric values, relationships, settings and typed availability survive without recomputation or silently invented provenance. Malformed/future/traversal/link/bomb/invalid-reference imports are rejected before mutation; successful load invalidates old job authority atomically. No imported code/recipe executes. Changed public format rollout remains held until representative legacy users restore results with the security-approved path.

**AC-009 — Consistent figures/exports (REQ-005,007,013,016).** Given the same source run and supported plots, when settings/export are used, then dataset order/cues and statistic labels agree, display filters do not alter scientific input/results, and the figure bundle contains full-precision used data plus source run, transform/filter/settings and provenance availability. A saved specification reproduces plotted rows/numbers; cross-platform raster pixel identity is not required.

**AC-010 — Clustering review/comparison (REQ-017).** Given one/multiple datasets and each existing engine, when the chooser and named reruns/comparison are used, then effective policies match actual engine submission, each run persists under a distinct stable ID, incompatible input/provenance differences are visible, and comparison does not equate numeric cluster labels or promise cross-engine numerical equality.

**AC-011 — Quality/accessibility/security gate (REQ-015,018,019).** Given the complete candidate and canonical policy snapshot, when installed-package full suite/check/coverage, CLI browser, automated/manual accessibility and security checks run in the appropriate clean gate, then required criteria pass with exact commands/counts/artifacts and no unresolved Critical/High security findings. Missing tools, skipped required cases or unsafe legacy conversion block the affected gate and are not reported as passes. Primary keyboard/zoom/narrow-screen tasks have no confirmed blocking accessibility issue.

**AC-012 — Unfamiliar-user task and compatibility gate (REQ-014,018,019).** Given representative users unfamiliar with richStudio, when they perform the task set below, then their completion, assistance, errors and scientific interpretation are observed and recorded, and all blocking task issues are corrected and retested. Participant count/context is stated; team review alone never closes this criterion.

**AC-013 — Release evidence (REQ-019).** Given a reviewed candidate passing every required enabled-feature and compatibility criterion, when staging and a separately user-executed deployment are evaluated, then reports identify exact commit, installed runtime/worker libraries, actual startup/browser behavior, rollback location and all unobserved gaps before any deployment claim.

## Scientific and lifecycle verification matrix

| Family | Required cases | Evidence layer |
|---|---|---|
| Input | Empty/blank/NA/duplicate identifiers; ambiguous mappings; Padj/Pvalue priority; preview/committed difference; invalid probabilities | Unit + actual Shiny submission snapshot |
| Enrichment | GO/KEGG/Reactome deterministic annotation, zero query failure, valid empty result, unmatched/mapped counts and explicit background | Installed public worker/API + independent numerical oracle |
| Clustering | Three existing engines; single/multi dataset; raw versus adjusted policies; empty dataset drops; duplicate/numeric labels | Installed engine fixture + chooser adapter |
| Identity | Duplicate term names, reordered rows, multiple results, same display run names | Unit + browser linked views |
| Jobs | Out-of-order completion, double click, retry, delete, replace, successful/failed load, close, cancellation unsupported/supported, two sessions | Cleanup-guaranteed worker harness + actual callback assertions |
| Projects |007 additive exact-value writer/JSON roundtrip and atomic legacy state application;012 controlled1.0 RDS bridge, capability/confinement probes and nondeveloper restoration; unknown major version, typed missingness, interrupted jobs | Serialization + independently inspected bundle + browser restore and security decision |
| Trust boundary | Traversal/links/duplicates/bombs, HTML/formula labels, arbitrary URLs/recipes, mixed object types, resource admission | Safe synthetic negative tests + independent security review |
| Figures | Plot rows/values, statistic labels/transforms, top-N settings, unavailable metrics, colors/order, export replay | Numerical unit assertions + browser artifact inspection |
| Accessibility | Keyboard/focus/dialog restore, announced status, contrast/non-color cues,200% zoom,1280x720/375x667, labeled table overflow, reduced motion | CLI scan + manual observation |
| Runtime | External-CWD installed package, distinct worker namespace, server-compatible R/library identities, deterministic and separate real-provider smoke | Clean CI/staging receipts |

Numeric oracle illustration: universe4, query2, term2, overlap2 gives p=1/6 only when those are the effective annotated sizes. Expanding to8 gives p=1/28 only if the implementation retains those background members. Assert effective universe first; do not build a passing-looking fixture around silently excluded unannotated IDs. Multiple-testing expectations must separately identify the tested term family and correction method, not merely call the same application helper twice.

## Observed usability task set

1. Start with a gene-list example, explain selected identifier/filter/background, run enrichment, locate and explain a result, and make a figure without clustering.
2. Import external enrichment, resolve ambiguous/missing statistics, make a multi-dataset figure and explain missing versus tested-nonsignificant terms.
3. Start clustering from an existing result, explain the selected engine/threshold, name a second run and compare memberships without assuming numeric cluster labels match.
4. Navigate while work runs, locate its status, recover from a deterministic failure, and correctly distinguish Stop, unsupported Stop and detach.
5. Save, leave, reopen current and representative legacy analyses; identify preserved outputs and unavailable provenance without recomputing results or executing a recipe.

Research is consented and de-identified. Record what actually happened, including assistance and unsuccessful tasks. No arbitrary completion-rate claim is introduced without a stated study design; any blocking primary-task failure keeps that route open pending a successful retest.

## Completion, evidence and release criteria

- Every leaf requirement has explicit leaf AC mapping; every umbrella requirement maps through plan.md. Reports retain failing and superseded attempts as evidence rather than deleting them.
- 001 additionally verifies all enabled gate policy/rule dependency assets, a nonempty explicit TypeScript file set and a measured application resource policy/loader before consumers.012 separately owns bounded isolation discovery and bridge acceptance; a hold outcome leaves its required feature open while007 consumers proceed.
- Clean CI owns full suite/check/coverage with canonical quality/harness/LSP policy snapshots and digests. Local tests remain scoped. Runtime/tool unavailability is a gap; no invented threshold, LSP pass or CI run is reported.
- Required enabled science and legacy compatibility criteria cannot be skipped. Hiding an unsafe/incomplete feature is an intermediate containment/rollback state, not full-program completion.
- Independent reviewer approves each leaf; QA unifies baselines; security closes critical/high findings and specifically reviews each touched data boundary. Five failed implementer attempts trigger re-scope.
- Final evidence distinguishes Claim, Evidence (commands/observed output), Baseline-attribution, Gaps and Residual-risk. Inherited deployment evidence is named as inherited.
- Production release remains a separate explicitly authorized user-executed privileged operation. Preserve prior release, original legacy files and unintegrated worktrees. Actual deployed status requires actual post-run live evidence.
