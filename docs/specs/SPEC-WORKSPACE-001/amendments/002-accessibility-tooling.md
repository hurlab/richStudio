# SPEC-WS-002 root re-scope and accessibility tooling amendment

Date: 2026-10-21. Status: **PROPOSED — pending independent plan-audit and coordinator acceptance**.

## Decision and reason

The original002 execution cycle reached its five-unplanned-failure cap and is stopped. This root re-scope proposes two bounded corrective children and standard locked QA tooling. No sixth attempt or corrective cycle is authorized by this document.

Propose exactly `axe-core` version `4.14.0` as an npm development dependency for real browser accessibility scanning. Use the existing `package.json` and npm-supported `package-lock.json` lifecycle instead of the ignored custom download/extraction provisioner. This is verification tooling; it adds no R Imports, application framework or production browser dependency. No dependency has been added by this proposal.

Measured integration baseline: `67570a065d1a4a93c184fbb0e12868be3b6dea2f`, `workspace-evolution-integration`. The manifest and lockfile currently list Playwright, Node types, TypeScript and ast-grep, with no axe entry; lockfileVersion is3. Existing workspace-quality workflow already provisions with `npm ci --ignore-scripts --no-audit --no-fund`, then selectively rebuilds `@ast-grep/cli` offline. Retain that policy without workflow edits or new lifecycle-script permissions.

The existing ignored QA provisioner has119 lines and its separate diagnostic67, observed with `wc -l`; they own fetching, extraction, metadata/license checks and temporary resource cleanup. This proposal instead declares two existing metadata files, delegates dependency installation/integrity handling to npm, and resolves the local installed engine in the owned browser test. This is a comparison of actual code/data ownership, not an estimate of final implementation length or a claim that npm removes the need for provenance checks.

## Exact ownership and authority

Only two paths are added to002 `target_files` and `existing_target_files`: `package.json` and `package-lock.json`. No new target is added. Current product writer remains limited to `inst/application/www/custom.css`, `R/workspace_components.R`, `tests/testthat/test-workspace-components.R`, and `tests/e2e/design-system.spec.ts` until root issues the revised brief. After approval, root may delegate the two metadata writes to manager-develop under exclusive locks; the browser spec remains the location for local engine consumption and assertions.

The three reviewed design documents remain byte-frozen. After approval, this amendment supersedes only their restriction against a new development dependency/private-only axe provisioning, for this one pinned QA tool. Their product behavior, four REQs/three ACs, route/component inventory and design-r2 PASS subject are unchanged. Do not rewrite the reviewed documents or reinterpret that PASS as approval of this amendment or runtime acceptance.

No edits to DESCRIPTION, NAMESPACE, app/route wiring, runner, Playwright configuration, CI workflow, policy bundle, quality thresholds or other dependency versions are authorized. Existing root PROJECT_LOG changes belong to the coordinator.

## Bounded corrective children — proposed, execution frozen

| Child | Exclusive write targets | Locked reads and prerequisites | Required milestone output |
|---|---|---|---|
| COMPONENTS | `inst/application/www/custom.css`, `R/workspace_components.R`, `tests/testthat/test-workspace-components.R` | Frozen three design documents, SPEC/registry/amendment, existing package/namespace/runner interfaces; no writes to those inputs | Minimal internal component API and scoped CSS; actual private installed-candidate unit evidence with source/installed identity, no required skips; independent component/API review before BROWSER execution |
| BROWSER | `tests/e2e/design-system.spec.ts`, `package.json`, `package-lock.json` | Approved reviewed COMPONENTS API/source/CSS snapshot plus frozen design, existing runner/config/workflow; no edits to COMPONENTS inputs | Supported exact npm lock addition; actual axe/version/provenance, fixture identity, browser/keyboard/narrow/real-zoom/contrast/motion and resource-cleanup evidence; independent review |

These are internal dispatch boundaries, not new whole-SPEC nodes. Root issues self-contained briefs after approval; children do not close002 or unlock003. COMPONENTS inputs remain read-locked during BROWSER execution. If API/source changes, invalidate dependent evidence and return to review rather than silently proceeding. Child writers are distinct/exclusive when active; no shared manifest writes. No nested framework, new runner or extra tracked fixture is introduced.

Before any corrective execution, root records exact tree/commit, source hashes, writer/read locks and attempt identity. Fixture processes/scratch/profile/ports and private installations require registered cleanup before allocation, bounded external lifetime, exact PID/start/parent-descendant/nonce identity and post-cleanup observations. Preserve unrelated processes. Security reviews exact fixture/zoom source before runtime; QA observes actual commands/results and gaps.

## Dependency and overlap semantics

All whole-SPEC prerequisites remain unchanged:002 follows approved integrated001;003 and other consumers wait for approved integrated002. Adding manifest ownership creates exclusive overlap with001 on both package files.001 is coordinator-recorded accepted/integrated before002; retain its original evidence and require its writer to be inactive. Any active lock conflict blocks package dispatch. Never infer permission from nonoverlapping lines.

