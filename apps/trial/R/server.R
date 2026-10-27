server <- function(input, output, session) {

  # Browsers throttle/suspend background tabs and drop the websocket; without
  # this the reconnect grace period is off and Shiny shows a dead gray
  # overlay requiring a full reload instead of reconnecting transparently.
  session$allowReconnect(TRUE)

  tr <- reactive(trials[[input$trial]])
  current <- reactive(fit_model(tr()$data, input$model))

  # The true trend is a layer only where there is one: switching from a
  # simulated trial to a real one takes the option away, and with it the
  # selection if that is where it was sitting.
  observeEvent(input$trial, {
    layers <- c("Observed yield" = "yield",
                "Fitted spatial effect" = "spatial",
                "Residual" = "resid")
    if (!tr()$real) layers <- c(layers, "True trend (simulated)" = "trend")
    keep <- if (input$layer %in% layers) input$layer else "yield"
    updateRadioButtons(session, "layer", choices = layers, selected = keep)
  })

  squish <- function(x) gsub("\\s+", " ", trimws(x))
  output$trial_note <- renderText(squish(tr()$note))
  output$model_note <- renderText(squish(models[[input$model]]$blurb))

  # Yield has a unit on the real trials only when the source stated one, and
  # Besag and Higdon do not, so the labels carry it on the simulated trials and
  # leave it off otherwise.
  unit <- reactive(unit_suffix(tr()))

  # Adjusted means beside the unadjusted plot averages, and beside the truth
  # where the trial was simulated and there is one.
  means <- reactive({
    d <- tr()$data
    g <- tr()$g_true
    raw <- tapply(d$yield, d$entry, mean)
    m <- current()$means
    m$raw <- as.vector(raw[m$entry])
    m$truth <- if (is.null(g)) NA_real_ else g[m$entry] + mean(d$yield)
    m$shift <- m$adjusted - m$raw
    m$move <- rank(-m$raw, ties.method = "min") - m$rank
    m[order(m$rank), ]
  })

  # -- Stat tiles ----------------------------------------------------------
  output$tiles <- renderUI({
    f <- current()
    u <- if (is.null(tr()$unit)) "" else paste0(tr()$unit, " · ")
    stat_tiles(
      stat_tile("Trial mean", sprintf("%.2f", mean(f$data$yield)),
                sprintf("%s%d plots", u, f$dims$n_plot)),
      stat_tile("Residual SD", sprintf("%.3f", f$sigma),
                sprintf("CV %.1f%% · %d df", f$cv, f$df)),
      stat_tile("LSD (5%)", sprintf("%.2f", f$lsd),
                paste0(u, "between entries")),
      stat_tile("Repeatability", sprintf("%.2f", f$h2), "H² of entry means")
    )
  })

  # -- Field map -----------------------------------------------------------
  # The radio buttons and the trial are two inputs, and for one flush they can
  # disagree -- the trial has changed but "trend" is still selected -- so the
  # layer is resolved against the columns the trial actually has.
  layer <- reactive({
    if (input$layer %in% names(current()$data)) input$layer else "yield"
  })

  field_data <- reactive({
    d <- current()$data
    d$value <- d[[layer()]]
    d
  })

  output$field <- renderPlot({
    f <- current()
    d <- field_data()
    g <- f$dims
    lay <- layer()
    ttl <- c(yield = "Observed plot yield", spatial = "Fitted spatial effect",
             resid = "Residual after fitting",
             trend = "True simulated trend")[[lay]]

    p <- ggplot(d, aes(col, row, fill = value)) +
      geom_tile(colour = pal$surface, linewidth = 0.8) +
      coord_fixed() +
      scale_x_continuous(breaks = seq_len(g$n_col)) +
      scale_y_reverse(breaks = seq_len(g$n_row)) +
      labs(title = ttl,
           subtitle = paste0(tr()$label, " · hover a plot for its entry"),
           x = "Range (column)", y = "Plot (row)",
           caption = if (tr()$real)
             paste0("Replicates are not contiguous ranges -- hover to see which.",
                    " Gaps are the plots this trial lost.")
           else "Replicates run in blocks of three ranges.") +
      theme_crop(12) +
      theme(panel.grid.major = element_blank(), axis.line = element_blank())

    # Yield is a level, so it gets a sequential scale; everything else is a
    # departure from zero and gets a diverging one centred there.
    nm <- if (is.null(tr()$unit)) "Yield" else tr()$unit
    if (lay == "yield") {
      p + scale_fill_gradient(low = pal$seq_lo, high = pal$seq_hi, name = nm)
    } else {
      lim <- max(abs(d$value))
      p + scale_fill_gradient2(low = pal$div_hi, mid = pal$div_mid,
                               high = pal$div_lo, midpoint = 0,
                               limits = c(-lim, lim), name = nm)
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
      sprintf("Yield %.2f%s", pt$yield, unit_suffix(tr(), " ", "")), tags$br(),
      sprintf("Fitted spatial %+.2f · residual %+.2f", pt$spatial, pt$resid)
    )
  })

  # -- Entry means ---------------------------------------------------------
  output$means_plot <- renderPlot({
    f <- current()
    m <- means()
    m$entry <- factor(m$entry, levels = m$entry[order(m$adjusted)])
    top <- max(m$adjusted + m$se)
    n <- f$dims$n_var
    pad <- 0.02 * diff(range(m$adjusted))

    ggplot(m, aes(adjusted, entry)) +
      geom_vline(xintercept = mean(f$data$yield), colour = pal$axis,
                 linewidth = 0.4) +
      geom_segment(aes(x = adjusted - se, xend = adjusted + se,
                       y = entry, yend = entry),
                   colour = pal$s1, linewidth = 2, alpha = 0.25,
                   lineend = "round") +
      geom_point(colour = pal$s1, size = 2.6) +
      annotate("segment", x = top + pad, xend = top + pad + f$lsd,
               y = n - 0.4, yend = n - 0.4,
               colour = pal$ink2, linewidth = 1.6, lineend = "round") +
      annotate("text", x = top + pad, y = n - 1.4,
               label = sprintf("LSD 5%% = %.2f", f$lsd),
               hjust = 0, size = 3.4, colour = pal$ink2) +
      scale_x_continuous(expand = expansion(mult = c(0.02, 0.20))) +
      labs(
        title = "Adjusted entry means",
        subtitle = paste0(f$label, " · bars are ±1 standard error,",
                          " vertical line is the trial mean"),
        x = paste0("Adjusted mean yield", unit()), y = NULL
      ) +
      theme_crop(12) +
      theme(panel.grid.major.y = element_blank())
  }, res = 96)

  output$means_table <- renderUI({
    m <- means()
    truth <- !all(is.na(m$truth))
    rows <- lapply(seq_len(nrow(m)), function(i) {
      r <- m[i, ]
      tags$tr(
        tags$td(r$rank), tags$td(tags$b(r$entry)),
        tags$td(sprintf("%.2f", r$adjusted)),
        tags$td(sprintf("%.3f", r$se)),
        tags$td(sprintf("%.2f", r$raw)),
        tags$td(sprintf("%+.2f", r$shift)),
        tags$td(sprintf("%+d", r$move)),
        if (truth) tags$td(sprintf("%.2f", r$truth))
      )
    })
    data_table(
      c("Rank", "Entry", "Adjusted", "SE", "Unadjusted", "Shift", "Rank move",
        if (truth) "True value"),
      rows
    )
  })

  # -- Model choice --------------------------------------------------------
  comparison <- reactive(compare_models(tr()$data, tr()$g_true))

  # With the truth known, accuracy against it settles the choice. Without it,
  # the honest stand-in is repeatability: how much of the spread between entry
  # means survives once estimation error is taken out of it.
  compare_metric <- reactive({
    d <- comparison()
    if (all(is.na(d$accuracy))) {
      list(var = "h2", fmt = "%.3f",
           title = "Repeatability under each spatial model",
           sub = paste0("H² of the entry means -- how much of the spread",
                        " between them is real. The selected model is orange."),
           x = "Repeatability (H²)")
    } else {
      list(var = "accuracy", fmt = "%.3f",
           title = "Accuracy of each spatial model",
           sub = paste0("Correlation between the adjusted means and the true",
                        " genetic values. The selected model is orange."),
           x = "Correlation with truth")
    }
  })

  output$compare_plot <- renderPlot({
    d <- comparison()
    spec <- compare_metric()
    d$value <- d[[spec$var]]
    d$model <- factor(d$model, levels = rev(vapply(models, `[[`, "", "label")))
    d$is_current <- d$key == input$model

    ggplot(d, aes(value, model)) +
      geom_segment(aes(x = min(value) - 0.01, xend = value,
                       y = model, yend = model),
                   colour = pal$grid, linewidth = 2.4, lineend = "round") +
      geom_point(aes(colour = is_current), size = 4) +
      geom_text(aes(label = sprintf(spec$fmt, value)), hjust = 0,
                nudge_x = 0.004, size = 3.5, colour = pal$ink2) +
      scale_colour_manual(values = c(`FALSE` = pal$s1, `TRUE` = pal$s2),
                          guide = "none") +
      scale_x_continuous(expand = expansion(mult = c(0.01, 0.10))) +
      labs(title = spec$title, subtitle = spec$sub, x = spec$x, y = NULL) +
      theme_crop(12) +
      theme(panel.grid.major.y = element_blank())
  }, res = 96)

  output$compare_table <- renderUI({
    d <- comparison()
    truth <- !all(is.na(d$accuracy))
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
        if (truth) tags$td(sprintf("%.3f", r$accuracy))
      )
    })
    data_table(
      c("Model", "Parameters", "Residual SD", "LSD 5%", "H²",
        "Neighbour r", "AIC", if (truth) "Accuracy"),
      rows
    )
  })

  # -- Download ------------------------------------------------------------
  output$dl <- downloadHandler(
    filename = function() paste0("trial-", input$trial, "-", input$model, ".csv"),
    content = function(file) {
      m <- means()
      if (all(is.na(m$truth))) m$truth <- NULL
      m$trial <- tr()$label
      m$model <- models[[input$model]]$label
      write.csv(m, file, row.names = FALSE)
    }
  )

  # -- Method note ---------------------------------------------------------
  output$method <- renderUI({
    f <- current()
    g <- f$dims
    tagList(
      tags$h4("The design"),
      tags$p(sprintf(paste0(
        "%d entries in %d replicates, one plot each, on a %d row by %d range ",
        "grid. %s"
      ), g$n_var, g$n_rep, g$n_row, g$n_col,
      if (tr()$real)
        sprintf(paste0("%d of the %d grid positions carry a plot: the six this ",
                       "trial lost are left empty rather than filled in."),
                g$n_plot, g$n_row * g$n_col)
      else
        "Each replicate occupies three consecutive ranges and entries are
         randomised within it.")),

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
        "a simpler one is spending degrees of freedom it cannot afford -- ",
        "county 5 and the uniform block trial both show that case."
      )),

      tags$h4("Data"),
      if (tr()$real) tagList(
        tags$p(paste0(
          "Real published field results: 64 corn hybrids grown in six North ",
          "Carolina counties, each an 18 by 11 lattice of plots in three ",
          "replicates with incomplete blocks. Each county is missing six plots, ",
          "which are left out here rather than filled in, so a county has 192 ",
          "plots. The source does not state the unit yield was measured in, so ",
          "the labels carry none."
        )),
        tags$p(paste0(
          "Besag J, Higdon D (1999). Bayesian analysis of agricultural field ",
          "experiments. Journal of the Royal Statistical Society Series B ",
          "61:691-746, Table 1. doi:10.1111/1467-9868.00201. Used with ",
          "permission of David Higdon."
        ))
      ) else tags$p(paste0(
        "This trial is simulated with a fixed seed from a known genetic effect, ",
        "a known spatial trend and independent plot error, so the true entry ",
        "values are available to check the models against -- which is the only ",
        "way to find out how far the diagnostics can be trusted on the real ",
        "trials, where no truth exists. The yields and entries are invented."
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
