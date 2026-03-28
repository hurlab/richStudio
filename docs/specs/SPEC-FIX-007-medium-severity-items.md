# SPEC-FIX-007: Medium Severity Items

## Problem Statement

15 medium severity items identified in the code audit remain unaddressed. These represent code quality issues, potential bugs, and maintenance concerns.

## Items and Proposed Solutions

### MED-001: Inconsistent naming conventions across plot functions
- Files: rr_bar.R, rr_dot.R, rr_hmap.R, rr_network.R
- Issue: Mixed naming patterns (e.g., my_bar vs topterm_hmap)
- Fix: Document naming convention; refactoring names would break UI references, so add inline comments

### MED-002: suppressWarnings hiding legitimate warnings (round_table.R)
- File: R/round_table.R
- Issue: Blanket suppressWarnings may hide real issues
- Fix: Use tryCatch with specific warning classes or targeted suppression

### MED-003: Magic numbers in regex patterns (cluster_hmap.R)
- File: R/cluster_hmap.R
- Issue: Hardcoded regex patterns without named constants
- Fix: Extract regex patterns to named constants at module scope

### MED-004: Inefficient string matching in rr_column_handling.R
- File: R/rr_column_handling.R
- Issue: Repeated pattern matching that could be vectorized
- Fix: Use match() or %in% for simple lookups, pre-compile patterns

### MED-005: Missing empty dataframe validation in multiple handlers
- Files: Multiple UI handler files
- Issue: No check for nrow(df) == 0 before processing
- Fix: Add req(nrow(df) > 0) or early return guards

### MED-006: Redundant type coercion in enrich_tab.R
- File: R/enrich_tab.R
- Issue: Unnecessary as.numeric() or as.character() calls on already-typed data
- Fix: Remove redundant coercions after verifying types upstream

### MED-007: Silent NA creation in numeric conversions
- Files: Multiple files
- Issue: as.numeric() on non-numeric strings silently creates NA
- Fix: Add explicit NA checks or use type-safe conversion with warning

### MED-008: Mixed = and <- assignment style (rr_network.R)
- File: R/rr_network.R
- Issue: Inconsistent use of = and <- for assignment
- Fix: Standardize to <- for all assignments (R convention)

### MED-009: Missing namespace checks in enrich_tab.R
- File: R/enrich_tab.R
- Issue: Some functions called without package:: prefix
- Fix: Add explicit namespace prefixes for external package functions

### MED-010: Unreachable code paths in cluster_upload_tab.R
- File: R/cluster_upload_tab.R
- Issue: Dead code that can never execute
- Fix: Remove unreachable code paths

### MED-011: Intermediate results accumulate in clus_intermed
- File: R/cluster_tab.R
- Issue: clus_intermed reactive grows without cleanup
- Fix: Clear stale entries when new clustering replaces old

### MED-012: No file locking on session save/load
- File: R/save_tab.R
- Issue: Concurrent save/load could corrupt files
- Fix: Use base::lockfile() or check-and-lock pattern for RDS writes

### MED-013: Predictable session filenames
- File: R/save_tab.R
- Issue: Session files use predictable naming pattern
- Fix: Use digest::digest() with session ID for filenames (already partially addressed with session_id)

### MED-014: Sample data contention (read-only, minimal risk)
- Status: ACCEPTED - read-only access, no fix needed

### MED-015: Documentation incomplete in package.R
- File: R/package.R
- Issue: Missing or incomplete roxygen2 documentation
- Fix: Complete package-level documentation

## Acceptance Criteria

1. All R files parse successfully after changes
2. No blanket suppressWarnings() - all warning suppression is targeted
3. No magic numbers in regex patterns - all extracted to named constants
4. Empty dataframe guards on all handlers that process dataframes
5. Consistent <- assignment throughout
6. All dead code removed
7. clus_intermed cleanup implemented
8. package.R documentation complete

## Rollback Plan

Each item is independent - revert individual files as needed.
