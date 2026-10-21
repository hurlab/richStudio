# Workspace design system — SPEC-WS-002

Version: 1.0.1 · 2026-10-21 · local design candidate, awaiting independent review.

## Authority and measured reference

Native R/Shiny/shinydashboard/Bootstrap remains the stack. Preserve the existing logo, module namespaces and blue/teal identity. This is an additive workspace component contract; existing screens are adapted by their owning leaves, not replaced globally by002. Read with [screens](workspace-screens.md) and [handoff](workspace-handoff.md).

Reference inspected in this run: commit `2e52278601d150fd6982886681448d36eac2bdfe`, branch `WT-workspace-design-system`, tree `/home/juhur/PROJECTS/20_libs/richStudio/.moai/worktrees/workspace-design-system`. `inst/application/www/custom.css` SHA256 `f0b92df325f98e5646f504c8af61c6b4241f5c8f7525419b5bbb6a213b5fc539`. Original values below are extracted from that file, not inferred from a screenshot. DesignSync discovery returned no callable methods; no remote project, upload, validation or canvas edit occurred.

## Original token reference (retain for rollback)

| Existing token | Original value |
|---|---|
| `--rs-primary` | `#0f6fc5` |
| `--rs-primary-dark` | `#0a5a9e` |
| `--rs-primary-light` | `#e8f4fd` |
| `--rs-primary-lighter` | `#f0f7ff` |
| `--rs-accent` | `#21c4b6` |
| `--rs-accent-dark` | `#1aad9f` |
| `--rs-accent-light` | `#e6f9f7` |
| `--rs-danger` | `#dc3545` |
| `--rs-danger-light` | `#fdf0f1` |
| `--rs-warning` | `#e6a817` |
| `--rs-success` | `#28a745` |
| `--rs-success-light` | `#edf7ee` |
| `--rs-info` | `#17a2b8` |
| `--rs-text` | `#1e293b` |
| `--rs-text-secondary` | `#64748b` |
| `--rs-text-muted` | `#94a3b8` |
| `--rs-bg` | `#f1f5f9` |
| `--rs-bg-card` | `#ffffff` |
| `--rs-border` | `#e2e8f0` |
| `--rs-border-light` | `#f1f5f9` |
| `--rs-shadow-sm` | `0 1px 2px rgba(0,0,0,0.05)` |
| `--rs-shadow` | `0 1px 3px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.04)` |
| `--rs-shadow-md` | `0 4px 6px -1px rgba(0,0,0,0.08), 0 2px 4px -2px rgba(0,0,0,0.05)` |
| `--rs-shadow-lg` | `0 10px 15px -3px rgba(0,0,0,0.08), 0 4px 6px -4px rgba(0,0,0,0.05)` |
| `--rs-radius` | `8px` |
| `--rs-radius-sm` | `6px` |
| `--rs-radius-lg` | `12px` |
| `--rs-radius-xl` | `16px` |
| `--rs-font` | `'Segoe UI', system-ui, -apple-system, 'Helvetica Neue', Arial, sans-serif` |
| `--rs-font-mono` | `'Cascadia Code', 'Fira Code', 'Consolas', monospace` |
| `--rs-sidebar-width` | `250px` |
| `--rs-sidebar-bg` | `#1e293b` |
| `--rs-sidebar-text` | `#cbd5e1` |
| `--rs-sidebar-hover` | `#334155` |
| `--rs-sidebar-active` | `#0f6fc5` |
| `--rs-transition` | `0.2s ease` |

Existing geometry inspected: content padding20px24px (12px at max-width767px), card margin-bottom20px/body16px/header14px16px; form min-height38px and radius6px; button8px16px at13px; DT headings10px12px and cells8px12px at13px. Existing screen title22px/700; body inherits browser/Bootstrap sizing. Home title28px. These are source observations, not computed browser measurements.

## Additive workspace decisions

Use an `.rs-workspace` component scope and specific component classes. Do not recolor all Bootstrap selectors or overwrite the original token definitions. Proposed extensions below take effect only in the new components unless an owning screen explicitly adopts them. Reuse existing token values wherever possible.

