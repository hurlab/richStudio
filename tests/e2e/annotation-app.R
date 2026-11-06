# SPEC-WS-014 M2 e2e fixture app (test-only, not shipped).
#
# Installed richStudio only. Builds a throw-away annotation world under $ANN_WORLD (annotation library,
# local repository of two tiny source packages, fake downloader, test config), points the app's allowlist at
# it, and wires the existing `enrichment_runner` and `annotation_builder` parameters to stubs, so a fake
# `org.*` package never has to support a real buildAnnot. The downloader's behaviour is read per call from
# $ANN_WORLD/ctl/{mode,seconds}, which the spec writes.
library(shiny)
library(shinydashboard)
library(shinyjs)
library(shinyWidgets)
lib <- normalizePath(Sys.getenv("WORKSPACE_INSTALLED_LIBRARY"), mustWork = TRUE)
ns <- loadNamespace("richStudio", lib.loc = lib)
world <- normalizePath(Sys.getenv("ANN_WORLD"), mustWork = TRUE)
port <- as.integer(Sys.getenv("ANN_PORT", "3874"))

leaf <- getFromNamespace("annotation_lib_leaf", "richStudio")()
parent <- file.path(world, "annotation")
alib <- file.path(parent, leaf)
dir.create(alib, recursive = TRUE, mode = "0755")
Sys.chmod(c(parent, alib), "0755", use_umask = FALSE)
contrib <- file.path(world, "repo", "src", "contrib")
dir.create(contrib, recursive = TRUE)
dir.create(file.path(world, "ctl"), showWarnings = FALSE)
pkgs <- c("org.Fake1.eg.db", "org.Fake2.eg.db")
index <- character()
for (p in pkgs) {
  src <- file.path(world, "src", p)
  dir.create(file.path(src, "R"), recursive = TRUE)
  writeLines(c(paste0("Package: ", p), "Version: 1.0.0", "Title: Tiny fake annotation package",
               "Description: Tiny fake annotation package used only by e2e tests.", "License: GPL-2"), file.path(src, "DESCRIPTION"))
  writeLines("export(probe_ok)", file.path(src, "NAMESPACE"))
  writeLines("probe_ok <- function() TRUE", file.path(src, "R", "probe.R"))
  tar <- file.path(contrib, paste0(p, "_1.0.0.tar.gz"))
  system2("tar", c("-czf", shQuote(tar), "-C", shQuote(file.path(world, "src")), shQuote(p)))
  index <- c(index, paste0("Package: ", p), "Version: 1.0.0", paste0("MD5sum: ", unname(tools::md5sum(tar))), "")
}
writeLines(index, file.path(contrib, "PACKAGES"))
downloader <- file.path(world, "fake-downloader.sh")
writeLines(c(
  "#!/usr/bin/env bash",
  'out="" url="" i=0; args=("$@")',
  'while (( i < $# )); do a=${args[i]}; case $a in --output) out=${args[i+1]}; i=$((i+2)) ;; --max-time|--write-out|--proto|--proto-redir|--max-redirs) i=$((i+2)) ;; --*) i=$((i+1)) ;; *) url=$a; i=$((i+1)) ;; esac; done',
  'printf "%s %s %s\\n" "$(date +%s.%N)" "$$" "$url" >> "$ANN_WORLD/dl.log"',
  'mode=$(cat "$ANN_WORLD/ctl/mode" 2>/dev/null || echo ok); secs=$(cat "$ANN_WORLD/ctl/seconds" 2>/dev/null || echo 5)',
  'case $mode in slowtar) [[ $url == *.tar.gz ]] && sleep "$secs" ;; netfail) exit 7 ;; esac',
  'cp -- "${url#file://}" "$out" || exit 37',
  'printf "https://bioconductor.org/packages/3.23/data/annotation/src/contrib/%s" "$(basename "$url")"'),
  downloader)
Sys.chmod(downloader, "0755")
allow <- file.path(world, "allowlist.tsv")
writeLines(c("species\tpackage\tkind\tstatus\tpreinstall\test_mb\tinst_mb\treactome_supported\treason",
             "human\torg.Hs.eg.db\torganism\tavailable\tyes\t1\t1\tyes\t",
             "sp1\torg.Fake1.eg.db\torganism\tavailable\tno\t7\t1\tyes\t",
             "sp2\torg.Fake2.eg.db\torganism\tavailable\tno\t7\t1\tyes\t",
             "sco\tnone\torganism\tunavailable\tno\tn/a\tn/a\tno\tdropdown value has no richR species key",
             "*\treactome.db\treactome\tavailable\tno\t1\t1\tn/a\t"), allow)
