# Rendered module interface guards; no CSS-class or layout implementation snapshots.
compact_ui_nodes <- function(x) {
  if (inherits(x, "shiny.tag")) {
    return(c(list(x), do.call(c, lapply(x$children, compact_ui_nodes))))
  }
  if (is.list(x)) {
    return(do.call(c, lapply(x, compact_ui_nodes)))
  }
  list()
}

compact_ui_dependencies <- function(envir) {
  for (package in c("shinyjs", "shinyWidgets")) {
    attached <- paste0("package:", package)
    if (!attached %in% search()) {
      do.call(
        withr::defer,
        list(
          substitute(
            detach(name = NAME, character.only = TRUE),
            list(NAME = attached)
          ),
          envir = envir
        )
      )
      library(package, character.only = TRUE)
    }
  }
}

# Actual frozen installed-4bc controls, before presentation edits. These are the
# namespaced Shiny interface, not a markup/class/whole-document hash.
compact_ui_contracts <- list(
  enrich = list(
    fun = "enrich_tab_ui",
    ids = c(
      "deg_files",
      "deg_load",
      "deg_text",
      "degtext_name",
      "upload_degtext",
      "degtext_load",
      "degs_to_enrich",
      "anntype_select",
      "keytype_select",
      "ont_select",
      "species_select",
      "deg_filter_cutoff",
      "enrich_deg",
      "deglist_help",
      "remove_deg",
      "rrlist_help",
      "remove_rr",
      "deg_table_select",
      "review_gene_col",
      "review_p_col",
      "review_p_role",
      "review_cutoff",
      "review_commit",
      "deg_export_type",
      "rr_table_select",
      "rr_export_type"
    )
  ),
  rr_visualize = list(
    fun = "rr_vis_tab_ui",
    ids = c(
      "rr_files",
      "rr_load",
      "rr_text",
      "rrtext_name",
      "upload_rrtext",
      "remove_rr",
      "select_table",
      "select_bar",
      "bar_type",
      "bar_valtype",
      "bar_pvalue",
      "bar_nterms",
      "select_dot",
      "dot_valtype",
      "dot_cutoff",
      "dot_nterms",
      "select_net",
      "net_valtype",
      "net_cutoff",
      "net_nterms",
      "select_tophmap",
      "tophmap_valtype",
      "tophmap_cutoff",
      "tophmap_nterms",
      "select_cushmap",
      "cushmap_valtype",
      "cushmap_title",
      "cushmap_add_rr",
      "rr_delete_select",
      "rr_term_delete_select",
      "delete_rr_terms",
      "delete_rr"
    )
  ),
  cluster_upload = list(
    fun = "cluster_upload_tab_ui",
    ids = c(
      "rr_files",
      "rr_load",
      "rr_text",
      "rrtext_name",
      "upload_rrtext",
      "rrlist_help",
      "remove_rr",
      "cluslist_help",
      "remove_clus",
      "rr_table_select",
      "rr_export_type",
      "clus_table_select",
      "clus_export_type"
    )
  ),
  cluster = list(
    fun = "clusterTabUI",
    ids = c("selected_rrs", "cluster_name", "cluster", "reset_params")
  ),
  clus_visualize = list(
    fun = "clus_vis_tab_ui",
    ids = c(
      "clus_files",
      "rr_text",
      "clustext_name",
      "upload_clustext",
      "remove_clus",
      "clusdf_select",
      "big_value_type",
      "value_by",
      "indiv_clus_select",
      "small_value_type",
      "cluslist_select",
      "cluslist_export_type"
    )
  ),
  update = list(
    fun = "updateTabUI",
    ids = c(
      "rename_deg_select",
      "new_deg_name",
      "rename_deg_btn",
      "rename_rr_select",
      "new_rr_name",
      "rename_rr_btn",
      "rename_clus_select",
      "new_clus_name",
      "rename_clus_btn",
      "remove_deg_select",
      "remove_deg_btn",
      "remove_rr_select",
      "remove_rr_btn",
      "remove_clus_select",
      "remove_clus_btn"
    )
  ),
  save = list(
    fun = "saveTabUI",
    ids = c(
      "session_name",
      "load_session_file",
      "load_session",
      "export_rr_select",
      "export_rr_format",
      "export_clus_select",
      "export_clus_format"
    )
  )
)

test_that("compact analysis forms preserve each native module control exactly once", {
  compact_ui_dependencies(environment())
  for (name in names(compact_ui_contracts)) {
    contract <- compact_ui_contracts[[name]]
    for (namespace in c("compact_one", "compact_two")) {
      ui <- getFromNamespace(contract$fun, "richStudio")(
        namespace,
        paste0(name, "_tab")
      )
      expect_true(nzchar(htmltools::renderTags(ui)$html))
      controls <- Filter(
        function(x) {
          x$name %in%
            c("input", "select", "textarea", "button") &&
            !is.null(x$attribs$id)
        },
        compact_ui_nodes(ui)
      )
      ids <- vapply(controls, function(x) x$attribs$id, character(1))
      expect_setequal(ids, paste0(namespace, "-", contract$ids))
      expect_false(anyDuplicated(ids) > 0, info = name)
    }
  }
})

test_that("compact form rendering retains review, scientific and session cautions", {
  compact_ui_dependencies(environment())
  cases <- list(
    enrich_tab_ui = c(
      "Select DEG sets to enrich",
      "Select annotation source",
      "Select keytype",
      "Select ontology",
      "Select species",
      "Review before Run",
      "Default cutoff",
      "without a committed revision",
      "Commit input revision",
      "P-value role"
    ),
    clusterTabUI = c(
      "Select enrichment results to cluster",
      "Clustering Method",
      "Run Clustering",
      "Reset to Defaults"
    ),
    saveTabUI = c(
      "Loading a session will replace your current analysis state.",
      "RDS format preserves all R objects exactly",
      "may lose some data types"
    )
  )
  for (fun in names(cases)) {
    ui <- getFromNamespace(fun, "richStudio")("compact", "workflow")
    text <- gsub(
      "[[:space:]]+",
      " ",
      gsub("<[^>]+>", " ", htmltools::renderTags(ui)$html)
    )
    for (phrase in cases[[fun]]) {
      expect_match(text, phrase, fixed = TRUE, info = fun)
    }
  }
})
