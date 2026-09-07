#!/usr/bin/env Rscript

#' Example: Weighted Double Score Matching with LaLonde Data
#' 
#' This script demonstrates the use of WDSM for estimating population-level
#' causal effects from survey data using the LaLonde (1986) dataset.

# Load required packages
library(Matching)
library(wdsmatch)

# Load LaLonde data
data("lalonde")

# Prepare data
Y <- lalonde[, "re78"]  # Outcome: 1978 earnings
A <- lalonde[, "treat"]  # Treatment: job training program

# Covariates
X <- lalonde[, c("age", "educ", "black", "hisp", "married", 
                 "nodegr", "re74", "re75", "u74", "u75")]
X <- as.matrix(X)

# Create linear predictors for more flexible modeling
# (following the original dsmatch example)
Z <- X
Z[, "re74"] <- log(Z[, "re74"] + 1)
Z[, "re75"] <- log(Z[, "re75"] + 1)
Z[, "age"] <- (Z[, "age"] - mean(Z[, "age"])) / sd(Z[, "age"])
Z[, "educ"] <- (Z[, "educ"] - mean(Z[, "educ"])) / sd(Z[, "educ"])
Z[, "re74"] <- (Z[, "re74"] - mean(Z[, "re74"])) / sd(Z[, "re74"])
Z[, "re75"] <- (Z[, "re75"] - mean(Z[, "re75"])) / sd(Z[, "re75"])
Z <- cbind(Z, Z[, "age"]^2, Z[, "educ"]^2, Z[, "re74"]^2, Z[, "re75"]^2)

cat("========================================\n")
cat("WDSM Example: LaLonde Job Training Data\n")
cat("========================================\n\n")

cat("Sample size: n =", length(Y), "\n")
cat("Treated units: n1 =", sum(A), "\n")
cat("Control units: n0 =", sum(1-A), "\n\n")

# ==== Example 1: Prospective Sampling ====
cat("Example 1: PATE with Prospective Sampling\n")
cat("-----------------------------------------\n")

# Simulate survey weights (in practice, use actual survey weights)
# Here we simulate weights that depend on covariates
set.seed(123)
# Create weights that depend on age and education (common in surveys)
prob_inclusion <- plogis(-2 + 0.05 * X[, "age"] + 0.1 * X[, "educ"])
weights_pros <- 1 / prob_inclusion

# Estimate PATE with prospective sampling
result_pate_pros <- wdsmatch(Y, X, A, weights_pros,
                             estimand = "PATE",
                             sampling = "prospective",
                             method = "dsm",
                             model.ps = "linpred", lp.ps = Z,
                             model.pg = "linpred", lp.pg = Z,
                             M = 3,
                             bias.correct = TRUE,
                             varest = TRUE,
                             boots = 100,
                             cov.balance = TRUE)

print(result_pate_pros)

# ==== Example 2: Retrospective Sampling ====
cat("\n\nExample 2: PATE with Retrospective Sampling\n")
cat("--------------------------------------------\n")

# Simulate treatment-specific survey weights
# (e.g., oversampling of treated units)
set.seed(456)
prob_inclusion_0 <- plogis(-2.5 + 0.05 * X[, "age"] + 0.1 * X[, "educ"])
prob_inclusion_1 <- plogis(-1.5 + 0.05 * X[, "age"] + 0.1 * X[, "educ"])
weights0_retro <- 1 / prob_inclusion_0
weights1_retro <- 1 / prob_inclusion_1

# Create weight list for retrospective sampling
weights_retro <- list(weights0 = weights0_retro, weights1 = weights1_retro)

# Estimate PATE with retrospective sampling
result_pate_retro <- wdsmatch(Y, X, A, weights_retro,
                              estimand = "PATE", 
                              sampling = "retrospective",
                              method = "dsm",
                              model.ps = "linpred", lp.ps = Z,
                              model.pg = "linpred", lp.pg = Z,
                              M = 3,
                              bias.correct = TRUE,
                              varest = TRUE,
                              boots = 100)

print(result_pate_retro)

# ==== Example 3: PATT Estimation ====
cat("\n\nExample 3: PATT with Prospective Sampling\n")
cat("------------------------------------------\n")

# Estimate PATT (only requires weaker assumption)
result_patt_pros <- wdsmatch(Y, X, A, weights_pros,
                             estimand = "PATT",
                             sampling = "prospective",
                             method = "dsm",
                             model.ps = "linpred", lp.ps = Z,
                             model.pg = "linpred", lp.pg = Z,
                             M = 3,
                             bias.correct = TRUE,
                             varest = TRUE,
                             boots = 100)

print(result_patt_pros)

# ==== Example 4: Compare Different Matching Methods ====
cat("\n\nExample 4: Comparing Different Matching Methods\n")
cat("------------------------------------------------\n")

# Compare double score vs propensity score only
result_ps_only <- wdsmatch(Y, X, A, weights_pros,
                          estimand = "PATE",
                          sampling = "prospective", 
                          method = "ps",  # Propensity score only
                          model.ps = "linpred", lp.ps = Z,
                          model.pg = "linpred", lp.pg = Z,
                          varest = TRUE,
                          boots = 100)

cat("\nPropensity Score Only:\n")
cat("  Estimate:", sprintf("%.2f", result_ps_only$est.ps), "\n")
cat("  SE:", sprintf("%.2f", sqrt(result_ps_only$bootvar)), "\n")

cat("\nDouble Score Matching:\n")
cat("  Estimate:", sprintf("%.2f", result_pate_pros$est.dsm), "\n")
cat("  SE:", sprintf("%.2f", sqrt(result_pate_pros$bootvar)), "\n")

# ==== Example 5: Sensitivity to Number of Matches ====
cat("\n\nExample 5: Sensitivity to Number of Matches (M)\n")
cat("------------------------------------------------\n")

for (m in c(1, 3, 5)) {
  result_m <- wdsmatch(Y, X, A, weights_pros,
                       estimand = "PATE",
                       sampling = "prospective",
                       method = "dsm",
                       model.ps = "linpred", lp.ps = Z,
                       model.pg = "linpred", lp.pg = Z,
                       M = m,
                       bias.correct = TRUE,
                       varest = FALSE)  # Skip variance for speed
  
  cat("M =", m, ": Estimate =", sprintf("%.2f", result_m$est.dsm), "\n")
}

# ==== Summary ====
cat("\n\n========================================\n")
cat("Summary of Results\n")
cat("========================================\n")

cat("\nPATE Estimates:\n")
cat("  Prospective sampling:", sprintf("%.2f", result_pate_pros$est.dsm),
    "(SE:", sprintf("%.2f", sqrt(result_pate_pros$bootvar)), ")\n")
cat("  Retrospective sampling:", sprintf("%.2f", result_pate_retro$est.dsm),
    "(SE:", sprintf("%.2f", sqrt(result_pate_retro$bootvar)), ")\n")

cat("\nPATT Estimate:\n")
cat("  Prospective sampling:", sprintf("%.2f", result_patt_pros$est.dsm),
    "(SE:", sprintf("%.2f", sqrt(result_patt_pros$bootvar)), ")\n")

cat("\nKey Insights:\n")
cat("- WDSM properly accounts for survey weights in matching\n")
cat("- Bootstrap variance estimation captures matching uncertainty\n")
cat("- Double score matching provides robustness against model misspecification\n")
cat("- Results may differ between prospective and retrospective sampling\n") 