# SPEC-FIX-003: Fix Visualization Function Bugs

## Overview
Fix missing return statements and logic errors in visualization functions.

## Requirements

### REQ-1: rr_dot.R Missing Return (CRIT-006a)
**When** a dot plot is generated,
**the system shall** return the plotly object,
**so that** the plot renders in the UI.

### REQ-2: rr_network.R Incomplete Function (CRIT-006b)
**When** a network plot weight matrix is computed,
**the system shall** return the computed result,
**so that** the network visualization renders.

### REQ-3: rr_bar.R Rename Syntax (HIGH-008)
**When** bar plot data is prepared,
**the system shall** use correct `dplyr::rename()` syntax,
**so that** the function does not error.

### REQ-4: rr_hmap.R Hover Text (HIGH-003)
**When** a heatmap displays hover information,
**the system shall** use the actual `value_type` parameter in hover text,
**so that** users see correct labels (Padj vs Pvalue).

### REQ-5: rr_column_handling.R Logic Error (CRIT-007)
**When** columns are matched for enrichment results,
**the system shall** correctly select matched columns from the dataframe,
**so that** column mapping is accurate.

## Files to Modify
- `R/rr_dot.R`: Add `return(p)`
- `R/rr_network.R`: Add return statement for weight matrix
- `R/rr_bar.R`: Fix `dplyr::rename()` call
- `R/rr_hmap.R`: Use `value_type` in hover text
- `R/rr_column_handling.R`: Fix line 78 column selection logic
