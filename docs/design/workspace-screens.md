# Workspace screens — SPEC-WS-002

Version1.0.1 · 2026-10-21 · annotated local wireframes, awaiting independent review. Component IDs refer to [design system](workspace-design-system.md). All examples are synthetic; numeric examples below are explicitly fixture values, never application observations.

## Navigation and frame (annotation A01)

Preserve current tab names and module namespaces:

| User destination | Current tab / module prefix | Owning leaf | Annotated screen/state coverage |
|---|---|---|---|
| Home | home_tab / home |003 | A02 Home |
| Gene-list intake, scientific review | enrich_tab / enrich |004/005 | A04 Intake; A05 Scientific review |
| External enrichment intake | cluster_upload_tab / cluster_upload |004 | A04 Intake |
| Results and enrichment figures | rr_visualize_tab / rr_visualize |008/009 | A07 Result explorer; A09 Figures |
| Clustering chooser and run comparison | cluster_tab / cluster |010 | A10 Clustering chooser; A11 Run comparison |
| Cluster figures | clus_visualize_tab / clus_visualize |009 | A09 Figures |
| Manage Files / dataset management | update_tab / update |006 owns R/update_tab.R;008 contributes identity/selection adapters only | A17 Manage Files |
| Save/open | save_tab / save |007/012 | A12 Save/open |

Header, job panel and linked selection are shared surfaces inside these routes, not additional analysis-submit routes. Current menu groups remain navigable; do not create a linear wizard that forces clustering. Preserve valid settings when changing routes. A navigation event cannot trigger analysis, import, demo loading or recomputation. Dataset-management deletion names the selected stable dataset, describes dependent records, and never clears unrelated datasets.

Desktop frame,1280x720 design target:

```text
[Skip to main]
[richStudio logo] [Menu] [Route title]                     [Save/open]
[Sidebar250px]   [C02 D-A Synthetic A · run r-a · Succeeded]
[Home         ] [Organism: recorded value | Identifier type: recorded value]
[Enrichment   ] [Setup draft differs from run | Unsaved project changes]
[Clustering   ] [Route heading]
[Manage Files ] [Main card(s), minimum320px each] [Optional review/details]
[Save/Load    ] [C05 current jobs + link to captured run settings]
```

At375x667, hide the sidebar behind a labeled toggle, wrap C02 facts and buttons, keep the route heading in main, then stack cards in DOM order. No fixed bottom toolbar; all actions remain in normal vertical scroll. At true200% browser zoom use the same layout based on measured CSS viewport, not device pixel ratio. Sidebar opening focuses its first link and closing returns focus to Menu; it must not cover an unreachable primary action. Long labels wrap and can be copied in full.

## Annotated primary route wireframes

