# SPEC-FIX-002: Fix Remaining Clustering Bugs

## Overview
Fix DAVID and richR Kappa clustering paths for single enrichment result inputs, matching the fix already applied to hierarchical clustering.

## Requirements

### REQ-1: DAVID Single-Result Clustering (CRIT-001)
**When** a user clusters a single enrichment result using DAVID method,
**the system shall** bypass `richCluster::david_cluster()` for single inputs and handle clustering directly,
**so that** the result contains properly suffixed columns (`Pvalue_<gsname>`, `Padj_<gsname>`).

**Acceptance Criteria:**
- Single enrichment result clusters successfully with DAVID method
- Cluster summary table renders without error
- Comprehensive heatmap renders with correct column names
- Multi-result DAVID clustering continues to work unchanged

### REQ-2: richR Kappa Suffixed Columns (CRIT-002)
**When** a user clusters enrichment results using richR Kappa method,
**the system shall** ensure output contains geneset-suffixed columns (`Pvalue_<gsname>`, `Padj_<gsname>`),
**so that** downstream heatmap functions find the expected columns.

**Acceptance Criteria:**
- richR single-result clustering produces suffixed columns
- richR multi-result clustering continues to work
- Heatmap renders correctly for richR clustering results

## Files to Modify
- `R/rr_cluster.R`: `cluster_david()` and `cluster_richR()` functions

## Implementation Notes
- Follow the same pattern used in `cluster_hierarchical()` lines 374-453
- For DAVID single input: detect `length(enrichment_list) == 1`, bypass `david_cluster()`, call underlying function directly
- For richR: after clustering, add suffixed column copies if missing (like lines 442-453 in hierarchical path)
- The `add_geneset_columns()` function at line 603 may already handle this if called correctly; verify
