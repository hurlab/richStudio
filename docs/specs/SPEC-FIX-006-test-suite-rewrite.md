# SPEC-FIX-006: Test Suite Rewrite

## Problem Statement

All existing tests (29 of 36) fail due to systemic issues:
1. `reactiveValues` accessed outside `isolate()` context - Shiny reactive values cannot be read outside reactive consumers
2. `source("../R/rr_cluster.R")` uses relative paths that don't resolve from test runner working directory
3. Functions like `add_file_clusdf` were not in NAMESPACE (now fixed via roxygen2)
4. `system.file("extdata", ...)` returns empty string unless package is installed or `devtools::load_all()` used

## Proposed Solution

Rewrite all test files to use proper R package testing patterns:

### Pattern 1: Use `isolate()` for reactive value access in tests
```r
# WRONG
rv$df  # Error: Can't access reactive value outside reactive consumer

# RIGHT
isolate(rv$df)  # Works in test context
```

### Pattern 2: Use `devtools::load_all()` or package functions instead of `source()`
```r
# WRONG
source("../R/rr_cluster.R")

# RIGHT - rely on testthat loading the package (via test runner or load_all)
# Functions are available through NAMESPACE exports
```

### Pattern 3: Create test fixtures directly instead of `system.file()`
```r
# WRONG (requires installed package)
read.delim(system.file("extdata", "go1.txt", package = "richStudio"))

# RIGHT - create fixture data inline or use testthat::test_path()
go1 <- data.frame(Term = c("GO:0001", "GO:0002"), GeneID = c("A/B", "C/D"), ...)
```

## Files to Modify

- `tests/testthat.R` - ensure it uses `devtools::load_all()` or `library(richStudio)`
- `tests/testthat/test-kappa.R` - fix system.file and source paths
- `tests/testthat/test-reactive-values.R` - wrap all reactiveValues access in isolate()
- `tests/testthat/test-file-management.R` - wrap reactive access, fix function loading
- `tests/testthat/test-upload-workflow.R` - wrap reactive access
- `tests/testthat/test-clustering-state.R` - fix source() path, wrap reactive access

## Acceptance Criteria

1. All tests pass when run via `Rscript -e "devtools::load_all(); testthat::test_dir('tests/testthat')"`
2. Zero warnings about reactive values accessed outside consumers
3. No `source()` calls with relative paths
4. No `system.file()` calls that depend on package installation
5. Tests cover: file management, reactive values, clustering state, upload workflows, kappa clustering

## Rollback Plan

Revert all test file changes via git checkout of the test files.
