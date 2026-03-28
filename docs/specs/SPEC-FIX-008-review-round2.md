# SPEC-FIX-008: Second Review Round Fixes

## Overview
Second comprehensive codebase review identifying and fixing issues missed in initial rounds.

## Date
2026-03-10

## Issues Found and Fixed

### A1: Missing `digest` dependency in DESCRIPTION
- **Severity**: HIGH
- **File**: DESCRIPTION
- **Issue**: `digest::digest()` used in app.R:156 but `digest` not listed in Imports
- **Fix**: Added `digest` to DESCRIPTION Imports section
- **Impact**: Would fail at runtime if digest not installed as transitive dependency

### A2: `library(knitr)` in package code
- **Severity**: LOW
- **File**: R/round_table.R:2
- **Issue**: Using `library()` inside a package source file is bad practice
- **Fix**: Removed `library(knitr)` call (knitr already in Suggests)

### A3: Missing `slice_head` import
- **Severity**: MEDIUM
- **File**: R/rr_hmap.R:124, R/package.R
- **Issue**: `slice_head()` used without importFrom declaration in NAMESPACE
- **Fix**: Added `slice_head` to `@importFrom dplyr` in package.R, regenerated NAMESPACE

### B1: NULL dereference in enrichment async handler
- **Severity**: HIGH
- **File**: R/enrich_tab.R:378-382
- **Issue**: `u_big_degdf[['df']]` accessed without NULL guard before subsetting by column
- **Fix**: Added `req(u_big_degdf[['df']])` before the lapply that reads big_df

### B2: Division by zero in visualization functions
- **Severity**: HIGH
- **File**: R/rr_bar.R:39, R/rr_dot.R:37
- **Issue**: `Significant/Annotated` divides without checking if Annotated is zero
- **Fix**: Replace zero values with NA before division to produce NA instead of Inf

### B3: Ineffective session cleanup
- **Severity**: MEDIUM
- **File**: inst/application/app.R:160-167
- **Issue**: `onSessionEnded` callback assigned NULL to local variables, not reactive objects
- **Fix**: Iterate over each reactiveValues store and NULL out entries properly

### B4: Unused `dataTableProxy()` variables
- **Severity**: LOW
- **Files**: R/cluster_upload_tab.R:253,344; R/enrich_tab.R:280,472; R/clus_visualize_tab.R:142; R/rr_visualize_tab.R:327,475
- **Issue**: 7 proxy variables created but never used (no replaceData/selectRows calls)
- **Fix**: Removed all 7 unused proxy assignments

### B5: Missing default branch for invalid `view` parameter
- **Severity**: LOW
- **File**: R/rr_bar.R
- **Issue**: If `view` is neither "rich" nor "value", function returns NULL silently
- **Fix**: Added else clause that throws informative error

### B6: Dead test file
- **Severity**: LOW
- **File**: tests/testthat/compare_david_clustering.R
- **Issue**: Contains `test_david()` function that is never called, not integrated into test suite
- **Fix**: Removed file

## Verification
- All 21 R files parse successfully
- NAMESPACE regenerated via roxygen2 (added slice_head import)
- 152 unit tests pass (0 failures, 0 warnings)
- renv.lock already up to date

## Summary
| Severity | Fixed |
|----------|-------|
| HIGH     | 3     |
| MEDIUM   | 2     |
| LOW      | 4     |
| Total    | 9     |
