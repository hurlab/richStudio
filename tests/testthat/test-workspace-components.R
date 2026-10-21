test_that("native actions escape labels and namespace local IDs exactly once", {
  action <- getFromNamespace("workspace_action", "richStudio")
  for (prefix in c("alpha", "beta")) {
    node <- action(prefix, "open", "<img src=x onerror=alert(1)>")
    expect_identical(node$name, "button")
    expect_identical(node$attribs$id, paste0(prefix, "-open"))
    expect_identical(node$attribs$type, "button")
    expect_match(as.character(node), "&lt;img", fixed = TRUE)
    expect_false(grepl("<img", as.character(node), fixed = TRUE))
  }
  expect_error(action("a", "go", "Go", available = FALSE), "reason")
  unavailable <- as.character(action("a", "go", "Go", FALSE, "No recorded input"))
  expect_match(unavailable, "disabled")
  expect_match(unavailable, "No recorded input", fixed = TRUE)
  expect_match(unavailable, "aria-describedby=\"a-go-reason\"", fixed = TRUE)
})

test_that("actions keep sanitized text inside the native updateable label child", {
  action <- getFromNamespace("workspace_action", "richStudio")
  payload <- htmltools::HTML("<img src=x onerror=alert(1)>")
  for (available in c(TRUE, FALSE)) {
    node <- action("alpha", "open", payload, available,
      htmltools::HTML("<script>Unavailable</script>"))
    button <- if (available) node else node$children[[1]]
    labels <- Filter(function(child) inherits(child, "shiny.tag") &&
      identical(child$attribs$class, "action-label"), button$children)
    expect_length(labels, 1L)
    expect_identical(button$attribs$id, "alpha-open")
    expect_match(button$attribs$class, "action-button", fixed = TRUE)
    expect_match(as.character(button), "&lt;img", fixed = TRUE)
    expect_false(grepl("<img", as.character(button), fixed = TRUE))
    # No initial label text can remain outside Shiny's replacement container.
    outside <- Filter(function(child) !inherits(child, "shiny.tag"), button$children)
    expect_false(any(grepl("<img", unlist(outside), fixed = TRUE)))
    if (length(labels) == 1L) {
      expect_identical(labels[[1]]$children[[1]], as.character(payload))
      expect_false(inherits(labels[[1]]$children[[1]], "html"))
    }
    if (!available) {
      expect_match(as.character(node), "&lt;script&gt;Unavailable", fixed = TRUE)
      expect_false(grepl("<script>", as.character(node), fixed = TRUE))
      expect_match(as.character(node), 'aria-describedby="alpha-open-reason"', fixed = TRUE)
    }
  }
})

test_that("review facts retain unknown metadata and distinguish edit categories", {
  card <- getFromNamespace("workspace_card", "richStudio")
  facts <- list("Organism" = NA_character_, "Membership" = "Not supplied",
    "Exact source value" = "1e-300", "Provider" = "<script>bad()</script>")
  for (kind in c("Setup draft", "Captured run settings", "Display filter",
                 "Committed input revision", "Unsaved project changes")) {
    html <- as.character(card("a", "review", "Scientific review", facts, kind))
    expect_match(html, kind, fixed = TRUE)
    expect_match(html, "Not recorded", fixed = TRUE)
    expect_match(html, "Not supplied", fixed = TRUE)
    expect_match(html, "1e-300", fixed = TRUE)
    expect_false(grepl("<script>", html, fixed = TRUE))
  }
  expect_error(card("a", "x", "Review", list("x"), "draft"), "named")
})

test_that("field diagnostics link visible label help and retained invalid input", {
  field <- getFromNamespace("workspace_field", "richStudio")
  html <- as.character(field("a", "name", "New name", "<img>", "Display label only", "Name conflicts"))
  for (value in c('for="a-name"', 'id="a-name-help"', 'id="a-name-error"',
    'aria-describedby="a-name-help a-name-error"', 'aria-invalid="true"',
    'value="&lt;img&gt;"', 'New name', 'Name conflicts')) expect_match(html, value, fixed = TRUE)
})

test_that("lifecycle text stays truthful and never fabricates measured progress", {
  status <- getFromNamespace("workspace_status", "richStudio")
  for (state in c("queued", "running", "failed", "succeeded", "stop-requested",
                   "cancelled", "detached", "interrupted")) {
    node <- status("a", "job", state)
    expect_match(as.character(node), "rs-workspace-status", fixed = TRUE)
    expect_identical(node$attribs$role, if (state == "failed") "alert" else "status")
    expect_null(node$attribs[["aria-busy"]])
    expect_false(grepl("progressbar", as.character(node), fixed = TRUE))
  }
  expect_match(as.character(status("a", "x", "running")), "Running — progress not reported", fixed = TRUE)
  expect_match(as.character(status("a", "x", "detached")), "computation may continue", fixed = TRUE)
  expect_error(status("a", "x", "invented"), "arg")
})

