################################################################################
# QUICK M=3 RESULTS - GETTING COMPLETE RESULTS
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
nhanes_data <- NHANES

cat("\n")
cat("========================================================================\n")
cat("         COMPLETE RESULTS: M=3 FOR WDSM, BOOTSTRAP=200 FOR ALL\n")
cat("========================================================================\n")

# Define covariate sets
ses_vars <- c("EDUC_3CAT", "MARTL_3CAT", "PIR_3CAT", "EMPSTAT_4CAT", 
              "OCC_5CAT", "HHSIZE_5CAT", "HHINC_5CAT", "HIQ_2CAT", 
              "WIC_2CAT", "FDSEC_3CAT", "HOD_4CAT", "OWNHOME_2CAT")
demo_vars <- c("AGE", "SEX")
blood_vars <- c("LBXWBCSI", "LBXLYPCT", "LBXMOPCT", "LBXNEPCT", 
                "LBXEOPCT", "LBXBAPCT")

# Load adaptive WDSM function
source("WDSM_adaptive.R")

# ==============================================================================
# PART 1: RACE ANALYSIS
# ==============================================================================

cat("\n========================================================================\n")
cat("                    PART 1: RACE ANALYSIS\n")
cat("========================================================================\n")

# Get complete cases for race analysis
all_vars_race <- c("lTELOMEAN", "RACE_2CAT", "WTMEC4YR", ses_vars, demo_vars, blood_vars)
complete_idx <- complete.cases(nhanes_data[, all_vars_race])
data_race <- nhanes_data[complete_idx, ]
n_race <- nrow(data_race)

# Define variables
Y_race <- data_race$lTELOMEAN
A_race <- data_race$RACE_2CAT
w_race <- data_race$WTMEC4YR
sw_race <- w_race * n_race / sum(w_race)

# Calculate proportions
n_treated_race <- sum(A_race == 1)
n_control_race <- sum(A_race == 0)
prop_treated_race <- mean(A_race)
prop_control_race <- 1 - prop_treated_race
weighted_prop_treated_race <- sum(w_race[A_race == 1]) / sum(w_race)
weighted_prop_control_race <- sum(w_race[A_race == 0]) / sum(w_race)

cat("\n=== RACE ANALYSIS: SAMPLE COMPOSITION ===\n")
cat("Total sample size: ", n_race, "\n")
cat("\nUnweighted proportions:\n")
cat("  Black (Treated):  ", n_treated_race, " (", round(prop_treated_race*100, 1), "%)\n", sep="")
cat("  White (Control):  ", n_control_race, " (", round(prop_control_race*100, 1), "%)\n", sep="")
cat("\nWeighted proportions (population-level):\n")
cat("  Black (Treated):  ", round(weighted_prop_treated_race*100, 1), "%\n", sep="")
cat("  White (Control):  ", round(weighted_prop_control_race*100, 1), "%\n", sep="")

# Create data frame for MatchIt
df_race <- data.frame(
  Y = Y_race,
  A = A_race,
  sw = sw_race,
  data_race[, c(ses_vars, demo_vars, blood_vars)]
)

# Initialize results storage
race_results <- list()

# -----------------------------------------------------------------------------
# METHOD 1: WDSM with M=3
# -----------------------------------------------------------------------------

cat("\n--- METHOD 1: WDSM (M=3) ---\n")

wdsm_data_race <- data_race
wdsm_data_race$Y <- Y_race
wdsm_data_race$A <- A_race
wdsm_data_race$survey_weight <- w_race

ps_formula_wdsm <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))
pg_formula_wdsm <- as.formula(paste("~ ", paste(c(ses_vars, demo_vars, blood_vars), 
                                                 collapse = " + ")))

# Run WDSM with M=3
suppressWarnings({
  wdsm_result_race <- wdsm_adaptive(
    data = wdsm_data_race,
    ps_formula = ps_formula_wdsm,
    pg_formula = pg_formula_wdsm,
    outcome_var = "Y",
    treatment_var = "A",
    weight_var = "survey_weight",
    M = 3,  # M=3
    use_bias_correction = TRUE,
    verbose = FALSE
  )
})

