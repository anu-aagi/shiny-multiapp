# Three simulated trials with fixed seeds and a known spatial trend, so the
# right answer is available for comparison. Nothing here is a real result.

trials <- list(
  gradient = list(
    label = "Ginninderra 2024 · slope gradient",
    note  = "A strong soil-depth gradient running down each range. The
             replicates are blocks of ranges, so they lie parallel to the
             gradient and blocking alone buys almost nothing.",
    seed = 101, amp = 1.00, sd_g = 0.32, sd_e = 0.22, kind = "gradient"
  ),
  patchy = list(
    label = "Wagga Wagga 2024 · patchy",
    note  = "Two wet patches and a dry corner. The pattern cuts across the
             replicates, so block means cannot remove it and a surface is needed.",
    seed = 202, amp = 0.95, sd_g = 0.30, sd_e = 0.20, kind = "patchy"
  ),
  clean = list(
    label = "Horsham 2024 · uniform block",
    note  = "An even block with little spatial structure. Here the elaborate
             models only spend degrees of freedom for nothing.",
    seed = 303, amp = 0.18, sd_g = 0.34, sd_e = 0.21, kind = "gradient"
  )
)

# The smooth pattern the ground puts on the plots, centred so it does not move
# the trial mean.
field_trend <- function(row, col, kind) {
  r <- (row - 1) / (N_ROW - 1)
  cc <- (col - 1) / (N_COL - 1)
  z <- switch(
    kind,
    gradient = 0.90 * (1 - r) + 0.30 * sin(pi * cc) - 0.25 * r^2,
    patchy = {
      bump <- function(r0, c0, s) exp(-((r - r0)^2 + (cc - c0)^2) / (2 * s^2))
      0.85 * bump(0.25, 0.70, 0.20) + 0.60 * bump(0.80, 0.20, 0.17) -
        0.75 * bump(0.15, 0.10, 0.15)
    }
  )
  z - mean(z)
}

# Yield = trial mean + genetic effect + spatial trend + independent plot error.
simulate_trial <- function(spec) {
  set.seed(spec$seed)
  entry <- sprintf("E%02d", seq_len(N_VAR))
  g <- rnorm(N_VAR, 0, spec$sd_g)
  names(g) <- entry

  # Three replicates of three ranges each; entries randomised within replicate.
  d <- expand.grid(row = seq_len(N_ROW), col = seq_len(N_COL))
  d$rep <- factor(ceiling(d$col / 3))
  d <- d[order(d$rep, d$col, d$row), ]
  d$entry <- unlist(lapply(seq_len(N_REP), function(i) sample(entry)))
  d$entry <- factor(d$entry, levels = entry)

  d$trend <- spec$amp * field_trend(d$row, d$col, spec$kind)
  d$yield <- 4.10 + g[as.character(d$entry)] + d$trend +
    rnorm(nrow(d), 0, spec$sd_e)
  rownames(d) <- NULL
  list(data = d, g_true = g, spec = spec)
}

sims <- lapply(trials, simulate_trial)
