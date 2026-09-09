# Run from the SW_DSM repository root. No packages, downloads, or file outputs.
source("StabilizedWDSM/wdsm_stabilized.R")
set.seed(2024)
n <- 600L
dat <- as.data.frame(matrix(rnorm(n * 6L), n, 6L))
names(dat) <- paste0("X", 1:6)
dat$A <- rbinom(n, 1, plogis(-0.2 + 0.3 * dat$X1 - 0.2 * dat$X2))
dat$Y <- 0.7 * dat$A + dat$X1 + 0.4 * dat$X2 + rnorm(n)
# A simple positive, nonconstant weight specification for an execution check.
# This is not the paper's informative-sampling simulation design.
dat$survey_weight <- 2 + 0.1 * plogis(dat$X3 + 0.2 * dat$A)
ps_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6
pg_formula <- Y ~ X1 + X2 + X3 + X4 + X5 + X6
rows <- list()
for (design in c("retrospective", "prospective")) {
  for (estimand in c("PATE", "PATT")) {
    for (M in c(1L, 3L, 5L)) {
      fit <- wdsm_stabilized_point_estimate(dat, ps_formula, pg_formula,
        estimand = estimand, sampling_design = design, M = M)
      rows[[length(rows) + 1L]] <- data.frame(
        design = design, estimand = estimand, M = M,
        original_same_fit = fit$self_normalized_tau,
        stabilized = fit$tau, identity_error = fit$identity_error)
    }
  }
}
print(do.call(rbind, rows), row.names = FALSE)
cat("\nExecution check only; no inference or comparative-performance claim.\n")
