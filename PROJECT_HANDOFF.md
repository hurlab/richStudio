# richStudio Project Handoff

## 1. Project Overview

Last updated: 2026-10-30 20:43 CDT. Last coding CLI used: **Codex**.
R Shiny application for enrichment, corrected richCluster clustering, scientific
visualization, saved sessions and exports. Conversation Korean; artifacts English.

- Authoritative worktree: `/home/juhur/.moai/worktrees/projects/richStudio/compact-workspace-layout`, branch `WT-compact-workspace-layout`.
- Pushed verification/docs baseline: `db3bd42d4fc1b3eea3cab5150644a34d3e2ba0a3`; session-close docs follow.
- Original entry: `/home/juhur/PROJECTS/20_libs/richStudio`. Its tracked handoff is historical; machine-local NEXT_SESSION.md points here. Do not switch/reset/stash the primary checkout.
- Superseded handoff is preserved in Git at db3bd42; history lives in PROJECT_LOG.md and archives. Do not dispatch completed work from historical pending lists.

## 2. Current State

**Completed in Session 2026-10-30 20:43 CDT: compact workflow implementation, owner-run deployment and actual public/native verification.**

- Actual application source `e8fef99a07b744dfdfcbb69f226e3a624fdce51e`; live release `/opt/richStudio/releases/richStudio-e8fef99a07b744dfdfcbb69f226e3a624fdce51e-20261031T012242Z`.
- Site https://hurlab.med.und.edu/richStudio/ ; SSH juhur@100.94.67.89. Owner executed the prepared command; DEPLOY COMPLETE, service active; previous4bc retained.
- Seven workflow menus compacted. Enrich desktop related settings use two columns; narrow screens stack. Initial desktop Run bottom526.265625px; populated spans641.65625/661.65625px versus1044.34375 baseline (38.56%/36.64% reduction).
- All17non-UI definitions,155control expressions and scientific/heatmap boundaries remain intact. Old33777CSSbytes preserved; total34803bytes SHA256 `b3c1ad641912f6597f5cdc6c2324fb59e66d70c38d2133efbb855cde30d1e78f`.
- Full wide Enrich document is longer because retained previews move below the compact primary form; no total-page-height reduction is claimed.
- **In progress (records/local gap only):** SPEC-COMPACTUI-001 v0.1.2 frontmatter remains in-progress. Two local native-zoom launches failed before Chromium page creation; public success does not rewrite those failures.
- Prior completed heatmap/scientific/manuscript/deployment-recovery milestones remain completed. Preserve their evidence/worktrees; no new analysis or figure refresh is requested.

## 3. Execution Plan Status

Statuses last updated 2026-10-30 20:43 CDT.

| Phase | Status | Current note |
|---|---|---|
| Compact plan, implementation and independent review | Completed | Seven static UIs and append-only CSS, sourcee8 |
| Scoped local verification | Completed with recorded gap |32density/protected+6primitive browser passes;2native launch failures retained |
| Exact-source server preflight / wrapper checks | Completed |Preflight/Shiny construction PASS; recovery11tests and wrapper10controls |
| Owner-run deployment | Completed |New e8 release; previous4bc retained |
| Actual public/native verification | Completed |15public passes; source/runtime/7installed UI checks pass |
| GitHub CI deployment prerequisite | Superseded |Explicit owner policy removes request/review/poll/wait |
| Further development / integration / formal release | Not started in this scope |Owner selects; no automatic merge, release or redeployment |

## 4. Outstanding Work

All entries updated 2026-10-30 20:43 CDT; reference PROJECT_LOG.md Session 2026-10-30 20:43 CDT.

- **Open:** agree the next scope with the owner; no further implementation was assigned at close.
- **Open if selected:** diagnose the two retained local native200%zoom launch failures and reconcile compact SPEC progress. SIGTRAP was pre-page; AF_UNIX path length remains a hypothesis, not an established cause or product defect.
- **Deferred:** main integration/formal release and retained-worktree disposition are separate work. Do not remove worktrees until branches are remotely integrated.
- Historical WS activation/deployment/CI holds are not fresh assignments; do not reopen completed items.

