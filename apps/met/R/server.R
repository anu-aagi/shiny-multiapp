server <- function(input, output, session) {

  # Cap the highlight selector at four series -- past that, line identity
  # stops being readable even with direct labels.
  observeEvent(input$focus, ignoreNULL = FALSE, {
    if (length(input$focus) > 4) {
      updateSelectInput(session, "focus", selected = input$focus[1:4])
    }
  })

  env_sub <- reactive(met$env[met$env$year %in% as.integer(input$years), ])

  fit <- reactive({
    e <- env_sub()
    validate(need(nrow(e) >= min_env, sprintf(
      "Select at least %d environments to fit the model.", min_env)))
    fa_fit(met$Y[, e$env, drop = FALSE], as.integer(input$k))
  })

  varieties <- reactive(variety_summary(fit()))
  focus <- reactive(intersect(input$focus, met$variety))

  output$n_env <- renderText(nrow(env_sub()))

  # -- Stat tiles ----------------------------------------------------------
  output$tiles <- renderUI({
    f <- fit()
    d <- varieties()
    best <- d[1, ]
    stat_tiles(
      stat_tile("Environments", nrow(env_sub()),
                sprintf("%d sites · mean %.2f t/ha",
                        length(unique(env_sub()$site)), f$grand_mean)),
      stat_tile("Variance explained", sprintf("%.0f%%", f$vaf_total),
                paste0(f$k, if (f$k == 1) " factor" else " factors")),
      stat_tile("Top variety", best$variety,
                sprintf("%+.2f t/ha (%+.1f%%)", best$op, best$op_pct)),
      stat_tile("Most stable", d$variety[which.min(d$rmsd)],
                sprintf("RMSD %.2f", min(d$rmsd)))
    )
  })

  # -- Overall performance against stability -------------------------------
  op_data <- reactive({
    d <- varieties()
    d$sel <- d$variety %in% focus()
    d
  })

  output$op <- renderPlot({
    d <- op_data()
    lab <- d[d$sel | d$rank <= 5 | d$rmsd == max(d$rmsd), ]

    ggplot(d, aes(op, rmsd)) +
      geom_vline(xintercept = 0, colour = pal$axis, linewidth = 0.4) +
      geom_hline(yintercept = median(d$rmsd), colour = pal$axis,
                 linewidth = 0.4, linetype = "22") +
      geom_point(aes(fill = sel), size = 3.6, shape = 21,
                 colour = pal$surface, stroke = 1.1) +
      geom_text(data = lab, aes(label = variety), nudge_y = 0.012,
                size = 3.4, colour = pal$ink2, vjust = 0) +
      scale_fill_manual(values = c(`FALSE` = pal$s1, `TRUE` = pal$s2),
                        guide = "none") +
      scale_x_continuous(labels = function(x) sprintf("%+.1f", x)) +
      labs(
        title = "Overall performance against stability",
        subtitle = paste0("Dashed line is the median RMSD. Highlighted varieties",
                          " in orange. Hover a point for detail."),
        x = "Overall Performance (t/ha relative to the mean variety)",
        y = "RMSD -- deviation from the factor 1 regression (t/ha)",
        caption = paste0("Bottom right: high yielding and dependable. Top right:",
                         " high yielding but season dependent.")
      ) +
      theme_crop()
  }, res = 96)

  output$op_tip <- renderUI({
    h <- input$op_hover
    if (is.null(h)) return(NULL)
    pt <- nearPoints(op_data(), h, xvar = "op", yvar = "rmsd",
                     threshold = 20, maxpoints = 1)
    if (!nrow(pt)) return(NULL)
    hover_tip(
      h,
      tags$b(pt$variety), tags$br(),
      sprintf("Rank %d of %d", pt$rank, n_var), tags$br(),
      sprintf("OP %+.2f t/ha (%+.1f%%)", pt$op, pt$op_pct), tags$br(),
      sprintf("Predicted %.2f t/ha", pt$predicted), tags$br(),
      sprintf("RMSD %.2f · response %.2f", pt$rmsd, pt$response)
    )
  })

  output$summary_table <- renderUI({
    d <- varieties()
    rows <- lapply(seq_len(nrow(d)), function(i) {
      r <- d[i, ]
      tags$tr(
        class = if (r$variety %in% focus()) "current" else NULL,
        tags$td(r$rank), tags$td(tags$b(r$variety)),
        tags$td(sprintf("%.2f", r$predicted)),
        tags$td(sprintf("%+.2f", r$op)),
        tags$td(sprintf("%+.1f%%", r$op_pct)),
        tags$td(sprintf("%.2f", r$rmsd)),
        tags$td(sprintf("%.2f", r$response))
      )
    })
    data_table(
      c("Rank", "Variety", "Predicted t/ha", "OP t/ha", "OP %", "RMSD",
        "Responsiveness"),
      rows
    )
  })

  # -- Latent regression ---------------------------------------------------
  output$lr_plot <- renderPlot({
    f <- fit()
    v <- focus()
    validate(need(length(v) > 0, "Select at least one variety to highlight."))

    lam1 <- f$lam[, 1]
    rng <- range(lam1)
    pts <- do.call(rbind, lapply(v, function(i) data.frame(
      variety = i, loading = lam1, effect = f$eff[i, ],
      stringsAsFactors = FALSE
    )))
    lines <- do.call(rbind, lapply(v, function(i) data.frame(
      variety = i, loading = rng, effect = f$scores[i, 1] * rng,
      stringsAsFactors = FALSE
    )))
    ends <- lines[!duplicated(lines$variety, fromLast = TRUE), ]

    ggplot(pts, aes(loading, effect, colour = variety)) +
      geom_hline(yintercept = 0, colour = pal$axis, linewidth = 0.4) +
      geom_rug(sides = "b", colour = pal$muted, linewidth = 0.3, alpha = 0.7) +
      geom_point(size = 2.6, alpha = 0.55) +
      geom_line(data = lines, linewidth = 0.9) +
      geom_text(data = ends, aes(label = variety), hjust = 0, nudge_x = 0.012,
                size = 3.6, show.legend = FALSE) +
      scale_colour_manual(values = setNames(series_cols[seq_along(v)], v),
                          name = NULL) +
      scale_x_continuous(expand = expansion(mult = c(0.03, 0.12))) +
      labs(
        title = "Latent regression on the first factor",
        subtitle = paste0("Each tick on the base axis is one environment.",
                          " Slope = the variety's responsiveness."),
        x = "Environment loading on factor 1 (t/ha per SD of variety)",
        y = "Variety effect within environment (t/ha)"
      ) +
      theme_crop() +
      theme(legend.position = "top")
  }, res = 96)

  # -- Environments --------------------------------------------------------
  output$load_plot <- renderPlot({
    f <- fit()
    d <- data.frame(
      env = rownames(f$lam), f1 = f$lam[, 1],
      f2 = if (f$k >= 2) f$lam[, 2] else 0,
      stringsAsFactors = FALSE
    )
    d <- merge(d, env_sub()[, c("env", "site", "year", "mean_yield")], by = "env")

    p <- ggplot(d, aes(f1, f2)) +
      geom_hline(yintercept = 0, colour = pal$axis, linewidth = 0.4) +
      geom_vline(xintercept = 0, colour = pal$axis, linewidth = 0.4) +
      geom_point(aes(fill = mean_yield), size = 4, shape = 21,
                 colour = pal$surface, stroke = 1) +
      geom_text(aes(label = env), size = 3, colour = pal$ink2,
                nudge_y = 0.012, check_overlap = TRUE, vjust = 0) +
      scale_fill_gradient(low = pal$seq_lo, high = pal$seq_hi,
                          name = "Trial mean\n(t/ha)") +
      labs(
        title = "Environment loadings",
        subtitle = paste0("Factor 1 rises with how strongly a trial separates",
                          " varieties. Factor 2 splits the trials that reverse",
                          " the ranking."),
        x = "Factor 1 loading", y = "Factor 2 loading"
      ) +
      theme_crop()

    if (f$k < 2) {
      p <- p + labs(y = NULL, subtitle = "Only one factor retained.") +
        theme(axis.text.y = element_blank())
    }
    p
  }, res = 96)

  output$gcor_plot <- renderPlot({
    f <- fit()
    ord <- names(sort(f$lam[, 1]))
    d <- data.frame(
      a = factor(rep(ord, times = length(ord)), levels = ord),
      b = factor(rep(ord, each = length(ord)), levels = ord),
      r = as.vector(f$gcor[ord, ord])
    )
    ggplot(d, aes(a, b, fill = r)) +
      geom_tile(colour = pal$surface, linewidth = 0.5) +
      scale_fill_gradient2(low = pal$div_hi, mid = pal$div_mid,
                           high = pal$div_lo, midpoint = 0,
                           limits = c(-1, 1), name = "Genetic\ncorrelation") +
      coord_fixed() +
      labs(
        title = "Genetic correlation between environments",
        subtitle = paste0("Implied by the factor structure, ordered by factor 1",
                          " loading. Blue pairs rank varieties alike."),
        x = NULL, y = NULL
      ) +
      theme_crop(12) +
      theme(
        panel.grid.major = element_blank(),
        axis.line = element_blank(),
        axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5,
                                   size = rel(0.75)),
        axis.text.y = element_text(size = rel(0.75))
      )
  }, res = 96)

  # -- Download ------------------------------------------------------------
  output$dl <- downloadHandler(
    filename = function() "met-variety-summary.csv",
    content = function(file) {
      d <- varieties()
      d$environments <- nrow(env_sub())
      write.csv(d, file, row.names = FALSE)
    }
  )

  # -- Method note ---------------------------------------------------------
  output$method <- renderUI({
    f <- fit()
    vaf <- f$vaf_factor[seq_len(f$k)]
    tagList(
      tags$h4("What is being fitted"),
      tags$p(HTML(paste0(
        "The variety-by-environment table of predicted means is centred within ",
        "each environment, then decomposed as <code>u<sub>ij</sub> = ",
        "&Sigma;<sub>k</sub> &lambda;<sub>jk</sub> f<sub>ik</sub> + ",
        "&delta;<sub>ij</sub></code>, with &lambda; the environment loadings, ",
        "f the variety scores and &delta; the environment-specific residual. ",
        "This is the factor analytic variance structure of Smith et al. (2015), ",
        "recovered here by singular value decomposition because the input is ",
        "already a table of trial means rather than plot data."
      ))),
      tags$h4("Current fit"),
      tags$p(HTML(paste0(
        sprintf("%d environments, %d varieties, %d factor%s. ", nrow(env_sub()),
                n_var, f$k, if (f$k == 1) "" else "s"),
        paste(sprintf("Factor %d accounts for %.1f%%", seq_along(vaf), vaf),
              collapse = "; "),
        sprintf("; %.1f%% in total.", f$vaf_total)
      ))),
      tags$h4("Overall Performance and RMSD"),
      tags$p(HTML(paste0(
        "OP<sub>i</sub> = mean(&lambda;<sub>1</sub>) &times; f<sub>i1</sub> is ",
        "the variety's yield advantage averaged over the environments in the ",
        "selection, on the t/ha scale. RMSD<sub>i</sub> is the root mean square ",
        "distance between the variety's actual effects and the first-factor ",
        "regression line, so it measures unpredictability rather than low yield. ",
        "A grower reads OP first and uses RMSD to decide how much of the crop ",
        "to commit."
      ))),
      tags$h4("Data"),
      tags$p(paste0(
        "All values are simulated from a known FA(2) process with a fixed seed. ",
        "Site names are real locations but the yields, varieties and ",
        "loadings are invented; nothing here should be read as a variety ",
        "recommendation."
      )),
      tags$h4("Reference"),
      tags$p(paste0(
        "Smith AB, Ganesalingam A, Kuchel H, Cullis BR (2015). Factor analytic ",
        "mixed models for the provision of grower information from national ",
        "crop variety testing programs. Theoretical and Applied Genetics ",
        "128:55-72. doi:10.1007/s00122-014-2412-x"
      ))
    )
  })
}
