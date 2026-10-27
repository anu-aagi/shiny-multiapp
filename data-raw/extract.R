# Builds the two CSVs the apps read, from published trial data in the agridat
# package. Run from the repository root:
#
#   Rscript data-raw/extract.R
#
# agridat is needed here and nowhere else: the CSVs it writes are committed, so
# the apps themselves (and the Docker images) still need only shiny and ggplot2.
#
#   install.packages("agridat")
#
# Both datasets are real, published field results, redistributed by agridat
# (GPL-2) with the permission noted in its help pages. Sources:
#
#   apps/trial/data/besag-met.csv
#     Besag J, Higdon D (1999). Bayesian analysis of agricultural field
#     experiments. J R Stat Soc Series B 61:691-746, Table 1.
#     doi:10.1111/1467-9868.00201. 64 corn hybrids in six North Carolina
#     counties, each an 18 row x 11 column lattice of plots in 3 replicates
#     with 8 incomplete blocks. Used with permission of David Higdon.
#
#   apps/met/data/perry-springwheat.csv
#     Perry MW, D'Antuono MF (1989). Yield improvement and associated
#     characteristics of some Australian spring wheat cultivars introduced
#     between 1860 and 1982. Aust J Agric Res 40:457-472. 28 cultivars in 20
#     trials over four years in the central and eastern wheatbelt of Western
#     Australia. Used with permission of Mario D'Antuono and CSIRO Publishing.

library(agridat)

out <- function(app, file) {
  dir <- file.path("apps", app, "data")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  file.path(dir, file)
}

# -- Single-trial data: six real fields, one design ------------------------
#
# agridat pads each county out to a full 18x11 rectangle so that asreml can fit
# AR1xAR1 on it: the six plots each county is actually missing are present as
# rows with a missing yield and a genotype of G01 that was never sown there.
# Those rows are dropped, which is why each county has 192 plots and not 198 --
# the field map is meant to show the holes the trial really had.

trial <- besag.met
stopifnot(nrow(trial) == 1188, nlevels(trial$gen) == 64)

trial <- trial[!is.na(trial$yield), c("county", "row", "col", "rep", "block",
                                      "gen", "yield")]
names(trial)[names(trial) == "gen"] <- "entry"
trial <- trial[order(trial$county, trial$col, trial$row), ]

stopifnot(
  nrow(trial) == 1152,
  tapply(trial$entry, trial$county, function(x) length(unique(x))) == 64,
  tapply(trial$row, trial$county, max) == 18,
  tapply(trial$col, trial$county, max) == 11
)

write.csv(trial, out("trial", "besag-met.csv"), row.names = FALSE)

# -- Multi-environment data: 20 Western Australian wheat trials -----------
#
# The factor analytic decomposition is a singular value decomposition of the
# variety-by-environment table, so the table has to be complete. Fourteen of
# the 560 cells are missing, spread over five cultivars; those five are dropped
# rather than filled, leaving 23 cultivars measured in all 20 environments.
#
# Yields are published in kg/ha and converted to t/ha, the scale the app reads
# and labels throughout.

met <- perry.springwheat
stopifnot(nrow(met) == 560, nlevels(met$env) == 20)

drop <- unique(as.character(met$gen[is.na(met$yield)]))
met <- met[!as.character(met$gen) %in% drop, ]
stopifnot(length(drop) == 5, !anyNA(met$yield))

met$yield <- met$yield / 1000
met$gen <- as.character(met$gen)
met$site <- as.character(met$site)
met <- met[order(met$env, met$gen),
           c("env", "site", "year", "gen", "yield", "yor")]

# Three site-years hold two trials each -- Wongan Hills was sown early and late
# in 1979 and 1980, and the Merredin 1979 pair is probably the same thing. A
# label of site and year alone would collide for those, so the duplicates are
# suffixed in the order the source numbers them.
key <- paste0(met$site, substr(met$year, 3, 4))
envs <- unique(data.frame(env = as.character(met$env), key = key,
                          stringsAsFactors = FALSE))
dup <- envs$key %in% envs$key[duplicated(envs$key)]
envs$label <- envs$key
envs$label[dup] <- paste0(envs$key[dup], "-",
                          sequence(rle(envs$key[dup])$lengths))
met$env_label <- envs$label[match(as.character(met$env), envs$env)]

stopifnot(
  length(unique(met$env_label)) == 20,
  table(met$gen) == 20,
  nrow(met) == 460
)

write.csv(met, out("met", "perry-springwheat.csv"), row.names = FALSE)

cat("wrote", nrow(trial), "trial plots and", nrow(met), "MET means\n")
