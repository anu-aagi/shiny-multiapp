server <- function(input, output, session) {

  sim <- reactive(sims[[input$trial]])
  current <- reactive(fit_model(sim()$data, input$model))

  squish <- function(x) gsub("\\s+", " ", trimws(x))
  output$trial_note <- renderText(squish(trials[[input$trial]]$note))
  output$model_note <- renderText(squish(models[[input$model]]$blurb))

  # Adjusted means beside the unadjusted plot averages and the simulated truth.
  means <- reactive({
    d <- sim()$data
    raw <- tapply(d$yield, d$entry, mean)
    m <- current()$means
    m$raw <- as.vector(raw[m$entry])
    m$truth <- sim()$g_true[m$entry] + mean(d$yield)
    m$shift <- m$adjusted - m$raw
    m$move <- rank(-m$raw, ties.method = "min") - m$rank
    m[order(m$rank), ]
  })

  # -- Stat tiles ----------------------------------------------------------
  output$tiles <- renderUI({
    f <- current()
    stat_tiles(
      stat_tile("Trial mean", sprintf("%.2f", mean(f$data$yield)),
                sprintf("t/ha · %d plots", nrow(f$data))),
      stat_tile("Residual SD", sprintf("%.3f", f$sigma),
                sprintf("CV %.1f%% · %d df", f$cv, f$df)),
      stat_tile("LSD (5%)", sprintf("%.2f", f$lsd), "t/ha between entries"),
      stat_tile("Repeatability", sprintf("%.2f", f$h2), "H² of entry means")
    )
  })

  # -- Field map -----------------------------------------------------------
  field_data <- reactive({
    d <- current()$data
    d$value <- d[[input$layer]]
    d
  })

  output$field <- renderPlot({
    d <- field_data()
    lay <- input$layer
    ttl <- c(yield = "Observed plot yield", spatial = "Fitted spatial effect",
             resid = "Residual after fitting",
             trend = "True simulated trend")[[lay]]

    p <- ggplot(d, aes(col, row, fill = value)) +
      geom_tile(colour = pal$surface, linewidth = 0.8) +
      coord_fixed() +
      scale_x_continuous(breaks = seq_len(N_COL)) +
      scale_y_reverse(breaks = seq_len(N_ROW)) +
      labs(title = ttl,
           subtitle = paste0(trials[[input$trial]]$label,
                             " · hover a plot for its entry"),
           x = "Range (column)", y = "Plot (row)",
           caption = "Replicates run in blocks of three ranges.") +
      theme_crop(12) +
      theme(panel.grid.major = element_blank(), axis.line = element_blank())

    # Yield is a level, so it gets a sequential scale; everything else is a
    # departure from zero and gets a diverging one centred there.
    if (lay == "yield") {
      p + scale_fill_gradient(low = pal$seq_lo, high = pal$seq_hi, name = "t/ha")
    } else {
      lim <- max(abs(d$value))
      p + scale_fill_gradient2(low = pal$div_hi, mid = pal$div_mid,
                               high = pal$div_lo, midpoint = 0,
                               limits = c(-lim, lim), name = "t/ha")
    }
  }, res = 96)

  output$field_tip <- renderUI({
    h <- input$field_hover
    if (is.null(h)) return(NULL)
    pt <- nearPoints(field_data(), h, xvar = "col", yvar = "row",
                     threshold = 24, maxpoints = 1)
    if (!nrow(pt)) return(NULL)
    hover_tip(
      h,
      tags$b(as.character(pt$entry)), tags$br(),
      sprintf("Row %d, range %d · rep %s", pt$row, pt$col,
              as.character(pt$rep)), tags$br(),
      sprintf("Yield %.2f t/ha", pt$yield), tags$br(),
      sprintf("Fitted spatial %+.2f · residual %+.2f", pt$spatial, pt$resid)
    )
  })

  # -- Entry means ---------------------------------------------------------
  output$means_plot <- renderPlot({
    f <- current()
    m <- means()
    m$entry <- factor(m$entry, levels = m$entry[order(m$adjusted)])
    top <- max(m$adjusted + m$se)

    ggplot(m, aes(adjusted, entry)) +
      geom_vline(xintercept = mean(f$data$yield), colour = pal$axis,
                 linewidth = 0.4) +
      geom_segment(aes(x = adjusted - se, xend = adjusted + se,
                       y = entry, yend = entry),
                   colour = pal$s1, linewidth = 2, alpha = 0.25,
                   lineend = "round") +
      geom_point(colour = pal$s1, size = 2.6) +
      annotate("segment", x = top + 0.04, xend = top + 0.04 + f$lsd,
               y = N_VAR - 0.4, yend = N_VAR - 0.4,
               colour = pal$ink2, linewidth = 1.6, lineend = "round") +
      annotate("text", x = top + 0.04, y = N_VAR - 1.4,
               label = sprintf("LSD 5%% = %.2f", f$lsd),
               hjust = 0, size = 3.4, colour = pal$ink2) +
      scale_x_continuous(expand = expansion(mult = c(0.02, 0.20))) +
      labs(
        title = "Adjusted entry means",
        subtitle = paste0(f$label, " · bars are ±1 standard error,",
                          " vertical line is the trial mean"),
        x = "Adjusted mean yield (t/ha)", y = NULL
      ) +
      theme_crop(12) +
      theme(panel.grid.major.y = element_blank())
  }, res = 96)

  output$means_table <- renderUI({
    m <- means()
    rows <- lapply(seq_len(nrow(m)), function(i) {
      r <- m[i, ]
      tags$tr(
        tags$td(r$rank), tags$td(tags$b(r$entry)),
        tags$td(sprintf("%.2f", r$adjusted)),
        tags$td(sprintf("%.3f", r$se)),
        tags$td(sprintf("%.2f", r$raw)),
        tags$td(sprintf("%+.2f", r$shift)),
        tags$td(sprintf("%+d", r$move)),
        tags$td(sprintf("%.2f", r$truth))
      )
    })
    data_table(
      c("Rank", "Entry", "Adjusted t/ha", "SE", "Unadjusted", "Shift",
        "Rank move", "True value"),
      rows
    )
  })

  # -- Model choice --------------------------------------------------------
  comparison <- reactive(compare_models(sim()$data, sim()$g_true))

  output$compare_plot <- renderPlot({
    d <- comparison()
    d$model <- factor(d$model, levels = rev(vapply(models, `[[`, "", "label")))
    d$is_current <- d$key == input$model

    ggplot(d, aes(accuracy, model)) +
      geom_segment(aes(x = min(accuracy) - 0.01, xend = accuracy,
                       y = model, yend = model),
                   colour = pal$grid, linewidth = 2.4, lineend = "round") +
      geom_point(aes(colour = is_current), size = 4) +
      geom_text(aes(label = sprintf("%.3f", accuracy)), hjust = 0,
                nudge_x = 0.004, size = 3.5, colour = pal$ink2) +
      scale_colour_manual(values = c(`FALSE` = pal$s1, `TRUE` = pal$s2),
                          guide = "none") +
      scale_x_continuous(expand = expansion(mult = c(0.01, 0.10))) +
      labs(
        title = "Accuracy of each spatial model",
        subtitle = paste0("Correlation between the adjusted means and the true",
                          " genetic values. The selected model is orange."),
        x = "Correlation with truth", y = NULL
      ) +
      theme_crop(12) +
      theme(panel.grid.major.y = element_blank())
  }, res = 96)

  output$compare_table <- renderUI({
    d <- comparison()
    rows <- lapply(seq_len(nrow(d)), function(i) {
      r <- d[i, ]
      tags$tr(
        class = if (r$key == input$model) "current" else NULL,
        tags$td(tags$b(r$model)),
        tags$td(r$n_par),
        tags$td(sprintf("%.3f", r$sigma)),
        tags$td(sprintf("%.2f", r$lsd)),
        tags$td(sprintf("%.2f", r$h2)),
        tags$td(sprintf("%+.2f", r$nb)),
        tags$td(sprintf("%.1f", r$aic)),
        tags$td(sprintf("%.3f", r$accuracy))
      )
    })
    data_table(
      c("Model", "Parameters", "Residual SD", "LSD 5%", "H²",
        "Neighbour r", "AIC", "Accuracy"),
      rows
    )
  })

  # -- Download ------------------------------------------------------------
  output$dl <- downloadHandler(
    filename = function() paste0("trial-", input$trial, "-", input$model, ".csv"),
    content = function(file) {
      m <- means()
      m$trial <- input$trial
      m$model <- models[[input$model]]$label
      write.csv(m, file, row.names = FALSE)
    }
  )

  # -- Method note ---------------------------------------------------------
  output$method <- renderUI({
    f <- current()
    tagList(
      tags$h4("The design"),
      tags$p(sprintf(paste0(
        "%d entries in %d replicates, one plot each, on a %d row by %d range ",
        "grid of %d plots. Each replicate occupies three consecutive ranges and ",
        "entries are randomised within it."
      ), N_VAR, N_REP, N_ROW, N_COL, N_ROW * N_COL)),

      tags$h4("The model"),
      tags$p(HTML(paste0(
        "<code>", paste(deparse(f$formula), collapse = " "),
        "</code> fitted by least squares. ",
        "Entry means are least-squares means: every non-entry term is held at ",
        "its average over the whole design, so the means do not depend on which ",
        "plots an entry happened to occupy. That is what makes them comparable ",
        "across the models in the comparison tab."
      ))),

      tags$h4("Precision measures"),
      tags$p(HTML(paste0(
        "The average LSD is <code>t<sub>0.975, df</sub></code> times the mean ",
        "standard error of difference over all entry pairs. Repeatability is ",
        "<code>H&sup2; = &sigma;&sup2;<sub>g</sub> / (&sigma;&sup2;<sub>g</sub> ",
        "+ mean(SE&sup2;))</code>, with <code>&sigma;&sup2;<sub>g</sub></code> ",
        "the variance of the adjusted means less the average squared standard ",
        "error. It answers how much of the spread between entry means is real ",
        "rather than noise."
      ))),

      tags$h4("Reading the diagnostics"),
      tags$p(paste0(
        "Neighbour r is the lag 1 correlation between the residuals of adjacent ",
        "plots, averaged along rows and along ranges. A model that leaves a ",
        "visible patch on the residual map, or a neighbour correlation well ",
        "above zero, has not finished. A model whose LSD has grown relative to ",
        "a simpler one is spending degrees of freedom it cannot afford -- the ",
        "uniform block trial shows that case."
      )),

      tags$h4("Data"),
      tags$p(paste0(
        "All three trials are simulated with fixed seeds from a known genetic ",
        "effect, a known spatial trend and independent plot error. Site names ",
        "are real locations; the yields and entries are invented."
      )),

      tags$h4("Where this fits"),
      tags$p(paste0(
        "Adjusted entry means from single trials like these are the input to a ",
        "multi-environment analysis. The MET Explorer takes that table and fits ",
        "the factor analytic structure of Smith et al. (2015) across sites and ",
        "seasons."
      ))
    )
  })
}
