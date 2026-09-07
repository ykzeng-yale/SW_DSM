################################################################################
# COMPLETE ANALYSIS WITH ALL METHODS (INCLUDING PSM AND PGM)
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
cat("    COMPLETE ANALYSIS WITH ALL METHODS FROM SIMULATION\n")
cat("========================================================================\n")

# Define covariate sets
ses_vars <- c("EDUC_3CAT", "MARTL_3CAT", "PIR_3CAT", "EMPSTAT_4CAT", 
              "OCC_5CAT", "HHSIZE_5CAT", "HHINC_5CAT", "HIQ_2CAT", 
              "WIC_2CAT", "FDSEC_3CAT", "HOD_4CAT", "OWNHOME_2CAT")
demo_vars <- c("AGE", "SEX")
blood_vars <- c("LBXWBCSI", "LBXLYPCT", "LBXMOPCT", "LBXNEPCT", 
                "LBXEOPCT", "LBXBAPCT")

# Set bootstrap replications
B_BOOTSTRAP <- 200

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

# Calculate treatment/control proportions
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

# Prepare matrices for dsmatch methods
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
# METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING (DSM)
# -----------------------------------------------------------------------------

cat("\n--- METHOD 1: Unweighted DSM (1:1 matching) ---\n")

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
    boots = B_BOOTSTRAP,
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
# METHOD 2: UNWEIGHTED PROGNOSTIC SCORE MATCHING (PGM)
# -----------------------------------------------------------------------------

cat("\n--- METHOD 2: Unweighted PGM (1:1 matching) ---\n")

suppressWarnings({
  pg_result_race <- dsmatchATE(
    Y = Y_race,
    X = X_pg,  # PG model uses X_pg (SES + demo + blood)
    A = A_race,
    method = "pg",
    model.pg = "glm",  # Always glm for PG
    cov.balance = FALSE,
    varest = TRUE,
    boots = B_BOOTSTRAP,
    mc = FALSE,
    ncpus = 1
  )
})

race_results$pgm <- list(
  estimate = pg_result_race$est.pg,
  se = sqrt(pg_result_race$bootvar[1,1]),
  ci_lower = pg_result_race$est.pg - 1.96*sqrt(pg_result_race$bootvar[1,1]),
  ci_upper = pg_result_race$est.pg + 1.96*sqrt(pg_result_race$bootvar[1,1])
)

cat("  Estimate:", round(race_results$pgm$estimate, 4), "\n")
cat("  95% CI: [", round(race_results$pgm$ci_lower, 4), ", ", 
    round(race_results$pgm$ci_upper, 4), "]\n", sep="")

# -----------------------------------------------------------------------------
# METHOD 3: UNWEIGHTED PROPENSITY SCORE MATCHING (PSM)
# -----------------------------------------------------------------------------

cat("\n--- METHOD 3: Unweighted PSM (1:1 matching) ---\n")

suppressWarnings({
  ps_result_race <- dsmatchATE(
    Y = Y_race,
    X = X_ps,  # PS model uses only SES variables
    A = A_race,
    method = "ps",
    model.ps = "logit",  # Always logit for PS
    cov.balance = FALSE,
    varest = TRUE,
    boots = B_BOOTSTRAP,
    mc = FALSE,
    ncpus = 1
  )
})

race_results$psm <- list(
  estimate = ps_result_race$est.ps,
  se = sqrt(ps_result_race$bootvar[1,1]),
  ci_lower = ps_result_race$est.ps - 1.96*sqrt(ps_result_race$bootvar[1,1]),
  ci_upper = ps_result_race$est.ps + 1.96*sqrt(ps_result_race$bootvar[1,1])
)

cat("  Estimate:", round(race_results$psm$estimate, 4), "\n")
cat("  95% CI: [", round(race_results$psm$ci_lower, 4), ", ", 
    round(race_results$psm$ci_upper, 4), "]\n", sep="")

# -----------------------------------------------------------------------------
# METHOD 4: SURVEY-WEIGHTED PS FULL MATCHING
# -----------------------------------------------------------------------------

