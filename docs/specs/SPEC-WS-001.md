---
id: "SPEC-WS-001"
title: "Measured baseline, scientific fixtures and verification harness"
version: "0.1.0"
status: draft
created: "2026-10-20"
updated: "2026-10-20"
author: "workspace planning team"
priority: P1
phase: "v0.1.7 target"
module: "R/"
lifecycle: spec-anchored
tags: "workspace, usability, reproducibility"
---

# SPEC-WS-001 — Measured baseline, scientific fixtures and verification harness

Planning-only draft. This existing-style leaf document is the self-contained implementation contract; no implementation/test completion is claimed. Companion umbrella: [SPEC-WORKSPACE-001](SPEC-WORKSPACE-001/plan.md).

## Problem and observable outcome

The existing installed-package regressions are a useful inherited reference. This initiative needs its own reproducible baseline and browser harness before behavior changes. No fresh runtime suite has been run in this planning task.

## Dependencies and ownership

- Logical prerequisites: none; first measured baseline.
- One disposable implementer owns this entire leaf in its own fresh worktree; independently reviewed before integration.
- Shared targets are exclusive locks, even for nonoverlapping line edits; derive conflicts from the umbrella dispatch.json. No metadata/namespace edits outside this list without registry revision.
- Upstream richR work is separately owned and integrated through an official release, never edited by this consumer leaf.

### Existing targets

- `DESCRIPTION`
- `.Rbuildignore`
- `tests/testthat.R`

### New targets

- `.github/workflows/workspace-quality.yml`
- `package.json`
- `package-lock.json`
- `playwright.config.ts`
- `tsconfig.json`
- `tests/e2e/fixtures.ts`
- `tests/e2e/baseline.spec.ts`
- `tests/fixtures/workspace/README.md`
- `tests/fixtures/workspace/annotation.tsv`
- `tests/fixtures/workspace/query.tsv`
- `tests/fixtures/workspace/background.tsv`
- `tests/fixtures/workspace/imported-results.tsv`
- `tests/fixtures/workspace/legacy-session-v1.json`
- `tests/testthat/test-workspace-baseline.R`
- `scripts/test-workspace.sh`
- `scripts/export-workspace-policy.py`
- `docs/quality/workspace-policy-bundle.json`
- `inst/config/workspace-resources.json`
- `R/workspace_resources.R`
- `scripts/measure-workspace-resources.R`
- `tests/testthat/test-workspace-resources.R`
- `docs/quality/workspace-resource-baseline.md`

## Technical implementation plan

1. Record exact Git SHA, R/package identities, worker library paths, OS, fixture digests and commands in one QA evidence ledger. Build/install the package, then test from an external working directory so source-tree loading cannot mask namespace errors.

2. Introduce a pinned TypeScript/Chromium CLI suite and a clean CI runner; own tsconfig.json with strict noEmit checking and explicit inclusion of playwright.config.ts and tests/e2e/**/*.ts. Run npx --no-install tsc --noEmit --project tsconfig.json and assert the resolved file list includes the config, fixtures and every current browser spec, rather than accepting an empty typecheck. Reuse existing testthat files without rewriting them. Check existing framework availability before adding dependencies. Add a policy exporter that reads the allowlisted canonical quality/harness/gate/security/LSP files from the primary repository, generates the reviewed tracked docs/quality/workspace-policy-bundle.json with source-relative paths, exact UTF-8 content and SHA256 digests, and checks that only intended non-secret policy content is exported. This is an automatically generated versioned snapshot, not a second manually maintained threshold definition. Regenerate and review it before the release candidate whenever source policies change. The exporter recursively resolves enabled gate rule/config references, including .moai/config/astgrep-rules/sgconfig.yml, referenced ruleDirs and all required rule assets, storing their canonical relative paths and content digests. Export a dependency inventory and fail on any missing enabled dependency, unexpected symlink or out-of-root production rule reference. Classify optional rule-self-test fixtures separately: the currently distributed sgconfig testConfigs path is not a scan dependency; if rule self-tests become a required gate their fixture closure must also be available, never silently skipped. Hosted CI verifies bundle digests, dependency inventory and schema, materializes canonical relative paths in an isolated policy root, and invokes configured tools with explicit isolated-root rules/config paths. For example, resolve the bundled rules directory into the supported moai --rules-dir argument and pin the ast-grep config path under that root; validate actual supported CLI flags at preparation. Run tools against the candidate code tree while all policy references resolve from the materialized policy root. No ambient primary-machine assets may satisfy a missing file. Record bundle digest and original source digests with every result. Missing bundle, malformed digest, unsupported tool or unresolved LSP policy/tooling disposition blocks G0; no threshold defaults or primary-machine absolute paths are allowed. Provision the actual R check/coverage/diagnostic and browser tools in CI from pinned manifests; archive their versions and gate outputs.

