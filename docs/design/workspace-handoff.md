# Workspace design handoff — SPEC-WS-002

Version1.0.1 · issued2026-10-21 · receipt DESIGN-WS002-LOCAL-02 (supersedes LOCAL-01).

## Receipt and authority

Delivered by manager-design: [workspace-design-system.md](workspace-design-system.md), [workspace-screens.md](workspace-screens.md), and this handoff. This explicit receipt records local artifact delivery only. Receiver is root/coordinator for independent design review; review decision and implementation kickoff are pending at issuance. No code, CSS, tests, namespace, package metadata or production route was changed. Root retains gate authority and records reviewer outcome separately; this receipt cannot claim reviewer acceptance on its own.

Authoritative seed: `2e52278601d150fd6982886681448d36eac2bdfe`, isolated `/home/juhur/PROJECTS/20_libs/richStudio/.moai/worktrees/workspace-design-system`, branch `WT-workspace-design-system`. User authorization covers sequential/dependency-safe001–012 work.001G0 acceptance is coordinator-attributed; the original integration QA `implementation/qa/ci05/resumed/report.md` was read, including its explicit keyboard/zoom/accessibility gaps and release holds. Its hosted result is not002 execution evidence.

DesignSync discovery found zero matching callable methods. Remote project creation, canvas review, write_files, get_file and report_validate did not run; no remote was written and no zero-drift render metrics are claimed. The approved local versioned fallback satisfies the design delivery route. Manual attachment is unnecessary for this fallback; if requested later, copy reviewed bytes to ignored design-export/ and identify that no sync occurred. Do not introduce another remote push mechanism.

## D1 correction receipt

The first independent handoff audit returned FAIL for missing Manage Files coverage (D1, REQ001/AC001). The preserved update_tab route lacked both an annotated screen and state row. Version1.0.1 adds A17 and its six-state inventory using existing components, specifies rename/removal diagnostics, actual dependent-record consequences, named stable targets, confirmation/focus/status and narrow/zoom behavior, and corrects adoption ownership:006 exclusively writes R/update_tab.R;008 contributes adapters only. No production target is added. The prior author inventory-driver failure and this audit failure remain recorded; the revised route checker then failed once on its “Run comparison”/“Comparison” label alias, which was corrected before its successful rerun. The cumulative failure counter is3, without stage resets; this revision is not a confirming audit PASS. Root must run the independent confirming review against the new frozen hashes.

## A — Context and preservation

Contract: docs/specs/SPEC-WS-002.md, umbrella design.md/acceptance.md/dispatch.json, approved002 dispatch brief. Native Shiny/shinydashboard/Bootstrap, no frontend framework, font dependency, logo redesign or global CSS replacement. Preserve all three reviewed design documents during implementation; manager-design alone corrects them through review. Preserve original CSS token values, tab names and module namespaces, exact scientific values/provider columns, source/run identity and all optional analysis paths.

002 code owner may write only inst/application/www/custom.css, R/workspace_components.R, tests/testthat/test-workspace-components.R and tests/e2e/design-system.spec.ts. New functions stay internal; do not edit NAMESPACE/DESCRIPTION/app.R/config/runner for a gallery. Downstream leaves own real route wiring. You are not alone in this repository; preserve other actors' edits. Do not spawn agents from this leaf.

## B — Annotation → implementation requirement → candidate AC