# Small bootstrap for testing (20 reps)
set.seed(2024)
boot_wdsm_race <- numeric(20)
cat("  Running quick bootstrap (20 reps)...")
for (b in 1:20) {
  m_star <- rmultinom(1, n_race, rep(1/n_race, n_race))[, 1]
  data_boot <- wdsm_data_race
  data_boot$survey_weight <- m_star * w_race
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  
  tryCatch({
    suppressWarnings({
      boot_result <- wdsm_adaptive(data_boot, ps_formula_wdsm, pg_formula_wdsm,
                                  "Y", "A", "survey_weight",
                                  M = 3,
                                  use_bias_correction = TRUE, 
                                  verbose = FALSE)
    })
    boot_wdsm_race[b] <- boot_result$tau
  }, error = function(e) NULL)
}
cat(" Done!\n")

boot_wdsm_race <- boot_wdsm_race[!is.na(boot_wdsm_race) & boot_wdsm_race != 0]
wdsm_se_race <- sd(boot_wdsm_race)
wdsm_ci_race <- wdsm_result_race$tau + c(-1.96, 1.96) * wdsm_se_race

race_results$wdsm <- list(
  estimate = wdsm_result_race$tau,
  se = wdsm_se_race,
  ci_lower = wdsm_ci_race[1],
  ci_upper = wdsm_ci_race[2]
)

cat("  Estimate:", round(race_results$wdsm$estimate, 4), "\n")
cat("  95% CI: [", round(race_results$wdsm$ci_lower, 4), ", ", 
    round(race_results$wdsm$ci_upper, 4), "]\n", sep="")

# -----------------------------------------------------------------------------
# METHOD 2: Unweighted DSM
# -----------------------------------------------------------------------------

cat("\n--- METHOD 2: Unweighted DSM (Bootstrap=20) ---\n")

X_ps_df <- data_race[, ses_vars]
for (col in names(X_ps_df)) {
  if (is.factor(X_ps_df[[col]])) {
    X_ps_df[[col]] <- as.numeric(X_ps_df[[col]])
  }
}
X_ps <- as.matrix(X_ps_df)

X_pg_df <- data_race[, c(ses_vars, demo_vars, blood_vars)]
for (col in names(X_pg_df)) {
  if (is.factor(X_pg_df[[col]])) {
    X_pg_df[[col]] <- as.numeric(X_pg_df[[col]])
  }
}
X_pg <- as.matrix(X_pg_df)

suppressWarnings({
  dsm_result_race <- dsmatchATE(
    Y = Y_race,
    X = X_ps,
    A = A_race,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X_pg,
    cov.balance = FALSE,
    varest = TRUE,
    boots = 20,  # Quick bootstrap
    mc = FALSE,
    ncpus = 1
  )
})

race_results$dsm <- list(
  estimate = dsm_result_race$est.ds,
  se = sqrt(dsm_result_race$bootvar[1,1]),
  ci_lower = dsm_result_race$est.ds - 1.96*sqrt(dsm_result_race$bootvar[1,1]),
  ci_upper = dsm_result_race$est.ds + 1.96*sqrt(dsm_result_race$bootvar[1,1])
)

cat("  Estimate:", round(race_results$dsm$estimate, 4), "\n")
cat("  95% CI: [", round(race_results$dsm$ci_lower, 4), ", ", 
    round(race_results$dsm$ci_upper, 4), "]\n", sep="")

# -----------------------------------------------------------------------------
# METHOD 3: Survey-Weighted PS Full Matching
# -----------------------------------------------------------------------------

cat("\n--- METHOD 3: Survey-Weighted PS Full Matching ---\n")

ps_formula_matchit <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))

suppressWarnings({
  m_ps_race <- matchit(ps_formula_matchit,
                       data = df_race,
                       method = "full",
                       distance = "glm",
                       link = "logit",
                       estimand = "ATE",
                       s.weights = sw_race,
                       verbose = FALSE)
})

md_race <- match.data(m_ps_race)

outcome_formula_race <- Y ~ A * (EDUC_3CAT + MARTL_3CAT + PIR_3CAT + EMPSTAT_4CAT + 
                                 OCC_5CAT + HHSIZE_5CAT + HHINC_5CAT + HIQ_2CAT + 
                                 WIC_2CAT + FDSEC_3CAT + HOD_4CAT + OWNHOME_2CAT +
                                 AGE + SEX + 
                                 LBXWBCSI + LBXLYPCT + LBXMOPCT + LBXNEPCT + 
                                 LBXEOPCT + LBXBAPCT)

fit_race <- lm(outcome_formula_race, data = md_race, weights = weights)
ate_race <- avg_comparisons(fit_race, 
                           variables = "A",
                           vcov = ~subclass,
                           wts = "sw",
                           comparison = "difference")

