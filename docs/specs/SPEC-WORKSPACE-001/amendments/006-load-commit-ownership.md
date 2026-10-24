# Amendment 006 — SPEC-WS-006 load-commit ownership and job-record ownership (draft r4)

**Status:** D1 (a) is owner-adopted (2026-10-23). It takes effect only through step 3 of `ws006-dispatch-plan-r4.md`, after root acceptance. The SPEC sentence in § Scope widening for owner confirmation (SW-1) needs the owner's confirmation at root acceptance; plan audit r2 accepted it on its merits after rewording (M11).

This draft supersedes r3 (`ws006-registry-amendment-draft-r3.md`, sha256 `bcb436e7ef2ec1506be70d1746d8f192019409abcba68c3d887ce47a43176355`), r2 and r1. The r4 changes:
- **SW-1 reworded (audit r2 M11).** The sentence now says exactly what a queue entry holds — for dispatch only, references to the owning sessions' job registries — names the queue version counter, and says which counts another session can see: entries ahead of its own queued job, and the queue length when the queue is full. The expected SPEC file changes to `ws006-spec-ws006-expected-r4.md`.
- **Hunks 2 and 3 carry run records as one string field (audit r2 B5).** `run_records_json` is used in both save formats, replacing r3's normalization of a native list (PC-6, rejected by audit r2).
- **Registry: no change.** The registry delta and its expected file are unchanged from r1. No `man/*.Rd` path is added.

Line numbers are at `2b52c9d`.

## Owner decision (2026-10-23)

D1 (a): adopt the amendment — R/save_tab.R joins 006 for the three hunks only; AC-001's load arm and saved run metadata are demonstrated in 006.

## Gap (measured)

SPEC-WS-006 AC-001 requires that a delayed worker's callback cannot add data, selection or a success notification "when … another session is loaded before completion". Technical plan item 4 (`docs/specs/SPEC-WS-006.md:53`) asks for invalidation "immediately before the successful atomic load state swap". Item 1 (`:47`) asks that run status persist "in saved project metadata", with saved queued or running records reopening as interrupted.

The load and save code lives in `R/save_tab.R`:
- `saveTabServer` at `:149-151` has no job or generation parameter;
- the load observer `:243-342` validates at `:271-312` and restores with direct store assignments at `:315-331`;
- the save payload is built at `:197-207`.

`R/save_tab.R` is not a SPEC-WS-006 target (`dispatch.json` node `SPEC-WS-006`, lines 533-565). The only alternative inside the lock is an `app.R` observer on `save-load_session`. That is the picker-click invalidation `003-004-006-dispatch-notes.md` (lines 31-41) prohibits: it would fire before validation, also on rejected files, and in an unordered relation to the module observer. A callback-time identity check is not enough either, because a loaded file can carry byte-identical data under the same label (`006-setup-recon.md` §6 E).

## The three hunks in `R/save_tab.R` (signature unchanged)

The registry is read from `session$userData$workspace_jobs` through the internal `workspace_jobs_peek(session)`, which returns NULL when the app did not install one. `saveTabServer`'s exported signature and its Rd stay byte-identical (plan r4 § Scope; probe-006h `B3 userData preset via testServer(session=): module sees 'app'; module userData identical to root=TRUE`).

1. One line near the top of the module server: `jobs <- workspace_jobs_peek(session)`.
2. In the load observer:
   - after the existing checks (`:274-277`, the unsupported-format `stop()` at `:286`, and the version handling at `:288-312`) and immediately before the first store assignment at `:315`, when `jobs` is non-NULL, call `workspace_jobs_commit_workspace_swap(jobs)`;
   - after the restore (`:331`), when `jobs` is non-NULL, call `workspace_run_records_reopen(session_data$run_records_json, jobs)`. It parses the string with `jsonlite::fromJSON(…, simplifyVector = FALSE)`, rejects anything other than one string holding a JSON array, reopens saved `queued`, `running` and `cancel_requested` records as `interrupted` (never re-enqueued, never resumed), and appends them. A missing field (older files) is a no-op. A malformed field is reported once and does not fail the load.
3. In the save handler, when `jobs` is non-NULL, add `run_records_json = workspace_run_records_json(workspace_run_records(jobs))` to `session_data` (`:197-207`): one character string, `jsonlite::toJSON(records, auto_unbox = TRUE, digits = I(17), null = "null", na = "null")`. Both the RDS branch (`:219`) and the JSON branch (`:221-235`) then carry the same string unchanged. `write_json` stores an opaque string, so neither `simplifyVector` at `:279` nor its default 4-digit rounding touches the records.

   Measured on a mixed session — enrichment and clustering records; scalar and length-2 vector settings; `0.123456`, `1e-5` and `0.1 + 0.2`; integers; NULL and NA; empty `outputs`; non-ASCII names; a single record; zero records — through the exact save/load calls (`probe-006j.out`): `rds mixed4: … identical per record=[TRUE,TRUE,TRUE,TRUE]` and `json mixed4: … identical per record=[TRUE,TRUE,TRUE,TRUE] whole-list identical=TRUE`, and the same for `single` and `zero`. Precision needs 17 significant digits: `digits=NA: bit-exact 5/10`, `digits=17: bit-exact 10/10`. The r3 control fails: `control native-list JSON: class=data.frame; enrichment settings keys=[species,…,cutoff,query,method,params,cluster_name,selected]`.

When `jobs` is NULL — every existing test and caller except `app.R` — behaviour and saved bytes are unchanged. The session `version` stays `"1.0"`. The load validation itself is not strengthened: its "fully validated candidate" semantics remain SPEC-WS-007's validated load path, which keeps the generation call when it replaces the checks.

## Changes (exact bytes)

