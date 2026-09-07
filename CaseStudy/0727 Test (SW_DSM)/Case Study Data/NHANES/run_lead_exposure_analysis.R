################################################################################
# SUPPLEMENTARY ANALYSIS: Lead Exposure Effect on Telomere Length
# Complete Comparison: WDSM vs DSM vs PS Full Matching
# Following Salerno et al. Section 5.5
################################################################################

# Clear workspace
rm(list = ls())

# Load libraries
cat("\n=== Loading Libraries ===\n")
suppressPackageStartupMessages({
  library(MASS)
  library(mvtnorm)
  library(nnet)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(matrixStats)
  library(survey)
  library(sampling)
  library(MatchIt)
  library(marginaleffects)
})

# Install dsmatch if needed
if (!require("dsmatch", quietly = TRUE)) {
  cat("\nInstalling dsmatch package from GitHub...\n")
  if (!require("devtools", quietly = TRUE)) {
    install.packages("devtools")
  }
  devtools::install_github("Yunshu7/dsmatch")
  library(dsmatch)
} else {
  library(dsmatch)
}

# Source adaptive WDSM functions
cat("\n=== Loading Adaptive WDSM Functions ===\n")
source("WDSM_adaptive.R")

# Load NHANES data
cat("\n=== Loading NHANES Data ===\n")
nhanes_data <- readRDS("data/nhanes_complete_cases.rds")
cat("Initial observations:", nrow(nhanes_data), "\n")

# ==============================================================================
# PREPARE DATA FOR LEAD EXPOSURE ANALYSIS
# ==============================================================================

cat("\n=== Preparing Lead Exposure Data ===\n")

# Remove observations with missing lead levels
nhanes_lead <- nhanes_data[!is.na(nhanes_data$LBXBPB_LOD), ]
cat("After removing missing lead:", nrow(nhanes_lead), "observations\n")

# Calculate median lead level
lead_median <- median(nhanes_lead$LBXBPB_LOD)
cat("Median lead level:", round(lead_median, 2), "μg/dL\n")

# Create dichotomized lead exposure (1 = high, 0 = low)
nhanes_lead$lead_high <- ifelse(nhanes_lead$LBXBPB_LOD > lead_median, 1, 0)

# Summary of exposure groups
cat("\nExposure Groups:\n")
cat("  Lower lead exposure (A=0):", sum(nhanes_lead$lead_high == 0), "\n")
cat("  Higher lead exposure (A=1):", sum(nhanes_lead$lead_high == 1), "\n")

# Extract variables
Y <- nhanes_lead$lTELOMEAN  # Log telomere length (outcome)
A <- nhanes_lead$lead_high  # Lead exposure (treatment)
w_raw <- nhanes_lead$WTMEC4YR  # Survey weights
n <- length(Y)

# Normalize weights for MatchIt
sw <- w_raw * n / sum(w_raw)

# Define covariate sets
# 12 SES indicators for propensity score
ses_vars <- c("EDUC_3CAT", "MARTL_3CAT", "HHSIZE_5CAT", "OWNHOME_2CAT",
              "HOD_4CAT", "HHINC_5CAT", "PIR_3CAT", "EMPSTAT_4CAT",
              "OCC_5CAT", "HIQ_2CAT", "FDSEC_3CAT", "WIC_2CAT")

# Precision covariates (race, age, blood composition)
precision_vars <- c("RACE_2CAT", "AGE", "SEX",
                   "LBXWBCSI", "LBXLYPCT", "LBXMOPCT", 
                   "LBXNEPCT", "LBXEOPCT", "LBXBAPCT")

cat("\nCovariate Sets:\n")
cat("  PS model: 12 SES indicators\n")
cat("  PG model: 12 SES + 9 precision variables\n")

# Create matrices for dsmatch
X_ps_numeric <- nhanes_lead[, ses_vars]
for (col in ses_vars) {
  if (is.factor(X_ps_numeric[[col]])) {
    X_ps_numeric[[col]] <- as.numeric(X_ps_numeric[[col]])
  }
}
X_ps <- as.matrix(X_ps_numeric)

X_pg_numeric <- nhanes_lead[, c(ses_vars, precision_vars)]
for (col in c(ses_vars, precision_vars)) {
  if (is.factor(X_pg_numeric[[col]])) {
    X_pg_numeric[[col]] <- as.numeric(X_pg_numeric[[col]])
  }
}
X_pg <- as.matrix(X_pg_numeric)