test_that("table regions retain semantic headers and labeled contained overflow", {
  region <- getFromNamespace("workspace_table", "richStudio")
  node <- region("a", "results", "Imported results", data.frame(Term = "<img>", Value = "Not supplied"))
  html <- as.character(node)
  for (value in c('<caption>Imported results</caption>', '<th scope="col">Term</th>',
    'role="region"', 'tabindex="0"', 'aria-labelledby="a-results-heading"',
    'Scroll horizontally to view all columns', '&lt;img&gt;', 'Not supplied')) expect_match(html, value, fixed = TRUE)
})

test_that("dataset cues expose stable supplied code symbol and full identity", {
  cue <- getFromNamespace("workspace_dataset_cue", "richStudio")
  html <- as.character(cue("D-A", "Same label <img>", "ds-a", "circle"))
  for (value in c("D-A", "Same label &lt;img&gt;", "ds-a", "●")) expect_match(html, value, fixed = TRUE)
  expect_error(cue("D-A", "Name", "ds-a", "unknown"), "arg")
})

test_that("named confirmation uses safe cancel first and native dialog semantics", {
  dialog <- getFromNamespace("workspace_confirmation", "richStudio")
  node <- dialog("a", "remove", "Remove named items", c("ds-a <img>"), "Remove these named items")
  expect_identical(node$name, "dialog")
  html <- as.character(node)
  for (value in c('aria-labelledby="a-remove-heading"', 'autofocus', 'Cancel',
    'Remove these named items', 'ds-a &lt;img&gt;')) expect_match(html, value, fixed = TRUE)
  expect_lt(regexpr("Cancel", html)[1], regexpr("Remove these named items", html)[1])
  expect_error(dialog("a", "x", "Remove", character(), "Remove"), "targets")
})

test_that("original CSS bytes precede additive scoped workspace rules", {
  css <- readBin(system.file("application/www/custom.css", package = "richStudio"), "raw", n = 1e7)
  text <- rawToChar(css)
  marker <- "/* Workspace presentation primitives (SPEC-WS-002). */"
  original <- strsplit(text, marker, fixed = TRUE)[[1]][1]
  file <- tempfile()
  on.exit(unlink(file), add = TRUE)
  writeBin(charToRaw(original), file)
  expect_identical(unname(tools::md5sum(file)), "3dc7da1312126fb3a028db075e1c0e60")
  expect_match(text, ".rs-workspace", fixed = TRUE)
  expect_match(text, "prefers-reduced-motion: reduce", fixed = TRUE)
})

test_that("workspace sizing resolves frozen design values against native Bootstrap", {
  # Static declaration arithmetic only; computed browser sizing is a separate gate.
  native <- readChar(system.file("www/shared/bootstrap/css/bootstrap.css", package = "shiny"), 1e7)
  text <- readChar(system.file("application/www/custom.css", package = "richStudio"), 1e7)
  css <- strsplit(text, "/* Workspace presentation primitives (SPEC-WS-002). */", fixed = TRUE)[[1]][2]
  declaration <- function(source, selector, property) {
    blocks <- strsplit(source, paste0(selector, " {"), fixed = TRUE)[[1]][-1]
    entries <- unlist(lapply(blocks, function(block) {
      block <- strsplit(block, "}", fixed = TRUE)[[1]][1]
      trimws(strsplit(block, ";", fixed = TRUE)[[1]])
    }), use.names = FALSE)
    value <- entries[startsWith(entries, paste0(property, ":"))]
    if (!length(value)) return(NA_character_)
    trimws(substring(tail(value, 1L), nchar(property) + 2L))
  }
  pixels <- function(value, root) {
    units <- strsplit(trimws(value), "[[:space:]]+")[[1]]
    vapply(units, function(unit) {
      if (is.na(unit) || !grepl("^[0-9]*[.]?[0-9]+(px|rem)$", unit)) return(NA_real_)
      as.numeric(sub("(px|rem)$", "", unit)) * if (endsWith(unit, "rem")) root else 1
    }, numeric(1), USE.NAMES = FALSE)
  }
  root <- pixels(declaration(native, "html", "font-size"), 1)
  expect_equal(root, 10)
  size <- function(selector, property) pixels(declaration(css, selector, property), root)
  expect_equal(size(".rs-workspace", "font-size"), 14)
  expect_equal(size(".rs-workspace h3", "font-size"), 16)
  expect_equal(size(".rs-workspace table", "font-size"), 13)
  # Inputs inherit the scoped body size. Helpers get their own secondary size.
  expect_identical(declaration(css, ".rs-workspace-field .form-control", "font"), "inherit")
  expect_equal(size(".rs-workspace-field p", "font-size"), 13)
  expect_equal(size(".rs-workspace-card", "padding"), 16)
  expect_equal(size(".rs-workspace-card", "margin-bottom"), 20)
  expect_equal(size(".rs-workspace-field label", "margin-bottom"), 4)
  expect_equal(size(".rs-workspace-field", "margin-bottom"), 12)
  expect_equal(size(".rs-workspace-action-group, .rs-workspace-actions", "gap"), 8)
  expect_false(grepl("(^|[}\\n])\\s*html\\s*\\{", css))
})
