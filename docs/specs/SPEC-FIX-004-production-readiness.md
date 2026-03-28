# SPEC-FIX-004: Production Readiness Fixes

## Overview
Address multi-user concurrency and production deployment issues.

## Requirements

### REQ-1: Session-Isolated Temp Directories (CRIT-003)
**When** a user exports data,
**the system shall** use a unique temp directory per session (not shared `tempdir()`),
**so that** concurrent exports don't collide.

### REQ-2: Session Cleanup (CRIT-004)
**When** a user session ends,
**the system shall** explicitly free large data structures,
**so that** memory is reclaimed promptly.

### REQ-3: round_table.R Vectorization (HIGH-002)
**When** numeric values are rounded in data tables,
**the system shall** use vectorized operations instead of cell-by-cell loops,
**so that** large tables don't freeze the UI.

### REQ-4: Filename Sanitization (HIGH-004)
**When** generating download filenames from user input,
**the system shall** sanitize filenames to prevent path traversal,
**so that** security is maintained.

### REQ-5: Upload Size Validation (HIGH-005)
**When** a user uploads a file,
**the system shall** validate file size before processing,
**so that** oversized uploads don't crash the server.

### REQ-6: Temp File Cleanup (HIGH-006)
**When** export operations complete,
**the system shall** clean up temporary files,
**so that** disk space is not leaked.

## Files to Modify
- `R/save_tab.R`: tempdir isolation, temp file cleanup
- `inst/application/app.R`: session cleanup handler
- `R/round_table.R`: vectorize rounding
- `R/enrich_tab.R`: filename sanitization, upload size validation
- `R/cluster_upload_tab.R`: upload size validation
