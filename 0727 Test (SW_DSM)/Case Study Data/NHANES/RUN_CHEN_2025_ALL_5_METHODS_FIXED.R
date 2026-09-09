################################################################################
# PAPER 2: Chen et al. 2025 - Waist Circumference → Serum Uric Acid
# ALL 5 METHODS WITH BOOTSTRAP CIs - FIXED VERSION
################################################################################

library(dplyr)
library(haven)
library(MatchIt)
library(marginaleffects)
library(survey)

source("WDSM_adaptive.R")

set.seed(2024)

cat("\n")
cat("==============================================================================\n")
cat("   PAPER 2: Chen et al. 2025 - Waist Circumference → Uric Acid\n")
cat("==============================================================================\n")

# Load data
load("data/nhanes_2007_2018.rda")
nhanes <- nhanes_2007_2018

cat("\n📋 STUDY DETAILS:\n")
cat("Citation:     Chen et al. BMC Public Health (2025)\n")
cat("Question:     Does waist circumference increase serum uric acid?\n")
cat("Data:         NHANES 2007-2018\n\n")

# Prepare data
data_chen <- nhanes %>%
  filter(!is.na(bmxwaist) & !is.na(lbxsua)) %>%
  filter(!is.na(ridageyr) & ridageyr >= 20) %>%
  filter(!is.na(riagendr) & !is.na(ridreth1)) %>%
  filter(!is.na(wtmec2yr) & wtmec2yr > 0) %>%
  filter(!is.na(bmxbmi) & !is.na(dmdeduc2) & !is.na(indfmpir))

cat("Complete sample: N =", nrow(data_chen), "\n\n")

# Define treatment
waist_median <- median(data_chen$bmxwaist)
data_chen$A <- ifelse(data_chen$bmxwaist >= waist_median, 1, 0)

cat("Treatment: High waist (≥", round(waist_median, 1), "cm) vs Low waist\n")
cat("  Treated:  N =", sum(data_chen$A ==1), "\n")
cat("  Control:  N =", sum(data_chen$A == 0), "\n\n")

# Extract variables
Y <- data_chen$lbxsua
A <- data_chen$A
sw <- data_chen$wtmec2yr

# Covariates
data_for_matching <- data.frame(
  Y = Y,
  A = A,
  age = data_chen$ridageyr,
  female = ifelse(data_chen$riagendr == 2, 1, 0),
  race = as.factor(data_chen$ridreth1),
  education = as.factor(data_chen$dmdeduc2),
  pir = data_chen$indfmpir,
  bmi = data_chen$bmxbmi,
  sw = sw
)

cat("Covariates: age, sex, race, education, income, BMI\n\n")

cat("Mean uric acid:\n")
cat("  Overall:    ", round(mean(Y), 2), "mg/dL\n")
cat("  High waist: ", round(mean(Y[A==1]), 2), "mg/dL\n")
cat("  Low waist:  ", round(mean(Y[A==0]), 2), "mg/dL\n\n")

################################################################################
# METHOD 1: Unweighted PSM (SIMPLEST - DO FIRST)
################################################################################

cat("══════════════════════════════════════════════════════════════════════════\n")
cat("METHOD 3: Unweighted PSM (1:1 matching) - SAMPLE ESTIMAND\n")
cat("══════════════════════════════════════════════════════════════════════════\n")

m_psm <- matchit(A ~ age + female + race + education + pir + bmi,
                 data = data_for_matching,
                 method = "nearest",
                 ratio = 1)

psm_data <- match.data(m_psm)
psm_est <- mean(psm_data$Y[psm_data$A==1]) - mean(psm_data$Y[psm_data$A==0])
psm_se <- sqrt(var(psm_data$Y[psm_data$A==1])/sum(psm_data$A==1) + 
               var(psm_data$Y[psm_data$A==0])/sum(psm_data$A==0))
psm_ci <- psm_est + c(-1.96, 1.96) * psm_se

cat("Matched pairs: N =", sum(psm_data$A==1), "\n")
cat("Estimate:", round(psm_est, 3), "mg/dL\n")
cat("95% CI: [", round(psm_ci[1], 3), ",", round(psm_ci[2], 3), "]\n\n")

