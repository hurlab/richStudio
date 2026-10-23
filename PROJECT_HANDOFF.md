# richStudio Project Handoff

## 1. Project Overview

richStudio is an R Shiny application for enrichment analysis, gene-set clustering, visualization, saved sessions and exports. The authorized workspace evolution covers SPEC-WS-001 through SPEC-WS-012 in dependency and file-lock order.

- Last updated: 2026-10-23 (Claude Code)
- Last coding CLI used: Claude Code (root changed from Codex on 2026-10-21; user-instructed).
- Conversation: Korean (`/lang gloss`); artifacts: English.
- Integration worktree: `/home/juhur/PROJECTS/20_libs/richStudio/.moai/worktrees/workspace-evolution-integration`, branch `WT-workspace-evolution-integration`, HEAD `4142c940b5abd0cbd164634f43b2fb07b48f3f48` (pushed; SPEC-WS-002, 003, 004 and the R 4.6.1 deploy script).
- Corrective source worktree: `/home/juhur/PROJECTS/20_libs/richStudio/.moai/worktrees/workspace-check-warning-portability`, branch `WT-workspace-check-warning-portability`, HEAD and remote `2442363`. Now integrated; keep until I is pushed/merged.
- Previous handoffs preserved verbatim: [2026-10-21 15:56](logs/PROJECT_HANDOFF_2026-10-21_1556.md), [2026-10-21 21:02 pre-update](logs/PROJECT_HANDOFF_2026-10-21_2102.md).
- Reusable lesson: [CI evidence needs protocol and type identity](/home/juhur/PROJECTS/wiki/concept/ci-evidence-needs-protocol-and-type-identity.md).

## 2. Current State

Status as of 2026-10-21 21:02 CDT:

