################################################################################
# ANALYSIS 1: Smoking Status → Triglycerides (mg/dL)
# 
# Research Question: Does current smoking increase serum triglyceride levels?
# 
# Design: Cross-sectional analysis using NHANES 2007-2018
# Treatment: Current smoking status (binary)
# Outcome: Serum triglycerides (continuous, mg/dL)
# Methods: 5 matching approaches (3 unweighted, 2 weighted)
#
# Author: Biostatistical Analysis Team
# Date: October 23, 2025
################################################################################

library(dplyr)
library(haven)
library(MatchIt)
library(marginaleffects)
library(survey)
library(ggplot2)

source("WDSM_adaptive.R")

set.seed(20241023)

cat("\n")
cat("===============================================================================\n")
cat("  ANALYSIS 1: Current Smoking → Serum Triglycerides\n")
cat("===============================================================================\n")

################################################################################
# STEP 1: DATA PREPARATION AND EXPLORATION
################################################################################

cat("\n")
cat("───────────────────────────────────────────────────────────────────────────\n")
cat(" STEP 1: DATA PREPARATION\n")
cat("───────────────────────────────────────────────────────────────────────────\n\n")

# Load data
load("data/nhanes_2007_2018.rda")
nhanes <- nhanes_2007_2018

cat("Total NHANES 2007-2018: N =", nrow(nhanes), "\n\n")

# Define treatment: Current smoker
# SMQ020: Smoked at least 100 cigarettes in life (1=Yes, 2=No)
# SMQ040: Do you now smoke cigarettes? (1=Every day, 2=Some days, 3=Not at all)

cat("Defining Treatment Variable (Current Smoking):\n")
cat("  Step 1: Identify ever smokers (SMQ020=1)\n")
cat("  Step 2: Among ever smokers, identify current smokers (SMQ040=1 or 2)\n\n")

# Create smoking status variable
nhanes_work <- nhanes %>%
  mutate(
    # Ever smoker
    ever_smoker = case_when(
      smq020 == 1 ~ 1,
      smq020 == 2 ~ 0,
      TRUE ~ NA_real_
    ),
    # Current smoker (among ever smokers)
    current_smoker = case_when(
      smq020 == 2 ~ 0,  # Never smoker
      smq020 == 1 & smq040 %in% c(1, 2) ~ 1,  # Current smoker
      smq020 == 1 & smq040 == 3 ~ 0,  # Former smoker
      TRUE ~ NA_real_
    )
  )

# Check treatment distribution
cat("Treatment Distribution:\n")
treatment_table <- table(nhanes_work$current_smoker, useNA = "ifany")
print(treatment_table)
cat("\n  Current smokers:", treatment_table["1"], "\n")
cat("  Non-smokers (never + former):", treatment_table["0"], "\n")
cat("  Missing:", sum(is.na(nhanes_work$current_smoker)), "\n\n")

# Define outcome: Triglycerides
cat("Outcome Variable: Serum Triglycerides (LBXTR, mg/dL)\n")
trig_summary <- nhanes_work %>%
  filter(!is.na(lbxtr)) %>%
  summarise(
    N = n(),
    Mean = mean(lbxtr),
    SD = sd(lbxtr),
    Median = median(lbxtr),
    Q25 = quantile(lbxtr, 0.25),
    Q75 = quantile(lbxtr, 0.75),
    Min = min(lbxtr),
    Max = max(lbxtr)
  )

cat("  N non-missing:", trig_summary$N, "\n")
cat("  Mean (SD):", round(trig_summary$Mean, 1), "(", round(trig_summary$SD, 1), ") mg/dL\n")
cat("  Median [IQR]:", round(trig_summary$Median, 1), 
    "[", round(trig_summary$Q25, 1), ",", round(trig_summary$Q75, 1), "]\n")
cat("  Range:", round(trig_summary$Min, 1), "-", round(trig_summary$Max, 1), "mg/dL\n\n")

# Select covariates (following standard epidemiological practice)
cat("Selecting Covariates:\n")
cat("  Demographics: Age, sex, race/ethnicity\n")
cat("  Socioeconomic: Education, income (PIR)\n")
cat("  Health behaviors: Alcohol use, physical activity\n")
cat("  Metabolic: BMI, diabetes status\n\n")

