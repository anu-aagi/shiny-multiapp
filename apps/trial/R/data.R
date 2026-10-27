# Two kinds of trial, in one list.
#
# The six REAL trials are published field results: 64 corn hybrids grown in six
# North Carolina counties, each an 18 row by 11 range lattice in 3 replicates.
#
#   Besag J, Higdon D (1999). Bayesian analysis of agricultural field
#   experiments. Journal of the Royal Statistical Society Series B 61:691-746,
#   Table 1. Used with permission of David Higdon; redistributed in the agridat
#   package. data-raw/extract.R writes the CSV.
#
# Each county is short the six plots it actually lost, so a real field map has
# holes in it, and the source does not state the unit yield is measured in --
# hence `unit = NULL`, which the page reads as "leave the unit off the labels".
#
# The three SIMULATED trials have fixed seeds and a known spatial trend, so the
# right answer is available for comparison -- which is the only way to see which
# of the diagnostics deserve to be trusted on the real ones.

# -- The real trials -------------------------------------------------------

# What each field turns out to show, once the four models have been fitted to
# it. These are the reason all six are here rather than one.
county_notes <- c(
  C1 = "A strong pattern across the whole field. Every rung of the ladder still
        buys precision, and repeatability climbs from almost nothing to better
        than two thirds.",
  C2 = "Replicate blocking buys close to nothing here: the structure cuts
        across the replicates, so block means cannot reach it and only a
        surface or free row and range terms move the residual.",
  C3 = "The opposite case. Blocking does most of the work, and the cubic
        surface is actually worse than the replicate means -- what is on this
        ground is block-shaped, not smooth.",
  C4 = "A mild pattern, with modest gains all the way up the ladder and no
        rung that clearly settles it.",
  C5 = "A smooth pattern that the surface removes almost entirely. Going on to
        free row and range terms shaves the residual again, but the LSD gets
        worse and repeatability does not improve: degrees of freedom spent for
        nothing.",
  C6 = "The noisiest field: repeatability starts at zero, and even free row and
        range terms leave a positive neighbour correlation. Much of what
        happened here was never spatial."
)

load_real_trials <- function(path = data_path("besag-met.csv")) {
  d <- read.csv(path, stringsAsFactors = FALSE)
  d$entry <- factor(d$entry)
  d$rep <- factor(d$rep)

  lapply(split(d, d$county), function(s) {
    cty <- s$county[1]
    s <- s[order(s$col, s$row), c("row", "col", "rep", "entry", "yield")]
    rownames(s) <- NULL
    list(
      label = sprintf("North Carolina county %s · corn", sub("^C", "", cty)),
      note = county_notes[[cty]],
      real = TRUE,
      unit = NULL,
      data = s,
      g_true = NULL
    )
  })
}

# -- The simulated trials --------------------------------------------------

sim_specs <- list(
  gradient = list(
    label = "Simulated · slope gradient",
    note  = "A strong soil-depth gradient running down each range. The
             replicates are blocks of ranges, so they lie parallel to the
             gradient and blocking alone buys almost nothing.",
    seed = 101, amp = 1.00, sd_g = 0.32, sd_e = 0.22, kind = "gradient"
  ),
  patchy = list(
    label = "Simulated · patchy",
    note  = "Two wet patches and a dry corner. The pattern cuts across the
             replicates, so block means cannot remove it and a surface is needed.",
    seed = 202, amp = 0.95, sd_g = 0.30, sd_e = 0.20, kind = "patchy"
  ),
  clean = list(
    label = "Simulated · uniform block",
    note  = "An even block with little spatial structure. Here the elaborate
             models only spend degrees of freedom for nothing.",
    seed = 303, amp = 0.18, sd_g = 0.34, sd_e = 0.21, kind = "gradient"
  )
)

# The smooth pattern the ground puts on the plots, centred so it does not move
# the trial mean.
field_trend <- function(row, col, kind) {
  r <- (row - 1) / (SIM_ROW - 1)
  cc <- (col - 1) / (SIM_COL - 1)
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
  entry <- sprintf("E%02d", seq_len(SIM_VAR))
  g <- rnorm(SIM_VAR, 0, spec$sd_g)
  names(g) <- entry

  # Three replicates of three ranges each; entries randomised within replicate.
  d <- expand.grid(row = seq_len(SIM_ROW), col = seq_len(SIM_COL))
  d$rep <- factor(ceiling(d$col / 3))
  d <- d[order(d$rep, d$col, d$row), ]
  d$entry <- unlist(lapply(seq_len(SIM_REP), function(i) sample(entry)))
  d$entry <- factor(d$entry, levels = entry)

  d$trend <- spec$amp * field_trend(d$row, d$col, spec$kind)
  d$yield <- 4.10 + g[as.character(d$entry)] + d$trend +
    rnorm(nrow(d), 0, spec$sd_e)
  rownames(d) <- NULL

  list(label = spec$label, note = spec$note, real = FALSE, unit = "t/ha",
       data = d, g_true = g)
}

# -- Both, keyed for the selector -----------------------------------------

trials <- c(
  load_real_trials(),
  setNames(lapply(sim_specs, simulate_trial), paste0("sim_", names(sim_specs)))
)

# Two groups in the dropdown, so it is never in doubt which kind is on screen.
trial_choices <- local({
  real <- vapply(trials, `[[`, TRUE, "real")
  lab <- vapply(trials, `[[`, "", "label")
  list(
    "Real trials (Besag & Higdon 1999)" = setNames(names(trials)[real],
                                                   lab[real]),
    "Simulated trials (truth known)" = setNames(names(trials)[!real],
                                                lab[!real])
  )
})

# A unit to hang on an axis label or a tile, empty when the source never said
# what yield was measured in.
unit_suffix <- function(tr, open = " (", close = ")") {
  if (is.null(tr$unit)) "" else paste0(open, tr$unit, close)
}
