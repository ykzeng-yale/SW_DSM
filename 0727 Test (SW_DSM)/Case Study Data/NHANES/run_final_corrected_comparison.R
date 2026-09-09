################################################################################
# FINAL CORRECTED COMPARISON ANALYSIS
# Complete comparison of WDSM, DSM, and PS Full Matching
# Following exact specifications from simulation example
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
cat("========================================================================\n")
cat("          FINAL CORRECTED NHANES ANALYSIS - ALL METHODS\n")
cat("========================================================================\n")

# Define covariate sets (as per Salerno et al.)
ses_vars <- c("EDUC_3CAT", "MARTL_3CAT", "PIR_3CAT", "EMPSTAT_4CAT", 
              "OCC_5CAT", "HHSIZE_5CAT", "HHINC_5CAT", "HIQ_2CAT", 
              "WIC_2CAT", "FDSEC_3CAT", "HOD_4CAT", "OWNHOME_2CAT")
demo_vars <- c("AGE", "SEX")
blood_vars <- c("LBXWBCSI", "LBXLYPCT", "LBXMOPCT", "LBXNEPCT", 
                "LBXEOPCT", "LBXBAPCT")

# ==============================================================================
# PART 1: RACE ANALYSIS (Main Research Question)
# ==============================================================================

cat("\n========================================================================\n")
cat("                    PART 1: RACE ANALYSIS\n")
cat("========================================================================\n")

# Get complete cases for race analysis
all_vars_race <- c("lTELOMEAN", "RACE_2CAT", "WTMEC4YR", ses_vars, demo_vars, blood_vars)
complete_idx <- complete.cases(nhanes_data[, all_vars_race])
data_race <- nhanes_data[complete_idx, ]
cat("\nComplete cases for race analysis:", nrow(data_race), "out of", nrow(nhanes_data), "\n")

# Define variables
Y_race <- data_race$lTELOMEAN
A_race <- data_race$RACE_2CAT
w_race <- data_race$WTMEC4YR
n_race <- length(Y_race)
sw_race <- w_race * n_race / sum(w_race)  # Normalized for MatchIt

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
# METHOD 1: WDSM (Survey-Weighted Double Score Matching)
# -----------------------------------------------------------------------------

cat("\n--- METHOD 1: WDSM ---\n")

# Load adaptive WDSM function
source("WDSM_adaptive.R")

# Prepare WDSM data
wdsm_data_race <- data_race
wdsm_data_race$Y <- Y_race
wdsm_data_race$A <- A_race
wdsm_data_race$survey_weight <- w_race

# Create formulas
ps_formula_wdsm <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))
pg_formula_wdsm <- as.formula(paste("~ ", paste(c(ses_vars, demo_vars, blood_vars), 
                                                 collapse = " + ")))

# Run WDSM
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
B <- 200
boot_wdsm_race <- numeric(B)
for (b in 1:B) {
  m_star <- rmultinom(1, n_race, rep(1/n_race, n_race))[, 1]
  data_boot <- wdsm_data_race
  data_boot$survey_weight <- m_star * w_race
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  
  tryCatch({
    suppressWarnings({
      boot_result <- wdsm_adaptive(data_boot, ps_formula_wdsm, pg_formula_wdsm,
                                  "Y", "A", "survey_weight",
                                  M = 5, use_bias_correction = TRUE, 
                                  verbose = FALSE)
    })
    boot_wdsm_race[b] <- boot_result$tau
  }, error = function(e) NULL)
}

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

# -----------------------------------------------------------------------------
# METHOD 2: Unweighted DSM (dsmatch package)
# -----------------------------------------------------------------------------

cat("\n--- METHOD 2: Unweighted DSM ---\n")

# Prepare matrices for dsmatch
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

# Run DSM
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
    boots = 200,
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
# METHOD 3: Survey-Weighted PS Full Matching (MatchIt)
# -----------------------------------------------------------------------------

cat("\n--- METHOD 3: Survey-Weighted PS Full Matching ---\n")

# PS formula - ONLY SES variables
ps_formula_matchit <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))

# Perform PS full matching
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

# Extract matched data
md_race <- match.data(m_ps_race)

# Outcome model with all covariates and interactions (bias correction)
outcome_formula_race <- Y ~ A * (EDUC_3CAT + MARTL_3CAT + PIR_3CAT + EMPSTAT_4CAT + 
                                 OCC_5CAT + HHSIZE_5CAT + HHINC_5CAT + HIQ_2CAT + 
                                 WIC_2CAT + FDSEC_3CAT + HOD_4CAT + OWNHOME_2CAT +
                                 AGE + SEX + 
                                 LBXWBCSI + LBXLYPCT + LBXMOPCT + LBXNEPCT + 
                                 LBXEOPCT + LBXBAPCT)

# Fit outcome model
fit_race <- lm(outcome_formula_race, data = md_race, weights = weights)

# Get treatment effect
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
# PART 2: LEAD EXPOSURE ANALYSIS (Supplementary)
# ==============================================================================

