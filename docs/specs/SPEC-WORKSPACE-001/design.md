# Design and architecture handoff — SPEC-WORKSPACE-001

This is an implementation-planning contract, not a completed screen design or a claim that a design-sync operation ran. A future manager-design owner produces the token/screens/handoff artifacts in002 before UI code. Runtime stack remains R/Shiny/shinydashboard with current modules and existing CSS; no framework migration follows from generic configuration defaults.

## Routes and context-preserving handoffs

| Starting point | First action | Next useful action | Must remain optional |
|---|---|---|---|
| Gene lists | Upload and review columns/query | Enrich, inspect results, make figure | Clustering |
| External enrichment | Validate mappings/probabilities/membership | Inspect, figure or cluster | Running enrichment |
| Saved analysis | Validate/open with compatibility route | Inspect existing results/settings | Recomputing anything |
| Demo | Explicitly load bundled synthetic/example context | Explore each supported route | Uploading a personal dataset |

Home entry buttons are actions, not decorative numbered cards. First iteration retains existing tab/input namespaces. A compact header identifies active dataset/run and recorded organism/keytype/status. Context-preserving handoffs carry stable object IDs and selected run/settings, not copied reactive blobs or human labels. Merely navigating never launches analysis.

A completed result card offers View results, Create figure, Cluster these results and Run again where meaningful. Run again opens the captured setup for explicit submission; it does not overwrite an immutable historical run. A draft changed since the last run is visibly marked. Display filtering, committed preprocessing and unsaved project changes use separate terms.

## Screen/state inventory for manager-design

| Surface | Required annotated states | Key handoff/accessibility contract |
|---|---|---|
| Home | Empty workspace; active project; explicit demo | Four keyboard actions, links/About secondary |
| Workspace header | Known/unknown metadata; selected data/run; unsaved changes | Consistent identity/status labels; no missing metadata guesses |
| Intake | No file; mapping suggestion; ambiguity; invalid; preview; committed | Explicit field errors and exact query snapshot; no mutation on failure |
| Scientific review | Ready; missing annotation counts; incompatible query/background | Primary concise facts; advanced exact parameters/provenance |
| Job panel | Running; indeterminate; failed; stop requested/acknowledged; detached; interrupted | Announced meaningful status without noisy per-second live regions; no fake progress |
| Result explorer | Empty; zero valid terms; populated; filtered; imported; unsupported statistic | Exact-value source preserved; next action and missing-state explanation |
| Linked selection | Term; cluster; gene; duplicate label; hidden-by-filter | Stable source identity; explicit clear-selection action |
| Figures | Supported plot; no required metric; display filter; export | Consistent dataset cues; plot alternative/data table; source/settings receipt |
| Clustering chooser | Available engines; missing required column; pending/completed | Distinct algorithm/default semantics; no claim of equivalence |
| Run comparison | Compatible; differing inputs/annotations; legacy unknown | Membership-based description; numeric cluster labels not identity |
| Save/open | Dirty; saving; invalid import; valid preview; legacy bridge; unsupported version | Transactional swap; preserve current workspace on error; migration help |

The design handoff includes existing-token mapping, typography/spacing/contrast/focus rules, component examples, screenshots or annotated wireframes, mobile/zoom/table-overflow states, draft/error/empty language and explicit adapter boundaries. Actual available design-sync capability determines whether a remote handoff receipt exists; unavailable tooling is recorded and local versioned artifacts suffice. Review must compare components and states, not approve a screenshot of Home alone.

## Scientific input contract

Primary review shows selected data/column, source revision, organism/keytype, database/ontology, actual gene-selection rule and count, effective background and mapping-count availability. Advanced details show cutoffs, adjustment family/method where known, annotation provider/release/build/digest and engine versions. Available values come from submitted data/engine observations, never guessed from filenames.

A preview does not modify the persisted scientific query. Committed preprocessing creates a new revision. The run captures that exact revision and explicit effective settings before dispatch. Padj-versus-Pvalue priority and strictness must match the actual worker path and be visible; moving controls must not alter default scientific behavior.

Default annotated universe, explicit complete measured background and richR clustering term-union background are different concepts with different labels. A DEG-only list is not silently the measured background. Public richR015 exposes universe formals; all supported annotation-route oracles still gate the complete feature. Invalid query containment, unrecognized background and filtering/adjustment-family differences must be diagnosed and recorded.

## Run and data identity contract

This table describes responsibilities and semantics; exact R structure/names are settled in006/007 implementation and frozen through versioned adapters before consumers dispatch.

| Record | Immutable scientific content | Mutable display/lifecycle content |
|---|---|---|
| Source dataset | Stable ID, original digest/type, original columns/data | Human label, visibility, display order |
| Committed input revision | Source ID, selected columns/IDs, preprocessing rule, query count | Preview filter is separate and never changes this revision |
| Run | Stable run ID, revision IDs/digests, effective settings, engine/version, result reference | Human name; lifecycle state transitions and timestamps |
| Enrichment result | Source statistics, raw/adjusted meaning, term IDs/memberships, provider extras | Formatted precision, sort/filter, selected term |
| Cluster result | Engine/parameters, term membership and numerical outputs, source run IDs | Human name, active cluster selection |
| Figure specification | Source run/result identity, statistic/transform/filters, order/colors | Current edit draft until explicitly saved/exported |
| Project manifest | Versioned references/provenance/typed missingness and table digests | Project label, saved display selections |

