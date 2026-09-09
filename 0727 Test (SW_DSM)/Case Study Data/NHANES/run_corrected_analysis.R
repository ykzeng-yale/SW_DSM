################################################################################
# CORRECTED COMPLETE COMPARISON ANALYSIS
# Fixing PS Full Matching Implementation
################################################################################

# Clear workspace
rm(list = ls())

# Set options
options(scipen = 999)
options(width = 100)

# Load required libraries
suppressPackageStartupMessages({
  library(dplyr)
  library(MatchIt)
  library(marginaleffects)
  library(MASS)
  if (!require(dsmatch)) {
    devtools::install_github("Yunshu7/dsmatch", quiet = TRUE)
    library(dsmatch)
  }
})

# Load data
load("data/nhanes_svycdiff_data.RData")
nhanes_data <- NHANES  # Rename for consistency

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("          CORRECTED NHANES ANALYSIS: RACE AND TELOMERE LENGTH\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("\nData loaded successfully.\n")
cat("Sample size:", nrow(nhanes_data), "\n")

# ==============================================================================
# PART 1: RACE ANALYSIS (Main Research Question)
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                    PART 1: RACE ANALYSIS\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Define variables
Y <- nhanes_data$lTELOMEAN
A <- nhanes_data$RACE_2CAT
w_raw <- nhanes_data$WTMEC4YR
n <- length(Y)

# Normalize weights for MatchIt (CRITICAL!)
sw <- w_raw * n / sum(w_raw)

# Define covariate sets (as per Salerno et al.)
ses_vars <- c("EDUC_3CAT", "MARTL_3CAT", "PIR_3CAT", "EMPSTAT_4CAT", 
              "OCC_5CAT", "HHSIZE_5CAT", "HHINC_5CAT", "HIQ_2CAT", 
              "WIC_2CAT", "FDSEC_3CAT", "HOD_4CAT", "OWNHOME_2CAT")

demo_vars <- c("AGE", "SEX")

blood_vars <- c("LBXWBCSI", "LBXLYPCT", "LBXMOPCT", "LBXNEPCT", 
                "LBXEOPCT", "LBXBAPCT")

# Create data frame for MatchIt
df_data <- data.frame(
  Y = Y,
  A = A,
  sw = sw,
  nhanes_data[, c(ses_vars, demo_vars, blood_vars)]
)

# ==============================================================================
# METHOD 1: SURVEY-WEIGHTED PS FULL MATCHING (MatchIt) - CORRECTED
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("  METHOD 1: CORRECTED PS FULL MATCHING (Survey-Weighted)\n")
cat("=" ,rep("=", 70), "\n", sep="")

# PS formula - ONLY SES variables (12 covariates as per Salerno)
ps_formula_matchit <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))

cat("\nPerforming PS full matching with survey weights...\n")
cat("PS model uses 12 SES indicators only\n")

# Perform PS full matching with survey weights
# Note: We expect convergence warnings - this is normal with many covariates
suppressWarnings({
  m_ps_sw <- matchit(ps_formula_matchit,
                    data = df_data,
                    method = "full",
                    distance = "glm",
                    link = "logit",
                    estimand = "ATE",
                    s.weights = sw,
                    verbose = FALSE)
})

# Extract matched data
md_sw <- match.data(m_ps_sw)

# CRITICAL FIX: Outcome model should be correctly specified
# For PS Full matching, the outcome model is for bias correction
# It should include treatment and its interactions with covariates
# Following the simulation example structure:
outcome_formula_ps <- Y ~ A * (EDUC_3CAT + MARTL_3CAT + PIR_3CAT + EMPSTAT_4CAT + 
                               OCC_5CAT + HHSIZE_5CAT + HHINC_5CAT + HIQ_2CAT + 
                               WIC_2CAT + FDSEC_3CAT + HOD_4CAT + OWNHOME_2CAT +
                               AGE + SEX + 
                               LBXWBCSI + LBXLYPCT + LBXMOPCT + LBXNEPCT + 
                               LBXEOPCT + LBXBAPCT)

cat("\nFitting outcome model with all covariates and interactions...\n")

# Fit outcome model with product weights (matching * survey)
fit_sw <- lm(outcome_formula_ps,
            data = md_sw,
            weights = weights)  # This is the product of matching and survey weights