# Create analysis dataset
data_analysis <- nhanes_work %>%
  filter(
    !is.na(current_smoker),
    !is.na(lbxtr),
    !is.na(ridageyr),
    !is.na(riagendr),
    !is.na(ridreth1),
    !is.na(dmdeduc2),
    !is.na(indfmpir),
    !is.na(bmxbmi),
    !is.na(wtmec2yr),
    wtmec2yr > 0,
    ridageyr >= 20  # Adults only
  ) %>%
  mutate(
    # Create clean covariate variables
    age = ridageyr,
    female = ifelse(riagendr == 2, 1, 0),
    race = factor(ridreth1, levels = 1:5, 
                  labels = c("Mexican", "Hispanic", "White", "Black", "Other")),
    education = factor(dmdeduc2, levels = 1:5,
                      labels = c("Less9", "9-11", "HS", "SomeCollege", "College+")),
    pir = indfmpir,  # Poverty income ratio
    bmi = bmxbmi,
    # Alcohol use if available
    alcohol_use = case_when(
      !is.na(alq130) & alq130 > 0 ~ 1,
      !is.na(alq130) & alq130 == 0 ~ 0,
      TRUE ~ NA_real_
    ),
    # Physical activity if available
    vigorous_activity = case_when(
      !is.na(paq605) & paq605 == 1 ~ 1,
      !is.na(paq605) & paq605 == 2 ~ 0,
      TRUE ~ NA_real_
    )
  ) %>%
  # Keep only complete cases for core covariates
  filter(!is.na(alcohol_use) | !is.na(vigorous_activity)) %>%
  mutate(
    alcohol_use = ifelse(is.na(alcohol_use), 0, alcohol_use),
    vigorous_activity = ifelse(is.na(vigorous_activity), 0, vigorous_activity)
  )

cat("Analysis Dataset Created:\n")
cat("  Total N:", nrow(data_analysis), "\n")
cat("  Treatment: Current smokers =", sum(data_analysis$current_smoker == 1), "\n")
cat("  Control: Non-smokers =", sum(data_analysis$current_smoker == 0), "\n\n")

# Descriptive statistics by treatment group
cat("Descriptive Statistics by Treatment Group:\n\n")

desc_stats <- data_analysis %>%
  group_by(current_smoker) %>%
  summarise(
    N = n(),
    Age_mean = mean(age),
    Age_sd = sd(age),
    Female_pct = mean(female) * 100,
    BMI_mean = mean(bmi),
    BMI_sd = sd(bmi),
    Trig_mean = mean(lbxtr),
    Trig_sd = sd(lbxtr),
    Trig_median = median(lbxtr),
    .groups = "drop"
  )

print(desc_stats, width = Inf)
cat("\n")

# Crude difference (unadjusted)
crude_diff <- mean(data_analysis$lbxtr[data_analysis$current_smoker == 1]) - 
              mean(data_analysis$lbxtr[data_analysis$current_smoker == 0])
cat("Crude (unadjusted) difference:", round(crude_diff, 2), "mg/dL\n\n")

################################################################################
# STEP 2: PROPENSITY SCORE AND PROGNOSTIC SCORE MODELS
################################################################################

cat("───────────────────────────────────────────────────────────────────────────\n")
cat(" STEP 2: PROPENSITY SCORE AND PROGNOSTIC SCORE MODELS\n")
cat("───────────────────────────────────────────────────────────────────────────\n\n")

# Extract variables
Y <- data_analysis$lbxtr
A <- data_analysis$current_smoker
sw <- data_analysis$wtmec2yr

# Covariate matrix - ensure complete cases
X_covars <- data_analysis %>%
  select(age, female, race, education, pir, bmi, alcohol_use, vigorous_activity)

# Convert to model matrix (handles factors)
X_matrix_full <- model.matrix(~ age + female + race + education + pir + bmi + 
                          alcohol_use + vigorous_activity, 
                        data = X_covars)

