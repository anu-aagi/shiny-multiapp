# Where the data sits, the geometry of the simulated trials, and the one
# environment variable the page reads.
#
# These live here rather than in global.R so that every object the app uses
# sits in the same environment as the functions that use them -- global.R is
# sourced into the global environment, which is not always on the search path
# when the app is loaded for testing.
#
# The real trials and the simulated ones are not the same size, so nothing here
# fixes the geometry of a trial being analysed: `trial_dims()` in R/analysis.R
# reads it off whichever trial is loaded. The SIM_ constants below size the
# simulator only.

# Shiny runs an app with its own directory as the working directory, but the
# analysis code is also meant to be sourced from the repository root (see the
# README), so look for the data file both ways.
data_path <- function(file) {
  here <- file.path("data", file)
  if (file.exists(here)) return(here)
  from_root <- file.path("apps", "trial", "data", file)
  if (file.exists(from_root)) return(from_root)
  stop("cannot find data file: ", file, call. = FALSE)
}

# The simulated trials: plots (rows) sit within ranges (columns), and three
# consecutive ranges make one replicate.
SIM_ROW <- 12L
SIM_COL <- 9L
SIM_VAR <- 36L
SIM_REP <- 3L

# Where the "All applications" link points. Behind the nginx proxy the hub is
# at /hub/; set HUB_URL when running the apps directly on bare ports.
hub_url <- Sys.getenv("HUB_URL", unset = "/hub/")