011 owns the existing workflow and Playwright configuration as prerequisite targets, but does not own either npm metadata path in the current registry. This amendment adds no011 target and authorizes no workflow changes. Its existing dependency on002 ensures it later consumes the integrated locked tool. Recompute actual registry overlaps before dispatch rather than relying on these examples.

## Approval and verification gates

1. Root launches an independent read-only plan audit of this amendment, the exact SPEC/registry diff, current handoff and dependency/lifecycle boundaries. No package edit or provisioning occurs before actual PASS is read and root accepts it. Approval must be recorded separately; this proposal never self-approves.
2. Approved manager-develop uses supported npm lock generation to add only exact `axe-core: "4.14.0"` to devDependencies and its required lock metadata. Review the full metadata diff and reject unrelated dependency churn. Use an isolated implementation worktree/private node_modules, with `npm ci --ignore-scripts --no-audit --no-fund`; no global/shared install or new script execution. Retain any existing narrowly approved offline ast-grep rebuild only when needed by the existing gate.
3. Mechanically verify official registry/source provenance and compare exact lock resolution/integrity, installed name/version and SPDX license, retained LICENSE and actual engine version. Proposed source is `https://registry.npmjs.org/axe-core/-/axe-core-4.14.0.tgz`; expected SRI is `sha512-9WTZxEjsZ7b13TH8JPmbV2z8CHbl80/2hm3XPEG4JgNdQLK81IBRXmSxHfMAOkSqQeRxT/0dwNDz2GOm3zzpcQ==`, expected license `MPL-2.0`. These expected values are audit inputs, not fresh execution receipts. A mismatch blocks execution; no alternate version/source fallback.
4. Developer unit verification uses the actual privately installed richStudio candidate, external CWD and same-invocation environment scrub, recording namespace/body/formal/CSS identity and rejecting failed/error/skipped required tests. Source loading is not installed-candidate evidence.
5. Browser verification resolves the locally installed real axe engine, injects it into the actual owned component fixture, records its runtime version and actual scan results, and fails if the required tool is missing. Tests do not fetch tools from the network, silently skip scans or replace axe with a hand-written DOM check. Existing hosted locked npm installation supplies the same standard asset; demonstrate actual hosted execution before portability acceptance.
6. Retain CLI-driven real browser scanning plus keyboard activation/focus/dialog-return, narrow375x667, actual200% zoom, contrast and reduced-motion evidence required by the approved design. Automated scanning alone cannot close accessibility acceptance. Preserve existing fixture/zoom process-security review, bounded lifetime and cleanup requirements. No invented manual or participant evidence.
7. QA retains one cumulative evidence ledger and exact source/runtime attribution; independent post-implementation review precedes integration. Full suite/check/coverage remain clean-CI gates under unchanged policy. Missing required evidence remains an explicit gap.

## Failure history and test policy

Preserve the original unified002 ledger without a reset: (1) inventory-driver header-slice failure; (2) independent design-r1 FAIL for missing Manage Files coverage; (3) corrected route-checker label-alias failure; (4) actual private axe provisioner LICENSE identity failure; (5) malformed JavaScript read-only probe rejected by functions.exec before any shell. Root conservatively confirms count **5**, stops that execution cycle and abandons handwritten axe provisioning. LICENSE cause/bytes/per-path cleanup remain unobserved. Design-r2 PASS retains its original frozen subject and does not erase history.

The existing deliberate RED is separate: only the new unit test was authored, SHA256 `e8b46a780bf3082bc0c02f69d28407f29e209077b5d98d67cda2784ab6ab63f0`, in workspace-components. Root-relayed actual result was1pass,2fail,7errors,0skip,0warn with helpers absent, following a successful private install. Evidence root: `/tmp/richstudio-ws002-unit-_5mhvdj_`. Source pre/post Git status matched, but no pre-install source hash manifest was retained: this is an explicit identity gap, not fresh native/source identity proof. No R/CSS/browser implementation exists at this re-scope checkpoint. Read the receipts before relying on that test result.

Only actual independent plan-audit PASS plus explicit root acceptance starts a **new corrective-scope cycle**. Retain the original ledger/count5 separately; never relabel it count0. Root records every new attempt and its outcome, including evidence-driver failures, in the corrective cycle; after five unplanned failures stop and re-scope before another attempt. Expected TDD RED and deliberate negative controls are planned outcomes, separately attributed rather than counted as unplanned failures. Neither child acceptance nor a new cycle changes whole-leaf requirements, three ACs, twelve-node DAG or gates.

## Rollback and remaining scope

If approval is withheld, metadata writes remain blocked and the existing implementation/read locks continue. After implementation, rollback is a scoped reversal of the reviewed dependency/lock and dependent browser-test changes, preserving others' work; re-establish a consistent locked installation and record the new measured baseline. Removing the tool does not waive required accessibility checks:002 stays held until an approved verified alternative satisfies them.

No application dependency, product redesign, unlisted file ownership, threshold change or downstream feature is added.001 release hold, downstream science/data-retention/import/legacy work and target-R qualification remain under their existing owners. There is no runtime, accessibility, tooling-readiness or whole-leaf completion claim in this proposal.