## 5. Risks, Open Questions, Assumptions

- **Resolved, 2026-10-30 20:43 CDT:** agent prepares and verifies the deployment script; owner executes sudo on the server. Passwordless sudo is not a required agent capability.
- **Resolved, 2026-10-30 20:43 CDT:** retain local/server checks, but do not launch, review, poll or wait for GitHub CI as a deployment gate. Never fabricate ci.ok.
- **Mitigated, 2026-10-30 20:43 CDT:** compact wrapper `/home/juhur/richStudio-deploy-compact-e8fef99/deploy.sh` is consumed. Do not rerun it or the older4bc wrapper. Future release preparation must pin a new source and the then-current live target.
- **Open, 2026-10-30 20:43 CDT:** preserve local failed-zoom receipts/scratch. No successful zoom or application regression is inferred from them.
- **Open, 2026-10-30 20:43 CDT:** not every scientific input, concurrent load, browser or journal print reduction is verified. No new inference/heavy2000-row export/live rollback was run for compact deployment.
- **Mitigated, 2026-10-30 20:43 CDT:** retain this tree and heatmap-legibility. Prior immutable manuscript archive stays in the latter at `.moai/reports/richStudio-manuscript-figures-20261030.tar.gz`,140982334bytes,SHA256 `b5e59be8426abc6093440dc4363cf8138cf6042a33a5e720541b8e667dd99bb3`. This close did not rehash or regenerate it.

## 6. Verification Status

Session evidence recorded 2026-10-30 20:43 CDT; not a new full-suite measurement.

- Public Playwright15/15 at1440x900,1280x720,375x667: all seven menus, initial/populated Enrich, full review, preview/commit, keyboard/navigation/resize and method Reset. Zero skips/retries/flaky cases or console/page errors.
- Public HTTPS/CSS200, TLSverify0; CSS34803bytes matches the approved digest.
- Independent native audit:275tracked Git files,274immutable exact; sole explicit exclusion is historical logs/PROJECT_LOG_2026-H1.md removed by runtime-log recreation. Code root-owned/read-only; logs app-writable.
- R4.6.1, private richStudio0.1.6/richR0.1.5/richCluster2.0.1/bioAnno0.99.45; seven installed UI bodies/formals equal deployed source.
- Actual worker2320774 ->2320770 ->serviceMainPID2320697; its three native DLLs use the new release. PIDs are point-in-time observations, not fixed restart prerequisites.
- Observed local browser descendants and three Playwright workers exited; production R left intact.
- Local ledger38PASS/2native-launchFAIL; rendered-control59/primitive138R assertions pass. Actual27R-file LSP diagnostics0/syncPASS; AST26documents/0findings/negative canary; ASCII pass. Air's sole protected Save-helper indentation matches baseline.
- Reports: `docs/quality/compact-workspace-post-deployment-20261030.md`, `docs/quality/compact-workspace-layout-20261030.md`.
- Evidence: `.moai/reports/layout-density/{impl,qa,tooling,deployment,post-deploy}/`; independent final native/public reports are post-deploy/native/report.md and post-deploy/browser/report.md.
- Unobserved in this scope: full R suite/check/coverage, native zoom success, real rollback, exhaustive science/network/concurrency. No GitHub CI review is needed.

## 7. Restart Instructions

Last updated: 2026-10-30 20:43 CDT. Say **resume**. Read project-root NEXT_SESSION.md,
summarize in one line, CONFIRM before execution, verify its four preconditions and
report drift. Matching prompts are saved in this worktree and original entry root;
Claude auto-memory points at NEXT_SESSION.md first.

Start in the authoritative worktree. Read this handoff and newest log entry,
then agree the next outstanding scope with the owner. Do not redeploy, run a full
local suite, activate GitHub CI, discard worktrees or repeat completed manuscript work
as a default resume action.
