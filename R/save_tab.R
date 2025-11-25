saveTabUI <- function(id, tabName) {
  ns <- NS(id)
  tabItem(tabName = tabName,
    h1("Save"),
    p("Save individual graphs as PNG, PDF, or save/load entire workspace."),
    downloadButton("save", "Save"),
    fileInput("load", "Load")
  )
}


saveTabServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$load, {
      # Load saved app state from the selected file
      state <- jsonlite::fromJSON(input$loadFile$datapath)
      updateTextInput(session, "text", value = state$text)
      updateSliderInput(session, "slider", value = state$slider)
    })

    output$save <- downloadHandler(
      filename = function() {
        paste0("app_state_", format(Sys.time(), "%Y%m%d%H%M%S"), ".json")
      },
      content = function(file) {
        # Save current app state to a JSON file for download
        values <<- lapply(reactiveValuesToList(input), unclass)
        jsonlite::write_json(state, file)
      }
    )
  })
}
