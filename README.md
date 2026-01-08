# richStudio

R Shiny application for integrative functional enrichment analysis and visualization of multiple gene datasets.

## Features

- **Enrichment Analysis**: Perform functional enrichment using GO, KEGG, and Reactome databases
- **Multiple Clustering Methods**: Choose from richR (Kappa), Hierarchical, or DAVID-style clustering
- **Interactive Visualization**: Bar plots, dot plots, heatmaps, and network graphs
- **Session Save/Load**: Save your analysis state and reload it later
- **Multiple Species Support**: 20+ supported organisms

## Installation

### Quick Start

```R
# Install dependencies
source("install_dependencies.R")
install_all_dependencies()

# Or if you have the richCluster tarball locally:
install_all_dependencies("../richCluster_1.0.1.tar.gz")

# Load and run
devtools::load_all()
richStudio::launch_richStudio()
```

### Using renv (Recommended for reproducibility)

```R
renv::restore()
devtools::load_all()
richStudio::launch_richStudio()
```

### Manual Installation

```R
# CRAN packages (including richCluster)
install.packages(c("shiny", "shinydashboard", "shinyjs", "shinyWidgets",
                   "shinyjqui", "dplyr", "tidyverse", "ggplot2", "plotly",
                   "heatmaply", "DT", "jsonlite", "writexl", "zip", "richCluster"))

# Bioconductor packages (if needed)
BiocManager::install(c("AnnotationDbi", "org.Hs.eg.db"))

# GitHub packages
devtools::install_github("guokai8/richR")
devtools::install_github("guokai8/bioAnno")
```

## Usage

### Online Version

Visit: http://hurlab.med.und.edu:3838/richStudio

### Local Development

```R
# Load the package
devtools::load_all()

# Launch the application
richStudio::launch_richStudio()
```

### As RStudio Project

1. Open `richStudio.Rproj` in RStudio
2. Run `devtools::load_all()`
3. Run `richStudio::launch_richStudio()`

## Clustering Methods

richStudio v0.1.5 supports three clustering algorithms:

| Method | Description | Best For |
|--------|-------------|----------|
| **richR (Original)** | Kappa-based clustering using gene overlap | Quick clustering with simple parameters |
| **Hierarchical** | Flexible clustering with multiple linkage methods | Fine-tuned control over clustering behavior |
| **DAVID** | DAVID-style functional clustering | Compatibility with DAVID results |

### Hierarchical Clustering Options

- **Distance Metrics**: Kappa (Cohen's Kappa), Jaccard
- **Linkage Methods**: Single, Complete, Average, Ward

## App Overview

### Upload Files

Upload DEG sets or enrichment results in various formats:
- `.txt`, `.csv`, `.tsv` files
- Text input (gene lists)

### Enrichment

- Supported databases: GO, KEGG, Reactome
- Supported ontologies: BP (Biological Process), MF (Molecular Function), CC (Cellular Component)
- 20+ supported species

### Clustering

1. Select enrichment results to cluster
2. Choose clustering method and parameters
3. View intermediate results (distance matrix, seeds)
4. Export clustered results

### Visualization

- **Bar plots**: Enrichment significance
- **Dot plots**: Gene ratio visualization
- **Heatmaps**: Term-sample relationships
- **Network plots**: Term similarity networks
- **Cluster heatmaps**: Comprehensive and individual term views

### Save/Load Session

- Save analysis state as RDS or JSON
- Reload sessions to continue analysis
- Export individual results (CSV, TSV, Excel)
- Export all results as ZIP archive

## Project Structure

```
richStudio/
├── DESCRIPTION          # Package metadata
├── NAMESPACE            # Exported functions
├── R/                   # R source files
│   ├── rr_cluster.R     # Clustering functions
│   ├── cluster_tab.R    # Clustering UI/server
│   ├── enrich_tab.R     # Enrichment UI/server
│   ├── save_tab.R       # Save/load functionality
│   └── ...              # Other modules
├── inst/
│   ├── application/     # Shiny app entry point
│   │   └── app.R
│   └── extdata/         # Demo data
├── src/                 # C++ source (Rcpp)
├── tests/               # Unit tests
└── man/                 # Documentation
```

## Development

### Build Commands

```R
# Restore dependencies
renv::restore()

# Compile C++ and load package
Rcpp::compileAttributes()
devtools::load_all()

# Run tests
devtools::test()

# Generate documentation
devtools::document()

# Full check
devtools::check()
```

### Code Style

- tidyverse-style R (snake_case, `<-` assignment)
- 2-space indentation
- roxygen2 documentation for exported functions

## Authors

- **Junguk Hur** - Lead developer, maintainer (hurlabshared@gmail.com)
- **Sarah Hong** - Core development
- **Jane Kim** - Contributions

## License

GPL-3

## Links

- **Public Server**: http://hurlab.med.und.edu:3838/richStudio
- **Issues**: https://github.com/hurlab/richStudio/issues
- **richCluster Package**: https://github.com/hurlab/richCluster
