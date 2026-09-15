# The statistics: the factor analytic decomposition of the variety by
# environment table, and the two numbers a grower reads off it.
#
# Method follows Smith, Ganesalingam, Kuchel & Cullis (2015), "Factor analytic
# mixed models for the provision of grower information from national crop
# variety testing programs", Theor Appl Genet 128:55-72. The paper fits the
# factor analytic structure inside a mixed model; here the input is already a
# table of per-trial predicted variety means (stage-two input), so the same
# structure is recovered by singular value decomposition of the centred table
# -- identical algebra, no extra package needed.

# Y: varieties x environments table of predicted means (t/ha).
# Returns loadings on the t/ha scale and variety scores standardised to unit
# variance, so a loading reads as "t/ha per standard deviation of variety".
fa_fit <- function(Y, k) {
  m <- nrow(Y)
  eff <- sweep(Y, 2, colMeans(Y))          # variety effects within environment
  sv <- svd(eff)
  k <- min(k, length(sv$d), m - 1L)

  lam <- sv$v[, seq_len(k), drop = FALSE] *
    rep(sv$d[seq_len(k)], each = ncol(Y)) / sqrt(m)
  scores <- sv$u[, seq_len(k), drop = FALSE] * sqrt(m)

  # Rotate each factor so its loadings are predominantly positive; otherwise
  # the sign of "good" is arbitrary and the plots read backwards.
  for (j in seq_len(k)) {
    if (sum(lam[, j]) < 0) {
      lam[, j] <- -lam[, j]
      scores[, j] <- -scores[, j]
    }
  }
  rownames(lam) <- colnames(Y)
  rownames(scores) <- rownames(Y)
  colnames(lam) <- colnames(scores) <- paste0("F", seq_len(k))

  resid <- eff - scores %*% t(lam)

  # Variance accounted for, overall and by factor.
  vaf_factor <- 100 * sv$d^2 / sum(sv$d^2)

  # Genetic covariance between environments implied by the factor structure.
  psi <- colMeans(resid^2)
  gcov <- lam %*% t(lam) + diag(psi, ncol(Y))
  dimnames(gcov) <- list(colnames(Y), colnames(Y))

  # Overall Performance and stability, both from the first factor only.
  op <- mean(lam[, 1]) * scores[, 1]
  rmsd <- sqrt(rowMeans((eff - outer(scores[, 1], lam[, 1]))^2))

  list(
    eff = eff, lam = lam, scores = scores, k = k,
    vaf_factor = vaf_factor, vaf_total = sum(vaf_factor[seq_len(k)]),
    gcor = cov2cor(gcov), psi = psi,
    op = op, rmsd = rmsd, grand_mean = mean(colMeans(Y))
  )
}

# One row per variety: what the tables, tiles and scatter all read from.
variety_summary <- function(f) {
  d <- data.frame(
    variety = names(f$op),
    op = as.vector(f$op),
    op_pct = 100 * as.vector(f$op) / f$grand_mean,
    predicted = f$grand_mean + as.vector(f$op),
    rmsd = as.vector(f$rmsd),
    response = as.vector(f$scores[, 1]),
    stringsAsFactors = FALSE
  )
  d$rank <- rank(-d$op, ties.method = "min")
  d[order(-d$op), ]
}
