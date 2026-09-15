# The size of the trial series and the one environment variable the page reads.
#
# These live here rather than in global.R so that every object the app uses
# sits in the same environment as the functions that use them -- global.R is
# sourced into the global environment, which is not always on the search path
# when the app is loaded for testing.

years <- 2021:2023
n_var <- 25L

# Fewer environments than this and the loadings are fitted to almost nothing,
# so the app asks for a wider selection instead of fitting.
min_env <- 4L

# Where the "All applications" link points. Behind the nginx proxy the hub is
# at /hub/; set HUB_URL when running the apps directly on bare ports.
hub_url <- Sys.getenv("HUB_URL", unset = "/hub/")