Stable term identity includes qualified term ID and annotation namespace/context in addition to dataset/run. Stable identities cannot depend solely on human labels, bare term IDs, current row indices, or numeric cluster labels. Species/keytype/annotation compatibility gates gene-overlap comparisons; unknown imported/legacy context yields an explicit unsupported comparison. Mean/min adjusted-value summaries remain descriptive, never a newly combined significance test. Dataset color assignment uses stable identity and remains consistent after sorting/reopening; symbol/text cues cover color independence. Clustering adapters preserve raw_result and existing strict raw-Pvalue hierarchical policy, unfiltered DAVID policy and richR term-union policy.

## Typed values and provenance

Store actual numeric values separately from status and availability. `not_significant` requires a known tested term and threshold, `not_tested` requires test-family evidence, `not_supplied` identifies missing imported content and `not_recorded`/unknown covers unavailable legacy/external provenance. A missing imported row alone proves none of these statistical conclusions. Missing p-values never become zero. Exact source/provider columns survive normalized views and exports.

Record annotation provider, dataset/release/build/digest where available; species, identifier type, ontology and fetch/build time; background source/effective size/mapping policy; engine/app/R versions; raw/adjusted statistics and correction family. A successful old session load cannot manufacture these fields. Methods text states only recorded facts and marks missing details. Sensitive identifiers/original paths need not be embedded in a public methods summary; include/export private source data only as explicitly selected.

## Owned jobs and state transitions

Each asynchronous job captures a session owner, workspace generation, stable run ID and input revision before launch. At result application, owner/generation/revision/run validity are checked again. Delete/replace/successful load invalidate old authority before the state swap. A failed import leaves current state and authority unchanged. Errors retain previous valid results. Session close clears or detaches owned resources using cleanup guaranteed by the actual backend.

Only backend-confirmed events appear as completed/cancelled. Opaque calls show indeterminate running and elapsed time. Stop is enabled only after owned-process termination is proven on the installed backend; detach means ignoring a result while computation may continue. Unsupported Stop is an explicit unresolved desired capability, not a completed cancellation feature. Saved running/queued jobs reopen as interrupted historical records; promises, process handles and executable closures are never serialized or resumed.

## Project import/export trust contract

Data-only JSON manifest and typed table ZIP is the preferred new interchange. All names inside archives are generated safe IDs; human names live in validated metadata. Validate compressed and expanded sizes, count/depth/rows/columns, member paths, duplicate names, links, future versions, table types and cross-references before any extraction/state swap. Limit values are measured/configured, not invented in this plan. Never resolve paths or arbitrary provider URLs from imported provenance.

RDS requires special handling before deserialization; plain-list/schema checks after readRDS do not establish safety. Preserve legacy support while evaluating a restricted browser-mediated conversion bridge. Prove no network/credentials, constrained writable directories/resources and protection of the serving process, rather than calling an ordinary R child a sandbox. If infeasible, a trusted-local converter has explicit support/usability costs and is not silently equated with browser compatibility. 012 owns bounded discovery (two candidate configurations/five probe cycles), a platform owner, actual Linux capability/confinement evidence and the nondeveloper restoration task.007 independently provides additive metadata/writers and safe JSON adapters; all supported loads, including the existing ordinary RDS parser, apply through common validated generation-safe atomic commit. The ordinary parser remains an explicit risk until 012 replaces it.008/009 do not depend on012, but changed public-format rollout and final release remain held until representative legacy users can restore their data/results safely without silent loss; retain original files and prior release during migration.

Recipes/scripts are inert documentation and never automatically executed. Source/result exact tables remain distinguishable from a spreadsheet-safe human export that escapes formula-like labels; do not alter scientific numeric values to sanitize display text. Methods text derives from captured metadata, not current global defaults.

## Security/performance review boundaries

Uploads, identifiers/labels/tooltips, asynchronous worker dispatch/termination, project parsing/deserialization, archive paths, annotation fetch routes and table/figure export all trigger security review. Stores/selection/jobs remain Shiny-session-local. Use synthetic data in fixtures/screens/traces, redact secrets and avoid patient payloads in logs. 001 produces the measured reviewed inst/config/workspace-resources.json and installed loader before 004/006/007 consume it;011 remeasures/refines. Bound resource admission from that source rather than hard-coding arbitrary limits. No arbitrary URL fetch, uploaded code execution, global R-process killing or new shared data service is introduced.

## Design review acceptance

Reviewer must trace each annotated screen state to a leaf requirement/AC, verify preserved routes and old IDs, check scientific labels with the science/QA owner and trust boundaries with security. Missing sync artifacts, unknown import metadata and unproven browser conversion are explicit gaps. Design approval enables implementation of the reviewed screen contracts; it is not usability, accessibility or runtime verification.
