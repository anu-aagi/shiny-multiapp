# The page: four controls on the left, four tabs on the right.

ui <- anu_page(
  browser_title = "Field Trial Analyser | The Australian National University",
  title = "Field Trial Analyser",
  lede = paste(
    "Spatial adjustment of a single-site variety trial: separating a variety's",
    "merit from the ground it was sown on."
  ),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      selectInput("trial", "Trial", choices = trial_choices),
      tags$div(class = "side-note", textOutput("trial_note")),
      radioButtons(
        "model", "Spatial model",
        choices = setNames(names(models), vapply(models, `[[`, "", "label")),
        selected = "rcb"
      ),
      tags$div(class = "side-note", textOutput("model_note")),
      # The fourth layer, the trend that went in, exists only for the simulated
      # trials, so the server adds and removes it as the trial changes.
      radioButtons(
        "layer", "Field map shows",
        choices = c("Observed yield" = "yield",
                    "Fitted spatial effect" = "spatial",
                    "Residual" = "resid"),
        selected = "yield"
      ),
      downloadButton("dl", "Download entry means", class = "btn-sm")
    ),

    mainPanel(
      width = 9,
      uiOutput("tiles"),
      tabsetPanel(
        id = "tabs",

        tabPanel(
          "Field map",
          tags$p(class = "panel-note",
                 "The trial as it sits on the ground. Look at the observed yield",
                 " first, then switch to the residual: if the model has done its",
                 " job the residual map should look like static, with no patches",
                 " or gradients left."),
          hover_plot("field", "500px")
        ),

        tabPanel(
          "Entry means",
          tags$p(class = "panel-note",
                 "Adjusted means with one standard error either side. The bar at",
                 " the top is the average LSD at 5%: two entries further apart",
                 " than that are separated by the trial. The table gives the same",
                 " means with the unadjusted average beside them, so you can see",
                 " which entries were sitting on good or bad ground."),
          plotOutput("means_plot", height = "760px"),
          tags$hr(),
          uiOutput("means_table")
        ),

        tabPanel(
          "Model choice",
          tags$p(class = "panel-note",
                 "Every model fitted to this trial. On the real trials the",
                 " decision rests on the LSD, the repeatability and the neighbour",
                 " correlation, as it does in practice. On the simulated ones the",
                 " true genetic values are also known, so accuracy can be shown",
                 " beside those diagnostics -- which is how you find out how far",
                 " to trust them when it cannot be."),
          plotOutput("compare_plot", height = "300px"),
          tags$hr(),
          uiOutput("compare_table")
        ),

        tabPanel(
          "Method",
          div(class = "method", htmlOutput("method"))
        )
      )
    )
  )
)
