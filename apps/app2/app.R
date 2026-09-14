library(shiny)
library(ggplot2)

# --- App 2: mtcars Explorer ---
# Slightly less trivial example: dropdown-driven scatter plot.
# Uses ggplot2, so make sure it's captured in renv.lock (see README).

ui <- fluidPage(
  titlePanel("App 2 - mtcars Explorer"),
  sidebarLayout(
    sidebarPanel(
      selectInput(
        "x_var", "X axis:",
        choices = names(mtcars),
        selected = "wt"
      ),
      selectInput(
        "y_var", "Y axis:",
        choices = names(mtcars),
        selected = "mpg"
      )
    ),
    mainPanel(
      plotOutput("scatter_plot")
    )
  )
)

server <- function(input, output, session) {
  output$scatter_plot <- renderPlot({
    ggplot(mtcars, aes(x = .data[[input$x_var]], y = .data[[input$y_var]])) +
      geom_point(size = 3, color = "steelblue") +
      labs(
        x = input$x_var,
        y = input$y_var,
        title = paste(input$y_var, "vs", input$x_var)
      ) +
      theme_minimal()
  })
}

shinyApp(ui, server)