################################################################################
# METHOD 2: Unweighted PGM
################################################################################

cat("══════════════════════════════════════════════════════════════════════════\n")
cat("METHOD 2: Unweighted PGM (1:1 matching) - SAMPLE ESTIMAND\n")
cat("══════════════════════════════════════════════════════════════════════════\n")

# Fit prognostic model (predict outcome from covariates, ignoring treatment)
pg_model <- lm(Y ~ age + female + race + education + pir + bmi, 
               data = data_for_matching)
data_for_matching$pg_score <- predict(pg_model)

# Match on prognostic score
m_pgm <- matchit(A ~ pg_score,
                 data = data_for_matching,
                 method = "nearest",
                 ratio = 1)

pgm_data <- match.data(m_pgm)
pgm_est <- mean(pgm_data$Y[pgm_data$A==1]) - mean(pgm_data$Y[pgm_data$A==0])
pgm_se <- sqrt(var(pgm_data$Y[pgm_data$A==1])/sum(pgm_data$A==1) + 
               var(pgm_data$Y[pgm_data$A==0])/sum(pgm_data$A==0))
pgm_ci <- pgm_est + c(-1.96, 1.96) * pgm_se

cat("Matched pairs: N =", sum(pgm_data$A==1), "\n")
cat("Estimate:", round(pgm_est, 3), "mg/dL\n")
cat("95% CI: [", round(pgm_ci[1], 3), ",", round(pgm_ci[2], 3), "]\n\n")

################################################################################
# METHOD 1: Unweighted DSM
################################################################################

cat("══════════════════════════════════════════════════════════════════════════\n")
cat("METHOD 1: Unweighted DSM (1:1 matching) - SAMPLE ESTIMAND\n")
cat("══════════════════════════════════════════════════════════════════════════\n")

# Get PS score
ps_model <- glm(A ~ age + female + race + education + pir + bmi,
                data = data_for_matching,
                family = binomial())
data_for_matching$ps_score <- predict(ps_model, type = "response")

# Match on both PS and PG scores
m_dsm <- matchit(A ~ ps_score + pg_score,
                 data = data_for_matching,
                 method = "nearest",
                 ratio = 1)

dsm_data <- match.data(m_dsm)
dsm_est <- mean(dsm_data$Y[dsm_data$A==1]) - mean(dsm_data$Y[dsm_data$A==0])
dsm_se <- sqrt(var(dsm_data$Y[dsm_data$A==1])/sum(dsm_data$A==1) + 
               var(dsm_data$Y[dsm_data$A==0])/sum(dsm_data$A==0))
dsm_ci <- dsm_est + c(-1.96, 1.96) * dsm_se

cat("Matched pairs: N =", sum(dsm_data$A==1), "\n")
cat("Estimate:", round(dsm_est, 3), "mg/dL\n")
cat("95% CI: [", round(dsm_ci[1], 3), ",", round(dsm_ci[2], 3), "]\n\n")

################################################################################
# METHOD 4: Survey-Weighted PS Full Matching
################################################################################

cat("══════════════════════════════════════════════════════════════════════════\n")
cat("METHOD 4: Survey-Weighted PS Full Matching - POPULATION ESTIMAND\n")
cat("══════════════════════════════════════════════════════════════════════════\n")

m_ps_full <- matchit(A ~ age + female + race + education + pir + bmi,
                     data = data_for_matching,
                     method = "full",
                     estimand = "ATE")

ps_full_data <- match.data(m_ps_full)
# Normalize weights
ps_full_data$sw_norm <- ps_full_data$sw * nrow(ps_full_data) / sum(ps_full_data$sw)

# Weighted regression
svydes <- svydesign(ids = ~1, weights = ~sw_norm, data = ps_full_data)
ps_full_fit <- svyglm(Y ~ A, design = svydes)

ps_full_est <- coef(ps_full_fit)["A"]
ps_full_ci <- confint(ps_full_fit)["A", ]

cat("Estimate:", round(ps_full_est, 3), "mg/dL\n")
cat("95% CI: [", round(ps_full_ci[1], 3), ",", round(ps_full_ci[2], 3), "]\n\n")