cat("\n--- METHOD 4: Survey-Weighted PS Full Matching ---\n")

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

# -----------------------------------------------------------------------------
# METHOD 5: WEIGHTED DOUBLE SCORE MATCHING (WDSM)
# -----------------------------------------------------------------------------

cat("\n--- METHOD 5: WDSM (1:5 matching) ---\n")

wdsm_data_race <- data_race
wdsm_data_race$Y <- Y_race
wdsm_data_race$A <- A_race
wdsm_data_race$survey_weight <- w_race

ps_formula_wdsm <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))
pg_formula_wdsm <- as.formula(paste("~ ", paste(c(ses_vars, demo_vars, blood_vars), 
                                                 collapse = " + ")))

suppressWarnings({
  wdsm_result_race <- wdsm_adaptive(
    data = wdsm_data_race,
    ps_formula = ps_formula_wdsm,
    pg_formula = pg_formula_wdsm,
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
boot_wdsm_race <- numeric(B_BOOTSTRAP)
cat("  Running bootstrap...")
for (b in 1:B_BOOTSTRAP) {
  m_star <- rmultinom(1, n_race, rep(1/n_race, n_race))[, 1]
  data_boot <- wdsm_data_race
  data_boot$survey_weight <- m_star * w_race
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  
  tryCatch({
    suppressWarnings({
      boot_result <- wdsm_adaptive(data_boot, ps_formula_wdsm, pg_formula_wdsm,
                                  "Y", "A", "survey_weight",
                                  M = 5,
                                  use_bias_correction = TRUE, 
                                  verbose = FALSE)
    })
    boot_wdsm_race[b] <- boot_result$tau
  }, error = function(e) NULL)
}
cat(" Done!\n")

boot_wdsm_race <- boot_wdsm_race[!is.na(boot_wdsm_race) & boot_wdsm_race != 0]
wdsm_se_race <- sd(boot_wdsm_race)
wdsm_ci_race <- quantile(boot_wdsm_race, c(0.025, 0.975))

race_results$wdsm <- list(
  estimate = wdsm_result_race$tau,
  se = wdsm_se_race,
  ci_lower = wdsm_ci_race[1],
  ci_upper = wdsm_ci_race[2]
)

cat("  Estimate:", round(race_results$wdsm$estimate, 4), "\n")
cat("  95% CI: [", round(race_results$wdsm$ci_lower, 4), ", ", 
    round(race_results$wdsm$ci_upper, 4), "]\n", sep="")

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

# Prepare matrices for dsmatch methods
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
# Lead Analysis - METHOD 1: UNWEIGHTED DSM
# -----------------------------------------------------------------------------

cat("\n--- METHOD 1: Unweighted DSM (1:1 matching) ---\n")

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
    boots = B_BOOTSTRAP,
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
# Lead Analysis - METHOD 2: UNWEIGHTED PGM
# -----------------------------------------------------------------------------

cat("\n--- METHOD 2: Unweighted PGM (1:1 matching) ---\n")

suppressWarnings({
  pg_result_lead <- dsmatchATE(
    Y = Y_lead,
    X = X_pg_lead,  # PG model uses X_pg (SES + precision vars)
    A = A_lead,
    method = "pg",
    model.pg = "glm",
    cov.balance = FALSE,
    varest = TRUE,
    boots = B_BOOTSTRAP,
    mc = FALSE,
    ncpus = 1
  )
})

lead_results$pgm <- list(
  estimate = pg_result_lead$est.pg,
  se = sqrt(pg_result_lead$bootvar[1,1]),
  ci_lower = pg_result_lead$est.pg - 1.96*sqrt(pg_result_lead$bootvar[1,1]),
  ci_upper = pg_result_lead$est.pg + 1.96*sqrt(pg_result_lead$bootvar[1,1])
)

cat("  Estimate:", round(lead_results$pgm$estimate, 4), "\n")
cat("  95% CI: [", round(lead_results$pgm$ci_lower, 4), ", ", 
    round(lead_results$pgm$ci_upper, 4), "]\n", sep="")

# -----------------------------------------------------------------------------
# Lead Analysis - METHOD 3: UNWEIGHTED PSM
# -----------------------------------------------------------------------------

cat("\n--- METHOD 3: Unweighted PSM (1:1 matching) ---\n")

suppressWarnings({
  ps_result_lead <- dsmatchATE(
    Y = Y_lead,
    X = X_ps_lead,  # PS model uses only SES variables
    A = A_lead,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = TRUE,
    boots = B_BOOTSTRAP,
    mc = FALSE,
    ncpus = 1
  )
})

lead_results$psm <- list(
  estimate = ps_result_lead$est.ps,
  se = sqrt(ps_result_lead$bootvar[1,1]),
  ci_lower = ps_result_lead$est.ps - 1.96*sqrt(ps_result_lead$bootvar[1,1]),
  ci_upper = ps_result_lead$est.ps + 1.96*sqrt(ps_result_lead$bootvar[1,1])
)

cat("  Estimate:", round(lead_results$psm$estimate, 4), "\n")
cat("  95% CI: [", round(lead_results$psm$ci_lower, 4), ", ", 
    round(lead_results$psm$ci_upper, 4), "]\n", sep="")

# -----------------------------------------------------------------------------
# Lead Analysis - METHOD 4: SURVEY-WEIGHTED PS FULL MATCHING
# -----------------------------------------------------------------------------

cat("\n--- METHOD 4: Survey-Weighted PS Full Matching ---\n")

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

# -----------------------------------------------------------------------------
# Lead Analysis - METHOD 5: WDSM
# -----------------------------------------------------------------------------

cat("\n--- METHOD 5: WDSM (1:5 matching) ---\n")

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
    M = 5,
    use_bias_correction = TRUE,
    verbose = FALSE
  )
})

