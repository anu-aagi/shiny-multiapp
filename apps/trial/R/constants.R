# Trial geometry and the one environment variable the page reads.
#
# These live here rather than in global.R so that every object the app uses
# sits in the same environment as the functions that use them -- global.R is
# sourced into the global environment, which is not always on the search path
# when the app is loaded for testing.

# Plots (rows) sit within ranges (columns); three consecutive ranges make one
# replicate, so the whole trial is N_ROW x N_COL plots.
N_ROW <- 12L
N_COL <- 9L
N_VAR <- 36L
N_REP <- 3L

# Where the "All applications" link points. Behind the nginx proxy the hub is
# at /hub/; set HUB_URL when running the apps directly on bare ports.
hub_url <- Sys.getenv("HUB_URL", unset = "/hub/")
