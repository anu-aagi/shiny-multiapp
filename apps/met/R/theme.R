# Chart colours and the ggplot theme. The page chrome is in www/app.css.
#
# The series colours are a colour-vision-validated set, deliberately separate
# from the ANU gold in the page styling -- gold is not a safe basis for a
# categorical or diverging data scale.

pal <- list(
  surface = "#ffffff", ink = "#000000", ink2 = "#333333", muted = "#5c5c5c",
  grid = "#e8e8e8", axis = "#d5d5d5",
  s1 = "#2a78d6", s2 = "#eb6834", s3 = "#1baf7a", s4 = "#eda100",
  seq_lo = "#cde2fb", seq_hi = "#0d366b",
  div_lo = "#2a78d6", div_mid = "#f0efec", div_hi = "#e34948"
)

# Up to four highlighted varieties are drawn as separate series; past that,
# line identity stops being readable even with direct labels.
series_cols <- c(pal$s1, pal$s2, pal$s3, pal$s4)

# renderPlot() rasterises server-side, so the graphics device cannot use the
# web font the browser loads -- Public Sans has to be installed on the machine.
# The Docker image installs it; fall back to the device default anywhere it is
# missing rather than emitting a font warning per plot.
plot_family <- local({
  have <- tryCatch({
    if (requireNamespace("systemfonts", quietly = TRUE)) {
      any(systemfonts::system_fonts()$family == "Public Sans")
    } else if (nzchar(Sys.which("fc-list"))) {
      any(grepl("Public Sans", system2("fc-list", stdout = TRUE), fixed = TRUE))
    } else {
      FALSE
    }
  }, error = function(e) FALSE)
  if (isTRUE(have)) "Public Sans" else ""
})

# geom_text does not inherit the theme's family, so set it once here; this
# covers annotate("text", ...) too, which draws with the same geom.
if (nzchar(plot_family)) {
  update_geom_defaults("text", list(family = plot_family))
}

theme_crop <- function(base = 13) {
  theme_minimal(base_size = base, base_family = plot_family) +
    theme(
      plot.background   = element_rect(fill = pal$surface, colour = NA),
      panel.background  = element_rect(fill = pal$surface, colour = NA),
      panel.grid.major  = element_line(colour = pal$grid, linewidth = 0.3),
      panel.grid.minor  = element_blank(),
      axis.line         = element_line(colour = pal$axis, linewidth = 0.4),
      axis.ticks        = element_blank(),
      axis.text         = element_text(colour = pal$muted, size = rel(0.85)),
      axis.title        = element_text(colour = pal$ink2, size = rel(0.9)),
      plot.title        = element_text(colour = pal$ink, size = rel(1.1)),
      plot.subtitle     = element_text(colour = pal$ink2, size = rel(0.85),
                                       margin = margin(b = 12)),
      plot.caption      = element_text(colour = pal$muted, size = rel(0.75),
                                       hjust = 0, margin = margin(t = 10)),
      legend.title      = element_text(colour = pal$ink2, size = rel(0.8)),
      legend.text       = element_text(colour = pal$ink2, size = rel(0.8)),
      strip.text        = element_text(colour = pal$ink2, size = rel(0.85)),
      plot.margin       = margin(12, 16, 12, 12)
    )
}
