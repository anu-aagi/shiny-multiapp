# Where the data sits, how small a selection may get, and the one environment
# variable the page reads.
#
# These live here rather than in global.R so that every object the app uses
# sits in the same environment as the functions that use them -- global.R is
# sourced into the global environment, which is not always on the search path
# when the app is loaded for testing.
#
# The size of the trial series is not fixed here: it is whatever the data file
# holds, so R/data.R defines `years` and `n_var` once it has read it.

# Shiny runs an app with its own directory as the working directory, but the
# analysis code is also meant to be sourced from the repository root (see the
# README), so look for the data file both ways.
data_path <- function(file) {
  here <- file.path("data", file)
  if (file.exists(here)) return(here)
  from_root <- file.path("apps", "met", "data", file)
  if (file.exists(from_root)) return(from_root)
  stop("cannot find data file: ", file, call. = FALSE)
}

# Fewer environments than this and the loadings are fitted to almost nothing,
# so the app asks for a wider selection instead of fitting.
min_env <- 4L

# Where the "All applications" link points. Behind the nginx proxy the hub is
# at /hub/; set HUB_URL when running the apps directly on bare ports.
hub_url <- Sys.getenv("HUB_URL", unset = "/hub/")