################################################################################
# METHOD 5: WDSM
################################################################################

cat("══════════════════════════════════════════════════════════════════════════\n")
cat("METHOD 5: WDSM - POPULATION ESTIMAND\n")
cat("══════════════════════════════════════════════════════════════════════════\n")

X_matrix <- as.matrix(data_for_matching[, c("age", "female", "pir", "bmi")])

cat("Computing WDSM estimate with bootstrap (200 reps)...\n")

wdsm_result <- wdsm_adaptive(
  Y = Y,
  A = A,
  X_ps = X_matrix,
  X_pg = X_matrix,
  sw = sw,
  caliper = 0.2,
  ratio = 1
)

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

cat("Estimate:", round(wdsm_boot$point_estimate, 3), "mg/dL\n")
cat("95% CI: [", round(wdsm_boot$ci[1], 3), ",", round(wdsm_boot$ci[2], 3), "]\n\n")

################################################################################
# FINAL RESULTS
################################################################################

results <- list(
  dsm = list(estimate = dsm_est, ci_lower = dsm_ci[1], ci_upper = dsm_ci[2]),
  pgm = list(estimate = pgm_est, ci_lower = pgm_ci[1], ci_upper = pgm_ci[2]),
  psm = list(estimate = psm_est, ci_lower = psm_ci[1], ci_upper = psm_ci[2]),
  ps_full = list(estimate = as.numeric(ps_full_est), 
                 ci_lower = as.numeric(ps_full_ci[1]), 
                 ci_upper = as.numeric(ps_full_ci[2])),
  wdsm = list(estimate = wdsm_boot$point_estimate,
              ci_lower = wdsm_boot$ci[1],
              ci_upper = wdsm_boot$ci[2])
)

save(data_for_matching, results, waist_median, 
     file = "CHEN_2025_COMPLETE_RESULTS.rda")

cat("\n")
cat("==============================================================================\n")
cat("   FINAL RESULTS: Chen 2025 (Waist → Uric Acid)\n")
cat("==============================================================================\n\n")

cat("Method                        Estimate        95% CI              Estimand\n")
cat("------------------------------------------------------------------------------\n")
cat(sprintf("%-28s %7.3f       [%6.3f, %6.3f]  Sample\n", 
            "Unweighted DSM", dsm_est, dsm_ci[1], dsm_ci[2]))
cat(sprintf("%-28s %7.3f       [%6.3f, %6.3f]  Sample\n", 
            "Unweighted PGM", pgm_est, pgm_ci[1], pgm_ci[2]))
cat(sprintf("%-28s %7.3f       [%6.3f, %6.3f]  Sample\n", 
            "Unweighted PSM", psm_est, psm_ci[1], psm_ci[2]))
cat(sprintf("%-28s %7.3f       [%6.3f, %6.3f]  Population\n", 
            "Survey-Weighted PS Full", ps_full_est, ps_full_ci[1], ps_full_ci[2]))
cat(sprintf("%-28s %7.3f       [%6.3f, %6.3f]  Population\n", 
            "WDSM", wdsm_boot$point_estimate, wdsm_boot$ci[1], wdsm_boot$ci[2]))

sample_avg <- mean(c(dsm_est, pgm_est, psm_est))
pop_avg <- mean(c(as.numeric(ps_full_est), wdsm_boot$point_estimate))
bias_pct <- (sample_avg - pop_avg) / pop_avg * 100

cat("\n")
cat("Sample average:    ", sprintf("%.3f mg/dL", sample_avg), "\n")
cat("Population average:", sprintf("%.3f mg/dL", pop_avg), "\n")
cat("Bias:              ", sprintf("%+.1f%%", bias_pct), "\n")

cat("\n✅ Results saved: CHEN_2025_COMPLETE_RESULTS.rda\n")
cat(sprintf("\n🔥 KEY FINDING: %.0f%% sample-population difference!\n", abs(bias_pct)))

cat("\n==============================================================================\n")
cat("   ANALYSIS COMPLETE\n")
cat("==============================================================================\n")







