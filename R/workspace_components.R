# Internal presentation adapters. Callers supply facts and backend-confirmed
# state;
# these helpers never calculate scientific values or apply workspace mutations.
workspace_text <- function(value, name = "text", missing = FALSE) {
  if (length(value) != 1L || !is.atomic(value) || is.na(value)) {
    if (missing && length(value) == 1L && is.atomic(value) && is.na(value)) {
      return("Not recorded")
    }
    stop(name, " must be one non-missing text value", call. = FALSE)
  }
  # Drop HTML classes: all supplied labels are text, never trusted markup.
  paste0(value)
}

workspace_action <- function(
  namespace,
  id,
  label,
  available = TRUE,
  reason = NULL
) {
  id <- shiny::NS(namespace, id)
  label <- workspace_text(label, "label")
  if (!is.logical(available) || length(available) != 1L || is.na(available)) {
    stop("available must be TRUE or FALSE", call. = FALSE)
  }
  if (!available && (is.null(reason) || !nzchar(workspace_text(reason)))) {
    stop("Unavailable actions require a reason", call. = FALSE)
  }
  button <- shiny::tags$button(
    id = id,
    type = "button",
    class = "rs-workspace rs-workspace-action action-button",
    disabled = if (!available) "disabled",
    `aria-describedby` = if (!available) paste0(id, "-reason"),
    shiny::tags$span(class = "action-label", label)
  )
  if (available) {
    return(button)
  }
  shiny::tags$span(
    class = "rs-workspace rs-workspace-action-group",
    button,
    shiny::tags$span(id = paste0(id, "-reason"), workspace_text(reason))
  )
}

# @MX:ANCHOR: [AUTO] Shared facts presentation for context, review and receipts.
# @MX:REASON: C02, C03, C08 and C09 compose this internal presentation
# primitive.
workspace_card <- function(namespace, id, title, facts, kind) {
  id <- shiny::NS(namespace, id)
  if (
    !is.list(facts) ||
      is.null(names(facts)) ||
      anyNA(names(facts)) ||
      any(!nzchar(names(facts))) ||
      anyDuplicated(names(facts))
  ) {
    stop("facts must be a uniquely named list", call. = FALSE)
  }
  kind <- match.arg(
    kind,
    c(
      "Setup draft",
      "Captured run settings",
      "Display filter",
      "Committed input revision",
      "Unsaved project changes"
    )
  )
  shiny::tags$section(
    id = id,
    class = "rs-workspace rs-workspace-card",
    `aria-labelledby` = paste0(id, "-heading"),
    shiny::tags$h3(id = paste0(id, "-heading"), workspace_text(title)),
    shiny::tags$p(class = "rs-workspace-kind", kind),
    shiny::tags$dl(lapply(seq_along(facts), function(i) {
      shiny::tagList(
        shiny::tags$dt(workspace_text(names(facts)[i])),
        shiny::tags$dd(workspace_text(facts[[i]], "fact", missing = TRUE))
      )
    }))
  )
}

workspace_field <- function(
  namespace,
  id,
  label,
  value = "",
  help = NULL,
  error = NULL
) {
  id <- shiny::NS(namespace, id)
  described <- c(
    if (!is.null(help)) paste0(id, "-help"),
    if (!is.null(error)) paste0(id, "-error")
  )
  shiny::tags$div(
    class = "rs-workspace rs-workspace-field",
    shiny::tags$label(`for` = id, workspace_text(label)),
    shiny::tags$input(
      id = id,
      type = "text",
      class = "form-control",
      value = workspace_text(value),
      `aria-describedby` = if (length(described)) {
        paste(described, collapse = " ")
      },
      `aria-invalid` = if (!is.null(error)) "true" else "false"
    ),
    if (!is.null(help)) {
      shiny::tags$p(id = paste0(id, "-help"), workspace_text(help))
    },
    if (!is.null(error)) {
      shiny::tags$p(
        id = paste0(id, "-error"),
        class = "rs-workspace-error",
        workspace_text(error)
      )
    }
  )
}