# Get treatment effect using marginaleffects
# CRITICAL: Use wts = "sw" to incorporate survey weights properly
ate_sw <- avg_comparisons(fit_sw, 
                         variables = "A",
                         vcov = ~subclass,
                         wts = "sw",
                         comparison = "difference")

ps_estimate_race <- ate_sw$estimate
ps_se_race <- ate_sw$std.error
ps_ci_race <- c(ate_sw$conf.low, ate_sw$conf.high)

cat("\n  CORRECTED PS Full Matching Results (Race):\n")
cat("    Estimate:", round(ps_estimate_race, 4), "\n")
cat("    SE:", round(ps_se_race, 4), "\n")
cat("    95% CI: [", round(ps_ci_race[1], 4), ", ", round(ps_ci_race[2], 4), "]\n", sep="")
cat("    P-value:", format.pval(2 * pnorm(-abs(ps_estimate_race/ps_se_race)), digits=3), "\n")

# ==============================================================================
# METHOD 2: UNWEIGHTED DSM (for comparison)
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("  METHOD 2: UNWEIGHTED DSM (dsmatch)\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Prepare matrices for dsmatch (converting factors to numeric)
X_ps_df <- nhanes_data[, ses_vars]
for (col in names(X_ps_df)) {
  if (is.factor(X_ps_df[[col]])) {
    X_ps_df[[col]] <- as.numeric(X_ps_df[[col]])
  }
}
X_ps <- as.matrix(X_ps_df)

X_pg_df <- nhanes_data[, c(ses_vars, demo_vars, blood_vars)]
for (col in names(X_pg_df)) {
  if (is.factor(X_pg_df[[col]])) {
    X_pg_df[[col]] <- as.numeric(X_pg_df[[col]])
  }
}
X_pg <- as.matrix(X_pg_df)

# Run DSM
suppressWarnings({
  dsm_result <- dsmatchATE(
    Y = Y,
    X = X_ps,  # PS model uses 12 SES
    A = A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X_pg,  # PG model uses all covariates
    cov.balance = FALSE,
    varest = TRUE,
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
})

dsm_estimate_race <- dsm_result$est.ds
dsm_se_race <- sqrt(dsm_result$bootvar[1,1])
dsm_ci_race <- c(dsm_estimate_race - 1.96*dsm_se_race, 
                 dsm_estimate_race + 1.96*dsm_se_race)

cat("\n  DSM Results (Race):\n")
cat("    Estimate:", round(dsm_estimate_race, 4), "\n")
cat("    SE:", round(dsm_se_race, 4), "\n")
cat("    95% CI: [", round(dsm_ci_race[1], 4), ", ", round(dsm_ci_race[2], 4), "]\n", sep="")

# ==============================================================================
# METHOD 3: WDSM (already correct from previous implementation)
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("  METHOD 3: WDSM (Survey-Weighted DSM)\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Load the adaptive WDSM function
source("WDSM_adaptive.R")

# Prepare data for WDSM
wdsm_data <- nhanes_data
wdsm_data$Y <- Y
wdsm_data$A <- A
wdsm_data$survey_weight <- w_raw

# Create formulas
ps_formula <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))
pg_formula <- as.formula(paste("~ ", paste(c(ses_vars, demo_vars, blood_vars), 
                                           collapse = " + ")))

# Run WDSM
suppressWarnings({
  wdsm_result <- wdsm_adaptive(
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
})

# Bootstrap for WDSM
set.seed(2024)
B <- 200
boot_wdsm <- numeric(B)

for (b in 1:B) {
  m_star <- rmultinom(1, n, rep(1/n, n))[, 1]
  data_boot <- wdsm_data
  data_boot$survey_weight <- m_star * w_raw
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  
  tryCatch({
    suppressWarnings({
      boot_result <- wdsm_adaptive(data_boot, ps_formula, pg_formula,
                                  "Y", "A", "survey_weight",
                                  M = 5, use_bias_correction = TRUE, 
                                  verbose = FALSE)
    })
    boot_wdsm[b] <- boot_result$tau
  }, error = function(e) NULL)
}

boot_wdsm <- boot_wdsm[!is.na(boot_wdsm) & boot_wdsm != 0]
wdsm_se_race <- sd(boot_wdsm)
wdsm_ci_race <- quantile(boot_wdsm, c(0.025, 0.975))

cat("\n  WDSM Results (Race):\n")
cat("    Estimate:", round(wdsm_result$tau, 4), "\n")
cat("    SE:", round(wdsm_se_race, 4), "\n")
cat("    95% CI: [", round(wdsm_ci_race[1], 4), ", ", round(wdsm_ci_race[2], 4), "]\n", sep="")

# ==============================================================================
# PART 2: LEAD EXPOSURE ANALYSIS (Supplementary)
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("              PART 2: LEAD EXPOSURE ANALYSIS\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Filter for non-missing lead data
lead_data <- nhanes_data[!is.na(nhanes_data$LBXBPB_LOD), ]
cat("\nSample size with lead data:", nrow(lead_data), "\n")

# Create treatment (dichotomized at median)
median_lead <- median(lead_data$LBXBPB_LOD)
lead_data$lead_high <- as.numeric(lead_data$LBXBPB_LOD > median_lead)

# Define variables for lead analysis
Y_lead <- lead_data$lTELOMEAN
A_lead <- lead_data$lead_high
w_lead <- lead_data$WTMEC4YR
n_lead <- length(Y_lead)
sw_lead <- w_lead * n_lead / sum(w_lead)

# Precision variables for PG model (including RACE as confounder)
precision_vars <- c("RACE_2CAT", "AGE", "SEX", blood_vars)

# Create data frame for lead analysis
df_lead <- data.frame(
  Y = Y_lead,
  A = A_lead,
  sw = sw_lead,
  lead_data[, c(ses_vars, precision_vars)]
)

# ==============================================================================
# Lead Analysis - METHOD 1: PS Full Matching
# ==============================================================================

cat("\n--- PS Full Matching (Lead) ---\n")

ps_formula_lead <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))

suppressWarnings({
  m_ps_lead <- matchit(ps_formula_lead,
                      data = df_lead,
                      method = "full",
                      distance = "glm",
                      link = "logit",
                      estimand = "ATE",
                      s.weights = sw_lead,
                      verbose = FALSE)
})

md_lead <- match.data(m_ps_lead)

# Outcome model with all covariates and interactions
outcome_formula_lead <- Y ~ A * (EDUC_3CAT + MARTL_3CAT + PIR_3CAT + EMPSTAT_4CAT + 
                                 OCC_5CAT + HHSIZE_5CAT + HHINC_5CAT + HIQ_2CAT + 
                                 WIC_2CAT + FDSEC_3CAT + HOD_4CAT + OWNHOME_2CAT +
                                 RACE_2CAT + AGE + SEX + 
                                 LBXWBCSI + LBXLYPCT + LBXMOPCT + LBXNEPCT + 
                                 LBXEOPCT + LBXBAPCT)

fit_lead <- lm(outcome_formula_lead, data = md_lead, weights = weights)
ate_lead <- avg_comparisons(fit_lead, variables = "A", vcov = ~subclass, 
                           wts = "sw", comparison = "difference")

ps_estimate_lead <- ate_lead$estimate
ps_se_lead <- ate_lead$std.error
ps_ci_lead <- c(ate_lead$conf.low, ate_lead$conf.high)

cat("  Estimate:", round(ps_estimate_lead, 4), "\n")
cat("  95% CI: [", round(ps_ci_lead[1], 4), ", ", round(ps_ci_lead[2], 4), "]\n", sep="")

# ==============================================================================
# Lead Analysis - METHOD 2: DSM
# ==============================================================================

cat("\n--- Unweighted DSM (Lead) ---\n")

X_ps_lead_df <- lead_data[, ses_vars]
for (col in names(X_ps_lead_df)) {
  if (is.factor(X_ps_lead_df[[col]])) {
    X_ps_lead_df[[col]] <- as.numeric(X_ps_lead_df[[col]])
  }
}
X_ps_lead <- as.matrix(X_ps_lead_df)

X_pg_lead_df <- lead_data[, c(ses_vars, precision_vars)]
for (col in names(X_pg_lead_df)) {
  if (is.factor(X_pg_lead_df[[col]])) {
    X_pg_lead_df[[col]] <- as.numeric(X_pg_lead_df[[col]])
  }
}
X_pg_lead <- as.matrix(X_pg_lead_df)

suppressWarnings({
  dsm_lead <- dsmatchATE(
    Y = Y_lead,
    X = X_ps_lead,
    A = A_lead,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X_pg_lead,
    cov.balance = FALSE,
    varest = TRUE,
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
})

dsm_estimate_lead <- dsm_lead$est.ds
dsm_se_lead <- sqrt(dsm_lead$bootvar[1,1])
dsm_ci_lead <- c(dsm_estimate_lead - 1.96*dsm_se_lead, 
                 dsm_estimate_lead + 1.96*dsm_se_lead)

cat("  Estimate:", round(dsm_estimate_lead, 4), "\n")
cat("  95% CI: [", round(dsm_ci_lead[1], 4), ", ", round(dsm_ci_lead[2], 4), "]\n", sep="")

# ==============================================================================
# Lead Analysis - METHOD 3: WDSM
# ==============================================================================

cat("\n--- WDSM (Lead) ---\n")

wdsm_lead_data <- lead_data
wdsm_lead_data$Y <- Y_lead
wdsm_lead_data$A <- A_lead
wdsm_lead_data$survey_weight <- w_lead

ps_formula_lead_wdsm <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))
pg_formula_lead_wdsm <- as.formula(paste("~ ", paste(c(ses_vars, precision_vars), 
                                                     collapse = " + ")))