# Check for NAs and remove incomplete rows
complete_rows <- complete.cases(X_matrix_full)
if(sum(!complete_rows) > 0) {
  cat("Removing", sum(!complete_rows), "rows with missing covariate data\n")
  data_analysis <- data_analysis[complete_rows, ]
  Y <- Y[complete_rows]
  A <- A[complete_rows]
  sw <- sw[complete_rows]
  X_covars <- X_covars[complete_rows, ]
  X_matrix_full <- X_matrix_full[complete_rows, ]
}

X_matrix <- X_matrix_full[, -1]  # Remove intercept

cat("\nFinal Analysis Sample:\n")
cat("  N =", nrow(data_analysis), "\n")
cat("  Treated:", sum(A==1), "| Control:", sum(A==0), "\n")
cat("  Covariates:", ncol(X_matrix), "predictors (after dummy coding)\n")
cat("  Variables: age, female, race (4 levels), education (4 levels),\n")
cat("             PIR, BMI, alcohol use, vigorous activity\n\n")

# Fit Propensity Score Model
cat("Fitting Propensity Score Model (Treatment ~ Covariates)...\n")
ps_formula <- as.formula(paste("A ~", paste(colnames(X_matrix), collapse = " + ")))
ps_data <- data.frame(A = A, X_matrix)
ps_model <- glm(ps_formula, data = ps_data, family = binomial())

ps_scores <- predict(ps_model, type = "response")

cat("  PS model: Logistic regression\n")
cat("  PS range: [", round(min(ps_scores), 3), ",", round(max(ps_scores), 3), "]\n")
cat("  PS mean (treated):", round(mean(ps_scores[A==1]), 3), "\n")
cat("  PS mean (control):", round(mean(ps_scores[A==0]), 3), "\n\n")

# Check overlap
cat("Propensity Score Overlap:\n")
ps_overlap_treated <- quantile(ps_scores[A==1], c(0.05, 0.50, 0.95))
ps_overlap_control <- quantile(ps_scores[A==0], c(0.05, 0.50, 0.95))
cat("  Treated - 5th, 50th, 95th percentiles:", 
    round(ps_overlap_treated, 3), "\n")
cat("  Control - 5th, 50th, 95th percentiles:", 
    round(ps_overlap_control, 3), "\n")

if(ps_overlap_treated[1] < ps_overlap_control[3] && 
   ps_overlap_control[1] < ps_overlap_treated[3]) {
  cat("  ✅ Good overlap - common support exists\n\n")
} else {
  cat("  ⚠️  Limited overlap - may affect matching quality\n\n")
}

# Fit Prognostic Score Model
cat("Fitting Prognostic Score Model (Outcome ~ Covariates, in controls)...\n")
pg_formula <- as.formula(paste("Y ~", paste(colnames(X_matrix), collapse = " + ")))
pg_data <- data.frame(Y = Y, X_matrix)
pg_model <- lm(pg_formula, data = pg_data, subset = (A == 0))

pg_scores <- predict(pg_model, newdata = pg_data)

cat("  PG model: Linear regression (fitted in controls)\n")
cat("  PG range: [", round(min(pg_scores), 1), ",", round(max(pg_scores), 1), "]\n")
cat("  PG mean (treated):", round(mean(pg_scores[A==1]), 1), "\n")
cat("  PG mean (control):", round(mean(pg_scores[A==0]), 1), "\n\n")

################################################################################
# STEP 3: METHOD 1 - UNWEIGHTED DSM (Double Score Matching)
################################################################################

cat("───────────────────────────────────────────────────────────────────────────\n")
cat(" METHOD 1: Unweighted DSM (1:1 matching) - SAMPLE ESTIMAND\n")
cat("───────────────────────────────────────────────────────────────────────────\n\n")

# Create matching data
match_data <- data.frame(
  Y = Y,
  A = A,
  ps_score = ps_scores,
  pg_score = pg_scores,
  sw = sw
)

# DSM: Match on both PS and PG scores
m_dsm <- matchit(A ~ ps_score + pg_score,
                 data = match_data,
                 method = "nearest",
                 distance = "mahalanobis",
                 ratio = 1,
                 replace = FALSE)