# human counts as installed for the hint logic
dir.create(file.path(alib, "org.Hs.eg.db"))
writeLines(c("Package: org.Hs.eg.db", "Version: 1.0.0"), file.path(alib, "org.Hs.eg.db", "DESCRIPTION"))
cfg <- file.path(world, "test.cfg")
writeLines(c(paste0("repo: file://", file.path(world, "repo")), paste0("allowlist: ", allow),
             paste0("downloader: ", downloader), "probe: stub", "limit_download: 60"), cfg)
Sys.setenv(RICHSTUDIO_ANNOTATION_LIB = alib, RICHSTUDIO_ANNOTATION_TEST_MODE = "1", RICHSTUDIO_ANNOTATION_TEST_CONFIG = cfg,
           RICHSTUDIO_RSCRIPT = file.path(R.home("bin"), "Rscript"))
# The fixture points the app's allowlist at the world (the production path is the shipped file).
local({
  nsenv <- asNamespace("richStudio")
  unlockBinding("annotation_allowlist_path", nsenv)
  assign("annotation_allowlist_path", function() allow, envir = nsenv)
})

enrich_tab_ui <- getFromNamespace("enrich_tab_ui", "richStudio")
enrich_tab_server <- getFromNamespace("enrich_tab_server", "richStudio")
jobs_ui <- getFromNamespace("workspace_jobs_ui", "richStudio")
badge_ui <- getFromNamespace("workspace_jobs_badge_ui", "richStudio")
jobs_server <- getFromNamespace("workspace_jobs_server", "richStudio")
jobs_registry <- getFromNamespace("workspace_jobs_registry", "richStudio")
jobs_close <- getFromNamespace("workspace_jobs_close", "richStudio")
shiny::addResourcePath("rs", system.file("application/www", package = "richStudio"))
future::plan(future::multisession, workers = 2L)

stub_runner <- function(deg_inputs, cutoff, species, anntype, keytype, ontology, ...) {
  lapply(deg_inputs, function(inp) list(name = inp$name,
    result = data.frame(Annot = "Term one", Term = "T1", Pvalue = 0.01, Padj = 0.02, GeneID = "g1,g2"),
    anntype = anntype, keytype = keytype, ontology = ontology, species = species))
}
stub_builder <- function(species, keytype, anntype) stop("annotation builder stub: not called by the stub runner")

ui <- dashboardPage(
  dashboardHeader(title = "Annotation install fixture"),
  dashboardSidebar(sidebarMenu(id = "tabs", menuItem("Enrichment", tabName = "enrich_tab"))),
  dashboardBody(shinyjs::useShinyjs(),
    tags$div(id = "fixture", "data-world" = world),
    tags$head(tags$link(rel = "stylesheet", href = "rs/custom.css"), tags$script(src = "rs/workspace-ui.js")),
    badge_ui("jobs"), jobs_ui("jobs"),
    tabItems(enrich_tab_ui("enrich", tabName = "enrich_tab")))
)
server <- function(input, output, session) {
  u_degnames <- reactiveValues(labels = c("deg_a"))
  df <- data.frame(gene = paste0("g", 1:4), Padj = rep(0.01, 4))
  u_degdfs <- reactiveValues(deg_a = df)
  u_big_degdf <- reactiveValues(df = richStudio::add_file_degdf(NULL, "deg_a", df))
  u_rrnames <- reactiveValues(labels = NULL)
  u_rrdfs <- reactiveValues()
  u_big_rrdf <- reactiveValues()
  jobs <- jobs_registry(session)
  session$userData$workspace_jobs <- jobs
  session$onSessionEnded(function() jobs_close(jobs))
  jobs_server("jobs", jobs)
  enrich_tab_server("enrich", u_degnames = u_degnames, u_degdfs = u_degdfs, u_big_degdf = u_big_degdf,
                    u_rrnames = u_rrnames, u_rrdfs = u_rrdfs, u_big_rrdf = u_big_rrdf,
                    enrichment_runner = stub_runner, annotation_builder = stub_builder)
}
runApp(shinyApp(ui, server), host = "127.0.0.1", port = port, launch.browser = FALSE)
