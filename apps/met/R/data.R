# A simulated trial series: ten sites over three harvest years, generated from
# a known FA(2) process with a fixed seed. Site names are real locations; the
# yields, varieties and loadings are invented.

sites <- data.frame(
  site   = c("Ginninderra", "Wagga Wagga", "Narrabri", "Horsham", "Katanning",
             "Merredin", "Roseworthy", "Dalby", "Mingenew", "Tamworth"),
  code   = c("GIN", "WAG", "NAR", "HOR", "KAT",
             "MER", "ROS", "DAL", "MIN", "TAM"),
  region = c("NSW South", "NSW South", "NSW North", "Victoria", "WA South",
             "WA East", "SA", "Queensland", "WA North", "NSW North"),
  base   = c(4.6, 5.1, 3.2, 4.3, 3.6, 2.2, 3.9, 2.8, 2.6, 3.4),
  stringsAsFactors = FALSE
)

simulate_met <- function() {
  set.seed(20150128)

  env <- expand.grid(year = years, site = sites$site, stringsAsFactors = FALSE)
  env <- merge(env, sites, by = "site")
  env <- env[order(env$region, env$site, env$year), ]
  env$env <- paste0(env$code, substr(env$year, 3, 4))
  rownames(env) <- NULL
  p <- nrow(env)

  # Season effect: 2022 wet and kind, 2023 dry in the west.
  season <- c(`2021` = 0.0, `2022` = 0.9, `2023` = -0.6)
  west <- env$region %in% c("WA South", "WA East", "WA North", "SA")
  env$mean_yield <- env$base + season[as.character(env$year)] +
    ifelse(west & env$year == 2023, -0.5, 0) +
    rnorm(p, 0, 0.28)
  env$mean_yield <- pmax(env$mean_yield, 0.8)

  # Factor 1 loadings scale with site productivity: high-yielding trials
  # discriminate between varieties more strongly. Factor 2 separates the
  # short-season western trials from the long-season eastern ones.
  lam1 <- 0.04 + 0.085 * env$mean_yield + rnorm(p, 0, 0.025)
  lam2 <- ifelse(west, 0.18, -0.13) + rnorm(p, 0, 0.07)
  env$psi <- runif(p, 0.015, 0.075)   # environment-specific variance

  variety <- sprintf("V%02d", seq_len(n_var))
  scores <- cbind(rnorm(n_var, 0, 1), rnorm(n_var, 0, 1))

  eff <- scores %*% rbind(lam1, lam2) +
    matrix(rnorm(n_var * p, 0, rep(sqrt(env$psi), each = n_var)), n_var, p)

  Y <- sweep(eff, 2, env$mean_yield, "+")
  dimnames(Y) <- list(variety, env$env)
  list(Y = pmax(Y, 0.1), env = env, variety = variety)
}

met <- simulate_met()

# Open on two strong performers and the least dependable variety, so the
# contrast the app is about is visible before anything is clicked.
default_varieties <- local({
  f <- fa_fit(met$Y, 2)
  c(names(sort(f$op, decreasing = TRUE))[1:2],
    names(sort(f$rmsd, decreasing = TRUE))[1])
})