3. Create small synthetic annotation/query/background and imported-result fixtures with manually derived expected statistics, plus data-only legacy JSON. Real provider calls are a separate opt-in check; deterministic CI does not depend on annotation network availability. Generate a trusted legacy RDS fixture during the compatibility test rather than checking executable or opaque R objects into source.


4. Produce the application resource policy before 004/006/007 consume it. The001 implementer owns inst/config/workspace-resources.json and R/workspace_resources.R; QA owns measurement and security reviews trust-boundary limits. scripts/measure-workspace-resources.R measures bounded synthetic small/representative upper-size inputs and records bytes/rows/columns/strings, decoded table memory, archive expansion/member count/depth, table/graph render sizes, worker admission/history retention, and temporary-disk cleanup. Run serially with externally bounded processes and framework cleanup, no unbounded contention. Record exact runtime/fixtures, peak-memory/disk observations and justified safety headroom in docs/quality/workspace-resource-baseline.md. Select/review actual limits only from these observations and target-host constraints; do not invent numbers in this planning document. The loader validates schema and finite positive limits, resolves the installed config, and fails closed on absent/invalid policy.004/006/007 depend on G0 acceptance of this artifact;011 repeats/refines the same measurements, not first creates them. Boundary tests cover at/above configured limits.

## GEARS requirements

- **REQ-001** The verification harness shall record the exact measured source, installed package origins, commands, exit codes, pass/fail/skip totals and retained artifacts.
- **REQ-002** When a required test is skipped, unavailable or fails, the gate shall remain incomplete rather than report success.
- **REQ-003** The browser suite shall run via Playwright CLI with accessible locators and web-first assertions on desktop and narrow-screen viewports.
- **REQ-004** When the baseline is measured, the harness shall characterize enrichment, all three clustering routes, raw/adjusted threshold semantics and version1.0 session data without imposing old-engine numerical equivalence.
- **REQ-005** When isolated gate preparation runs, the harness shall verify the policy dependency closure and typecheck every intended browser-test input before reporting readiness.
- **REQ-006** When G0 is evaluated, the baseline shall include a measured, reviewed application resource configuration and validated loader before its consumers dispatch.

## Binary acceptance scenarios

**AC-001** Given the clean baseline commit and pinned fixtures, when the QA command installs and tests the app, then the receipt identifies exact package paths and full-suite totals with no source-only substitute.

**AC-002** Given a deliberately broken fixture expectation, when the CI workflow runs, then the job fails and retains its diagnostic artifacts.

**AC-003** Given a Chromium run at 1280x720 and 375x667, when navigation and fixture upload complete, then the suite asserts visible state using roles/labels/test IDs without hard sleeps.

**AC-004** Given a bundle missing a referenced enabled rule or an empty TypeScript file set, when clean preparation runs, then it fails before a gate can pass; a complete bundle resolves all required assets from the isolated root and typechecks the intended config/fixtures/specs.

**AC-005** Given representative bounded fixtures, when resource measurement and review complete, then the documented runtime observations justify each configured input/archive/worker/history/render limit, the installed loader reads them, and at/above-limit tests demonstrate enforcement before 004/006/007 dispatch.

All requirements must be exercised by the listed scenarios plus scoped tests; verification receipts identify the specific REQ/AC IDs. Disabled controls are valid intermediate/rollback containment only; they do not close the desired capability or justify full-program completion. Required feature criteria remain unresolved until demonstrated or explicitly re-scoped by the user.

## Scoped verification and gate evidence

- Run existing affected tests first; measure the clean full R suite/check and coverage in CI, never infer them from six deployed files.
- Run installed namespace enrichment/worker and three-engine clustering fixture tests; record any pre-existing failure separately and block the relevant surface until resolved.
- Run headless Chromium smoke, inspect artifacts, and test one intentionally failing harness assertion before removing that deliberate failure.
- Follow the canonical primary-repository quality/harness/LSP policies; record exact snapshot digests in CI. Do not duplicate their numerical thresholds here.
- Report commands, verbatim bounded outputs, commit/runtime baseline, gaps and residual risks. Full-suite phase gates run in clean CI; local checks are scoped to affected behavior.

## Requirement-to-acceptance traceability

| Requirement | Required scenarios |
|---|---|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003 |
| REQ-004 | AC-001 |
| REQ-005 | AC-004 |
| REQ-006 | AC-005 |

## Security and trust boundary

Synthetic fixtures only. No patient data, secrets or browser storage in committed traces. Limit artifact access and redact temporary/server paths where needed. Provider credentials are not introduced.

## Rollout and rollback

Keep workflow additions isolated; revert the harness commit without touching runtime modules. A failed baseline blocks later implementation rather than prompting runtime fixes in this leaf.

## Exclusions

### Out of Scope — Scope discipline

- Runtime redesign, production deployment or claims that historical deployment tests constitute this baseline.

## HISTORY

- 2026-10-20: Planning-only draft, authored after repository inspection and Hur Harness team consultation.
