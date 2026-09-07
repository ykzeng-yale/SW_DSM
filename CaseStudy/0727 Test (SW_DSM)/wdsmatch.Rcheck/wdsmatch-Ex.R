pkgname <- "wdsmatch"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
base::assign(".ExTimings", "wdsmatch-Ex.timings", pos = 'CheckExEnv')
base::cat("name\tuser\tsystem\telapsed\n", file=base::get(".ExTimings", pos = 'CheckExEnv'))
base::assign(".format_ptime",
function(x) {
  if(!is.na(x[4L])) x[1L] <- x[1L] + x[4L]
  if(!is.na(x[5L])) x[2L] <- x[2L] + x[5L]
  options(OutDec = '.')
  format(x[1L:3L], digits = 7L)
},
pos = 'CheckExEnv')

### * </HEADER>
library('wdsmatch')

base::assign(".oldSearch", base::search(), pos = 'CheckExEnv')
base::assign(".old_wd", base::getwd(), pos = 'CheckExEnv')
cleanEx()
nameEx("survey_obs")
### * survey_obs

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: survey_obs
### Title: Simulated Survey Observational Data
### Aliases: survey_obs
### Keywords: datasets

### ** Examples

data(survey_obs)
head(survey_obs)

# Estimate PATE
fit <- wdsmatchATE(Y = survey_obs$Y, X = survey_obs[, 3:8],
                   Z = survey_obs$Z, weights = survey_obs$survey_weight,
                   M = 3, varest = FALSE)
fit




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("survey_obs", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("wdsmatchATE")
### * wdsmatchATE

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: wdsmatchATE
### Title: Weighted Double Score Matching Estimator for Population Average
###   Treatment Effect
### Aliases: wdsmatchATE

### ** Examples

data(survey_obs)
fit <- wdsmatchATE(
  Y = survey_obs$Y,
  X = survey_obs[, c("X1","X2","X3","X4","X5","X6")],
  Z = survey_obs$Z,
  weights = survey_obs$survey_weight,
  M = 3,
  model.ps = Z ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
  model.pg = Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
  sampling = "retrospective",
  varest = FALSE
)
fit




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("wdsmatchATE", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("wdsmatchATT")
### * wdsmatchATT

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: wdsmatchATT
### Title: Weighted Double Score Matching Estimator for Population Average
###   Treatment Effect on the Treated
### Aliases: wdsmatchATT

### ** Examples

data(survey_obs)
fit <- wdsmatchATT(
  Y = survey_obs$Y,
  X = survey_obs[, c("X1","X2","X3","X4","X5","X6")],
  Z = survey_obs$Z,
  weights = survey_obs$survey_weight,
  M = 3,
  model.ps = Z ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
  model.pg = Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
  sampling = "retrospective",
  varest = FALSE
)
fit




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("wdsmatchATT", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = 'CheckExEnv'),"\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit('no')