dsm_data <- match.data(m_dsm)

cat("Matching Summary:\n")
cat("  Matched pairs:", nrow(dsm_data)/2, "\n")
cat("  Matched treated:", sum(dsm_data$A == 1), "\n")
cat("  Matched controls:", sum(dsm_data$A == 0), "\n\n")

# Calculate ATE
dsm_est <- mean(dsm_data$Y[dsm_data$A == 1]) - mean(dsm_data$Y[dsm_data$A == 0])

# Bootstrap CI
cat("Computing bootstrap confidence interval (200 replicates)...\n")
dsm_boot <- replicate(200, {
  boot_idx <- sample(1:nrow(data_analysis), replace = TRUE)
  Y_b <- Y[boot_idx]
  A_b <- A[boot_idx]
  X_b <- X_matrix[boot_idx, ]
  
  # Refit models
  ps_b <- glm(A_b ~ X_b, family = binomial())$fitted.values
  pg_b <- lm(Y_b ~ X_b, subset = (A_b == 0))
  pg_pred_b <- predict(pg_b, newdata = data.frame(X_b))
  
  # Match
  m_b <- matchit(A_b ~ ps_b + pg_pred_b,
                 method = "nearest",
                 distance = "mahalanobis",
                 ratio = 1,
                 replace = FALSE)
  
  d_b <- match.data(m_b)
  mean(d_b$Y_b[d_b$A_b == 1]) - mean(d_b$Y_b[d_b$A_b == 0])
})

dsm_ci <- quantile(dsm_boot, c(0.025, 0.975), na.rm = TRUE)

cat("\n✅ DSM Results:\n")
cat("   Estimate:", round(dsm_est, 2), "mg/dL\n")
cat("   95% CI: [", round(dsm_ci[1], 2), ",", round(dsm_ci[2], 2), "]\n\n")

################################################################################
# STEP 4: METHOD 2 - UNWEIGHTED PGM (Prognostic Score Matching)
################################################################################

cat("───────────────────────────────────────────────────────────────────────────\n")
cat(" METHOD 2: Unweighted PGM (1:1 matching) - SAMPLE ESTIMAND\n")
cat("───────────────────────────────────────────────────────────────────────────\n\n")

m_pgm <- matchit(A ~ pg_score,
                 data = match_data,
                 method = "nearest",
                 distance = "mahalanobis",
                 ratio = 1,
                 replace = FALSE)

pgm_data <- match.data(m_pgm)

cat("Matching Summary:\n")
cat("  Matched pairs:", nrow(pgm_data)/2, "\n\n")

pgm_est <- mean(pgm_data$Y[pgm_data$A == 1]) - mean(pgm_data$Y[pgm_data$A == 0])

# Bootstrap CI
cat("Computing bootstrap confidence interval...\n")
pgm_boot <- replicate(200, {
  boot_idx <- sample(1:nrow(data_analysis), replace = TRUE)
  Y_b <- Y[boot_idx]
  A_b <- A[boot_idx]
  X_b <- X_matrix[boot_idx, ]
  
  pg_b <- lm(Y_b ~ X_b, subset = (A_b == 0))
  pg_pred_b <- predict(pg_b, newdata = data.frame(X_b))
  
  m_b <- matchit(A_b ~ pg_pred_b, method = "nearest", ratio = 1, replace = FALSE)
  d_b <- match.data(m_b)
  mean(d_b$Y_b[d_b$A_b == 1]) - mean(d_b$Y_b[d_b$A_b == 0])
})

pgm_ci <- quantile(pgm_boot, c(0.025, 0.975), na.rm = TRUE)

cat("\n✅ PGM Results:\n")
cat("   Estimate:", round(pgm_est, 2), "mg/dL\n")
cat("   95% CI: [", round(pgm_ci[1], 2), ",", round(pgm_ci[2], 2), "]\n\n")

################################################################################
# STEP 5: METHOD 3 - UNWEIGHTED PSM (Propensity Score Matching)
################################################################################

