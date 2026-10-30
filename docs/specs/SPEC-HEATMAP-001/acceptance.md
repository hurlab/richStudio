# Acceptance — SPEC-HEATMAP-001

These criteria are binary future checks, not completed validation claims.

## §D Acceptance matrix

| Criterion | Requirements |
|---|---|
|AC-001|REQ-001,REQ-002,REQ-003,REQ-005|
|AC-002|REQ-001,REQ-003,REQ-004,REQ-007|
|AC-003|REQ-003,REQ-007,REQ-008|
|AC-004|REQ-001,REQ-005,REQ-006|
|AC-005|REQ-001,REQ-006,REQ-012|
|AC-006|REQ-008,REQ-009|
|AC-007|REQ-010,REQ-001|
|AC-008|REQ-011,REQ-003|
|AC-009|REQ-001,REQ-008,REQ-012|
|AC-010|REQ-012|

## Binary scenarios

**AC-001 — Dense normal matrices.** Given 141 row bundled and 366 row real-result
fixtures with two or more datasets, when the installed summary UI renders at
1280×720 and 375×667, then all original trace coordinates/values/NA positions remain,
cluster rows have at least 18 CSS pixels, row-axis tick text is at least 14 CSS
pixels, axis labels
do not overlap adjacent labels or cover cells, the label column is no wider than
240px, the physical plot is at most 8192px per dimension, and the scroll region
is at most min(720px,70vh). The first and last row are reachable and the document
has no horizontal overflow beyond1px rounding tolerance.

**AC-002 — Bounded maximum.** Given 401 and the installed maximum/current 2000 row
fixtures, when users move the row-window control to its first and last positions,
then the plot retains all input cluster/dataset coordinate pairs and exact values,
shows at most 400 readable rows per window, labels its range/total accurately,
reaches every row without a new clustering run and never allocates a plot/image
dimension above 8192px. For ascending original category IDs 1..2000, logical rows
1–400 show IDs 2000..1601, rows 401–800 show1600..1201, and rows 1601–2000 show
400..1, preserving the original category order and complete trace membership.
The native "Cluster row window" dropdown exposes these disjoint windows; for 401
rows its last option exposes only the last logical row. View movement changes
visibility only, not trace membership.

**AC-003 — Keyboard and resize.** Given a dense view at either required viewport,
when users reach the region named "Cluster heatmap" and native dropdown named
"Cluster row window" with Tab and operate their native keyboard scrolling/
navigation, then the focusable region and control have visible focus,
first/last admitted rows remain reachable, the selected result is preserved,
and resizing between desktop/mobile does not expose stale limits or outer-page
horizontal overflow.

**AC-004 — Original label access.** Given duplicate representative terms,
noncontiguous IDs, long Unicode terms and two already accepted 101character IDs
that differ only in their final character, when users inspect axis text, hover
cells and open individual-cluster choices, then fitting IDs retain their full
`Cluster <original ID>` prefix and overlong IDs have distinct `Display row <r>`
aliases based on complete rendered-row positions. Aliases remain unchanged across
windows, fit the label column, and cannot collide with normal prefixed labels.
A visible notice explains the alias; aliased hover text maps it to the complete
original ID. All full IDs/terms remain unchanged in hover, chooser and trace keys.
No otherwise valid ID is rejected and no coordinate collision is introduced.

**AC-005 — Scientific and text safety.** Given ordinary, missing, raw-zero and
all-NA values plus HTML-like representative names, when the view is rendered and
a cell is inspected, then raw data, transformed values, missing masks, existing
zero-floor explanations and source strings match the original baseline. An
injected synthetic event-handler marker does not execute, the name remains inert
display content, and no new unsafe HTML insertion path is introduced. The
existing NA/zero explanatory annotation retains its wording and fits wholly inside
the actual plot bounds for 141/366/400 visible rows and a small result; its 11px text
is allowed. Its distance below the matrix stays bounded in pixels as plot height
grows rather than following a negative fraction of that height.

**AC-006 — Empty/small/change-result.** Given no selection, empty data and 1/2/10 row
results, when the view opens and then switches from a large last-row window to a
small result, then the honest empty state or compact readable figure appears,
small content does not require800px, the window dropdown is hidden for at most
400 rows/empty states, no invalid navigation remains, scroll/window
resets to the new result's first displayed rows, and result selection remains
stable. Changing Padj/Pvalue or mean/median/min/max preserves the existing formulas.

**AC-007 — Honest export.** Given a normal result and a maximum-size windowed
result, when the actual image download is activated, then each downloaded image
has dimensions no larger than 8192px, corresponds to the displayed values/missing
mask and row window, and identifies the row range and total whenever it is
partial. Scrolling a normal result to its last row does not crop the camera
image to the CSS viewport; its whole logical row window is included. The NA/zero
annotation remains complete inside the exported image; artifact inspection
confirms it is not clipped below the bottom boundary. Existing
result/session exports still contain all admitted rows and
reload with the same identities and values.

**AC-008 — Resource boundary.** Given a result with installed policy
render_rows+1(currently2001) rows, when rendering is requested, then a clear
resource-limit response occurs before oversized figure construction, no height
or canvas above the limit is allocated, no cluster subset is silently substituted,
and the installed policy is unchanged. The policy maximum itself passes AC-002.

**AC-009 — Existing workflows.** Given saved boundary sessions and the existing
bundled/real hierarchical and DAVID paths, when the installed candidate is used,
then ID-based choice, repeated representative names, missing/zero behavior,
method-specific inputs and save/load remain correct. Full source tables and
plot coordinates/values compare exactly to the attributed pre-change baseline;
only display labels, layout and viewport state may differ.

**AC-010 — Required quality.** Given the independently reviewed candidate, when
the canonical scoped/static/sync checks and hosted workflow run, then all
required jobs pass without skips or relaxed gates, candidate LSP diagnostics
total zero, coverage meets the unchanged policy, and there is no unresolved
Critical/High security finding in the changed surface.

## Closure evidence

Each row requires its command, observed output, exact source/install/runtime
attribution and artifact paths. Browser-only screenshots do not prove numerical
equivalence; a data-only unit check does not prove readable rows or safe scrolling.
The Reviewer, QA and Security roles report their own scope and gaps. Full
verification runs on CI rather than being relabeled from prior hosted evidence.