| File | sha256 | Base | `git diff --no-index --numstat` |
|---|---|---|---|
| `D6/ws006-dispatch-json-expected.json` (unchanged from r1/r2) | `8a96fcc1b55be470f6ee5fb99bff9aed7e385e8f62232cc4ed8aa96d111d2965` | `dispatch.json` blob at `2b52c9d`, sha256 `6e708ee9c0321509827a6e7da238e9b618e5af5873464a0f745003b5abd1ff73` | `3 1` |
| `D6/ws006-spec-ws006-expected-r4.md` (new; replaces `-r3` `5f2d44b5…1f11`, which differs only in the SW-1 sentence: `--numstat 1 1`) | `c2e329f76b9f21ea8c2494ba46cd4c6afe8e17f5dda2d4a1ad2da1df0d77b276` | `SPEC-WS-006.md` blob at `2b52c9d`, sha256 `f4bc1420b544c9a37e4e1845b8239684e4615b8a03845fb0d15a2d29d8de9081` | `5 3` |

1. **`docs/specs/SPEC-WORKSPACE-001/dispatch.json`**, node `SPEC-WS-006` only, two hunks: `"R/save_tab.R",` added to `target_files` after `"R/update_tab.R",` (new line 544); in `existing_target_files`, `"R/update_tab.R"` gains a comma and `"R/save_tab.R"` follows. That is three lines added and one modified. No other node, field or order changes; `depends_on` is unchanged.
2. **`docs/specs/SPEC-WS-006.md`:**
   - front matter `updated: "2026-10-23"`;
   - under "Existing targets", `` - `R/save_tab.R` (amendment 006: load-commit and record hooks only; validated-load semantics remain SPEC-WS-007) ``;
   - technical item 4 gains one sentence before "Session close invalidates owned work during cleanup.": "The existing session load in `R/save_tab.R` calls the session job registry's generation commit after its current checks and immediately before its first store assignment; SPEC-WS-007 later replaces those checks with its validated load path without removing the call.";
   - **SW-1**, the security section (base line 97, published line 98) gains, after "All job stores belong to the Shiny session.": "Job records, handles, captured inputs and results stay session-owned. The only process-level state is a bounded, in-memory admission queue of the R process, which holds, for dispatch only, references to the owning sessions' job registries, and a queue version counter; neither is persisted, and another session can observe only counts (the number of entries ahead of its own queued job, and the queue length when the queue is full).";
   - the HISTORY line reads: "- 2026-10-23: Amendment 006 adds `R/save_tab.R` (load-commit and run-record hooks only) and states the session ownership of job records next to the in-process admission queue; no REQ or AC text changes."

   No REQ or AC text changes. The SPEC already names the `queued` state (technical item 2, `:49`).

## Scope widening for owner confirmation

- **SW-1 — SPEC text (audit r1 S2, reworded per audit r2 M11).** The security-section sentence above. Reason: SPEC base line 97 says "All job stores belong to the Shiny session", while the owner-chosen D3 (b) queue is one per-process structure shared by that process's sessions. The sentence states what the implementation does:
  - records, handles, captured inputs and results stay in the session's registry;
  - each queue entry is `{seq, run_id, registry}`, a reference to the owning session's registry, used by dispatch only;
  - a version counter lets queued sessions refresh their position;
  - nothing is persisted;
  - another session sees two counts, never content: the entries ahead of its own queued job, and the queue length in the queue-full refusal.

  The step-7 review and the step-9 result audit can then judge against literal text. If the owner rejects SW-1, root acceptance must instead record this reading of L97 and L107 as an owner-accepted interpretation, and step 3 publishes `ws006-spec-ws006-expected.md` (r1/r2 bytes) instead.
- **No `man/*.Rd` path is added.** Audit r1 B3 is resolved by keeping all four module-server signatures unchanged (plan r4 § Scope). So `man/clusterTabServer.Rd`, `man/updateTabServer.Rd` and `man/saveTabServer.Rd` stay byte-identical and outside 006. Baseline `tools::codoc(dir = <I>)` reports `codoc mismatches: 0` (probe-006i), and plan r4 adds the same check on the installed candidate before the push.

## Queue (D3 (b)) — no further target needed

The queue lives entirely in `R/workspace_jobs.R`, a 006 new target. Its process-wide length bound is a 006 constant `workspace_job_queue_limit()` (8), because the 001 policy defines no queue key: `workspace_resource_keys()` at `R/workspace_resources.R:2-6` lists 15 keys, and `:11` requires exactly that set. Adding a key would change 001-owned files (`R/workspace_resources.R`, `inst/config/workspace-resources.json`, the 001 policy bundle). **This amendment does not widen 006 to them.** The constant is held for 001 adoption, as with 004's `review_line_bytes_limit`.

## Lock and ordering check

`R/save_tab.R` is already a target of SPEC-WS-007 (`depends_on` 006), SPEC-WS-009 (007, 008) and SPEC-WS-012 (001, 006, 007). Each follows 006 in the dependency graph, so adding it to 006 makes the locks sequential and adds no edge or cycle. None of those leaves has started. Root re-checks **before step 2** of the plan (audit r1 M5: one point).

## Boundaries kept

SPEC-WS-007 still owns the project manifest, the import validation, the atomic load swap and `docs/PROJECT_FORMAT.md`. SPEC-WS-012 still owns the legacy-session bridge. SPEC-WS-006 does not edit `R/cluster_upload_tab.R`, `R/rr_visualize_tab.R`, `R/clus_visualize_tab.R`, `R/input_review.R`, `R/deg_enrich.R`, `R/workspace_resources.R`, `inst/config/workspace-resources.json`, any `man/*.Rd`, DESCRIPTION or NAMESPACE.