| Surface / annotation | Ordered content and primary action | Follow-on / keyboard contract |
|---|---|---|
| Home / A02 | C01 four actions: **Upload gene lists**, **Import enrichment results**, **Open saved analysis**, **Load demo**. Populated workspace adds C02 current context, **View results** and **Continue setup**. | About/links secondary. Demo requires its own explicit action and is labeled synthetic/example. No numbered compulsory pipeline. Native buttons in reading order; never whole-card click-only handlers. |
| Workspace header / A03 | C02 dataset code/name/stable ID, selected run ID/state, organism/identifier type; captured run versus setup-draft marker; unsaved-project indicator. **Change dataset** opens labeled chooser. | Unknown facts read “Not recorded”; no organism guess from filename. Read-only metadata details include background/provenance. Dataset/run switching keeps independently saved selections/settings. |
| Intake / A04 | C04 labeled file input → source preview → explicit column mappings (ID, raw Pvalue, adjusted value, membership as applicable) → errors → C03 query snapshot → **Commit input revision**. | **Run enrichment** is a separate explicit action after scientific review. External results offer **View results / Create figure** after validation without enrichment or clustering. Preview search/filter is labeled “Preview only”; committing creates new revision. Invalid file keeps prior workspace. |
| Scientific review / A05 | C03 dataset/revision and selected columns, effective gene-selection rule/count, actual query, organism/keytype, database/ontology, background source/effective count. Advanced details: cutoffs/adjustment family/provider/build/digest/engine versions. **Run enrichment** submits captured settings only. | Missing mapping count says “Not available”, not0. Distinguish default annotated universe, complete measured background and clustering term union. Incompatible query/background blocks submission with field-linked explanation. Imported-only results offer recorded metadata, not editable invented history. |
| Job panel / A06 | C05 named run and captured input revision → actual lifecycle → elapsed time → captured settings → **View results** on success, **Review setup / Run again** after failure. | Unknown progress: “Running — progress not reported”. Stop only if backend proves owned termination. Stop requested stays pending until acknowledgement. **Detach from this job** explains computation may continue. Failure retains old valid results. Navigation remains enabled. |
| Result explorer / A07 | C02 source/run → C06 table caption/statistic source → external display filter → C07 linked term selection → exact-value/details region → **Create figure / Export exact results / Cluster these results** when supported. | Zero valid terms and no result are different states. Columns preserve source raw/adjusted definitions and provider extras. Selection identity uses dataset+run+annotation context+qualified term ID, never row number/name. Display filter does not alter source/run. |
| Linked selection / A08 | C07 “Selected term: [qualified ID, label, dataset, run]” or cluster-membership/gene identity → source-linked details → **Clear selection**. | Duplicate labels show disambiguating IDs. Hidden by filter says so and offers **Clear display filter** without changing selected identity. Missing gene membership disables only the gene-dependent view with a reason; no fake gene count. |
| Figures / A09 | C08 source/run → plot type/statistic → display-only transform/filter/order/dataset cues → plot+alternative table → **Export figure and used data**. | Missing required metric explains unsupported plot and offers available table/plot types; never inserts0. Export receipt records source, full-precision used data, settings and provenance availability. Editing a figure specification is a draft until saved/exported. |
| Clustering chooser / A10 | C09 engine cards with actual required columns and effective policy → source-run/revision → C03 review → **Run clustering**. | Existing hierarchical strict raw-Pvalue, DAVID unfiltered and richR term-union policies remain distinct. Adjusted-only import explains raw-Pvalue limitation for affected engine. No cross-engine equivalence promise; retain raw_result. |
| Run comparison / A11 | C09 two stable run IDs and names → input/annotation/background/engine differences → compatibility statement → membership-aligned table/plot → **Export comparison** if supported. | Compare clusters by term membership, never numeric labels alone. Unknown/incompatible species/keytype/annotation means gene-overlap comparison unsupported. Mean/min adjusted-value summaries explicitly descriptive, never a combined significance test. |
| Save/open / A12 | C10 unsaved status → **Save project**; separate file input → validation summary/format/version/counts only if measured → **Open validated project** with replacement confirmation. | Cancel preserves current state. Invalid/future-version candidate leaves current project/jobs intact. Successful atomic apply invalidates old authority. Legacy route explains metadata gaps and restoration path; no claim that ordinary RDS parsing is safe. No automatic recipe execution. |
| Manage Files / A17 | C02/C06 inventory grouped by DEG sets, enrichment results and cluster results; C07 stable ID+name selection; C04 **New name** → **Rename selected item**; separate **Remove selected items** → C10 named confirmation. |006 alone adopts this screen in R/update_tab.R.008 supplies identity/selection adapters without writing that file. Rename changes the display label while preserving stable IDs, references and source values. Validate no target, blank name and conflicting name with linked diagnostics; show the selected current name+ID so duplicate labels are unambiguous. |

Example detail layout (fixture values only):

```text
Results · Synthetic A [D-A ○] · dataset ds-a · run r-a
Captured run: Succeeded       Setup draft differs from captured run
Organism: Not recorded        Identifier type: Not recorded
Display filter [term label contains ...] [Clear display filter]
Results table — Source adjusted p-value [horizontal scroll hint]
  [Select] Qualified term ID | Term label | Source adjusted value
   ( )     SYN:T-A           | Synthetic term | 0.002
Exact source value: 0.002; no additional significance test implied
[Create figure] [Export exact results] [Cluster these results]
```

Narrow form/table arrangement (same reading order at zoom):