# Create data frame for MatchIt
df_data <- nhanes_lead
df_data$Y <- Y
df_data$A <- A
df_data$sw <- sw

# ==============================================================================
# ANALYSIS 1: PRIMARY (Race as precision covariate)
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("    ANALYSIS 1: PRIMARY (Race as precision covariate)\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Prepare data for WDSM
wdsm_data <- nhanes_lead
wdsm_data$Y <- Y
wdsm_data$A <- A
wdsm_data$survey_weight <- w_raw

# Create formulas
ps_formula <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))
pg_formula <- as.formula(paste("~ ", paste(c(ses_vars, precision_vars), 
                                           collapse = " + ")))

# ----------------------------------------------------------------------------
# METHOD 1: WEIGHTED DOUBLE SCORE MATCHING (WDSM)
# ----------------------------------------------------------------------------

cat("\n--- METHOD 1: WDSM (Survey-Weighted) ---\n")

# Use the WDSM function with convergence handling
wdsm_adaptive_salerno <- function(data, ps_formula, pg_formula, 
                                  outcome_var = "Y", treatment_var = "A", 
                                  weight_var = "survey_weight", M = 5,
                                  use_bias_correction = TRUE, verbose = TRUE) {
  
  if (verbose) cat("\nRunning WDSM...\n")
  
  Y <- data[[outcome_var]]
  A <- data[[treatment_var]]
  w <- data[[weight_var]]
  n <- nrow(data)
  
  # Estimate PS with increased iterations
  data$wdsm_weight_temp <- w
  
  ps_model <- tryCatch({
    glm(ps_formula, data = data, family = binomial(link = "logit"),
        weights = wdsm_weight_temp,
        control = glm.control(maxit = 100, epsilon = 1e-6))
  }, warning = function(warn) {
    suppressWarnings(glm(ps_formula, data = data, 
                        family = binomial(link = "logit"), 
                        weights = wdsm_weight_temp,
                        control = glm.control(maxit = 100, epsilon = 1e-6)))
  })
  
  data$wdsm_weight_temp <- NULL
  e_score <- ps_model$fitted.values
  e_score <- pmax(pmin(e_score, 0.995), 0.005)  # Trim
  
  # Estimate PG scores
  pg_formula_full <- update(pg_formula, paste(outcome_var, "~ ."))
  
  data_0 <- data[A == 0, ]
  w_0 <- w[A == 0]
  data_0$wdsm_weight_temp <- w_0
  prog0_model <- lm(pg_formula_full, data = data_0, weights = wdsm_weight_temp)
  psi0 <- predict(prog0_model, newdata = data)
  
  data_1 <- data[A == 1, ]
  w_1 <- w[A == 1]
  data_1$wdsm_weight_temp <- w_1
  prog1_model <- lm(pg_formula_full, data = data_1, weights = wdsm_weight_temp)
  psi1 <- predict(prog1_model, newdata = data)
  
  # Bias correction
  if (use_bias_correction) {
    sieve_vars_0 <- cbind(psi0, psi0^2, e_score, e_score^2, e_score * psi0)
    colnames(sieve_vars_0) <- c("mu0", "mu0_sq", "ps", "ps_sq", "ps_mu0")
    bc0_data <- data.frame(Y = Y[A == 0], sieve_vars_0[A == 0, ])
    bc0_data$wdsm_weight_temp <- w_0
    bc0_fit <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0,
                  data = bc0_data, weights = wdsm_weight_temp)
    mu0_bc <- predict(bc0_fit, newdata = data.frame(sieve_vars_0))
    
    sieve_vars_1 <- cbind(psi1, psi1^2, e_score, e_score^2, e_score * psi1)
    colnames(sieve_vars_1) <- c("mu1", "mu1_sq", "ps", "ps_sq", "ps_mu1")
    bc1_data <- data.frame(Y = Y[A == 1], sieve_vars_1[A == 1, ])
    bc1_data$wdsm_weight_temp <- w_1
    bc1_fit <- lm(Y ~ mu1 + mu1_sq + ps + ps_sq + ps_mu1,
                  data = bc1_data, weights = wdsm_weight_temp)
    mu1_bc <- predict(bc1_fit, newdata = data.frame(sieve_vars_1))
  } else {
    mu0_bc <- psi0
    mu1_bc <- psi1
  }
  
  # Create double scores
  e_score_logit <- qlogis(e_score)
  double_score_0 <- cbind(-e_score_logit, psi1)
  double_score_1 <- cbind(e_score_logit, psi0)
  
  double_score_0_std <- standardize_with_weights(double_score_0, w)
  double_score_1_std <- standardize_with_weights(double_score_1, w)
  
  # Matching
  matches_0 <- vector("list", n)
  matches_1 <- vector("list", n)
  
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  
  for (i in treated_idx) {
    if (length(control_idx) > 0) {
      distances <- sqrt(rowSums((double_score_0_std[control_idx, , drop = FALSE] - 
                                matrix(double_score_0_std[i, ], 
                                       nrow = length(control_idx), 
                                       ncol = 2, byrow = TRUE))^2))
      n_matches <- min(M, length(control_idx))
      nearest <- control_idx[order(distances)[1:n_matches]]
      matches_0[[i]] <- nearest
    }
  }
  
  for (i in control_idx) {
    if (length(treated_idx) > 0) {
      distances <- sqrt(rowSums((double_score_1_std[treated_idx, , drop = FALSE] - 
                                matrix(double_score_1_std[i, ], 
                                       nrow = length(treated_idx), 
                                       ncol = 2, byrow = TRUE))^2))
      n_matches <- min(M, length(treated_idx))
      nearest <- treated_idx[order(distances)[1:n_matches]]
      matches_1[[i]] <- nearest
    }
  }
  
  # Imputation
  Y_hat_0 <- rep(NA, n)
  Y_hat_1 <- rep(NA, n)
  
  for (i in 1:n) {
    if (A[i] == 1) {
      if (!is.null(matches_0[[i]]) && length(matches_0[[i]]) > 0) {
        neighbors <- matches_0[[i]]
        neighbor_weights <- w[neighbors]
        Y_matched <- sum(neighbor_weights * Y[neighbors]) / sum(neighbor_weights)
        mu_matched <- sum(neighbor_weights * mu0_bc[neighbors]) / sum(neighbor_weights)
        Y_hat_0[i] <- Y_matched + (mu0_bc[i] - mu_matched)
      }
      Y_hat_1[i] <- Y[i]
    } else {
      if (!is.null(matches_1[[i]]) && length(matches_1[[i]]) > 0) {
        neighbors <- matches_1[[i]]
        neighbor_weights <- w[neighbors]
        Y_matched <- sum(neighbor_weights * Y[neighbors]) / sum(neighbor_weights)
        mu_matched <- sum(neighbor_weights * mu1_bc[neighbors]) / sum(neighbor_weights)
        Y_hat_1[i] <- Y_matched + (mu1_bc[i] - mu_matched)
      }
      Y_hat_0[i] <- Y[i]
    }
  }
  
  # Calculate PATE
  valid_idx <- !is.na(Y_hat_0) & !is.na(Y_hat_1)
  tau_wdsm <- sum(w[valid_idx] * (Y_hat_1[valid_idx] - Y_hat_0[valid_idx])) / 
              sum(w[valid_idx])
  
  return(list(tau = tau_wdsm, Y_hat_0 = Y_hat_0, Y_hat_1 = Y_hat_1,
              e_score = e_score, weights = w))
}

