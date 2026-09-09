#!/usr/bin/env Rscript

# This script shows the correct dsmatchATT function signatures that should be used

# METHOD 1: DOUBLE SCORE MATCHING (DSM)
# --------------------------------------
# result <- withTimeout({
#   dsmatchATT(
#     Y = Y,
#     X = X_dsm,  # Use PS-specific covariates for PS model
#     A = A,
#     method = "dsm",
#     model.ps = "logit",    # Standard GLM with logit link
#     model.pg = "linpred",  # Use linear predictors for outcome
#     lp.pg = X_pgs,         # Use PGS-specific covariates for PGS model
#     cov.balance = FALSE,
#     varest = TRUE,
#     boots = B,
#     mc = FALSE,
#     ncpus = 1,
#     M = M
#   )
# }, timeout = 240, onTimeout = "error")
#
# list(
#   method = "DSM",
#   est = result$est.ds,
#   se = sqrt(result$bootvar[1,1]),
#   ci_lower = result$est.ds - qnorm(1 - alpha/2) * sqrt(result$bootvar[1,1]),
#   ci_upper = result$est.ds + qnorm(1 - alpha/2) * sqrt(result$bootvar[1,1])
# )

# METHOD 2: PROGNOSTIC SCORE MATCHING (PG)
# -----------------------------------------
# result <- withTimeout({
#   dsmatchATT(
#     Y = Y,
#     X = X_pgs,
#     A = A,
#     method = "pg",
#     model.pg = "linpred",  # Use linear predictors
#     lp.pg = X_pgs,         # Use PGS-specific covariates
#     cov.balance = FALSE,
#     varest = TRUE,
#     boots = B,
#     mc = FALSE,
#     ncpus = 1,
#     M = M
#   )
# }, timeout = 240, onTimeout = "error")
#
# list(
#   method = "PG",
#   est = result$est.pg,
#   se = sqrt(result$bootvar[1,1]),
#   ci_lower = result$est.pg - qnorm(1 - alpha/2) * sqrt(result$bootvar[1,1]),
#   ci_upper = result$est.pg + qnorm(1 - alpha/2) * sqrt(result$bootvar[1,1])
# )

# METHOD 3: PROPENSITY SCORE MATCHING (PS)
# -----------------------------------------
# result <- withTimeout({
#   dsmatchATT(
#     Y = Y,
#     X = X_ps,  # Use PS-specific covariates
#     A = A,
#     method = "ps",  # Propensity score matching
#     model.ps = "logit",    # Standard GLM with logit link
#     cov.balance = FALSE,
#     varest = TRUE,
#     boots = B,
#     mc = FALSE,
#     ncpus = 1,
#     M = M
#   )
# }, timeout = 240, onTimeout = "error")
#
# list(
#   method = "PS",
#   est = result$est.ps,
#   se = sqrt(result$bootvar[1,1]),
#   ci_lower = result$est.ps - qnorm(1 - alpha/2) * sqrt(result$bootvar[1,1]),
#   ci_upper = result$est.ps + qnorm(1 - alpha/2) * sqrt(result$bootvar[1,1])
# )

# Model Specification Settings:
# -----------------------------
# CorCor: ps_correct = TRUE,  pgs_correct = TRUE
# MisCor: ps_correct = FALSE, pgs_correct = TRUE
# CorMis: ps_correct = TRUE,  pgs_correct = FALSE
# MisMis: ps_correct = FALSE, pgs_correct = FALSE