cat("───────────────────────────────────────────────────────────────────────────\n")
cat(" METHOD 3: Unweighted PSM (1:1 matching) - SAMPLE ESTIMAND\n")
cat("───────────────────────────────────────────────────────────────────────────\n\n")

m_psm <- matchit(A ~ ps_score,
                 data = match_data,
                 method = "nearest",
                 ratio = 1,
                 replace = FALSE)

psm_data <- match.data(m_psm)

cat("Matching Summary:\n")
cat("  Matched pairs:", nrow(psm_data)/2, "\n\n")

psm_est <- mean(psm_data$Y[psm_data$A == 1]) - mean(psm_data$Y[psm_data$A == 0])

# Bootstrap CI
cat("Computing bootstrap confidence interval...\n")
psm_boot <- replicate(200, {
  boot_idx <- sample(1:nrow(data_analysis), replace = TRUE)
  Y_b <- Y[boot_idx]
  A_b <- A[boot_idx]
  X_b <- X_matrix[boot_idx, ]
  
  ps_b <- glm(A_b ~ X_b, family = binomial())$fitted.values
  
  m_b <- matchit(A_b ~ ps_b, method = "nearest", ratio = 1, replace = FALSE)
  d_b <- match.data(m_b)
  mean(d_b$Y_b[d_b$A_b == 1]) - mean(d_b$Y_b[d_b$A_b == 0])
})

psm_ci <- quantile(psm_boot, c(0.025, 0.975), na.rm = TRUE)

cat("\n✅ PSM Results:\n")
cat("   Estimate:", round(psm_est, 2), "mg/dL\n")
cat("   95% CI: [", round(psm_ci[1], 2), ",", round(psm_ci[2], 2), "]\n\n")

################################################################################
# STEP 6: METHOD 4 - SURVEY-WEIGHTED PS FULL MATCHING
################################################################################

cat("───────────────────────────────────────────────────────────────────────────\n")
cat(" METHOD 4: Survey-Weighted PS Full Matching - POPULATION ESTIMAND\n")
cat("───────────────────────────────────────────────────────────────────────────\n\n")

# Use subclass matching instead of full (too large for full)
m_ps_sub <- matchit(A ~ ps_score,
                    data = match_data,
                    method = "subclass",
                    estimand = "ATE",
                    subclass = 10)

ps_sub_data <- match.data(m_ps_sub)
ps_sub_data$sw_norm <- ps_sub_data$sw * nrow(ps_sub_data) / sum(ps_sub_data$sw)

cat("Matching Summary:\n")
cat("  Method: Subclassification (10 subclasses)\n")
cat("  All units retained\n\n")

# Weighted regression
svydes <- svydesign(ids = ~1, weights = ~sw_norm, data = ps_sub_data)
ps_sub_fit <- svyglm(Y ~ A, design = svydes)

ps_sub_est <- coef(ps_sub_fit)["A"]
ps_sub_ci <- confint(ps_sub_fit)["A", ]

cat("✅ Survey-Weighted Results:\n")
cat("   Estimate:", round(ps_sub_est, 2), "mg/dL\n")
cat("   95% CI: [", round(ps_sub_ci[1], 2), ",", round(ps_sub_ci[2], 2), "]\n\n")

################################################################################
# STEP 7: METHOD 5 - WDSM (Weighted Double Score Matching)
################################################################################

cat("───────────────────────────────────────────────────────────────────────────\n")
cat(" METHOD 5: WDSM - POPULATION ESTIMAND\n")
cat("───────────────────────────────────────────────────────────────────────────\n\n")

cat("Computing WDSM with bootstrap inference...\n")

wdsm_result <- wdsm_adaptive(
  Y = Y,
  A = A,
  X_ps = X_matrix,
  X_pg = X_matrix,
  sw = sw,
  caliper = 0.2,
  ratio = 1
)

cat("Point estimate computed\n")
cat("Running bootstrap (200 replicates)...\n")

wdsm_boot <- bootstrap_adaptive_wdsm(
  Y = Y,
  A = A,
  X_ps = X_matrix,
  X_pg = X_matrix,
  sw = sw,
  B = 200,
  caliper = 0.2,
  ratio = 1
)

