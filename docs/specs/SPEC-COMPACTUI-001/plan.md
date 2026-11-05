# Plan — SPEC-COMPACTUI-001 v0.1.2

## §A User-facing decisions first

Keep the existing workflow and theme. Enrich is the priority: its upload and
configuration stages currently stack while the other column is shorter.
A plausible minimal arrangement places upload and settings alongside one another
and gives preview/results their own full-width region below; this is an option,
not a required component architecture. Related settings need two or more columns
on desktop. Do not make every region share a forced height or turn plots into
small cards just to fill a grid.

Preserve full review messages and existing stage eligibility. The Run action
continues to follow its configuration/review summary; do not float or move it
over unrelated content merely to satisfy the viewport criterion. Keep ordinary
document scrolling for real preview/results content.

For the populated fixture, use the exact1044.34375px primary span at each desktop
size. Candidate span must be at most0.75 times that viewport's unrounded baseline
(783.2578125px for these recorded values). The paired inputs, review digest/text,
sidebar state, closed popup state, browser/fonts and viewport must match.
Initial comparison waits for the empty-selection review banner and settled
Shiny output. Earlier first-paint/open-popup screenshots remain diagnostic history.

Other workflows already contain useful column groups. Improve measured gaps and
unused control width where present; preserve groups that already work. Require
an observed before/after benefit in each modified panel, not arbitrary markup
changes on every route.

## §B Exact ownership and protected boundaries

| Production file | Allowed presentation surface |
|---|---|
|R/enrich_tab.R|Static enrich_tab_ui declaration; upload/configuration/preview grouping.|
|R/rr_visualize_tab.R|Static rr_vis_tab_ui declaration; intake and plot-option control grouping.|
|R/cluster_upload_tab.R|Static cluster_upload_tab_ui declaration; intake/table/export spacing.|
|R/cluster_tab.R|Static clusterTabUI declaration; stage spacing and existing parameter-group container.|
|R/clus_visualize_tab.R|Static clus_vis_tab_ui declaration; selection/term/export controls around protected figures.|
|R/update_tab.R|Static updateTabUI declaration; rename/remove form alignment.|
|R/save_tab.R|Static saveTabUI declaration; save/load/summary/export form alignment.|
|inst/application/www/custom.css|Append-only scoped compact workflow styles after all existing bytes, using existing tokens and responsive capabilities.|

The ownership list authorizes a file only where its baseline observation supports
a change. Do not rewrite an already satisfactory panel. In particular, dynamic
clustering parameters already have two/three/four-column rows; their server-side
renderers do not need alteration for new static ancestor styling.

| Verification file | Owner and purpose |
|---|---|
|tests/e2e/compact-layout.spec.ts|QA-owned actual browser density, responsive and workflow regression assertions.|
|tests/testthat/test-compact-layout.R|QA-owned minimal rendered-control/binding preservation checks where meaningful.|
|tests/e2e/design-system.spec.ts|QA-owned refresh of only the custom.css full-SHA256 literal after independent candidate identity/preservation proof; every other frozen pin, assertion and fixture behavior remains unchanged.|
|docs/specs/SPEC-COMPACTUI-001/|SPEC body by manager-spec; run evidence by manager-develop; sync evidence/status by manager-docs.|
|Ignored .moai/reports/layout-density/|Baseline/candidate measurements, paired images, source/binding manifests and independent reports.|

All other function bodies in the seven R files must remain byte-identical.
Freeze their raw source spans and public signatures before implementation;
preserve prefix/suffix helpers around the static UI declarations, including
save/load and intake validation. R/input_review.R and R/workspace_*.R are
protected, as are R/cluster_hmap.R and all scientific calculation/rendering files,
inst/application/app.R, dependency metadata, CI configuration and the five
previously completed SPECs. A discovered need to edit a different production
surface returns to the orchestrator for an explicit scoped amendment.

A whole-file source digest may change for an authorized UI-only edit. Generated
verification receipts must identify the actual candidate and independently prove
the preserved contract; never substitute a new expected hash to hide a change
to server/scientific behavior. Any necessary tracked-manifest edit outside this
list returns to the orchestrator for a scoped amendment. No new dependency or
generic layout framework.

### Verified CSS identity exception and append-only boundary

Late exploration found the concrete existing guard in
tests/e2e/design-system.spec.ts: its frozen map pins the entire custom.css at
SHA256 `92fdf6e04d0660037165b958c3dccf181f1b2f3258f25156f46b328dedb29d5e`,
and its snapshot assertion runs before fixture allocation. Its component server
also compares installed CSS bytes with source CSS. The orchestrator explicitly
authorized this narrow v0.1.1 amendment before implementation. It adds no density
concession or backend change.

Append new scoped rules after the full existing CSS file; the current full file
is the immutable byte prefix of the candidate. Keep the original portion before
`/* Workspace presentation primitives (SPEC-WS-002). */` unchanged, including MD5
`3dc7da1312126fb3a028db075e1c0e60`, as asserted by
tests/testthat/test-workspace-components.R. Preserve that R test completely.
Its subsequent literal-selector checks also freeze existing workspace font,
field/action sizing, card padding/margins and gaps. Do not append overrides of
these primitive selectors, even under another scope; compact the static tab
containers and review metadata using separate opted-in presentation surfaces.
Preserve primitive typography/hit areas inside actual workflow contexts as well
as the standalone component fixture; generic appended control rules must not
indirectly reduce those inherited values.