- **Completed:** SPEC-WS-001 foundation (prior session).
- **Completed in Session 2026-10-21 21:02 CDT: whole SPEC-WS-002 acceptance.** Scope `ws002-acceptance-recovery` closed COMPLETE at 1/cap5. Hosted run 39664812571 at `2442363`: 7/7 jobs success; tests 122/1351/0 fail/0 skip; R CMD check 0E/0W/5N (NOTE headings unchanged); coverage 3424/3988 = 85.86% (denominator unchanged); browser 16 pass, axe 0 violations; in-run negative rejection. Independently judged R1–R11 PASS (R11 via R11-bis). Integrated by fast-forward; amendment `docs/specs/SPEC-WORKSPACE-001/amendments/002-acceptance-recovery.md` and SPEC-WS-002 link published in `b8eb759`.
- **User decisions this session:** U1 keep the established audit method; U2 direct human keyboard/focus/200% zoom/contrast/reduced-motion review deferred to the SPEC-WS-011 release gate; U3 same-SHA negative alias skipped; U4 200% zoom state judged from measured layout receipts (screenshot capture was partial).
- **Completed 2026-10-22: SPEC-WS-003 accepted and integrated.** I = `2835467` (pushed). Gating hosted run 39726772374: 7/7 success; tests 145/1703; check 0E/0W/5N; coverage 86.65%; browser 30/30, axe 0. Result audit `ws003-result-audit-r1.md` PASS; receipt `.moai/reports/SPEC-WORKSPACE-001/implementation/003/ws003-root-acceptance.json`. Scopes: `ws003-navigation` STOP5 (preserved), `ws003-recovery` COMPLETE 2/5. Confirmatory I-branch run 39730055735 (not a gate). New holds: enrich_tab.R zero-height pane (pre-existing), design-system fixture flake, CI shiny 1.14 vs local 1.12.1 drift.
- **Completed 2026-10-23: SPEC-WS-004 accepted and integrated.** I = `4142c94` (pushed; tree `7d8d3264…` equals card tree). Gating run 39911249412: 7/7 success; tests 176/2102, 0 fail/err/skip/warn; check 0E/0W/5N (headings unchanged); coverage 88.48% (4194/4740); browser 38/38, 0 flaky. Result audit `004/ws004-result-audit-r1.md` PASS (f149ae63…); receipt `004/ws004-root-acceptance.json` (c10eec17…). Scope `ws004-intake` COMPLETE at 4/5: step-6 browser test race (fixed `fbdbb0b`), review r1 FAIL (invalid-UTF-8 session close; correction `0d7bfdb`/`a212d3a`, r2 PASS), two environment timeouts of run 39879098364 (owner-authorized workflow timeout 45→90, `4142c94`, review r4 PASS). Deviations D-A04-1, D-A04-2, D-AC002, D-A04-3 (Mapped-from only in importing tab), zero-token paste refused, workflow file-lock exception. Confirmatory I run 39914518293 (not a gate).
- **Deploy WS-001–004 (owner decision): preflight PASS 2026-10-23** for release `4142c94` on hurlab (`~/richStudio-deploy-r46-4142c94/`, script sha256 `7f3d1614…`; build left at `~/richStudio-r46-preflight.20261023T065708Z`). **Deployed and verified live 2026-10-23** (user-run sudo, run id `ws004-20261023`): live `/opt/richStudio/releases/richStudio-4142c94…-20261023T085133Z`, previous `06206d0…-20261022T114305Z` kept. Independent checks: symlink match; HTTPS 200, 0 error-text matches; R 4.6.1 only, workers on `release-r46` library, no R 4.5 process; app log clean (package-dir warning and masking messages only); browser via SSH tunnel to :3838 (public HTTPS cert CN mismatch blocks a headless browser) — DEG upload shows "Preview — not committed", review card "Default rule (not customized)", commit → "Committed revision 1, Submitted genes: 2", 0 console errors. Recorded in `004/ws004-state.json` (event DEPLOYED_VERIFIED). Preflight build `~/richStudio-r46-preflight.20261023T065708Z` deleted afterwards (user-authorized). Open: SPEC-WS-005 dispatch, merge to main, SPEC lifecycle sync (owner decisions); keep `.claude/worktrees/agent-aa140c340b8c52b17` and `agent-aa2a86ab19b0cc738` until the merge to main lands.
- **Not started:** SPEC-WS-005–012.
- **Server (updated 2026-10-23):** live app now runs release `4142c94` (WS-001–004), see the deploy entry above. As of 2026-10-22: hurlab runs R 4.6.1 + Bioconductor 3.23. Live app `https://100.94.67.89/richStudio/` (Tailscale) ran release `06206d0` rebuilt for R 4.6.1 (`/opt/richStudio/releases/richStudio-06206d0…-20261022T114305Z`, release-private library `renv/library/release-r46`, no R 4.5 fallback) via user-run `scripts/deploy-r46-release.sh`; HTTP 200, 0 error pages. R 4.5-era releases and `richStudio.PREV.20261020T164533Z` were removed; `scripts/rollback.sh` and `scripts/deploy-dependency-update.sh` are obsolete (R 4.5). No workspace work deployed.
- **Known CI flake:** `tests/e2e/design-system.spec.ts:758` 'Unknown process joined owned fixture group' failed once on run 39709359169 (I branch), passed on job rerun.
- No push, deployment, sudo, worktree disposal or primary-checkout branch change happened.

## 3. Execution Plan Status

| Phase | Status | Last updated | Current condition |
|---|---|---|---|
| 001 foundation | Completed | 2026-10-21 | Prior accepted integration |
| 002 design/components/browser | Completed | 2026-10-21 21:02 CDT | Accepted and integrated in I (`b8eb759`); holds below |
| 003 Home / header / navigation | Completed | 2026-10-22 | Accepted and integrated in I (`2835467`); holds in section 4 |
| 004 intake/review | Completed | 2026-10-23 | Accepted and integrated in I (`4142c94`); deployed live 2026-10-23 and verified |
| 005–010 workspace | Not started | 2026-10-22 | Each needs its own dispatch; respect app.R lock conflicts with 006/007/008/012 |
| 012 legacy restoration | Not started | 2026-10-21 | Required before 011 release |
| 011 compatibility/release | Blocked | 2026-10-21 21:02 CDT | Target R, SYNC, science, legacy, human review (incl. U2) gates |

## 4. Outstanding Work