# Run WDSM
wdsm_result <- wdsm_adaptive_salerno(
  data = wdsm_data,
  ps_formula = ps_formula,
  pg_formula = pg_formula,
  outcome_var = "Y",
  treatment_var = "A",
  weight_var = "survey_weight",
  M = 5,
  use_bias_correction = TRUE,
  verbose = FALSE
)

# Bootstrap for WDSM
cat("Running bootstrap (200 replicates)...\n")
set.seed(2024)
B <- 200
boot_wdsm <- numeric(B)
pb <- txtProgressBar(min = 0, max = B, style = 3)

for (b in 1:B) {
  m_star <- rmultinom(1, n, rep(1/n, n))[, 1]
  data_boot <- wdsm_data
  data_boot$survey_weight <- m_star * w_raw
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) {
    boot_wdsm[b] <- NA
    next
  }
  
  tryCatch({
    boot_result <- wdsm_adaptive_salerno(data_boot, ps_formula, pg_formula,
                                         "Y", "A", "survey_weight",
                                         M = 5, use_bias_correction = TRUE, 
                                         verbose = FALSE)
    boot_wdsm[b] <- boot_result$tau
  }, error = function(e) {
    boot_wdsm[b] <- NA
  })
  
  setTxtProgressBar(pb, b)
}
close(pb)