# Bootstrap
set.seed(2024)
boot_wdsm_lead <- numeric(B_BOOTSTRAP)
cat("  Running bootstrap...")
for (b in 1:B_BOOTSTRAP) {
  m_star <- rmultinom(1, n_lead, rep(1/n_lead, n_lead))[, 1]
  data_boot <- wdsm_data_lead
  data_boot$survey_weight <- m_star * w_lead
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  
  tryCatch({
    suppressWarnings({
      boot_result <- wdsm_adaptive(data_boot, ps_formula_lead, pg_formula_lead,
                                  "Y", "A", "survey_weight",
                                  M = 5,
                                  use_bias_correction = TRUE, 
                                  verbose = FALSE)
    })
    boot_wdsm_lead[b] <- boot_result$tau
  }, error = function(e) NULL)
}
cat(" Done!\n")

boot_wdsm_lead <- boot_wdsm_lead[!is.na(boot_wdsm_lead) & boot_wdsm_lead != 0]
wdsm_se_lead <- sd(boot_wdsm_lead)
wdsm_ci_lead <- quantile(boot_wdsm_lead, c(0.025, 0.975))

lead_results$wdsm <- list(
  estimate = wdsm_result_lead$tau,
  se = wdsm_se_lead,
  ci_lower = wdsm_ci_lead[1],
  ci_upper = wdsm_ci_lead[2]
)

cat("  Estimate:", round(lead_results$wdsm$estimate, 4), "\n")
cat("  95% CI: [", round(lead_results$wdsm$ci_lower, 4), ", ", 
    round(lead_results$wdsm$ci_upper, 4), "]\n", sep="")

# ==============================================================================
# FINAL COMPARISON TABLES
# ==============================================================================

cat("\n========================================================================\n")
cat("                 FINAL RESULTS WITH ALL METHODS\n")
cat("========================================================================\n")

