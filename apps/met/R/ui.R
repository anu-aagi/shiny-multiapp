# The page: three controls on the left, four tabs on the right.

ui <- anu_page(
  browser_title = "MET Explorer | The Australian National University",
  title = "MET Explorer",
  lede = paste(
    "Variety performance across environments, from a factor analytic",
    "decomposition of a multi-environment trial series."
  ),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      checkboxGroupInput(
        "years", "Harvest years",
        choices = years, selected = years, inline = TRUE
      ),
      radioButtons(
        "k", "Factors retained",
        choices = c(1, 2, 3), selected = 2, inline = TRUE
      ),
      selectInput(
        "focus", "Highlight varieties (max 4)",
        choices = met$variety, selected = default_varieties,
        multiple = TRUE, selectize = TRUE
      ),
      tags$p(
        class = "side-note",
        "Western Australian spring wheat, Perry & D'Antuono (1989). ",
        tags$b(textOutput("n_env", inline = TRUE)),
        " environments × ", n_var, " cultivars."
      ),
      downloadButton("dl", "Download variety summary", class = "btn-sm")
    ),

    mainPanel(
      width = 9,
      uiOutput("tiles"),
      tabsetPanel(
        id = "tabs",

        tabPanel(
          "Performance",
          tags$p(class = "panel-note",
                 "Each variety gets an Overall Performance score (yield advantage",
                 " averaged over environments) and an RMSD stability score (how far",
                 " its actual results sit from that average expectation). The useful",
                 " varieties are to the right; the dependable ones are low."),
          hover_plot("op", "480px"),
          tags$hr(),
          uiOutput("summary_table")
        ),

        tabPanel(
          "Latent regression",
          tags$p(class = "panel-note",
                 "Environments are placed on the horizontal axis by their factor 1",
                 " loading -- low on the left, high-yielding and discriminating on",
                 " the right. A steep line is a responsive variety that needs a good",
                 " season; a flat line is one that holds up everywhere. Points are the",
                 " variety's actual trial results."),
          plotOutput("lr_plot", height = "480px")
        ),

        tabPanel(
          "Environments",
          tags$p(class = "panel-note",
                 "Factor loadings show how each trial discriminates. Environments",
                 " close together rank varieties the same way; the correlation matrix",
                 " below makes that explicit."),
          plotOutput("load_plot", height = "420px"),
          tags$hr(),
          plotOutput("gcor_plot", height = "560px")
        ),

        tabPanel(
          "Method",
          div(class = "method", htmlOutput("method"))
        )
      )
    )
  )
)