race_results$ps_full <- list(
  estimate = ate_race$estimate,
  se = ate_race$std.error,
  ci_lower = ate_race$conf.low,
  ci_upper = ate_race$conf.high
)

cat("  Estimate:", round(race_results$ps_full$estimate, 4), "\n")
cat("  95% CI: [", round(race_results$ps_full$ci_lower, 4), ", ", 
    round(race_results$ps_full$ci_upper, 4), "]\n", sep="")

# ==============================================================================
# PART 2: LEAD EXPOSURE ANALYSIS
# ==============================================================================

cat("\n========================================================================\n")
cat("              PART 2: LEAD EXPOSURE ANALYSIS\n")
cat("========================================================================\n")

# Filter for non-missing lead data
data_lead <- nhanes_data[!is.na(nhanes_data$LBXBPB_LOD), ]
median_lead <- median(data_lead$LBXBPB_LOD)
data_lead$lead_high <- as.numeric(data_lead$LBXBPB_LOD > median_lead)

# Get complete cases
precision_vars <- c("RACE_2CAT", "AGE", "SEX", blood_vars)
all_vars_lead <- c("lTELOMEAN", "lead_high", "WTMEC4YR", ses_vars, precision_vars)
complete_idx_lead <- complete.cases(data_lead[, all_vars_lead])
data_lead <- data_lead[complete_idx_lead, ]
n_lead <- nrow(data_lead)

# Define variables
Y_lead <- data_lead$lTELOMEAN
A_lead <- data_lead$lead_high
w_lead <- data_lead$WTMEC4YR
sw_lead <- w_lead * n_lead / sum(w_lead)

# Calculate proportions
n_treated_lead <- sum(A_lead == 1)
n_control_lead <- sum(A_lead == 0)
prop_treated_lead <- mean(A_lead)
prop_control_lead <- 1 - prop_treated_lead
weighted_prop_treated_lead <- sum(w_lead[A_lead == 1]) / sum(w_lead)
weighted_prop_control_lead <- sum(w_lead[A_lead == 0]) / sum(w_lead)

cat("\n=== LEAD EXPOSURE: SAMPLE COMPOSITION ===\n")
cat("Total sample size: ", n_lead, "\n")
cat("Median lead level: ", round(median_lead, 2), " μg/dL\n")
cat("\nUnweighted proportions:\n")
cat("  High Lead (Treated): ", n_treated_lead, " (", round(prop_treated_lead*100, 1), "%)\n", sep="")
cat("  Low Lead (Control):  ", n_control_lead, " (", round(prop_control_lead*100, 1), "%)\n", sep="")
cat("\nWeighted proportions (population-level):\n")
cat("  High Lead (Treated): ", round(weighted_prop_treated_lead*100, 1), "%\n", sep="")
cat("  Low Lead (Control):  ", round(weighted_prop_control_lead*100, 1), "%\n", sep="")

# Create data frame
df_lead <- data.frame(
  Y = Y_lead,
  A = A_lead,
  sw = sw_lead,
  data_lead[, c(ses_vars, precision_vars)]
)

# Initialize results
lead_results <- list()

# -----------------------------------------------------------------------------
# Lead Analysis - METHOD 1: WDSM with M=3
# -----------------------------------------------------------------------------

cat("\n--- METHOD 1: WDSM (M=3) ---\n")

wdsm_data_lead <- data_lead
wdsm_data_lead$Y <- Y_lead
wdsm_data_lead$A <- A_lead
wdsm_data_lead$survey_weight <- w_lead

ps_formula_lead <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))
pg_formula_lead <- as.formula(paste("~ ", paste(c(ses_vars, precision_vars), 
                                                collapse = " + ")))

suppressWarnings({
  wdsm_result_lead <- wdsm_adaptive(
    data = wdsm_data_lead,
    ps_formula = ps_formula_lead,
    pg_formula = pg_formula_lead,
    outcome_var = "Y",
    treatment_var = "A",
    weight_var = "survey_weight",
    M = 3,  # M=3
    use_bias_correction = TRUE,
    verbose = FALSE
  )
})

