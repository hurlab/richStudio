# SPEC-WS-007: reproducible manifest, project writer, methods text.
# REQ-001 (AC-001), REQ-006 (AC-001, AC-002), AC-005 (escaping and spreadsheet safety).
# Everything runs against plain data frames and parsed run-record lists: no reactive
# state, no worker, no network.

pm_background <- function(mode = "explicit") {
  explicit <- identical(mode, "explicit")
  list(
    mode = mode,
    source = if (explicit) "Explicit background (measured and annotated)" else
      "Annotation universe (genes annotated in the selected source)",
    background_digest = if (explicit) "0123abcd" else NA_character_,
    submitted_count = if (explicit) 40L else NA_integer_,
    mapped_size = NA_integer_, unique_count = 30L, duplicate_count = 0L, invalid_count = 0L,
    unmapped_count = 10L, query_effective = 5L, query_unmapped_count = 1L, query_excluded_count = 0L,
    query_rule = "Query genes without annotation are dropped; the universe is the annotation.",
    annotation = list(species = "human", anntype = "GO", keytype = "SYMBOL", ontology = "BP",
                      annotation_genes = 100L, richR = "0.1.5"),
    unavailable = "mapped_size"
  )
}

pm_record <- function(run_id, kind, inputs, outputs, settings) {
  list(schema = "richstudio.run_record", version = 1L, run_id = run_id, kind = kind, state = "succeeded",
       created = "2026-10-25T10:00:00Z", queued_at = "2026-10-25T10:00:00Z",
       started = "2026-10-25T10:00:01Z", ended = "2026-10-25T10:00:09Z", settings = settings,
       inputs = inputs, outputs = outputs, retry_of = NA_character_, imported_from = NA_character_,
       note = NA_character_, error_summary = NA_character_)
}

pm_records <- function() {
  enrich <- pm_record("0123456789ab", "enrichment",
    list(list(store = "deg", label = "deg_a", revision = 2L)), "deg_a_enriched",
    list(species = "human", anntype = "GO", keytype = "SYMBOL", ontology = "BP", cutoff = 0.05,
         background = "annotation universe",
         query = list(list(name = "deg_a", query_rule = "annotated genes", n_submitted = 3L,
                           revision_digest = "feed"))))
  cluster <- pm_record("ba9876543210", "clustering",
    list(list(store = "rr", label = "deg_a_enriched", revision = 0L)), "clus1",
    list(method = "hierarchical", params = list(cutoff = 0.5), cluster_name = "clus1",
         selected = list("deg_a_enriched")))
  richStudio:::workspace_run_records_parse(richStudio:::workspace_run_records_json(list(enrich, cluster)))
}

pm_session <- function() {
  deg <- data.frame(gene = c("g1", "g2", "g3"), logFC = c(1.5, -2, NaN), Padj = c(0.01, NA, 0.5),
                    stringsAsFactors = FALSE)
  rr <- data.frame(Term = c("GO:1", "GO:2", "GO:3"), Annot = c("alpha", "beta", "gamma"),
                   GeneID = c("g1,g2", "g2", "g3"), Pvalue = c(1e-8, 0.02, 1 / 3),
                   Padj = c(1e-6, NA, 0.9), stringsAsFactors = FALSE)
  attr(rr, "richstudio_background") <- pm_background("annotation")
  summary <- data.frame(Cluster = 1:2, Representative_Term = c("GO:1", "GO:3"),
                        Pvalue_a = c(1e-8, 1 / 3), Padj_a = c(1e-6, NA), stringsAsFactors = FALSE)
  detail <- data.frame(Term = c("GO:1", "GO:2", "GO:3"), Cluster = c(1L, 1L, 2L),
                       Representative_Term = c("GO:1", "GO:1", "GO:3"),
                       Pvalue_a = c(1e-8, 0.02, 1 / 3), Padj_a = c(1e-6, NA, 0.9), stringsAsFactors = FALSE)
  list(version = "1.0", degnames = "deg_a", degdfs = list(deg_a = deg),
       rrnames = "deg_a_enriched", rrdfs = list(deg_a_enriched = rr),
       clusnames = "clus1", clusdfs = list(clus1 = summary), cluslists = list(clus1 = detail))
}

pm_build <- function(session = pm_session(), records = pm_records()) {
  richStudio:::project_manifest_build(session, records, created = as.POSIXct("2026-10-25 12:00:00", tz = "UTC"),
                                      versions = list(richStudio = richStudio:::project_typed("9.9.9"),
                                                      engine = list(name = "richR", version = richStudio:::project_typed("0.1.5")),
                                                      R = "R test", format = "1.0"))
}