boot_wdsm <- boot_wdsm[!is.na(boot_wdsm)]
wdsm_se <- sd(boot_wdsm)
wdsm_ci <- quantile(boot_wdsm, c(0.025, 0.975))

cat("\nWDSM Results:\n")
cat("  Estimate:", round(wdsm_result$tau, 4), "\n")
cat("  SE:", round(wdsm_se, 4), "\n")
cat("  95% CI: [", round(wdsm_ci[1], 4), ", ", round(wdsm_ci[2], 4), "]\n", sep="")
cat("  % Change:", round(100 * (exp(wdsm_result$tau) - 1), 2), "%\n")

# ----------------------------------------------------------------------------
# METHOD 2: UNWEIGHTED DOUBLE SCORE MATCHING (dsmatch)
# ----------------------------------------------------------------------------

cat("\n--- METHOD 2: DSM (Unweighted) ---\n")

dsm_result <- tryCatch({
  dsmatchATE(
    Y = Y,
    X = X_ps,  # PS model uses 12 SES
    A = A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X_pg,  # PG model uses SES + precision
    cov.balance = FALSE,
    varest = TRUE,
    boots = B,
    mc = FALSE,
    ncpus = 1
  )
}, error = function(e) {
  cat("Error in DSM:", e$message, "\n")
  list(est.ds = NA, bootvar = matrix(NA, 1, 1))
})

if (!is.na(dsm_result$est.ds)) {
  dsm_estimate <- dsm_result$est.ds
  dsm_se <- sqrt(dsm_result$bootvar[1,1])
  dsm_ci_lower <- dsm_estimate - qnorm(0.975) * dsm_se
  dsm_ci_upper <- dsm_estimate + qnorm(0.975) * dsm_se
  
  cat("DSM Results:\n")
  cat("  Estimate:", round(dsm_estimate, 4), "\n")
  cat("  SE:", round(dsm_se, 4), "\n")
  cat("  95% CI: [", round(dsm_ci_lower, 4), ", ", round(dsm_ci_upper, 4), "]\n", sep="")
  cat("  % Change:", round(100 * (exp(dsm_estimate) - 1), 2), "%\n")
} else {
  cat("DSM failed to converge\n")
  dsm_estimate <- dsm_se <- dsm_ci_lower <- dsm_ci_upper <- NA
}

# ----------------------------------------------------------------------------
# METHOD 3: SURVEY-WEIGHTED PS FULL MATCHING (MatchIt)
# ----------------------------------------------------------------------------

cat("\n--- METHOD 3: PS Full Matching (Survey-Weighted) ---\n")

ps_formula_matchit <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))

m_ps_sw <- tryCatch({
  matchit(ps_formula_matchit,
          data = df_data,
          method = "full",
          distance = "glm",
          link = "logit",
          estimand = "ATE",
          s.weights = sw,
          verbose = FALSE)
}, error = function(e) {
  cat("Error in MatchIt:", e$message, "\n")
  NULL
})

if (!is.null(m_ps_sw)) {
  md_sw <- match.data(m_ps_sw)
  
  # Outcome model with full specification
  outcome_formula <- as.formula(paste("Y ~ A * (", 
                                      paste(c(ses_vars, precision_vars), 
                                            collapse = " + "), ")"))
  
  fit_sw <- lm(outcome_formula, data = md_sw, weights = weights)
  
  ate_sw <- avg_comparisons(fit_sw, 
                            variables = "A",
                            vcov = ~subclass,
                            wts = "sw",
                            comparison = "difference")
  
  ps_estimate <- ate_sw$estimate
  ps_se <- ate_sw$std.error
  ps_ci_lower <- ate_sw$conf.low
  ps_ci_upper <- ate_sw$conf.high
  
  cat("PS Full Matching Results:\n")
  cat("  Estimate:", round(ps_estimate, 4), "\n")
  cat("  SE:", round(ps_se, 4), "\n")
  cat("  95% CI: [", round(ps_ci_lower, 4), ", ", round(ps_ci_upper, 4), "]\n", sep="")
  cat("  % Change:", round(100 * (exp(ps_estimate) - 1), 2), "%\n")
} else {
  cat("PS Full Matching failed\n")
  ps_estimate <- ps_se <- ps_ci_lower <- ps_ci_upper <- NA
}