# Create formatted tables
race_table <- data.frame(
  Method = c("Unweighted PSM (1:1)",
             "Unweighted PGM (1:1)",
             "Unweighted DSM (1:1)",
             "Survey-Weighted PS Full",
             "WDSM (1:5)"),
  `PATE Estimate` = sprintf("%.4f", c(race_results$psm$estimate,
                                       race_results$pgm$estimate,
                                       race_results$dsm$estimate, 
                                       race_results$ps_full$estimate, 
                                       race_results$wdsm$estimate)),
  `95% CI` = c(
    sprintf("[%.4f, %.4f]", race_results$psm$ci_lower, race_results$psm$ci_upper),
    sprintf("[%.4f, %.4f]", race_results$pgm$ci_lower, race_results$pgm$ci_upper),
    sprintf("[%.4f, %.4f]", race_results$dsm$ci_lower, race_results$dsm$ci_upper),
    sprintf("[%.4f, %.4f]", race_results$ps_full$ci_lower, race_results$ps_full$ci_upper),
    sprintf("[%.4f, %.4f]", race_results$wdsm$ci_lower, race_results$wdsm$ci_upper)
  ),
  Bootstrap = c("200", "200", "200", "N/A (Delta)", "200"),
  check.names = FALSE
)

lead_table <- data.frame(
  Method = c("Unweighted PSM (1:1)",
             "Unweighted PGM (1:1)",
             "Unweighted DSM (1:1)",
             "Survey-Weighted PS Full",
             "WDSM (1:5)"),
  `PATE Estimate` = sprintf("%.4f", c(lead_results$psm$estimate,
                                       lead_results$pgm$estimate,
                                       lead_results$dsm$estimate, 
                                       lead_results$ps_full$estimate, 
                                       lead_results$wdsm$estimate)),
  `95% CI` = c(
    sprintf("[%.4f, %.4f]", lead_results$psm$ci_lower, lead_results$psm$ci_upper),
    sprintf("[%.4f, %.4f]", lead_results$pgm$ci_lower, lead_results$pgm$ci_upper),
    sprintf("[%.4f, %.4f]", lead_results$dsm$ci_lower, lead_results$dsm$ci_upper),
    sprintf("[%.4f, %.4f]", lead_results$ps_full$ci_lower, lead_results$ps_full$ci_upper),
    sprintf("[%.4f, %.4f]", lead_results$wdsm$ci_lower, lead_results$wdsm$ci_upper)
  ),
  Bootstrap = c("200", "200", "200", "N/A (Delta)", "200"),
  check.names = FALSE
)

cat("\n=== TABLE 1: RACE ANALYSIS ===\n")
print(race_table, row.names = FALSE)

cat("\n=== TABLE 2: LEAD EXPOSURE ANALYSIS ===\n")
print(lead_table, row.names = FALSE)

# Save results
save(race_results, lead_results, race_table, lead_table,
     prop_treated_race, prop_control_race,
     weighted_prop_treated_race, weighted_prop_control_race,
     prop_treated_lead, prop_control_lead,
     weighted_prop_treated_lead, weighted_prop_control_lead,
     file = "analysis_results/complete_all_methods_results.rda")

cat("\n========================================================================\n")
cat("                    METHOD SPECIFICATIONS\n")
cat("========================================================================\n")
cat("\n1. UNWEIGHTED PSM (1:1):\n")
cat("   - Matches on propensity score only\n")
cat("   - PS model: 12 SES variables\n")
cat("   - No survey weights\n")

cat("\n2. UNWEIGHTED PGM (1:1):\n")
cat("   - Matches on prognostic score only\n")
cat("   - PG model (Race): 12 SES + age/sex + 6 blood markers\n")
cat("   - PG model (Lead): 12 SES + race/age/sex + 6 blood markers\n")
cat("   - No survey weights\n")

cat("\n3. UNWEIGHTED DSM (1:1):\n")
cat("   - Matches on double score (PS and PG)\n")
cat("   - Combines PS and PG models\n")
cat("   - No survey weights\n")

cat("\n4. SURVEY-WEIGHTED PS FULL:\n")
cat("   - Full matching with survey weights\n")
cat("   - Outcome regression for bias correction\n")
cat("   - Incorporates complex survey design\n")

cat("\n5. WDSM (1:5):\n")
cat("   - Survey-weighted double score matching\n")
cat("   - 5 matches per unit\n")
cat("   - Double robustness with survey weights\n")

cat("\n========================================================================\n")