| Annotation | Target components/surface | Required content/behavior | Requirement / candidate verification |
|---|---|---|---|
| A01 | C01,C02 frame/routes | Existing tab/namespace adapter; navigation never submits work; optional routes |002 REQ001/AC001 inventory;003 AC001–003 actual routing |
| A02 | C01 Home | Four named entry actions; demo explicit; result/figure direct entry |002 REQ001/AC001;003 AC001/002 |
| A03 | C02 context | Stable IDs, organism/keytype, actual status, unknown/unsaved/draft distinctions |002 REQ001/002 AC001/002;006/007 data adapter |
| A04 | C03,C04,C06 intake | Visible field names/linked errors; preview vs commit; imported columns preserved |002 REQ001/002 AC001/002;004 AC001–004 |
| A05 | C03,C04 science | Effective rule/count/background/provenance availability; no invented counts |002 REQ001 AC001;004/005 worker-oracle evidence later |
| A06 | C05 jobs | Semantic actual lifecycle; no fake percent/cancellation; retained valid results |002 REQ001/002/004 AC001/002;006 lifecycle/termination evidence |
| A07 | C06,C07 results | Caption/labeled focusable overflow; exact statistics; direct figure/export |002 REQ001/002/003 AC001–003;008 data/selection evidence |
| A08 | C07 selection | Qualified stable identity, noncolor cue, hidden-filter notice, Clear selection |002 REQ001/002 AC001/002;008 AC001–003 |
| A09 | C08 figures | Alternative table/receipt, unsupported reason, display-only filters |002 REQ001/003 AC001/003;009 export/reproduction evidence |
| A10 | C03,C05,C09 engines | Distinct effective engine policies/missing-column reason |002 REQ001 AC001;010 AC001 |
| A11 | C06,C09 comparison | Membership alignment, compatibility/missing context, descriptive statistics |002 REQ001 AC001;010 AC002–004 |
| A12 | C04,C10 project | Named confirmation, safe default Cancel, focus return, unchanged workspace on error |002 REQ001/002 AC001/002;007/012 application/security evidence |
| A13 | C01–C10 all surfaces | All12 rows×6 state classes including explicit N/A reasons |002 REQ001/AC001 static review |
| A14 | All text/link surfaces | Escaped untrusted synthetic labels; approved links/rel; no imported code |002 REQ002/AC002 component trust tests;007 export boundary |
| A15 | C02,C03,C05,C08,C10 | Setup draft/captured run/display filter/committed revision/project dirty separate |002 REQ001/AC001;004/006/007/009 actual state tests |
| A16 | All interactive components | Keyboard/focus-return,375x667,true200%zoom, reduced motion and measured contrast |002 REQ002/003/004 AC002/003 actual browser/manual evidence |
| A17 | C02,C04,C05,C06,C07,C10 Manage Files | Stable named rename/remove targets; linked diagnostics; actual dependency consequences, confirmation/focus return/status; narrow/zoom actions |002 REQ001/002/003 AC001–003 design coverage;006 alone writes R/update_tab.R and proves mutation/lifecycle behavior;008 identity/selection adapter contribution only |

No annotations were received from an external canvas. A01–A17 are the complete local annotation set; screen table, state matrix and component inventory are linked through these IDs, not an implied approval of one Home image.

## C — Preflight and adapter boundaries

Recompute reference CSS digest before implementation. If different from `f0b92df325f98e5646f504c8af61c6b4241f5c8f7525419b5bbb6a213b5fc539`, report drift and obtain corrected manager-design review; do not silently rebase visual assumptions. There is no brand-token directory among this leaf's targets; the measured existing --rs-* token block is local precedence. Added tokens are explicitly listed in the design system; no unlisted color/component names.

| Adapter input | Presentation responsibility | Owning downstream behavior |
|---|---|---|
| Explicit label, namespace/local ID, action availability/reason | Native Shiny control and escaped visible text; namespace once |003 routes actions; never submit from navigation |
| Typed facts/value/availability, dataset/revision/run identity | C02/C03 label-value groups; unknown text |004/005/006 compute/capture actual scientific facts |
| Enum lifecycle + measured progress if present + elapsed + capability | C05 text/live region/action intent; reject invented completion |006 worker ownership, termination, stale callback rejection |
| Data-source reference, caption, selected qualified identity, display cues | C06/C07 region/selection labels; no p-value calculation |008 joins/identity/filter/selection;009 plotting |
| Recorded statistic/settings/provenance/compatibility | C08/C09 labels and explanation |009/010 transformations, export and scientific policies |
| Dirty state/validation summary/dialog invoker; stable named management targets and dependency disposition | C10 confirmation/focus contract with linked C04 diagnostics and C05 actual status |007/012 project validation/confinement/atomic apply;006 exclusive R/update_tab.R management mutation/lifecycle ownership;008 supplies identity/selection adapters only |

This is a conceptual adapter contract, not a frozen R record schema.006/007 version their actual record adapters before dependent consumers dispatch. Presentation components must not deserialize sessions, launch/kill workers, fetch provider URLs, assign significance, infer species/background or fabricate metadata. Use existing Shiny/htmltools tags; no generic component framework is needed. Implement the smallest cohesive primitives that cover C01–C10 roles, reusing markup helpers where this reduces duplication; ten public functions are not required.

## D — Scoped implementation and verification package

Use characterization for original CSS behavior and TDD for new component semantics. Test fixture lives inside the two owned test files and can serve a temporary local Shiny app with the installed package's internal functions. Probe existing runner/library access first; no production gallery, namespace export, runner edit or new dependency is authorized here. Cleanup must be registered before launching owned fixture/server/browser resources, with a bounded external timeout and no global process killing.