suppressWarnings({
  wdsm_lead_result <- wdsm_adaptive(
    data = wdsm_lead_data,
    ps_formula = ps_formula_lead_wdsm,
    pg_formula = pg_formula_lead_wdsm,
    outcome_var = "Y",
    treatment_var = "A",
    weight_var = "survey_weight",
    M = 5,
    use_bias_correction = TRUE,
    verbose = FALSE
  )
})

# Bootstrap
set.seed(2024)
boot_wdsm_lead <- numeric(200)
for (b in 1:200) {
  m_star <- rmultinom(1, n_lead, rep(1/n_lead, n_lead))[, 1]
  data_boot <- wdsm_lead_data
  data_boot$survey_weight <- m_star * w_lead
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  
  tryCatch({
    suppressWarnings({
      boot_result <- wdsm_adaptive(data_boot, ps_formula_lead_wdsm, pg_formula_lead_wdsm,
                                  "Y", "A", "survey_weight",
                                  M = 5, use_bias_correction = TRUE, 
                                  verbose = FALSE)
    })
    boot_wdsm_lead[b] <- boot_result$tau
  }, error = function(e) NULL)
}

boot_wdsm_lead <- boot_wdsm_lead[!is.na(boot_wdsm_lead) & boot_wdsm_lead != 0]
wdsm_se_lead <- sd(boot_wdsm_lead)
wdsm_ci_lead <- quantile(boot_wdsm_lead, c(0.025, 0.975))

