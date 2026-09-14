library(shiny)

# --- App 1: Simple Counter ---
# Minimal example app. No extra packages beyond shiny needed.

ui <- fluidPage(
  titlePanel("App 1 - Counter"),
  sidebarLayout(
    sidebarPanel(
      actionButton("increment", "Add 1"),
      actionButton("reset", "Reset")
    ),
    mainPanel(
      h2("Current count:"),
      h1(textOutput("count_display"))
    )
  )
)

server <- function(input, output, session) {
  count <- reactiveVal(0)

  observeEvent(input$increment, {
    count(count() + 1)
  })

  observeEvent(input$reset, {
    count(0)
  })

  output$count_display <- renderText({
    count()
  })
}

shinyApp(ui, server)
