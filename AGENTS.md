# Repository Guidelines

## Project Structure & Module Organization
- `R/` stores Shiny modules, data handlers, and exported functions; document additions with roxygen2.
- `inst/application/app.R` is the Shiny entry point; keep the shell thin and delegate logic to `R/` modules.
- `inst/extdata/` provides sample DEG and enrichment files for manual checks; refresh when formats change.
- `src/` hosts the Rcpp clustering engine; update headers with sources and rebuild bindings before commits.
- `tests/testthat/` holds testthat 3e specs; follow `test-*.R` naming and wire helpers through `tests/testthat.R`.
- `renv/` and `renv.lock` define the reproducible environment; modify them only with `renv` workflows.

## Build, Test, and Development Commands
- `Rscript -e "renv::restore()"` — sync dependencies to `renv.lock`.
- `Rscript -e "Rcpp::compileAttributes(); devtools::load_all()"` — refresh bindings and load the package for iterative work.
- `Rscript -e "RichStudio::launch_RichStudio()"` — start the dashboard from the package build.
- `Rscript -e "devtools::test()"` — run the testthat suite after touching `R/` or `src/`.
- `Rscript -e "devtools::document(); devtools::check()"` — regenerate docs and perform full R CMD check pre-release.

## Coding Style & Naming Conventions
- Use tidyverse-flavored R style: two-space indents, `<-` for assignment, and `snake_case` for internals; reserve UpperCamelCase for exported functions.
- Annotate exports with roxygen2 tags (`@export`, parameters, return values) so `devtools::document()` stays authoritative.
- In `src/`, keep classes PascalCase, functions camelCase, and never commit compiled `.o`/`.so` artefacts.

## Testing Guidelines
- Mirror modules with `test_that()` specs in `tests/testthat/test-*.R`; place shared fixtures in helpers loaded via `tests/testthat.R`.
- Cover both R and C++ paths with small datasets from `inst/extdata/` to confirm clustering and enrichment behaviours.
- Add regression tests when fixing parsing, distance, or enrichment bugs to guard against future regressions.

## Commit & Pull Request Guidelines
- Write imperative commit subjects; Conventional Commit prefixes (`feat:`, `fix:`) are welcome, and unrelated work belongs in separate commits.
- Reference issues when relevant and call out dependency or schema updates in the body.
- PRs should list the change summary, tests or commands executed, and attach UI screenshots/GIFs when the dashboard changes.
- Run `devtools::test()` and `devtools::check()` before requesting review and include generated docs plus `NAMESPACE` updates.