pm_write <- function(session = pm_session(), records = pm_records(), policy_loader = NULL) {
  path <- withr::local_tempfile(fileext = ".zip", .local_envir = parent.frame())
  args <- list(session, records, path)
  if (!is.null(policy_loader)) args$policy_loader <- policy_loader
  do.call(richStudio:::project_write, args)
  path
}

pm_json <- function(x) jsonlite::fromJSON(
  jsonlite::toJSON(x, auto_unbox = TRUE, digits = I(17), null = "null", na = "null"), simplifyVector = FALSE)

# ---- manifest content (REQ-001, AC-001) ---------------------------------------------

test_that("the manifest is versioned and every entity gets a stable generated ID", {
  a <- pm_build()$manifest
  b <- pm_build()$manifest
  expect_identical(a$schema, "richstudio.project")
  expect_identical(a$format_version, "1.0")
  expect_identical(a, b)
  ids <- c(a$datasets[[1]]$id, a$results[[1]]$id, a$clusters[[1]]$id)
  expect_match(ids, "^(ds|rs|cl)-[0-9a-f]{12}$")
  expect_false(anyDuplicated(ids) > 0)
  expect_match(vapply(a$results[[1]]$term_ids, identity, ""), "^tm-[0-9a-f]{12}$")
  expect_identical(a$results[[1]]$term_ids[[1]], richStudio:::project_short_id("tm", "GO:1"))
  expect_match(a$clusters[[1]]$clusters[[1]]$id, "^cn-[0-9a-f]{12}$")

  changed <- pm_session()
  changed$degdfs$deg_a$logFC[1] <- 1.6
  expect_false(identical(pm_build(changed)$manifest$datasets[[1]]$id, a$datasets[[1]]$id))
})

test_that("an enrichment result records parameters, annotation identity, background and statistics", {
  r <- pm_build()$manifest$results[[1]]
  expect_identical(r$run_id, list(status = "recorded", value = "0123456789ab"))
  expect_identical(r$species$value, "human")
  expect_identical(r$annotation_type$value, "GO")
  expect_identical(r$keytype$value, "SYMBOL")
  expect_identical(r$ontology$value, "BP")
  expect_identical(r$parameters$status, "recorded")
  expect_identical(r$parameters$value$cutoff, 0.05)
  expect_identical(r$background$status, "recorded")
  expect_identical(r$background$value$mode, "annotation")
  expect_identical(r$background$value$unique_count, 30L)
  expect_identical(r$background$value$annotation$richR, "0.1.5")
  # Provider/release/build/digest are not reported by the engine and are never inferred.
  expect_identical(r$annotation_provenance$status, "not_recorded")
  expect_identical(r$statistics$raw_p$column, "Pvalue")
  expect_identical(r$statistics$adjusted_p$column, "Padj")
  expect_identical(r$statistics$correction_method$status, "not_recorded")
  expect_identical(r$statistics$correction_family$status, "recorded")
})

test_that("typed absence separates not_recorded, not_supplied, not_tested and not_significant", {
  m <- pm_build()$manifest
  bg <- m$results[[1]]$background$value
  # An annotation-universe run supplied no custom background; the engine did not report mapped_size.
  expect_identical(bg$background_digest, list(status = "not_supplied"))
  expect_identical(bg$submitted_count, list(status = "not_supplied"))
  expect_identical(bg$mapped_size, list(status = "not_recorded"))
  # NA adjusted p-values were not tested; they are counted, never written as zero.
  expect_identical(m$results[[1]]$statistics$adjusted_p$n_missing, 1L)
  expect_identical(m$results[[1]]$statistics$adjusted_p$missing_type, "not_tested")
  expect_identical(m$clusters[[1]]$statistics$per_dataset[[2]],
                   list(column = "Padj_a", n_missing = 1L, missing_type = "not_significant"))
  expect_true(all(c("not_recorded", "not_supplied", "not_tested", "not_significant") %in%
                    unlist(m$absence_types)))
})

test_that("a legacy-shaped session (no run records, no background) is marked not recorded, not guessed", {
  session <- pm_session()
  attr(session$rrdfs$deg_a_enriched, "richstudio_background") <- NULL
  m <- pm_build(session, list())$manifest
  r <- m$results[[1]]
  for (field in c("run_id", "species", "keytype", "annotation_type", "ontology", "parameters", "background")) {
    expect_identical(r[[field]]$status, "not_recorded", info = field)
  }
  expect_identical(r$statistics$correction_family$status, "not_recorded")
  expect_identical(m$clusters[[1]]$method$status, "not_recorded")
  expect_identical(m$clusters[[1]]$parameters$status, "not_recorded")
  expect_length(m$relationships, 0L)
  expect_length(m$runs, 0L)
  # The data themselves are unchanged and no value was invented.
  written <- jsonlite::toJSON(m, auto_unbox = TRUE, null = "null")
  expect_false(grepl("human", written, fixed = TRUE))
})