```text
[Menu] [Results]
[D-A ○ Synthetic A / ds-a]
[Run r-a · Succeeded]
[Organism: Not recorded]
[Identifier type: Not recorded]
[Unsaved project changes]
[Display filter label]
[Input full available width]
[Clear display filter]
[Results table heading]
[Focus region ↔ only table scrolls]
[Selected term full ID wraps]
[Create figure             ]
[Export exact results      ]
[Cluster these results     ]
```

### Manage Files interaction detail (A17)

```text
Manage Files · Unsaved project changes
[DEG sets / Enrichment results / Cluster results]
[Item: D-A Synthetic A · stable ID ds-a]
[New name: ________________________] [Rename selected item]
[Selected items: names + stable IDs] [Remove selected items]
Removal preview: exact selected records + actual dependent-record consequences
[Cancel] [Remove these named items]
```

Renaming is a display edit, not a new scientific run/revision. Successful rename updates visible labels while source IDs and captured scientific content remain intact; report “Renamed [old name / ID] to [new name]” only after application. Failed validation retains the text and current records, associates the error with its field/selector, and makes no job/workspace mutation. Preserve existing local input IDs under update namespace; adapters must separate identity from labels without silently changing existing module entry points.

Removal confirmation lists each stable selected target and actual dependent records, their retained/removed/invalidated disposition, and any affected owned job authority. Do not invent dependency counts or silently cascade to unrelated datasets. If consequences cannot be determined from current records, block destructive apply with an explicit diagnostic rather than guessing.006 owns the dependency/lifecycle policy and generation-safe application; this design requires the actual consequences to be reviewed before confirmation. Snapshot confirmation targets by stable ID and revalidate at apply; changed/missing targets or dependencies require a refreshed confirmation. Cancel/Escape leaves data/jobs unchanged. Focus begins on the safe Cancel action; after cancellation return to Remove selected items, and after deletion return there or to the surviving inventory heading if the invoker was removed. Announce actual completion once through C05; failure keeps prior valid content. Busy mutation reports real state only, guards duplicate apply and leaves navigation usable; no percentage or Stop claim.

At375x667 and true200% zoom, stack category selector, inventory, rename form and removal controls in that order. Labels/IDs/confirmation lists wrap; the C06 table alone may scroll horizontally with its visible heading/helper. Rename/Remove/Cancel/confirmation buttons remain outside that overflow in normal vertical flow with44px targets. C10 uses the shared viewport-bounded scrollable dialog and focus-return rules. No extra animation is introduced; reduced-motion preserves static text/status.

## Complete state inventory (annotation A13)

Every row below includes six required state classes. “Populated” includes completed data when applicable; running never erases prior valid content. All rows inherit visible focus, text+noncolor status, escaped labels and the responsive frame. N/A denotes absence of an independent operation, with its reason; relevant shared job/failure information remains visible.

