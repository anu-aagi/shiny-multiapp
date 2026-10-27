# A real trial series: 28 Western Australian spring wheat cultivars released
# between 1860 and 1982, grown in 20 trials over four years in the central and
# eastern wheatbelt.
#
#   Perry MW, D'Antuono MF (1989). Yield improvement and associated
#   characteristics of some Australian spring wheat cultivars introduced
#   between 1860 and 1982. Australian Journal of Agricultural Research
#   40:457-472. Used with permission of Mario D'Antuono and CSIRO Publishing;
#   redistributed in the agridat package.
#
# data-raw/extract.R writes the CSV: yields converted from kg/ha to t/ha, and
# the five cultivars with a missing cell dropped so the variety-by-environment
# table is complete -- the factor analytic decomposition is a singular value
# decomposition and cannot be taken of a table with holes in it. That leaves 23
# cultivars measured in every one of the 20 environments.
#
# An environment is a site by year combination. Wongan Hills was sown early and
# late in 1979 and 1980, and the Merredin 1979 pair is probably the same, so
# those labels carry a suffix. Site names are the source's three-letter codes.

load_met <- function(path = data_path("perry-springwheat.csv")) {
  d <- read.csv(path, stringsAsFactors = FALSE)

  env <- unique(d[, c("env_label", "env", "year", "site")])
  names(env) <- c("env", "code", "year", "site")
  env <- env[order(env$year, env$code), ]
  rownames(env) <- NULL

  variety <- sort(unique(d$gen))
  Y <- matrix(NA_real_, length(variety), nrow(env),
              dimnames = list(variety, env$env))
  Y[cbind(match(d$gen, variety), match(d$env_label, env$env))] <- d$yield
  stopifnot(!anyNA(Y))

  # The trial mean, used to colour the loadings plot and to say how good a
  # season each environment was.
  env$mean_yield <- as.vector(colMeans(Y))

  # Year of release, one value per cultivar: this series was assembled to
  # measure genetic gain, so it is worth carrying through to the table.
  yor <- d$yor[match(variety, d$gen)]
  names(yor) <- variety

  list(Y = Y, env = env, variety = variety, yor = yor)
}

met <- load_met()

# The span of the series, read off the data rather than fixed, so replacing the
# CSV with another series does not need these edited too.
years <- sort(unique(met$env$year))
n_var <- length(met$variety)

# Open on two strong performers and the least dependable cultivar, so the
# contrast the app is about is visible before anything is clicked.
default_varieties <- local({
  f <- fa_fit(met$Y, 2)
  c(names(sort(f$op, decreasing = TRUE))[1:2],
    names(sort(f$rmsd, decreasing = TRUE))[1])
})