# ==============================================================================
# ANALYSIS 2: SENSITIVITY (Race in PS model)
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("  ANALYSIS 2: SENSITIVITY (Race in PS model)\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Update formulas to include race in PS
ps_formula_sens <- as.formula(paste("A ~", paste(c(ses_vars, "RACE_2CAT"), 
                                                  collapse = " + ")))

# Update matrices for dsmatch
X_ps_sens_numeric <- nhanes_lead[, c(ses_vars, "RACE_2CAT")]
for (col in c(ses_vars, "RACE_2CAT")) {
  if (is.factor(X_ps_sens_numeric[[col]])) {
    X_ps_sens_numeric[[col]] <- as.numeric(X_ps_sens_numeric[[col]])
  }
}
X_ps_sens <- as.matrix(X_ps_sens_numeric)

# Run WDSM with race in PS
cat("\n--- WDSM with Race in PS ---\n")
wdsm_sens <- wdsm_adaptive_salerno(
  data = wdsm_data,
  ps_formula = ps_formula_sens,
  pg_formula = pg_formula,
  outcome_var = "Y",
  treatment_var = "A",
  weight_var = "survey_weight",
  M = 5,
  use_bias_correction = TRUE,
  verbose = FALSE
)

cat("  Estimate:", round(wdsm_sens$tau, 4), "\n")
cat("  % Change:", round(100 * (exp(wdsm_sens$tau) - 1), 2), "%\n")

# Run DSM with race in PS
cat("\n--- DSM with Race in PS ---\n")
dsm_sens <- tryCatch({
  dsmatchATE(
    Y = Y,
    X = X_ps_sens,
    A = A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X_pg,
    cov.balance = FALSE,
    varest = FALSE,
    mc = FALSE,
    ncpus = 1
  )
}, error = function(e) {
  list(est.ds = NA)
})

if (!is.na(dsm_sens$est.ds)) {
  cat("  Estimate:", round(dsm_sens$est.ds, 4), "\n")
  cat("  % Change:", round(100 * (exp(dsm_sens$est.ds) - 1), 2), "%\n")
} else {
  cat("  DSM failed to converge\n")
}

# ==============================================================================
# COMPARISON TABLE
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("              LEAD EXPOSURE ANALYSIS RESULTS\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Create comparison table
lead_results <- data.frame(
  Analysis = c(
    "PRIMARY (Race as precision):",
    "  WDSM (Survey-Weighted)",
    "  DSM (Unweighted)",
    "  PS Full (Survey-Weighted)",
    "",
    "SENSITIVITY (Race in PS):",
    "  WDSM (Survey-Weighted)",
    "  DSM (Unweighted)",
    "",
    "Salerno et al. reported:",
    "  IPW methods"
  ),
  PATE = c(
    "",
    sprintf("%.4f", wdsm_result$tau),
    ifelse(!is.na(dsm_estimate), sprintf("%.4f", dsm_estimate), "N/A"),
    ifelse(!is.na(ps_estimate), sprintf("%.4f", ps_estimate), "N/A"),
    "",
    "",
    sprintf("%.4f", wdsm_sens$tau),
    ifelse(!is.na(dsm_sens$est.ds), sprintf("%.4f", dsm_sens$est.ds), "N/A"),
    "",
    "",
    "-0.033 to -0.050"
  ),
  `Pct_Change` = c(
    "",
    sprintf("%.1f%%", 100 * (exp(wdsm_result$tau) - 1)),
    ifelse(!is.na(dsm_estimate), sprintf("%.1f%%", 100 * (exp(dsm_estimate) - 1)), "N/A"),
    ifelse(!is.na(ps_estimate), sprintf("%.1f%%", 100 * (exp(ps_estimate) - 1)), "N/A"),
    "",
    "",
    sprintf("%.1f%%", 100 * (exp(wdsm_sens$tau) - 1)),
    ifelse(!is.na(dsm_sens$est.ds), sprintf("%.1f%%", 100 * (exp(dsm_sens$est.ds) - 1)), "N/A"),
    "",
    "",
    "-3.3% to -5.0%"
  ),
  CI_95 = c(
    "",
    sprintf("[%.4f, %.4f]", wdsm_ci[1], wdsm_ci[2]),
    ifelse(!is.na(dsm_ci_lower), sprintf("[%.4f, %.4f]", dsm_ci_lower, dsm_ci_upper), "N/A"),
    ifelse(!is.na(ps_ci_lower), sprintf("[%.4f, %.4f]", ps_ci_lower, ps_ci_upper), "N/A"),
    "",
    "",
    "Not computed",
    "Not computed",
    "",
    "",
    "Significant"
  ),
  stringsAsFactors = FALSE
)

names(lead_results)[3] <- "% Change"
names(lead_results)[4] <- "95% CI"

print(lead_results, row.names = FALSE, right = FALSE)

# ==============================================================================
# INTERPRETATION
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                      INTERPRETATION\n")
cat("=" ,rep("=", 70), "\n", sep="")

cat("\n📊 KEY FINDINGS:\n\n")

cat("1. CAUSAL EFFECT OF LEAD EXPOSURE:\n")
cat("   Unlike race, lead exposure has a plausible causal interpretation.\n")
cat("   Higher lead levels may causally affect telomere length.\n\n")

cat("2. METHOD COMPARISON:\n")
if (!is.na(wdsm_result$tau)) {
  if (wdsm_result$tau < 0) {
    cat("   - WDSM: ", sprintf("%.1f%%", abs(100 * (exp(wdsm_result$tau) - 1))), 
        " reduction in telomere length\n", sep="")
  } else {
    cat("   - WDSM: ", sprintf("%.1f%%", 100 * (exp(wdsm_result$tau) - 1)), 
        " increase in telomere length\n", sep="")
  }
}
if (!is.na(dsm_estimate)) {
  if (dsm_estimate < 0) {
    cat("   - DSM:  ", sprintf("%.1f%%", abs(100 * (exp(dsm_estimate) - 1))), 
        " reduction (ignores survey weights)\n", sep="")
  } else {
    cat("   - DSM:  ", sprintf("%.1f%%", 100 * (exp(dsm_estimate) - 1)), 
        " increase (ignores survey weights)\n", sep="")
  }
}
if (!is.na(ps_estimate)) {
  if (ps_estimate < 0) {
    cat("   - PS:   ", sprintf("%.1f%%", abs(100 * (exp(ps_estimate) - 1))), 
        " reduction\n", sep="")
  } else {
    cat("   - PS:   ", sprintf("%.1f%%", 100 * (exp(ps_estimate) - 1)), 
        " increase\n", sep="")
  }
}

cat("\n3. CONSISTENCY WITH SALERNO:\n")
cat("   Salerno reported 3.3-5.0% reduction with IPW methods.\n")
cat("   Our WDSM results are ", 
    ifelse(wdsm_result$tau < 0 && abs(100 * (exp(wdsm_result$tau) - 1)) >= 3.3 && 
           abs(100 * (exp(wdsm_result$tau) - 1)) <= 5.0, 
           "consistent", "different from"), 
    " Salerno's findings.\n", sep="")

cat("\n4. SENSITIVITY TO RACE ADJUSTMENT:\n")
cat("   Including race in PS model ", 
    ifelse(abs(wdsm_sens$tau - wdsm_result$tau) < 0.005, 
           "does not materially change", "changes"),
    " the results.\n", sep="")

# ==============================================================================
# SAVE RESULTS
# ==============================================================================

cat("\n=== Saving Results ===\n")

lead_analysis_results <- list(
  primary = list(
    wdsm = list(estimate = wdsm_result$tau, se = wdsm_se, ci = wdsm_ci),
    dsm = list(estimate = dsm_estimate, se = dsm_se, 
               ci = c(dsm_ci_lower, dsm_ci_upper)),
    ps_full = list(estimate = ps_estimate, se = ps_se, 
                  ci = c(ps_ci_lower, ps_ci_upper))
  ),
  sensitivity = list(
    wdsm = list(estimate = wdsm_sens$tau),
    dsm = list(estimate = ifelse(!is.na(dsm_sens$est.ds), dsm_sens$est.ds, NA))
  ),
  comparison_table = lead_results,
  sample_size = n,
  median_lead = lead_median
)

if (!dir.exists("analysis_results")) {
  dir.create("analysis_results")
}

saveRDS(lead_analysis_results, "analysis_results/lead_exposure_results.rds")
write.csv(lead_results, "analysis_results/lead_exposure_table.csv", row.names = FALSE)

cat("Results saved to:\n")
cat("  - analysis_results/lead_exposure_results.rds\n")
cat("  - analysis_results/lead_exposure_table.csv\n")

cat("\n=== Lead Exposure Analysis Complete ===\n")