Observed verification interfaces (source inspection only; no checks executed here): scripts/test-workspace.sh owns install_candidate/installed/r_tests/types; its scoped mode hard-codes baseline/resources, so it does not run new component tests. package.json provides npm run typecheck; Playwright discovers tests/e2e/**/*.ts in existing desktop/narrow projects. Its configured webServer starts the production app on3871. A component-only fixture therefore needs its own owned temporary app/port inside design-system.spec.ts; configured webServer activity must be attributed separately, not called component-fixture proof.

Planned exact scoped commands, after an actual private candidate installation and bounded cleanup are in place:

- `npm run typecheck` for the existing TypeScript configuration.
- `R CMD INSTALL --preclean --library=<owned-private-library> <implementation-tree>` with actual paths substituted and logged, followed externally by installed namespace-path verification.
- Installed testthat::test_dir against the implementation tests/testthat directory with package="richStudio", load_package="installed", filter="^workspace-components$"; use the existing runner r_tests body pattern to emit totals and reject failures/errors/skips. Run externally with same-invocation environment scrub. No source() substitute.
- `bash scripts/test-workspace.sh browser` is the observed integrated browser interface: private candidate installation, installed identity receipt, renderer probe, then configured Playwright baseline cases plus the new owned spec. Treat retained baseline cases as affected-CSS regression scope, not a local full R suite. Attribute configured production-app activity separately from the owned component fixture. Record actual project/case counts and preserved failures; a direct per-spec rerun may use `npx --no-install playwright test tests/e2e/design-system.spec.ts` only while the same actual private candidate identity is established.

These are planned checks, not execution receipts. The concrete installation/test command must include the actual private library, external CWD and registered cleanup. Do not change runner/config to add a verb or production gallery; report a necessary interface gap before expanding ownership. Full suite/check/coverage belongs clean CI.

Required test observations: meaningful visible/accessibility names and IDs across two namespaces; escaped hostile-looking text; native keyboard activation and visible focus; modal open/close/focus return with no trap; state text and noncolor cues; imported/legacy unknown values never0; table-only labeled overflow with controls outside it; reachable primary actions at375x667 and real200% zoom; reduced-motion removes pulse/spin/translation while state remains visible; computed actual foreground/background contrast; screenshot comparison to these annotated wireframes without OS pixel-identity claims. CLI accessibility scanning complements, and cannot replace, keyboard/focus/zoom/contrast manual review. Existing product dependencies do not include axe; root has authorized QA-owned private /tmp official axe-core4.14.0 with registry/SRI verification, subject to security review. This is external verification tooling, not a tracked/product dependency or an executed scan receipt. Do not claim participant usability tasks passed from team inspection.

Native zoom technique available from001 QA preflight: bounded disposable Chromium extension using chrome.tabs.setZoom/getZoom with factor1→2, retain outer/physical size and actual CSS inner dimensions/visualViewport.scale. Reuse only after proving it on this component fixture; the old preflight is not002 acceptance. DPR emulation alone is insufficient.

## E — Self-verification and review disposition

Claim: three local design documents were authored from the measured CSS and source route contracts. Delivery scope is design artifacts; no002 runtime, accessibility, security, usability or whole-leaf completion is asserted.

Evidence: source reads (`cat`/targeted `sed`/`rg`), Python token extraction/static sRGB contrast computation and final document readback/hash inventory. Baseline is the exact design tree/seed above. Original contrast examples: white/primary5.12, white/teal2.18, muted/white2.56, secondary/gray4.34; these measurements motivate scoped extensions rather than a global replacement. Root receives exact artifact hashes after readback, then launches an independent read-only design audit before any code. High-change scientific labels/engine/unknown-data rules and text/import boundaries are explicit reviewer targets.

REQ001/AC001 is ready for independent inventory review, not declared passed here. REQ002/AC002, REQ003/AC003 and REQ004/AC002+003 remain future actual component/browser/manual checks. Reviewer acceptance enables implementation of reviewed components; post-implementation sync-auditor must judge consistency with these artifacts and acceptance evidence, with science/QA/security scoped to real claims.

Gaps: no DesignSync remote/metrics; no actual component code/render/screenshot; no keyboard/screen-reader/focus/zoom/motion runtime evidence; no unfamiliar-user observation; no downstream scientific/format/termination implementation evidence. Residual risks: legacy012, real Stop backend support006, scientific retention/network008/009, targetR4.5.2 qualification011 and001 SYNC1830 release hold remain open under their own owners. Do not treat unavailable controls as completed capabilities or this handoff as release clearance.