QA may refresh only the custom.css digest literal in the existing design-system
test after independent review proves the authorized additive CSS and preserved
contracts and the installed/source/served CSS identities agree. Keep all other
frozen-map values, assertions, fixture cleanup and test behavior byte-identical.
Record the old/new CSS hashes and the one-literal test diff. Do not accept multiple
hashes, weaken a comparison or refresh the policy bundle. A generic manifest
update is not authorized.

## §C Ordered milestones and dependency graph

1. **High — Freeze the observed contract.** Retain settled before screenshots and
   actual geometry for all seven menus at desktop and narrow sizes, including
   matched Enrich initial/populated states. Preserve input values, labels/help,
   rendered binding multiplicities, non-UI source spans, widget dimensions,
   scientific snapshots and supported viewport settings. The initial/native
   DOM snapshots have zero duplicate IDs; use matched-state inventories and
   module-binding checks rather than assume every future plot's generated SVG
   IDs are static. Independently approve this plan before source changes.
2. **High — Demonstrate the requested layout failures.** QA adds meaningful
   browser assertions for desktop Run visibility,25% populated span reduction
   and related field columns, captures their expected baseline failures and
   retains successful functional/scientific controls. Do not require a local
   full R suite/check/coverage baseline.
3. **High — Implement compact static presentation.** One isolated Implementer
   owns the approved UI/CSS surfaces; QA owns tests, avoiding file conflicts.
   Reuse theme tokens, min-width/wrapping/action patterns and existing Bootstrap
   groups. Apply styles only to opted-in workflow presentation; avoid global
   font, Home, sidebar, dialog and plot rules. Render with a freshly installed
   candidate package, not a mixed source/old namespace. Record package path/RDB,
   source and served CSS identities even though the package version is unchanged.
4. **High — Independently verify and converge.** Reviewer checks minimal source
   scope/non-UI byte preservation; Security checks escaping/intake/job/dialog
   contracts and no new unsafe handlers; QA runs paired geometry, actual rendered
   visual review and focused workflow/heatmap regressions. Verified failures
   return to the Implementer; unmet criteria are not relabeled as passed.
5. **High — Prepare the owner-run release and close observed evidence.** Root
   commits/pushes explicit owned paths and retains scoped local verification and
   exact-candidate server preflight receipts. The agent prepares and verifies the
   guarded deployment script; the owner executes it on the server. No GitHub CI
   request, execution, review or wait is part of this work. No CI receipt or
   ci.ok guard is required; local/preflight/recovery/version/host guards remain.
   Docs records actual verdicts and unresolved local gaps without relabeling them
   as passes. Production deployment remains a separately observed action.

Graph: measured baseline + approved plan → QA regression RED → UI/CSS candidate →
independent source/security review + installed scoped local QA → exact-source
server preflight + owner-run script preparation → observed evidence closure.
The explicit user policy does not reopen plan approval or add a confirmation gate.
Existing deployment/main state and
manuscript assets remain untouched by the layout implementation.

## §D Verification discipline

Use the same controlled viewport/state pairs:1440×900 and1280×720 for density;
1024×768,768×1024 and375×667 for adaptive behavior. Keep desktop sidebar state
matched; close the narrow sidebar after navigation. Measure visible control
containers, not hidden native selects behind Selectize. Compare existing fonts,
hit areas, labels/help and complete review text, not only outer card heights.

Make CSS layout failure checks binary and behavior-based; do not assert a
particular class name, grid implementation or screenshot byte identity.
Check popups/chips open, long values, empty/populated states, hidden conditional
groups and different clustering methods. Preserve ordinary table/figure scrolling.
Inspect actual paired screenshots; a bounding-box result alone does not certify
readability. Avoid one-off styles injected into the live page as candidate proof.

Exercise actual candidate upload → preview → commit → selection → controlled
Run → results/visualization → save/load using the established local cached/fixture
worker, with its substitution explicitly recorded. No external annotation fetch
or production analysis is needed to verify presentation wiring. Record exact
selected/committed snapshots and stored result identity after navigation,
resize and restoration. Reuse existing relevant regression tests; do not weaken
their assertions or rebuild backend mocks merely to make a layout test pass.

Only scoped native R/UI checks, format/parse/type checks and relevant browser
journeys run locally, followed by exact-candidate server preflight. Do not request,
run, review or await GitHub CI; a full R suite, package check or coverage run is not
added as a substitute. Preserve local assertions, source/resource guards and
configuration values. A failed or unobserved local journey, including native zoom,
remains explicitly unresolved rather than inheriting a pass from server preflight.
This user-directed verification-policy exception does not change scientific,
density, typography, preservation or functional acceptance targets.

The design-sync tool surface is unavailable in this harness. Use the established
theme plus actual browser evidence; no external design-system artifact is required.

## §E Risks and rollback

Long review text may legitimately require scrolling in populated/narrow views;
preserve it and compare the agreed primary span, not overall page height.
A grid that fits the viewport but not its actual panel can still clip controls;
verify measured containers at intermediate sizes. CSS scope mistakes can shrink
plots or alter Home/dialogs; compare protected geometry and unchanged source.

Withhold a failing candidate and retain all baseline/fixture evidence. Rollback
of this development means retaining the currently deployed4bc application,
not forcing a service failure or changing existing scientific data. If a necessary
new surface or a threshold proves incompatible with full content, stop and return
verified evidence to the orchestrator rather than weaken an acceptance criterion.