cat("\n✅ WDSM Results:\n")
cat("   Estimate:", round(wdsm_boot$point_estimate, 2), "mg/dL\n")
cat("   95% CI: [", round(wdsm_boot$ci[1], 2), ",", round(wdsm_boot$ci[2], 2), "]\n\n")

################################################################################
# STEP 8: COMPILE AND PRESENT RESULTS
################################################################################

cat("\n")
cat("===============================================================================\n")
cat(" FINAL RESULTS: Smoking → Triglycerides\n")
cat("===============================================================================\n\n")

cat("Research Question: Does current smoking increase serum triglyceride levels?\n")
cat("Sample: NHANES 2007-2018, N =", nrow(data_analysis), "adults (≥20 years)\n")
cat("Treatment: Current smoking (n =", sum(A==1), ") vs Non-smoking (n =", sum(A==0), ")\n")
cat("Outcome: Serum triglycerides (mg/dL)\n")
cat("Covariates: Age, sex, race, education, income, BMI, alcohol, physical activity\n\n")

# Create results table
results_table <- data.frame(
  Method = c("Unweighted DSM",
             "Unweighted PGM",
             "Unweighted PSM",
             "Survey-Weighted PS Subclass",
             "WDSM"),
  Estimate = c(dsm_est, pgm_est, psm_est, as.numeric(ps_sub_est), wdsm_boot$point_estimate),
  CI_Lower = c(dsm_ci[1], pgm_ci[1], psm_ci[1], ps_sub_ci[1], wdsm_boot$ci[1]),
  CI_Upper = c(dsm_ci[2], pgm_ci[2], psm_ci[2], ps_sub_ci[2], wdsm_boot$ci[2]),
  Estimand = c("Sample", "Sample", "Sample", "Population", "Population")
)

cat("Table 1: Effect of Current Smoking on Serum Triglycerides\n")
cat("───────────────────────────────────────────────────────────────────────────\n")
cat(sprintf("%-30s %10s  %25s  %s\n", "Method", "Estimate", "95% CI", "Estimand"))
cat("───────────────────────────────────────────────────────────────────────────\n")

for(i in 1:nrow(results_table)) {
  cat(sprintf("%-30s %7.2f     [%6.2f, %6.2f]     %s\n",
              results_table$Method[i],
              results_table$Estimate[i],
              results_table$CI_Lower[i],
              results_table$CI_Upper[i],
              results_table$Estimand[i]))
}

cat("───────────────────────────────────────────────────────────────────────────\n")
cat("Estimates represent mean difference in triglycerides (mg/dL):\n")
cat("Current smokers vs non-smokers\n\n")

# Calculate summary statistics
sample_avg <- mean(c(dsm_est, pgm_est, psm_est))
pop_avg <- mean(c(as.numeric(ps_sub_est), wdsm_boot$point_estimate))
bias_pct <- (sample_avg - pop_avg) / pop_avg * 100

cat("Summary:\n")
cat("  Sample average (3 unweighted):", round(sample_avg, 2), "mg/dL\n")
cat("  Population average (2 weighted):", round(pop_avg, 2), "mg/dL\n")
cat("  Difference:", round(sample_avg - pop_avg, 2), "mg/dL\n")
cat("  Relative bias:", sprintf("%+.1f%%", bias_pct), "\n\n")

cat("Clinical Interpretation:\n")
cat("  Current smoking is associated with an increase of approximately\n")
cat("  ", round(pop_avg, 0), "-", round(sample_avg, 0), "mg/dL in triglycerides\n")
cat("  Sample-based methods overestimate the population effect by", 
    round(abs(bias_pct)), "%\n\n")

# Save results
save(data_analysis, results_table, sample_avg, pop_avg, bias_pct,
     file = "ANALYSIS_01_SMOKING_TRIGLYCERIDES_RESULTS.rda")

cat("✅ Results saved: ANALYSIS_01_SMOKING_TRIGLYCERIDES_RESULTS.rda\n")

cat("\n")
cat("===============================================================================\n")
cat(" ANALYSIS 1 COMPLETE\n")
cat("===============================================================================\n")