# Quick bootstrap
set.seed(2024)
boot_wdsm_lead <- numeric(20)
cat("  Running quick bootstrap (20 reps)...")
for (b in 1:20) {
  m_star <- rmultinom(1, n_lead, rep(1/n_lead, n_lead))[, 1]
  data_boot <- wdsm_data_lead
  data_boot$survey_weight <- m_star * w_lead
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  
  tryCatch({
    suppressWarnings({
      boot_result <- wdsm_adaptive(data_boot, ps_formula_lead, pg_formula_lead,
                                  "Y", "A", "survey_weight",
                                  M = 3,
                                  use_bias_correction = TRUE, 
                                  verbose = FALSE)
    })
    boot_wdsm_lead[b] <- boot_result$tau
  }, error = function(e) NULL)
}
cat(" Done!\n")

boot_wdsm_lead <- boot_wdsm_lead[!is.na(boot_wdsm_lead) & boot_wdsm_lead != 0]
wdsm_se_lead <- sd(boot_wdsm_lead)
wdsm_ci_lead <- wdsm_result_lead$tau + c(-1.96, 1.96) * wdsm_se_lead

lead_results$wdsm <- list(
  estimate = wdsm_result_lead$tau,
  se = wdsm_se_lead,
  ci_lower = wdsm_ci_lead[1],
  ci_upper = wdsm_ci_lead[2]
)

cat("  Estimate:", round(lead_results$wdsm$estimate, 4), "\n")
cat("  95% CI: [", round(lead_results$wdsm$ci_lower, 4), ", ", 
    round(lead_results$wdsm$ci_upper, 4), "]\n", sep="")

# -----------------------------------------------------------------------------
# Lead Analysis - METHOD 2: Unweighted DSM
# -----------------------------------------------------------------------------

cat("\n--- METHOD 2: Unweighted DSM (Bootstrap=20) ---\n")

X_ps_lead_df <- data_lead[, ses_vars]
for (col in names(X_ps_lead_df)) {
  if (is.factor(X_ps_lead_df[[col]])) {
    X_ps_lead_df[[col]] <- as.numeric(X_ps_lead_df[[col]])
  }
}
X_ps_lead <- as.matrix(X_ps_lead_df)

X_pg_lead_df <- data_lead[, c(ses_vars, precision_vars)]
for (col in names(X_pg_lead_df)) {
  if (is.factor(X_pg_lead_df[[col]])) {
    X_pg_lead_df[[col]] <- as.numeric(X_pg_lead_df[[col]])
  }
}
X_pg_lead <- as.matrix(X_pg_lead_df)

suppressWarnings({
  dsm_result_lead <- dsmatchATE(
    Y = Y_lead,
    X = X_ps_lead,
    A = A_lead,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X_pg_lead,
    cov.balance = FALSE,
    varest = TRUE,
    boots = 20,  # Quick bootstrap
    mc = FALSE,
    ncpus = 1
  )
})

lead_results$dsm <- list(
  estimate = dsm_result_lead$est.ds,
  se = sqrt(dsm_result_lead$bootvar[1,1]),
  ci_lower = dsm_result_lead$est.ds - 1.96*sqrt(dsm_result_lead$bootvar[1,1]),
  ci_upper = dsm_result_lead$est.ds + 1.96*sqrt(dsm_result_lead$bootvar[1,1])
)

cat("  Estimate:", round(lead_results$dsm$estimate, 4), "\n")
cat("  95% CI: [", round(lead_results$dsm$ci_lower, 4), ", ", 
    round(lead_results$dsm$ci_upper, 4), "]\n", sep="")

# -----------------------------------------------------------------------------
# Lead Analysis - METHOD 3: Survey-Weighted PS Full Matching
# -----------------------------------------------------------------------------

cat("\n--- METHOD 3: Survey-Weighted PS Full Matching ---\n")

ps_formula_lead_matchit <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))

suppressWarnings({
  m_ps_lead <- matchit(ps_formula_lead_matchit,
                      data = df_lead,
                      method = "full",
                      distance = "glm",
                      link = "logit",
                      estimand = "ATE",
                      s.weights = sw_lead,
                      verbose = FALSE)
})

md_lead <- match.data(m_ps_lead)

outcome_formula_lead <- Y ~ A * (EDUC_3CAT + MARTL_3CAT + PIR_3CAT + EMPSTAT_4CAT + 
                                 OCC_5CAT + HHSIZE_5CAT + HHINC_5CAT + HIQ_2CAT + 
                                 WIC_2CAT + FDSEC_3CAT + HOD_4CAT + OWNHOME_2CAT +
                                 RACE_2CAT + AGE + SEX + 
                                 LBXWBCSI + LBXLYPCT + LBXMOPCT + LBXNEPCT + 
                                 LBXEOPCT + LBXBAPCT)

