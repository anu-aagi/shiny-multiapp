# MET Explorer -- multi-environment crop variety trial analysis.
#
# A variety-by-environment table of predicted means is decomposed into a small
# number of factors; the first factor gives each variety an Overall Performance
# (OP) score, and departure from that factor's regression gives a stability
# measure (RMSD). Growers read the two together. Method follows Smith,
# Ganesalingam, Kuchel & Cullis (2015) -- see R/analysis.R and the Method tab.
#
# Data is SIMULATED from a known FA(2) process with a fixed seed. Nothing here
# is a real variety or a real trial result.

library(shiny)
library(ggplot2)

# The app's files, in the order they have to be sourced: each one uses what the
# ones above it defined. Shiny's own auto-loading is turned off in
# R/_disable_autoload.R, because it sorts the directory alphabetically and
# never sources global.R for an app.R-style app -- which leaves nowhere to
# attach ggplot2 before R/theme.R needs it.
for (f in c(
  "constants",  # years, variety count and the hub link
  "theme",      # chart palette and ggplot theme
  "analysis",   # the factor analytic decomposition and variety summary
  "data",       # the simulated trial series (fits a model for its defaults)
  "layout",     # ANU page chrome and small UI helpers
  "server",     # reactives and outputs
  "ui"          # the page itself (needs the series above)
)) {
  source(file.path("R", paste0(f, ".R")), local = TRUE)
}

# Page styling lives in apps/www/app.css, shared with the other app.

shinyApp(ui, server)
