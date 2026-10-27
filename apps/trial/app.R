# Field Trial Analyser -- single-site variety trial with spatial adjustment.
#
# A yield trial is laid out on a grid, and the ground underneath it is never
# uniform. Soil, slope, an old fence line or the header's run all leave a smooth
# pattern across the plots that has nothing to do with the varieties sown in
# them. Fitting that pattern and removing it is what separates a variety's
# genetic merit from where it happened to land.
#
# This app lets you choose how much of that structure to model and shows what
# the choice does to the variety means, to the precision of the trial, and to
# the residuals left on the ground. Adjusted means from an analysis like this
# are the input to a multi-environment analysis -- see the MET Explorer.
#
# Six of the trials are real published results -- 64 corn hybrids in six North
# Carolina counties, from Besag & Higdon (1999) by way of the agridat package.
# Three more are simulated with fixed seeds from a known spatial trend, and they
# stay because they are the only place the true entry values are available: they
# are how you find out which of the diagnostics to trust on the real six, where
# there is nothing to check against. See R/data.R.

library(shiny)
library(ggplot2)

# The app's files, in the order they have to be sourced: each one uses what the
# ones above it defined. Shiny's own auto-loading is turned off in
# R/_disable_autoload.R, because it sorts the directory alphabetically and
# never sources global.R for an app.R-style app -- which leaves nowhere to
# attach ggplot2 before R/theme.R needs it.
for (f in c(
  "constants",  # where the data file is, simulator sizes, the hub link
  "theme",      # chart palette and ggplot theme
  "analysis",   # the spatial models, least-squares means, diagnostics
  "data",       # the six real trials and the three simulated ones
  "layout",     # ANU page chrome and small UI helpers
  "server",     # reactives and outputs
  "ui"          # the page itself (needs the models and trials above)
)) {
  source(file.path("R", paste0(f, ".R")), local = TRUE)
}

# Page styling lives in apps/www/app.css, shared with the other app.

shinyApp(ui, server)