| Proposed token | Value/reference | Reason |
|---|---|---|
| `--rs-workspace-text-subtle` | existing `--rs-text` (#1e293b) | Metadata/help on gray needs stronger foreground; secondary stays usable on white |
| `--rs-workspace-control-border` | existing `--rs-text-secondary` (#64748b) | Input/secondary-button boundary discernible on white and gray |
| `--rs-workspace-focus` | existing `--rs-primary-dark` (#0a5a9e) | Opaque focus indicator rather than only a translucent shadow |
| `--rs-workspace-focus-gap` | #ffffff | Separates focus from filled buttons/dark surfaces |
| `--rs-workspace-success-text` | #1e7a33 | Readable success label on existing success-light |
| `--rs-workspace-warning-text` | #92400e | Readable warning label on #fef9ec |
| `--rs-workspace-error-text` | #b91c1c | Readable error label on existing danger-light |
| `--rs-workspace-info-text` | #0e7c8c | Reuses existing info header foreground on #f0fafb |

Teal accents decorate rules/chips with dark text; use primary blue for filled action buttons. Do not put small white text on the blue-to-teal hero gradient. These rules leave original values intact and avoid a global CSS replacement. Blue/teal need no additional logo or font asset.

## Contrast evidence

Measured with Python3 standard library in this tree: decode each sRGB channel to linear (`c/12.92` at c<=0.04045; otherwise `((c+0.055)/1.055)**2.4`), compute Y=0.2126R+0.7152G+0.0722B, ratio=(lighter+0.05)/(darker+0.05). Values rounded only for display. Normal text target4.5:1 ([W3C SC1.4.3 explanation](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)); meaningful boundaries/focus target3:1 against adjacent colors ([W3C SC1.4.11 explanation](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)). Compare unrounded values to thresholds. This static calculation does not establish rendered or full-app conformance.

| Foreground / background | Measured ratio | Design use |
|---|---:|---|
| #ffffff / #0f6fc5 | 5.12:1 | Primary label |
| #ffffff / #0a5a9e | 7.07:1 | Primary hover label |
| #ffffff / #21c4b6 | 2.18:1 | Reject for normal text |
| #ffffff / #1aad9f | 2.79:1 | Reject for normal text |
| #1e293b / #ffffff | 14.63:1 | Body |
| #64748b / #ffffff | 4.76:1 | Secondary on white; control boundary |
| #94a3b8 / #ffffff | 2.56:1 | Decoration only, never necessary help |
| #64748b / #f1f5f9 | 4.34:1 | Reject for normal text on gray; boundary allowed |
| #0a5a9e / #e8f4fd | 6.33:1 | Selected label |
| #1e293b / #e6f9f7 | 13.42:1 | Teal chip label |
| #cbd5e1 / #1e293b | 9.85:1 | Sidebar label |
| #ffffff / #1e293b | 14.63:1 | Sidebar focus gap |
| #0f6fc5 / #f1f5f9 | 4.67:1 | Link on gray |
| #e2e8f0 / #ffffff | 1.23:1 | Decorative divider only |
| #ffffff / #dc3545 | 4.53:1 | Existing danger fill; avoid opacity reductions |
| #ffffff / #28a745 | 3.13:1 | Reject for normal text |
| #ffffff / #17a2b8 | 3.04:1 | Reject for normal text |
| #1e7a33 / #edf7ee | 4.92:1 | Success label |
| #92400e / #fef9ec | 6.74:1 | Warning label |
| #b91c1c / #fdf0f1 | 5.83:1 | Error label |
| #0e7c8c / #f0fafb | 4.62:1 | Information label |

## Typography, spacing and layout

Retain system font stack and existing radii/shadows. Workspace body/input text14px/1.5, secondary/helper13px/1.5 with a readable color, route heading22px/1.3 weight700, card heading16px/1.4 weight600. Use rem equivalents (base16px) so browser font preferences work; no remote fonts. Exact identifiers and source values use existing mono stack; wrap long identifiers (`overflow-wrap:anywhere`) without changing copied values. Numeric values/counts/times use tabular numerals. Text is never shrunk to fit.

Spacing scale4/8/12/16/20/24/32px; field label-to-control4px, related fields12px, card body16px, action gap8px. Retain card8px and control6px radii. Do not create concentric nested rounded surfaces with conflicting geometry: use plain inner groups and dividers instead. Existing shadow-sm/shadow express elevation; borders express structure. No additional animation or elevation is needed for static review cards.

Desktop1280x720: sidebar250px; content uses the available width with24px horizontal padding; two-column controls/results only when each column can remain at least320px. At CSS width<=767px collapse to one column, content12px, wrap header facts/actions, and provide a labeled sidebar toggle. DOM order equals reading/keyboard order. At375x667 the main content has351px before card padding; controls use min-width:0 and max-width:100%. Dialog width is viewport minus24px, with vertically scrollable body, wrapping footer buttons and no fixed-height action obstruction. No sticky action bar covers content.

True200% browser zoom at physical1280x720 is expected to expose approximately640x360 CSS space: use the same one-column rules and vertical scrolling. This is a design expectation, not a measured002 browser result. QA must use native browser zoom and record actual zoom factor, physical/outer dimensions and CSS inner dimensions. DPR or a narrow viewport alone does not prove zoom. No root horizontal overflow; intentionally wide data tables have their own labeled scroll regions.

## Interaction and accessibility contract

All actions use native buttons/links with meaningful visible text; icons are decorative (`aria-hidden`) supplements. Action targets at least44x44 CSSpx, including narrow mode; table action controls can use padding within their row. No hover-only help. Links are underlined or otherwise retain a noncolor link cue. The active navigation item has text/current-state semantics plus an indicator; color alone never identifies it.

Focus: visible3px solid primary-dark outline,2px white separation, not clipped; on dark surfaces keep the white separation visible. Filled buttons expose the two-color ring as well. Never remove outline without an equivalent. Focus must follow DOM order, with a skip-to-main link and labeled main region supplied by the shell owner003. Native Enter/Space activate buttons, Enter follows links; do not duplicate event handlers. A newly opened dialog receives heading/first meaningful control focus, traps within the modal only while open, closes by Escape when nondestructive, and returns focus to its invoker. If the invoker was removed, focus the surviving contextual heading. Destructive replacement requires a named confirmation; Cancel is first safe/default action. Inline validation links error summary entries to fields with aria-describedby/aria-invalid; preserve entered values.

Status components contain visible state text and optional decorative symbol. Routine transition announcements use a single polite status region; failures requiring attention use alert semantics once. No per-second elapsed-time announcements. Busy areas set aria-busy without blocking navigation or hiding previous valid results. Percent progress exists only with measured numerator/denominator; otherwise display “Running — progress not reported”. Never claim cancelled before backend acknowledgement; unsupported termination offers “Detach from this job” with explanation that computation may continue.

For `prefers-reduced-motion: reduce`, remove workspace translations, pulse/spin and nonessential transitions; static icon plus “Running”/“Loading application” supplies state. Loading-overlay motion is an existing global hook and needs a narrowly targeted reduced-motion override when002 implements this rule; no new overlay/process code. Preserve state indication with motion off. Default workspace transitions, if needed, are color/border-color/box-shadow only,0.2s ease; never transition:all.

## Tables, dataset cues and scientific text

Standard table density13px text, header10px12px, cell8px12px; readable mode14px with12px vertical padding can be adopted by screen owners. Use actual table headers/caption and row selection text/checkboxes with dataset+qualified-term accessible names. Surround wide tables with a keyboard-focusable region labeled by a unique visible heading, helper “Scroll horizontally to view all columns”, and contained overflow-x:auto. Region focus needs its own visible ring. Preserve DOM/table semantics rather than flattening cells on mobile. Search, column controls, pagination and primary actions stay outside horizontal overflow and wrap vertically. Screen-reader row/filtered counts come only from actual tables.

Dataset cues are keyed by stable dataset ID in a persisted display mapping, never current row/sort index or human label. Suggested ordered fills: primary #0f6fc5, teal #21c4b6, existing stepper indigo #6366f1; always pair with visible synthetic codes D-A/D-B/D-C, names and distinct symbols (circle/square/triangle). Additional datasets may cycle colors only if unique text codes remain. On charts do not rely on the teal-on-white boundary alone: add dark outline, symbols and matching legend/data alternative. Palette colors convey dataset identity, not significance or status. Do not infer accessibility from colorblind palette naming.

Use “Setup draft”, “Captured run settings”, “Display filter”, “Committed input revision” and “Unsaved project changes” distinctly. Metadata fields include stable dataset/revision/run IDs, organism, identifier type, annotation provider/release/build/digest where recorded, effective background source/size and engine/version. “Not recorded” means missing legacy metadata; “Not supplied” means absent imported content; “Not tested” requires test-family evidence; “Not significant” requires a tested value/threshold. Missing row/value is never0. Exact source values remain available alongside formatted values; extreme p-values are not replaced with arbitrary floors. Background terminology distinguishes default annotated universe, complete measured background and richR clustering term-union background.

## Component inventory

IDs below identify design contracts, not new public R exports. Functions remain internal and use Shiny NS once per local ID. Any actual function naming is settled by the implementer without changing behavior.

| ID | Primitive and required states | Boundary |
|---|---|---|
| C01 Entry action | Native labeled action; idle/focus/busy/unavailable+reason | Navigation intent only;003 performs routing |
| C02 Context facts | Dataset/run IDs, organism/keytype, metadata availability and unsaved flag; empty/known/unknown | Read-only facts;006/007 own records |
| C03 Review card | Heading, label/value facts, advanced details; ready/invalid/unknown/imported | No scientific calculation;004/005 provide effective values |
| C04 Field diagnostics | Visible label, help, linked error; untouched/valid/invalid | Text/association only;004 owns parsing |
| C05 Status panel | Text/icon/status semantics; queued/running/indeterminate/failed/succeeded/stop-requested/cancelled/detached/interrupted |006 supplies backend-confirmed state |
| C06 Results region | Heading/caption/labeled overflow; empty/zero-valid/populated/filtered/missing-statistic |008 owns data and selection |
| C07 Dataset/selection cue | Code+label+symbol+color, clear action; selected/hidden-by-filter/none/duplicate-label | Stable identity adapter from008 |
| C08 Figure receipt | Plot alternative, used-data/settings/source; ready/unsupported/exporting/failed |009 renders/exports |
| C09 Engine/comparison review | Named policies, compatibility explanations; available/missing/unknown/different |010 supplies science/compatibility |
| C10 Named confirmation | Dirty/save/open preview/error/legacy/unsupported-version; named management-removal consequences; safe Cancel and modal focus return |007/012 own project validation/atomic apply;006 owns Manage Files mutations in R/update_tab.R |

002 implements reusable presentation primitives, not every future route.003–012 consume this contract at their own gates. Presentation accepts explicit typed state and already-computed facts; it must not derive scientific counts, terminate jobs, deserialize files or interpret HTML.
