# Resource policy is installed package data; never fall back to a source tree.
workspace_resource_keys <- function() {
  c("upload_bytes", "rows", "columns", "string_bytes", "decoded_bytes",
    "archive_bytes", "archive_expanded_bytes", "archive_members", "archive_depth",
    "render_rows", "graph_nodes", "graph_edges", "workers", "history_runs", "temp_bytes")
}

workspace_validate_resource_policy <- function(policy) {
  keys <- workspace_resource_keys()
  valid <- is.list(policy) && identical(policy$schema_version, 1L) &&
    is.list(policy$limits) && setequal(names(policy$limits), keys) &&
    !anyDuplicated(names(policy$limits)) &&
    all(vapply(policy$limits, function(value) {
      is.numeric(value) && length(value) == 1L && !is.na(value) &&
        is.finite(value) && value > 0 && value == floor(value)
    }, logical(1)))
  if (!valid) stop("Invalid workspace resource policy", call. = FALSE)
  policy
}

workspace_resource_policy <- function(path = system.file(
    "config", "workspace-resources.json", package = "richStudio")) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) || !file.exists(path)) {
    stop("Workspace resource policy unavailable", call. = FALSE)
  }
  workspace_validate_resource_policy(jsonlite::fromJSON(path, simplifyVector = FALSE))
}

# @MX:ANCHOR: [AUTO] Shared admission boundary for workspace resource consumers.
# @MX:REASON: Intake, archives, jobs, history and rendering share one installed policy.
workspace_check_resources <- function(metrics, policy = workspace_resource_policy()) {
  policy <- workspace_validate_resource_policy(policy)
  if (!is.list(metrics) || is.null(names(metrics)) || anyDuplicated(names(metrics)) ||
      any(!names(metrics) %in% names(policy$limits))) {
    stop("Unknown workspace resource metric", call. = FALSE)
  }
  for (key in names(metrics)) {
    value <- metrics[[key]]
    if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
        !is.finite(value) || value < 0 || value != floor(value)) {
      stop("Invalid workspace resource metric: ", key, call. = FALSE)
    }
    if (value > policy$limits[[key]]) {
      stop("Workspace resource limit exceeded: ", key, call. = FALSE)
    }
  }
  invisible(TRUE)
}