cat("\n========================================================================\n")
cat("              PART 2: LEAD EXPOSURE ANALYSIS\n")
cat("========================================================================\n")

# Filter for non-missing lead data
data_lead <- nhanes_data[!is.na(nhanes_data$LBXBPB_LOD), ]
median_lead <- median(data_lead$LBXBPB_LOD)
data_lead$lead_high <- as.numeric(data_lead$LBXBPB_LOD > median_lead)

# Get complete cases for lead analysis
precision_vars <- c("RACE_2CAT", "AGE", "SEX", blood_vars)
all_vars_lead <- c("lTELOMEAN", "lead_high", "WTMEC4YR", ses_vars, precision_vars)
complete_idx_lead <- complete.cases(data_lead[, all_vars_lead])
data_lead <- data_lead[complete_idx_lead, ]
cat("\nComplete cases for lead analysis:", nrow(data_lead), "\n")

# Define variables
Y_lead <- data_lead$lTELOMEAN
A_lead <- data_lead$lead_high
w_lead <- data_lead$WTMEC4YR
n_lead <- length(Y_lead)
sw_lead <- w_lead * n_lead / sum(w_lead)

# Create data frame for MatchIt
df_lead <- data.frame(
  Y = Y_lead,
  A = A_lead,
  sw = sw_lead,
  data_lead[, c(ses_vars, precision_vars)]
)

# Initialize results storage
lead_results <- list()

# -----------------------------------------------------------------------------
# Lead Analysis - METHOD 1: WDSM
# -----------------------------------------------------------------------------

cat("\n--- METHOD 1: WDSM (Lead) ---\n")

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
boot_wdsm_lead <- numeric(200)
for (b in 1:200) {
  m_star <- rmultinom(1, n_lead, rep(1/n_lead, n_lead))[, 1]
  data_boot <- wdsm_data_lead
  data_boot$survey_weight <- m_star * w_lead
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  
  tryCatch({
    suppressWarnings({
      boot_result <- wdsm_adaptive(data_boot, ps_formula_lead, pg_formula_lead,
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

cat("\n--- METHOD 2: Unweighted DSM (Lead) ---\n")

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
    boots = 200,
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

cat("\n--- METHOD 3: Survey-Weighted PS Full Matching (Lead) ---\n")

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
cat("                    FINAL CORRECTED RESULTS\n")
cat("========================================================================\n")

# Create formatted tables
race_table <- data.frame(
  Method = c("Unweighted Double Score Matching (DSM)",
             "Survey-Weighted PS Full Matching",
             "Weighted Double Score Matching (WDSM)"),
  `ACD Estimate` = sprintf("%.4f", c(race_results$dsm$estimate, 
                                      race_results$ps_full$estimate, 
                                      race_results$wdsm$estimate)),
  `95% Confidence Interval` = c(
    sprintf("%.4f, %.4f", race_results$dsm$ci_lower, race_results$dsm$ci_upper),
    sprintf("%.4f, %.4f", race_results$ps_full$ci_lower, race_results$ps_full$ci_upper),
    sprintf("%.4f, %.4f", race_results$wdsm$ci_lower, race_results$wdsm$ci_upper)
  ),
  check.names = FALSE
)

lead_table <- data.frame(
  Method = c("Unweighted Double Score Matching (DSM)",
             "Survey-Weighted PS Full Matching",
             "Weighted Double Score Matching (WDSM)"),
  `PATE Estimate` = sprintf("%.4f", c(lead_results$dsm$estimate, 
                                       lead_results$ps_full$estimate, 
                                       lead_results$wdsm$estimate)),
  `95% Confidence Interval` = c(
    sprintf("%.4f, %.4f", lead_results$dsm$ci_lower, lead_results$dsm$ci_upper),
    sprintf("%.4f, %.4f", lead_results$ps_full$ci_lower, lead_results$ps_full$ci_upper),
    sprintf("%.4f, %.4f", lead_results$wdsm$ci_lower, lead_results$wdsm$ci_upper)
  ),
  check.names = FALSE
)

cat("\n=== TABLE 1: RACE ANALYSIS ===\n")
print(race_table, row.names = FALSE)

cat("\n=== TABLE 2: LEAD EXPOSURE ANALYSIS ===\n")
print(lead_table, row.names = FALSE)

# Save results
results_list <- list(
  race_results = race_results,
  lead_results = lead_results,
  race_table = race_table,
  lead_table = lead_table
)

save(results_list, file = "analysis_results/final_corrected_results.rda")
write.csv(race_table, "analysis_results/Table1_Race_Final.csv", row.names = FALSE)
write.csv(lead_table, "analysis_results/Table2_Lead_Final.csv", row.names = FALSE)

cat("\n========================================================================\n")
cat("Analysis Complete! Results saved to:\n")
cat("  - analysis_results/final_corrected_results.rda\n")
cat("  - analysis_results/Table1_Race_Final.csv\n")
cat("  - analysis_results/Table2_Lead_Final.csv\n")
cat("========================================================================\n")