test_that("relationships link datasets, results, clusters and runs", {
  m <- pm_build()$manifest
  rel <- function(type, from, to) any(vapply(m$relationships, function(r)
    identical(r$type, type) && identical(r$from, from) && identical(r$to, to), logical(1)))
  ds <- m$datasets[[1]]$id
  rs <- m$results[[1]]$id
  cl <- m$clusters[[1]]$id
  expect_true(rel("input_of", ds, rs))
  expect_true(rel("input_of", rs, cl))
  expect_true(rel("produced_by", rs, "0123456789ab"))
  expect_true(rel("produced_by", cl, "ba9876543210"))
  input <- Filter(function(r) identical(r$type, "input_of") && identical(r$to, rs), m$relationships)[[1]]
  expect_identical(input$input_revision, 2L)
  expect_identical(m$clusters[[1]]$method$value, "hierarchical")
  expect_identical(m$clusters[[1]]$parameters$value$cutoff, 0.5)
  expect_length(m$runs, 2L)
})

test_that("software versions and table descriptions are recorded", {
  m <- pm_build()$manifest
  expect_identical(m$software$richStudio$value, "9.9.9")
  expect_identical(m$software$engine$name, "richR")
  live <- richStudio:::project_versions()
  expect_identical(live$engine$name, "richR")
  expect_match(live$R, "^R version")
  d <- m$datasets[[1]]
  expect_identical(d$nrow, 3L)
  expect_identical(d$ncol, 3L)
  expect_identical(vapply(d$columns, function(c) c$name, ""), c("gene", "logFC", "Padj"))
  expect_identical(d$origin$status, "not_recorded")
  expect_identical(d$source_digest$value, richStudio:::project_table_digest(pm_session()$degdfs$deg_a))
})

# ---- the table digest ---------------------------------------------------------------

test_that("the table digest changes with any value, class, level, name or row order", {
  base <- data.frame(a = c(1, NA, 3), b = c("x", NA, "NA"), stringsAsFactors = FALSE)
  d <- richStudio:::project_table_digest
  expect_identical(d(base), d(base))
  variants <- list(
    {x <- base; x$a[1] <- 1 + 1e-15; x}, {x <- base; x$a[2] <- 0; x}, {x <- base; x$b[2] <- "NA"; x},
    {x <- base; x$b <- factor(x$b); x}, {x <- base; names(x)[1] <- "z"; x}, base[3:1, ],
    {x <- base; x$a <- as.integer(x$a); x}, base[1:2, ])
  digests <- vapply(variants, d, "")
  expect_false(anyDuplicated(c(d(base), digests)) > 0)
  expect_identical(d(base[FALSE, ]), d(base[FALSE, ]))
})

# ---- writer and round trip (AC-001) -------------------------------------------------

test_that("a saved project contains only the three generated members and verifiable digests", {
  path <- pm_write()
  listed <- zip::zip_list(path)
  expect_setequal(listed$filename, c("manifest.json", "tables.json", "methods.md"))
  expect_true(all(listed$type == "file"))
  dir <- withr::local_tempdir()
  zip::unzip(path, exdir = dir)
  manifest <- jsonlite::read_json(file.path(dir, "manifest.json"))
  for (f in manifest$files) {
    expect_identical(f$sha256, digest::digest(file.path(dir, f$name), algo = "sha256", file = TRUE))
    expect_equal(f$bytes, file.size(file.path(dir, f$name)))
  }
  expect_identical(manifest$format_version, "1.0")
  expect_identical(manifest$schema, "richstudio.project")
})

