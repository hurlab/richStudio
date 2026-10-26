# richStudio project format (version 1.0)

A project is a ZIP written by **Save tab > Download Project** and read by **Open Project**.
It explains saved results (parameters, versions, statistics, provenance) in addition to
preserving the exact tables. The JSON session (`docs/SESSION_FILES.md`) is unchanged and still
works; a project is an additive format, not a replacement.

A project contains data only. Opening one never sources a script, evaluates an expression,
deserializes an R object or runs a bundled recipe.

## Archive layout

| Member | Content |
|---|---|
| `manifest.json` | Versioned description of every saved result (below). |
| `tables.json` | Exact-value tables, one entry per generated table ID (`t0001`, `t0002`, ...). |
| `methods.md` | Plain-language methods summary generated from the manifest. |

Exactly these three members are accepted. Labels are user text and never become archive paths:
tables are addressed by generated IDs inside `tables.json`, and the human label lives in the
manifest. (Tables share one member rather than one file each because the reviewed resource policy,
`inst/config/workspace-resources.json`, bounds an archive to `archive_members` entries.)

## `manifest.json`

```
schema            "richstudio.project"
format_version    "1.0"            major.minor; a higher major is refused, a higher minor is read
created           UTC ISO-8601 time of the save
software          richStudio version, engine {name: richR, version}, R version string
datasets[]        DEG sets:      id ds-<12 hex>, label, kind "deg", listed, table, table_digest,
                                 nrow, ncol, columns[{name,class}], source_digest, origin
results[]         enrichment:    id rs-<12 hex>, label, kind "enrichment", listed, table fields as above,
                                 run_id, species, keytype, annotation_type, ontology,
                                 annotation_provenance, parameters, background, statistics,
                                 term_id_column, term_ids[]   (tm-<12 hex> per row)
clusters[]        clustering:    id cl-<12 hex>, label, kind "clustering", listed, table fields (summary
                                 table), detail {table fields} (per-term table), run_id, method,
                                 parameters, cluster_column, clusters[{id cn-<12 hex>, value}],
                                 statistics.per_dataset[]
runs[]            WS-006 run records as exported (id, kind, state, settings, inputs, outputs, ...)
relationships[]   {type, from, to, ...}: "input_of" (dataset->result, result->cluster, with run_id and
                  input_revision) and "produced_by" (result|cluster -> run id)
files[]           {name, role, sha256, bytes} for tables.json and methods.md
display           reserved for display settings; immutable numerical results never live here
absence_types     the four absence values below
```

`label` is a display label. `listed` records whether the label was in the workspace's name list; an
unlisted table (data without a name entry) is kept, not dropped.

### IDs

IDs are generated from content, so saving the same results twice gives the same IDs:
`ds-`, `rs-`, `cl-` are `sha256(kind, label, table digest)[1:12]`; `tm-` is `sha256(Term)[1:12]`;
`cn-` is `sha256(cluster result label, cluster value)[1:12]`. Run IDs are the registry's own.

### Digests

- `files[].sha256` is the SHA-256 of the file's bytes inside the archive.
- `table_digest` is the SHA-256 of a canonical text of the table's exact values: row count, row
  names, and for each column its name, class, factor levels and every value (doubles at 17
  significant digits, NA distinct from the string "NA"). It does not depend on how the table was
  serialized, so it can be recomputed from the decoded table.

Import recomputes both and refuses a mismatch.

### Typed absence

A field with no value says why; a missing value is never written as 0, an empty string or a guess.

| Status | Meaning |
|---|---|
| `not_recorded` | The application never captured it (older save, no run record, engine does not report it). |
| `not_supplied` | The user chose not to provide it (for example no custom background was supplied). |
| `not_tested` | The statistic was not computed for that row (NA adjusted p-value in an enrichment result). |
| `not_significant` | The row is absent from that source because it did not pass (NA per-dataset p-value in a clustering table). |

Recorded fields are `{"status": "recorded", "value": ...}`. Statistics columns that exist are
`{"status": "recorded", "column", "n_missing", "missing_type"}`. The missing values themselves stay
`null` in the table; only the manifest explains them. Annotation provider, release, build and digest
are never inferred: they are `not_recorded` until the engine reports them.

### Enrichment background

The `richstudio_background` attribute of an enrichment result (SPEC-WS-005: mode, source label,
digest, counts, annotation identity and richR version) is stored in `background` with each NA field
replaced by a typed absence, and restored as the attribute on open. When it is absent the whole
field is `not_recorded`.

## `tables.json`

```
schema "richstudio.project.tables", format_version "1.0",
tables { t0001: { data: {<column>: [values]}, schema: {nrow, names, classes, levels, row_names, row_names_class} } }
```

Columns use the lossless encoding of `R/session_json.R`: doubles with NaN/Inf are written as
17-significant-digit strings, factors keep their levels, zero-row tables keep their column classes.
Integer row names are marked with `row_names_class: "integer"`. Tables are exact values; they are
never altered for display or for spreadsheets.

## Methods text

`methods.md` is generated from the manifest only, in three sections: **Recorded facts** (parameters
and versions that were recorded), **Display labels** (names the user chose, not parameters) and
**Unavailable provenance** (what could not be stated). Every label is HTML-escaped. A recipe is never
exported or executed.

## Spreadsheet-safe export

Human-readable CSV/TSV exports (Save tab > Export Individual Results, Export All) prefix a cell that
starts with `=`, `+`, `-`, `@`, tab or carriage return with an apostrophe, so a spreadsheet does not
run it as a formula. The checkbox "Spreadsheet-safe text" turns this off for byte-exact files. The
exact-value tables in a project are never altered. Archive members of Export All use sanitized,
de-duplicated file names.

## Import is validate-then-swap

1. The installed resource policy is loaded; a missing or invalid policy blocks import.
2. The archive listing is checked before any byte is extracted: compressed size
   (`archive_bytes`), member count (`archive_members`), declared expanded size
   (`archive_expanded_bytes`), path depth (`archive_depth`), a compression-ratio ceiling (200:1 above
   1 MiB), duplicate and case-insensitive duplicate names, traversal (`..`), absolute and drive paths,
   backslashes, control characters, symlink/directory/special entries, encrypted entries, and any
   member other than the three above.
3. Members are extracted one by one into a private temporary directory and their real sizes are
   re-checked against the declared sizes.
4. `manifest.json` is parsed (JSON only, nesting-bounded); `format_version` must be `1.x`; file and
   table digests, table shapes (`rows`, `columns`, `string_bytes` for labels), IDs, labels,
   cross-references, relationships and run records are validated; tables must all be referenced.
5. Only then is the workspace replaced: the WS-006 job generation is invalidated, every store is
   cleared and filled, and the saved run history joins the registry as history. Any failure before
   step 5 leaves the workspace, selections and running jobs untouched.

Legacy JSON 1.0 sessions are read by `session_json_read()`, validated into the same candidate shape
(`project_legacy_candidate()`), and applied through the same step 5. Their manifest fields are
`not_recorded`; nothing is recomputed. RDS sessions are not accepted by the browser; trusted local
files are converted with `scripts/convert-trusted-session.R`.

## Limits and compatibility

- Tables over `rows` (50,000) or `columns` (24) per the installed policy are refused when saving, so a
  project that cannot be reopened is never written.
- Versions: a newer minor of major 1 is read (unknown manifest fields are ignored); a newer major is
  refused with no change to the workspace.
- Rollback: the JSON session save/load is untouched; disabling the project controls does not affect
  stored results.