- **Open; updated 2026-10-21 21:02 CDT:** decide SPEC-WS-003 activation. Draft `.moai/reports/SPEC-WORKSPACE-001/implementation/003/next-dispatch-draft.md` (unactivated).
- **Open; updated 2026-10-21 21:02 CDT:** push `WT-workspace-evolution-integration` and plan merge to `main` (owner decision; not done).
- **Hold (011); recorded 2026-10-21 21:02 CDT:** direct human keyboard/focus/200% zoom/contrast/reduced-motion review; 011 planning must read `docs/specs/SPEC-WORKSPACE-001/amendments/002-acceptance-recovery.md`.
- **Hold; recorded 2026-10-21 21:02 CDT:** fix the partial 200% screenshot capture — `page.screenshot({ fullPage: true })` under native zoom in `tests/e2e/design-system.spec.ts` (L363 at `2442363`) records only the top-left quarter — at the next browser-test change.
- **Hold; recorded 2026-10-21 21:02 CDT:** hosted browser-only negative path (`-negative-canary` ref / `negative_assertion` dispatch) never observed (U3).
- **Open:** SPEC-WS-002 lifecycle `status: draft` → completed belongs to a sync phase.
- **Decision 2026-10-22 (owner):** do not deploy WS-001–003 (`9fc6b21`) on its own; deploy once SPEC-WS-004 is integrated, using `scripts/deploy-r46-release.sh` (preflight first, then user-run sudo).
- **Open; target changed 2026-10-22:** target R qualification (011) is now **R 4.6.1 + Bioc 3.23** (server upgraded; R 4.5.2 superseded).
- **Open (unchanged):** SYNC1884 release hold, SCI-RETENTION-001 (008/009), SCI-NETWORK-002 (009), B3-OBS-002 (009), unclassified B3-OBS-001 (004/010), legacy 012, deployment.

## 5. Risks, Open Questions, Assumptions

- **Open; 2026-10-21 21:02 CDT:** I is unpushed; worktree I is the only copy of `b8eb759`. Do not dispose of I or W until pushed and merged.
- **Open:** 002 accessibility rests on automated evidence until the 011 human review.
- **Mitigated:** STOP5 of the prior publication scope was caused by reader tools (PNG decoded as UTF-8; JSON shape assumption), not by product defects; type-aware reading rules now apply.
- **Process note:** the audit method is heavy (four proposal revisions plus a correction were needed). Keep tool failures distinct from product failures.

## 6. Verification Status

Evidence directory: I `.moai/reports/SPEC-WORKSPACE-001/implementation/002/` (gitignored). Key files: `ws002-acceptance-recovery-plan-r4.md` (5f8d3098…), plan audit r4 PASS (4116f94e…), `ws002-acceptance-recovery-r11-correction-plan-r2.md` (bc319d57…) with audit r2 PASS (23584bd9…), result audit r1 (1769727d…; R1–R10 PASS), result audit r2 (fdefa89a…; R11-bis PASS), state `ws002-acceptance-recovery-state.json` (COMPLETE 1/5), receipt `ws002-acceptance-recovery-root-acceptance.json` (8b5ca741…). Raw retention: `/home/juhur/PROJECTS/20_libs/richStudio/tmp/runs/ws002-acceptance-recovery.cciaGXiu` (terminal metadata, full artifact, six screenshots, inventory 7bc659c9…).

- Root verified: `git show HEAD:<path> | sha256sum` equals accepted amendment r6 (a8af6fa4…) and expected SPEC r5 (b8bef7e8…); `git diff --quiet 2442363 HEAD -- . ':!docs'` identical; I tree at `2442363` = `3f89bfc5…`.
- Not observed: hosted browser-only negative path; complete 200% screenshot; human/AT/participant review; target R; local full suite (none run, by policy).

## 7. Restart Instructions

Last updated: 2026-10-21 21:02 CDT. Say **resume**; read the primary-root `NEXT_SESSION.md`, give a one-line summary and confirm before executing. Start in integration worktree I. Verify `git -C I rev-parse HEAD` = `b8eb759…` and the state file reads COMPLETE before treating 002 as accepted.

Next action candidates (owner decides): (a) dispatch SPEC-WS-003 from the existing draft; (b) push I and plan the merge to `main`; (c) fix the 200% capture hold as a small test-only card. Preserve the primary checkout's foreign `.gitignore` change; root owns I's handoff/log. No local full R suite/check/coverage; deployment remains user-manual sudo after review.