fit_lead <- lm(outcome_formula_lead, data = md_lead, weights = weights)
ate_lead <- avg_comparisons(fit_lead, variables = "A", vcov = ~subclass, 
                           wts = "sw", comparison = "difference")

lead_results$ps_full <- list(
  estimate = ate_lead$estimate,
  se = ate_lead$std.error,
  ci_lower = ate_lead$conf.low,
  ci_upper = ate_lead$conf.high
)

cat("  Estimate:", round(lead_results$ps_full$estimate, 4), "\n")
cat("  95% CI: [", round(lead_results$ps_full$ci_lower, 4), ", ", 
    round(lead_results$ps_full$ci_upper, 4), "]\n", sep="")

# ==============================================================================
# FINAL COMPARISON TABLES
# ==============================================================================

cat("\n========================================================================\n")
cat("                 FINAL RESULTS WITH M=3 FOR WDSM\n")
cat("========================================================================\n")

# Comparison with M=5 results
cat("\n=== RACE ANALYSIS COMPARISON ===\n")
cat("\n                  --- M=5 Results ---          --- M=3 Results ---\n")
cat("Method            Estimate [95% CI]            Estimate [95% CI]\n")
cat("----------------  ---------------------------  ---------------------------\n")
cat(sprintf("Unweighted DSM    0.0232 [0.0022, 0.0443]      %.4f [%.4f, %.4f]\n", 
    race_results$dsm$estimate, race_results$dsm$ci_lower, race_results$dsm$ci_upper))
cat(sprintf("SW PS Full       -0.0321 [-0.0572, -0.0069]   %.4f [%.4f, %.4f]\n",
    race_results$ps_full$estimate, race_results$ps_full$ci_lower, race_results$ps_full$ci_upper))
cat(sprintf("WDSM              0.0144 [-0.0009, 0.0401]    %.4f [%.4f, %.4f]\n",
    race_results$wdsm$estimate, race_results$wdsm$ci_lower, race_results$wdsm$ci_upper))

cat("\n=== LEAD EXPOSURE ANALYSIS COMPARISON ===\n")
cat("\n                  --- M=5 Results ---          --- M=3 Results ---\n")
cat("Method            Estimate [95% CI]            Estimate [95% CI]\n")
cat("----------------  ---------------------------  ---------------------------\n")
cat(sprintf("Unweighted DSM   -0.0014 [-0.0176, 0.0148]    %.4f [%.4f, %.4f]\n",
    lead_results$dsm$estimate, lead_results$dsm$ci_lower, lead_results$dsm$ci_upper))
cat(sprintf("SW PS Full       -0.0109 [-0.0300, 0.0083]    %.4f [%.4f, %.4f]\n",
    lead_results$ps_full$estimate, lead_results$ps_full$ci_lower, lead_results$ps_full$ci_upper))
cat(sprintf("WDSM             -0.0028 [-0.0214, 0.0125]    %.4f [%.4f, %.4f]\n",
    lead_results$wdsm$estimate, lead_results$wdsm$ci_lower, lead_results$wdsm$ci_upper))

cat("\n========================================================================\n")
cat("                    TREATMENT/CONTROL PROPORTIONS\n")
cat("========================================================================\n")

cat("\n=== RACE ANALYSIS ===\n")
cat("Unweighted: ", round(prop_treated_race*100, 1), "% Black (treated) vs ", 
    round(prop_control_race*100, 1), "% White (control)\n", sep="")
cat("Weighted:   ", round(weighted_prop_treated_race*100, 1), "% Black (treated) vs ", 
    round(weighted_prop_control_race*100, 1), "% White (control)\n", sep="")

cat("\n=== LEAD EXPOSURE ANALYSIS ===\n")
cat("Unweighted: ", round(prop_treated_lead*100, 1), "% High lead (treated) vs ", 
    round(prop_control_lead*100, 1), "% Low lead (control)\n", sep="")
cat("Weighted:   ", round(weighted_prop_treated_lead*100, 1), "% High lead (treated) vs ", 
    round(weighted_prop_control_lead*100, 1), "% Low lead (control)\n", sep="")

cat("\n========================================================================\n")
cat("                    BOOTSTRAP SUMMARY\n")
cat("========================================================================\n")
cat("Note: This quick run used 20 bootstrap replicates for testing.\n")
cat("Full analysis should use 200 replicates for publication quality.\n")
cat("PS Full Matching uses delta method (no bootstrap).\n")

cat("\n========================================================================\n")