workspace_status <- function(namespace, id, state) {
  labels <- c(
    queued = "Queued",
    running = "Running \u2014 progress not reported",
    failed = "Failed",
    succeeded = "Succeeded",
    `stop-requested` = "Stop requested \u2014 awaiting acknowledgement",
    cancelled = "Cancelled",
    detached = "Detached \u2014 computation may continue",
    interrupted = "Interrupted \u2014 historical job is not running"
  )
  state <- match.arg(state, names(labels))
  shiny::tags$div(
    id = shiny::NS(namespace, id),
    class = paste(
      "rs-workspace rs-workspace-status",
      paste0("rs-workspace-status-", state)
    ),
    role = if (state == "failed") "alert" else "status",
    `aria-atomic` = "true",
    shiny::tags$span(
      `aria-hidden` = "true",
      if (state == "failed") "! " else "\u2022 "
    ),
    unname(labels[state])
  )
}

workspace_table <- function(namespace, id, title, data) {
  id <- shiny::NS(namespace, id)
  if (!is.data.frame(data) || !ncol(data)) {
    stop("data must have table columns", call. = FALSE)
  }
  title <- workspace_text(title)
  shiny::tags$section(
    id = id,
    class = "rs-workspace rs-workspace-results",
    shiny::tags$h3(id = paste0(id, "-heading"), title),
    shiny::tags$p(
      id = paste0(id, "-help"),
      "Scroll horizontally to view all columns"
    ),
    shiny::tags$div(
      class = "rs-workspace-table-scroll",
      role = "region",
      tabindex = "0",
      `aria-labelledby` = paste0(id, "-heading"),
      `aria-describedby` = paste0(id, "-help"),
      shiny::tags$table(
        shiny::tags$caption(title),
        shiny::tags$thead(shiny::tags$tr(lapply(names(data), function(x) {
          shiny::tags$th(scope = "col", workspace_text(x))
        }))),
        shiny::tags$tbody(lapply(seq_len(nrow(data)), function(i) {
          shiny::tags$tr(lapply(data, function(column) {
            shiny::tags$td(workspace_text(column[[i]], "cell", missing = TRUE))
          }))
        }))
      )
    )
  )
}

workspace_dataset_cue <- function(
  code,
  label,
  dataset_id,
  symbol = c("circle", "square", "triangle")
) {
  symbol <- match.arg(symbol)
  symbols <- c(circle = "\u25cf", square = "\u25a0", triangle = "\u25b2")
  shiny::tags$span(
    class = paste(
      "rs-workspace rs-workspace-dataset",
      paste0("rs-workspace-dataset-", symbol)
    ),
    shiny::tags$span(`aria-hidden` = "true", unname(symbols[symbol])),
    " ",
    workspace_text(code),
    " \u00b7 ",
    workspace_text(label),
    " \u00b7 ",
    workspace_text(dataset_id)
  )
}

# Native showModal() provides modal focus containment, Escape and invoker
# return.
# The adopting caller opens it, handles returnValue, revalidates targets before
# applying, and focuses a surviving contextual heading if the invoker was
# removed.
workspace_confirmation <- function(
  namespace,
  id,
  title,
  targets,
  confirm_label
) {
  id <- shiny::NS(namespace, id)
  if (
    !is.character(targets) ||
      !length(targets) ||
      anyNA(targets) ||
      any(!nzchar(targets))
  ) {
    stop("Named targets are required", call. = FALSE)
  }
  shiny::tags$dialog(
    id = id,
    class = "rs-workspace rs-workspace-confirmation",
    `aria-labelledby` = paste0(id, "-heading"),
    shiny::tags$h3(id = paste0(id, "-heading"), workspace_text(title)),
    shiny::tags$ul(lapply(targets, function(x) {
      shiny::tags$li(workspace_text(x))
    })),
    shiny::tags$form(
      method = "dialog",
      class = "rs-workspace-actions",
      shiny::tags$button(
        type = "submit",
        value = "cancel",
        autofocus = "autofocus",
        "Cancel"
      ),
      shiny::tags$button(
        type = "submit",
        value = "confirm",
        workspace_text(confirm_label)
      )
    )
  )
}
