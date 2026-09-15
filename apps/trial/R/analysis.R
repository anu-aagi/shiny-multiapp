# The statistics: the ladder of spatial models, the least-squares means fitted
# under each, and the diagnostics used to choose between them.

# Four models, from ignoring the ground entirely to a free constant for every
# row and range. Each rung buys flexibility with degrees of freedom.
models <- list(
  none   = list(label = "Entry means only",
                terms = character(0),
                blurb = "No allowance for position. Every plot is treated as if
                         the ground were uniform."),
  rcb    = list(label = "Replicate blocks (RCB)",
                terms = "rep",
                blurb = "The classical randomised complete block analysis: one
                         constant per replicate."),
  smooth = list(label = "Smooth surface",
                terms = c("poly(row, 3)", "poly(col, 3)", "row:col"),
                blurb = "A cubic surface in both directions. Handles curvature
                         and patches that cut across the replicates."),
  rowcol = list(label = "Rows and ranges as factors",
                terms = c("factor(row)", "factor(col)"),
                blurb = "A free constant for every row and every range. The most
                         flexible option, and the most expensive in degrees of
                         freedom.")
)

# Lag-1 correlation between the residuals of neighbouring plots, averaged over
# the two directions. Near zero means the model has taken the spatial structure
# out; a clearly positive value means trend is still sitting in the residual.
neighbour_cor <- function(d) {
  m <- matrix(NA_real_, N_ROW, N_COL)
  m[cbind(d$row, d$col)] <- d$resid
  mean(c(
    cor(as.vector(m[-N_ROW, ]), as.vector(m[-1, ]), use = "complete.obs"),
    cor(as.vector(m[, -N_COL]), as.vector(m[, -1]), use = "complete.obs")
  ))
}

# Fit one model and return everything the app reports from it.
#
# Entry means are least-squares means: every non-entry term is held at its
# average over the whole design, so the means do not depend on which plots an
# entry happened to occupy and stay comparable across the models.
fit_model <- function(d, key) {
  spec <- models[[key]]
  rhs <- paste(c("entry", spec$terms), collapse = " + ")
  fit <- lm(as.formula(paste("yield ~", rhs)), data = d)

  X <- model.matrix(fit)
  keep <- !is.na(coef(fit))
  b <- coef(fit)[keep]
  V <- vcov(fit)

  # One row of the contrast matrix per entry: design averages everywhere,
  # except the entry columns, which carry that entry's indicator.
  lv <- levels(d$entry)
  L <- matrix(rep(colMeans(X)[keep], length(lv)), nrow = length(lv), byrow = TRUE)
  colnames(L) <- colnames(X)[keep]
  ecols <- grep("^entry", colnames(L))
  if (length(ecols)) L[, ecols] <- 0
  for (i in seq_along(lv)) {
    j <- match(paste0("entry", lv[i]), colnames(L))
    if (!is.na(j)) L[i, j] <- 1
  }

  est <- as.vector(L %*% b)
  C <- L %*% V %*% t(L)                      # covariance of the entry means
  se <- sqrt(pmax(diag(C), 0))

  # Pairwise standard errors of difference, then the average LSD at 5%.
  sed2 <- outer(diag(C), diag(C), "+") - 2 * C
  sed <- sqrt(pmax(sed2[upper.tri(sed2)], 0))
  dfr <- df.residual(fit)
  lsd <- qt(0.975, dfr) * mean(sed)

  # Variety variance net of estimation error gives a repeatability for the
  # trial: how much of the spread between entry means is real.
  ms_e <- mean(se^2)
  v_obs <- var(est)
  v_g <- max(v_obs - ms_e, 0)
  h2 <- if (v_obs > 0) v_g / (v_g + ms_e) else NA_real_

  means <- data.frame(entry = lv, adjusted = est, se = se,
                      stringsAsFactors = FALSE)
  means$rank <- rank(-means$adjusted, ties.method = "min")

  d$resid <- residuals(fit)
  # The spatial part of the fit: everything except the entry contribution.
  Xs <- X[, keep, drop = FALSE]
  ec <- grep("^entry", colnames(Xs))
  if (length(ec)) Xs[, ec] <- 0
  d$spatial <- as.vector(Xs %*% b)
  d$spatial <- d$spatial - mean(d$spatial)

  list(
    key = key, label = spec$label, formula = formula(fit), data = d,
    means = means, sigma = sigma(fit), df = dfr, lsd = lsd, h2 = h2,
    aic = AIC(fit), cv = 100 * sigma(fit) / mean(d$yield), n_par = sum(keep),
    nb = neighbour_cor(d)
  )
}

# One row per model for the comparison tab. Accuracy is the correlation with
# the true simulated genetic values -- available only because the data is
# simulated, but it shows which of the other diagnostics are worth trusting.
compare_models <- function(d, g_true) {
  do.call(rbind, lapply(names(models), function(k) {
    f <- fit_model(d, k)
    data.frame(
      key = k, model = f$label, n_par = f$n_par, sigma = f$sigma,
      lsd = f$lsd, h2 = f$h2, nb = f$nb, aic = f$aic,
      accuracy = cor(f$means$adjusted, g_true[f$means$entry]),
      stringsAsFactors = FALSE
    )
  }))
}