test_that("AC-001 a project round-trips tables, IDs, relationships, settings and typed missingness exactly", {
  session <- pm_session()
  session$degdfs$deg_a$logFC <- c(1.5, -Inf, NaN)
  path <- pm_write(session)
  candidate <- richStudio:::project_import_read(path)

  expect_identical(candidate$degnames, "deg_a")
  expect_identical(candidate$rrnames, "deg_a_enriched")
  expect_identical(candidate$clusnames, "clus1")
  expect_identical(candidate$degdfs, session$degdfs)
  expect_identical(candidate$rrdfs, session$rrdfs)
  expect_identical(candidate$clusdfs, session$clusdfs)
  expect_identical(candidate$cluslists, session$cluslists)
  expect_identical(attr(candidate$rrdfs$deg_a_enriched, "richstudio_background"), pm_background("annotation"))
  expect_identical(candidate$rrdfs$deg_a_enriched$Padj, c(1e-6, NA, 0.9))
  expect_identical(candidate$rrdfs$deg_a_enriched$Pvalue[3], 1 / 3)
  expect_identical(richStudio:::workspace_run_records_parse(candidate$run_records_json), pm_records())

  # IDs, relationships and absences survive: rebuilding the manifest from the opened
  # candidate yields the same manifest as the one that was saved.
  again <- richStudio:::project_manifest_build(
    candidate, richStudio:::workspace_run_records_parse(candidate$run_records_json),
    created = as.POSIXct(candidate$manifest$created, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    versions = candidate$manifest$software)
  strip <- function(m) { m$files <- NULL; m$software <- NULL; m }
  expect_equal(strip(pm_json(again$manifest)), strip(candidate$manifest))
})

test_that("a project of zero results round-trips", {
  empty <- list(version = "1.0", degnames = character(), degdfs = list(), rrnames = character(),
                rrdfs = list(), clusnames = character(), clusdfs = list(), cluslists = list())
  candidate <- richStudio:::project_import_read(pm_write(empty, list()))
  expect_identical(candidate$degnames, character())
  expect_length(candidate$rrdfs, 0L)
  expect_length(candidate$cluslists, 0L)
})

test_that("serialization property cases: NaN/NA/empty tables, Unicode and numeric labels, duplicates", {
  # Row names travel through the shared session_json schema: automatic ones stay automatic.
  fresh <- function(x) { rownames(x) <- NULL; x }
  base <- data.frame(id = c("a", NA, "caf\u00e9 \u03b1", "", "a"), v = c(NaN, Inf, -Inf, NA, 0),
                     n = c(1L, NA, 3L, 4L, 5L), ok = c(TRUE, NA, FALSE, TRUE, TRUE),
                     f = factor(c("b", "a", "b", NA, "a"), levels = c("b", "a", "unused")),
                     stringsAsFactors = FALSE)
  session <- list(version = "1.0",
    degnames = c("1", "2", "caf\u00e9", "empty"),
    degdfs = stats::setNames(list(base, base[FALSE, ], fresh(base[1, , drop = FALSE]), base[FALSE, 0]),
                             c("1", "2", "caf\u00e9", "empty")),
    rrnames = character(), rrdfs = list(), clusnames = character(), clusdfs = list(), cluslists = list())
  candidate <- richStudio:::project_import_read(pm_write(session, list()))
  expect_identical(candidate$degnames, session$degnames)
  for (nm in names(session$degdfs)) expect_identical(candidate$degdfs[[nm]], session$degdfs[[nm]], info = nm)
  # Two tables with identical content under different labels keep separate IDs.
  twin <- session
  twin$degnames <- c("p", "q")
  twin$degdfs <- list(p = base, q = base)
  ids <- vapply(pm_build(twin, list())$manifest$datasets, function(d) d$id, "")
  expect_false(anyDuplicated(ids) > 0)
})

test_that("a label without a table in the stores is kept as unlisted data, not dropped", {
  session <- pm_session()
  session$degdfs$extra <- data.frame(x = 1)
  candidate <- richStudio:::project_import_read(pm_write(session))
  expect_identical(candidate$degnames, "deg_a")
  expect_identical(names(candidate$degdfs), c("deg_a", "extra"))
})

# ---- resource limits on save --------------------------------------------------------

test_that("saving enforces the installed resource policy and is blocked without one", {
  policy <- richStudio:::workspace_resource_policy()
  tight <- policy
  tight$limits$rows <- 2L
  expect_error(pm_write(policy_loader = function() tight), "has 3 rows; the limit is 2")
  tight <- policy
  tight$limits$columns <- 2L
  expect_error(pm_write(policy_loader = function() tight), "columns; the limit is 2")
  expect_error(pm_write(policy_loader = function() stop("gone")), "resource policy missing or invalid")
  expect_error(pm_write(policy_loader = function() list()), "resource policy missing or invalid")
})

# ---- AC-005: safe paths, escaped text, spreadsheet safety ---------------------------

test_that("AC-005 hostile labels never reach archive paths and are escaped in methods text", {
  hostile <- c("../../evil/x", "<script>alert(1)</script>", "=HYPERLINK(\"http://x\")", "a/b\\c", "'; DROP")
  session <- pm_session()
  session$degnames <- hostile
  session$degdfs <- stats::setNames(rep(list(session$degdfs$deg_a), length(hostile)), hostile)
  session$rrnames <- character()
  session$rrdfs <- list()
  session$clusnames <- character()
  session$clusdfs <- list()
  session$cluslists <- list()
  path <- pm_write(session, list())
  expect_setequal(zip::zip_list(path)$filename, c("manifest.json", "tables.json", "methods.md"))
  dir <- withr::local_tempdir()
  zip::unzip(path, exdir = dir)
  expect_setequal(list.files(dir, recursive = TRUE), c("manifest.json", "tables.json", "methods.md"))
  methods <- paste(readLines(file.path(dir, "methods.md"), encoding = "UTF-8"), collapse = "\n")
  expect_false(grepl("<script>", methods, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;alert(1)&lt;/script&gt;", methods, fixed = TRUE))
  expect_false(grepl("\"http://x\"", methods, fixed = TRUE))
  # Exact labels are kept verbatim in the manifest (data), only generated IDs name files.
  manifest <- jsonlite::read_json(file.path(dir, "manifest.json"))
  expect_setequal(vapply(manifest$datasets, function(d) d$label, ""), hostile)
  expect_identical(richStudio:::project_html_escape("a&b<c>\"d'\n"), "a&amp;b&lt;c&gt;&quot;d&#39; ")
})

test_that("AC-005 spreadsheet-safe export is distinct from exact-value tables", {
  df <- data.frame(gene = c("=1+1", "+cmd", "-2", "@SUM(A1)", "\tx", "plain", NA), v = c(-1, 2, 3, 4, 5, 6, 7),
                   stringsAsFactors = FALSE)
  names(df)[2] <- "=bad"
  safe <- richStudio:::project_spreadsheet_safe(df)
  expect_identical(safe$gene, c("'=1+1", "'+cmd", "'-2", "'@SUM(A1)", "'\tx", "plain", NA))
  expect_identical(names(safe), c("gene", "'=bad"))
  expect_identical(safe[[2]], df[[2]])
  readable <- withr::local_tempfile(fileext = ".csv")
  exact <- withr::local_tempfile(fileext = ".csv")
  richStudio:::project_export_csv(df, readable, spreadsheet_safe = TRUE)
  richStudio:::project_export_csv(df, exact, spreadsheet_safe = FALSE)
  expect_true(any(grepl("^\"'=1\\+1\"", readLines(readable))))
  expect_true(any(grepl("^\"=1\\+1\"", readLines(exact))))
  # Project tables are always exact: the formula-like string round-trips unchanged.
  session <- pm_session()
  session$degdfs$deg_a$gene <- c("=1+1", "+cmd", "plain")
  expect_identical(richStudio:::project_import_read(pm_write(session))$degdfs$deg_a$gene,
                   c("=1+1", "+cmd", "plain"))
})

# ---- REQ-006: methods text ----------------------------------------------------------

test_that("REQ-006 methods text separates recorded facts, display labels and unavailable provenance", {
  text <- richStudio:::project_methods_text(pm_build()$manifest)
  expect_match(text, "## Recorded facts", fixed = TRUE)
  expect_match(text, "## Display labels", fixed = TRUE)
  expect_match(text, "## Unavailable provenance", fixed = TRUE)
  sections <- strsplit(text, "## ", fixed = TRUE)[[1]]
  facts <- sections[grepl("^Recorded facts", sections)]
  display <- sections[grepl("^Display labels", sections)]
  unavailable <- sections[grepl("^Unavailable provenance", sections)]
  expect_match(facts, "annotation GO, species human, key type SYMBOL, ontology BP", fixed = TRUE)
  expect_match(facts, "background mode annotation", fixed = TRUE)
  expect_match(facts, "method hierarchical", fixed = TRUE)
  expect_match(facts, "richR 0.1.5", fixed = TRUE)
  expect_match(facts, "1 adjusted p-value(s) were not tested and are stored as missing, not as zero", fixed = TRUE)
  expect_match(display, "deg_a_enriched", fixed = TRUE)
  expect_match(unavailable, "annotation provider, release, build and digest", fixed = TRUE)
  expect_match(unavailable, "multiple-testing correction method", fixed = TRUE)

  session <- pm_session()
  attr(session$rrdfs$deg_a_enriched, "richstudio_background") <- NULL
  bare <- richStudio:::project_methods_text(pm_build(session, list())$manifest)
  expect_match(bare, "Enrichment deg_a_enriched: run parameters.", fixed = TRUE)
  expect_match(bare, "Enrichment deg_a_enriched: background identity.", fixed = TRUE)
  expect_false(grepl("species human", bare, fixed = TRUE))
})