cat("  Estimate:", round(wdsm_lead_result$tau, 4), "\n")
cat("  95% CI: [", round(wdsm_ci_lead[1], 4), ", ", round(wdsm_ci_lead[2], 4), "]\n", sep="")

# ==============================================================================
# FINAL COMPARISON TABLES
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                    FINAL CORRECTED RESULTS\n")
cat("=" ,rep("=", 70), "\n", sep="")

cat("\n=== TABLE 1: RACE ANALYSIS ===\n")
race_table <- data.frame(
  Method = c("Unweighted DSM",
             "Survey-Weighted PS Full Matching",
             "WDSM"),
  `ACD Estimate` = c(dsm_estimate_race, ps_estimate_race, wdsm_result$tau),
  `95% CI Lower` = c(dsm_ci_race[1], ps_ci_race[1], wdsm_ci_race[1]),
  `95% CI Upper` = c(dsm_ci_race[2], ps_ci_race[2], wdsm_ci_race[2]),
  check.names = FALSE
)
print(race_table, digits = 4, row.names = FALSE)

cat("\n=== TABLE 2: LEAD EXPOSURE ANALYSIS ===\n")
lead_table <- data.frame(
  Method = c("Unweighted DSM",
             "Survey-Weighted PS Full Matching",
             "WDSM"),
  `PATE Estimate` = c(dsm_estimate_lead, ps_estimate_lead, wdsm_lead_result$tau),
  `95% CI Lower` = c(dsm_ci_lead[1], ps_ci_lead[1], wdsm_ci_lead[1]),
  `95% CI Upper` = c(dsm_ci_lead[2], ps_ci_lead[2], wdsm_ci_lead[2]),
  check.names = FALSE
)
print(lead_table, digits = 4, row.names = FALSE)

# Save results
save(race_table, lead_table, 
     file = "analysis_results/corrected_final_results.rda")

cat("\n=== Analysis Complete ===\n")
cat("Results saved to analysis_results/corrected_final_results.rda\n")
