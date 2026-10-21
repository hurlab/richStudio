# SPEC-WS-002 hosted browser environment binding amendment

Date: 2026-10-21. **PROPOSED — exact amendment/metadata delta requires independent review and root acceptance; no ownership or execution is active.** Intended tracked destination after approval: `docs/specs/SPEC-WORKSPACE-001/amendments/002-hosted-browser-binding.md`.

## Reason and unchanged acceptance

The accepted accessibility-tooling amendment requires actual hosted browser execution before portability acceptance but excludes workflow changes. Read-only inspection found that the browser fixture requires explicit canonical project scratch and an exact private-candidate/dependency library environment, while the existing workflow does not explicitly bind that interface. This is a static integration gap, not an observed CI failure or proof of adapter behavior. The independently reviewed hosted binding task plan is adequate as a proposal; its PASS does not grant target ownership or runtime release.

This amendment proposes only the workflow environment adapter needed to exercise the already-required hosted checks. No new product requirement, acceptance criterion, lifecycle transition, SPEC node or dependency edge is introduced. Four REQs/three ACs, tool versions, matrix, policy thresholds, product behavior and all prior evidence remain unchanged.

## Exact ownership delta and prerequisite locks

Add `.github/workflows/workspace-quality.yml` to SPEC-WS-002 `target_files` and `existing_target_files`, and to its documented existing targets. Keep all other registry fields unchanged. SPEC-WS-001 remains the historical workflow creator; SPEC-WS-011 retains its workflow/config prerequisite targets and existing dependency on002. No target is removed from either owner, no011 implementation is activated and no001 evidence is relabeled.

The adapter writer may hold the workflow lock only after root verifies accepted/integrated001, inactive001 workflow writing, accepted local final16 BROWSER evidence, terminated local packet/read locks, and no active011 or other workflow owner. Registry overlap denotes exclusive serialization, even for nonoverlapping edits. Root records actual owners/locks rather than inferring inactivity from dependency lists.

Only one implementation path is granted: `.github/workflows/workspace-quality.yml`. Product/helper/CSS/design, browser source, package metadata, runner, Playwright configuration, policy, dependencies and protected libraries stay readlocked. Administrative amendment/SPEC/dispatch edits belong to their separately designated metadata owner and require exact review before application.

## Permitted adapter behavior

Within the existing browser gate invocation, including deliberate browser-canary dispatch, derive the actual canonical checkout `tmp/runs` and fresh owned contained TMPDIR; validate paths and record allocation identities. After dependency provisioning, capture actual `Rscript --vanilla` `.libPaths()` and package origins, normalize existing absolute directories preserving order, reject unsafe delimiter/newline serialization, and record the dependency chain. Bind identical chain bytes to pre-run `WORKSPACE_DEPENDENCY_LIBRARIES` and `R_LIBS_USER`; let the unchanged runner prepend its live candidate. No developer paths or guessed package/candidate origins.

Capture provisioned inputs before the reviewed contamination scrub, then scrub/export/invoke in one gate-step shell. Preserve required setup-tool PATH, exact candidate/chain guard and actual runtime origin evidence. Do not rely on shell exports surviving another step. No GITHUB_ENV bridge is needed; any alternative transfer needs supported semantics and fresh review.

Retain all seven existing modes, ubuntu24.04/R4.6.1/Node22.21.0 pins, permissions, dependencies, thresholds and ordinary non-browser invocations. Preserve the deliberate broken assertion and failing exit. No skipped tests, relaxed containment, generic supervisor, driver, runner edit or additional lifecycle-script permission.

## Approval, validation and release

1. Before metadata application, obtain independent PASS for this amendment and exact proposed SPEC/dispatch delta, then explicit root acceptance. This proposal supplies no approval. Do not modify any frozen local source/readlock to prepare the adapter.
2. After local final16 acceptance and lock termination, assign a fresh isolated MoAI integration worktree at the accepted combined baseline. Apply only reviewed metadata and workflow changes with exclusive ownership; preserve primary checkout state and foreign work. Recompute actual overlap at dispatch because evidence ages.
3. Validate only the affected YAML/Actions structure and extracted shell using existing tools. Independently review exact combined accepted browser source, workflow, unchanged runner/config and process/security controls. Root reads complete verdicts and separately releases any commit/push/hosted action. No local full R suite/check/coverage or unreviewed probe is authorized.
4. Require actual exact-commit hosted browser/axe/focus/motion/native evidence, seven-mode full gates and deliberate negative-control rejection, with input/origin/job/run/commit/artifact/cleanup receipts and independent actual-result acceptance. Static checks or plan/source PASS cannot substitute. Whole002 and003 remain held until required acceptance and integration evidence exist.

## History, rollback and exclusions

Preserve original002/corrective01/corrective02/corrective03/final-gate STOP5 histories and the current scroll task's cumulative ledger unchanged. This integration amendment neither opens nor resets an execution counter. Root must explicitly assign any later integration task accounting within the approved workflow. Expected deliberate negative outcomes remain separately attributed; other failures are never silently converted into passes or automatically retried.

Rollback is a scoped reversal of the reviewed adapter and consistent ownership metadata, preserving historical reports and other work. Missing hosted evidence keeps002 open; rollback does not waive portability. No production/sudo/deployment, worktree disposal, manual/AT/participant result, target-R qualification, science/retention/network decision, SYNC or legacy hold is granted or closed.