| Surface / components | Empty | Populated / completed | Running / busy | Failed | Imported-only | Legacy / unknown |
|---|---|---|---|---|---|---|
| Home C01,C02,C05 | Four entry actions; no fabricated dataset count | Context + View results/Continue setup | Same actions/context + real job status | Keep context; failed-job link | View results/Create figure without DEG/clusters | Opened project + metadata-gap notice; no automatic rerun |
| Header C02,C05 | “No dataset selected”; run/organism/keytype not recorded | Actual IDs/facts/status; dirty flag | Captured run ID + running; draft separate | Failed run and previous selected valid result distinct | Source imported; absent run history not recorded | Explicit unknown fields; never guesses |
| Intake C03,C04,C06 | Choose file; no mapping controls with invented choices | Actual preview and mappings; committed revision label | Validation busy; preserve existing inputs/results | Field-linked errors + retained input/current workspace | Map supplied statistics; absent DEG/membership not supplied | Existing unknown mappings require confirmation for new revision; original preserved |
| Scientific review C02,C03,C04 | “Select committed input”; no query count | Effective submitted rule/count/background and advanced facts | Captured review read-only; changed draft labeled separately | Specific incompatibility; old run retained | Recorded-result review; enrichment N/A without committed gene input | Unknown facts explicit; rerun requires new confirmed setup |
| Job panel C02,C05 | “No jobs”; no progress bar | Succeeded+View results and captured settings | Real stage or indeterminate; measured elapsed; stop pending distinct | Error+Review setup/Run again creates new identity | “No recorded job for this import”; N/A running unless a new supported operation launched | Restored queued/running records shown interrupted; never resumed |
| Results C02,C06,C07 | “No results” + route to intake | Actual rows; zero-valid-term explanation distinct; next actions | Previous valid rows remain with source ID; job status separate | Previous rows preserved; result-load error linked | Direct table/figure/export; no clustering prerequisite | Exact tables available; provenance/unsupported statistics explicit |
| Selection C07 | “No selection”; clear absent | Qualified source identity + linked term/cluster/gene | N/A independent job; source selection remains usable during running job | Missing/stale source explanation; do not redirect to a same-label item | Term selection works; gene-dependent view explains absent membership | Stable imported identity available; incompatible gene linking unsupported |
| Figures C02,C07,C08 | “Choose a result” + source action | Supported plot+data alternative+receipt | Rendering/exporting actual state; previous preview labeled | Error and last valid source/settings; retry explicit | Supported imported metric plots without enrichment/clusters | Missing metric/provenance explained; never assumed defaults |
| Clustering C03,C05,C09 | Choose result; engine requirements visible | Named run/policies/results; rerun explicit | Captured policy+actual job state | Missing columns or backend failure; retain old result | Evaluate engines against supplied columns; adjusted-only restriction explained | Unknown background/annotation labeled; confirm new setup before run |
| Comparison C02,C06,C09 | “Select two runs”; no fabricated comparison | Membership alignment + differences; descriptive statistics | N/A independent analysis: comparison reads captured results; source jobs shown separately | Incompatible/missing source explanation; no numeric placeholder | Compare compatible recorded results; no input-gene comparison without evidence | Gene-overlap unsupported if context unknown; preserve side-by-side recorded facts |
| Save/open C02,C04,C10 | Save empty state honestly; choose project to open | Clean/saved receipt or dirty indicator; validated preview | Actual saving/validating; replacement only after validation+confirmation | Preserve current workspace/job authority; specific file error | Save available source tables+typed missingness | Legacy restoration instructions; unknown metadata stays unknown; historical jobs interrupted |
| Manage Files C02,C04,C05,C06,C07,C10 | “No files or results to manage”; link to intake/open; no invented selector items | Named stable inventory; explicit rename/removal preview; actual dependency consequences and dirty status | Actual rename/removal applying state; guard duplicate apply; source job status separately; N/A analysis launch because management never runs analysis | Linked target/name/dependency diagnostics; retained draft and prior records; no success announcement | Manage imported enrichment directly; DEG/cluster categories honestly empty; no gene-input prerequisite | Stable local identity shown alongside unknown provenance; do not fabricate dependencies; block removal when consequences unresolved; historical jobs interrupted |

Additional job states: queued (only backend-confirmed queue), stop requested, cancelled (only termination acknowledged), detached (may still run), interrupted (historical). Additional result missingness: not supplied, not recorded, not tested with evidence, not significant with known threshold; missing imported row alone proves none. Do not suppress these differences into a single blank/zero.

## Cross-cutting annotations

A14 — Trust: every dataset/provider/term label is text, including synthetic hostile-looking `<img src=x onerror=alert(1)>` and `=SUM(1,2)` examples. Use escaped text nodes/DT escaping/tooltips; never HTML(label), executable recipes, imported paths or arbitrary provider URLs. Links are approved http(s) destinations only; new tabs use target=_blank and rel=noopener noreferrer with “opens in new tab” indication. Exact scientific exports retain numeric values; spreadsheet-safe human export is separate and documented. No private datasets/screenshots.

A15 — Draft/run/display: committing preprocessing creates a new input revision; Run captures it and effective settings; display filtering affects only the current view; project dirty status describes unsaved edits. Navigation cannot change these categories. Run again opens a new setup/new ID and never overwrites old run history. Invalid imports cannot advance workspace generation.

A16 — Accessibility evidence: verify actual keyboard order/activation, focus visibility/return, live-region restraint, narrow scrolling, real200% zoom, static reduced-motion status and rendered contrast on the component fixture. These wireframes specify expected behavior; they are not screenshots, runtime proof or a completed usability study.
