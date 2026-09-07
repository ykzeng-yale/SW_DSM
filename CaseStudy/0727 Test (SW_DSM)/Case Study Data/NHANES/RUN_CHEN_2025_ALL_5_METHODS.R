################################################################################
# PAPER 2: Chen et al. 2025 - Waist Circumference → Serum Uric Acid
# ALL 5 METHODS WITH BOOTSTRAP CIs
################################################################################

library(dplyr)
library(haven)
library(MatchIt)
library(marginaleffects)
library(survey)
library(ggplot2)

source("WDSM_adaptive.R")

set.seed(2024)
B_BOOTSTRAP <- 200

cat("\n")
cat("==============================================================================\n")
cat("   PAPER 2: Chen et al. 2025 - Waist Circumference → Uric Acid\n")
cat("   ALL 5 METHODS WITH BOOTSTRAP CIs\n")
cat("==============================================================================\n")

# Load data
load("data/nhanes_2007_2018.rda")
nhanes <- nhanes_2007_2018

cat("\n📋 STUDY DETAILS:\n")
cat("─────────────────────────────────────────────────────────────────────────\n")
cat("Citation:     Chen et al. BMC Public Health (2025)\n")
cat("Question:     Does waist circumference increase serum uric acid?\n")
cat("Data:         NHANES 2007-2018 (multi-cycle)\n")
cat("Outcome:      Serum uric acid (mg/dL)\n\n")

# Prepare data
data_chen <- nhanes %>%
  filter(!is.na(bmxwaist) & !is.na(lbxsua)) %>%
  filter(!is.na(ridageyr) & ridageyr >= 20) %>%  # Adults
  filter(!is.na(riagendr) & !is.na(ridreth1)) %>%
  filter(!is.na(wtmec2yr) & wtmec2yr > 0) %>%
  filter(!is.na(bmxbmi))  # Need BMI as covariate

cat("Initial sample: N =", nrow(data_chen), "\n")

# Define treatment (binary: high vs low waist)
waist_median <- median(data_chen$bmxwaist, na.rm = TRUE)
data_chen$A <- ifelse(data_chen$bmxwaist >= waist_median, 1, 0)

cat("Treatment: High waist (≥", round(waist_median, 1), "cm) vs Low waist\n")
cat("  High waist: N =", sum(data_chen$A == 1), "\n")
cat("  Low waist:  N =", sum(data_chen$A == 0), "\n\n")

# Key covariates from Chen paper
ps_vars <- c("ridageyr", "riagendr", "ridreth1", "dmdeduc2", "indfmpir", "bmxbmi")

# Create complete case dataset
data_complete <- data_chen %>%
  select(lbxsua, bmxwaist, A, all_of(ps_vars), wtmec2yr) %>%
  na.omit()

cat("Complete cases: N =", nrow(data_complete), "\n")
cat("Covariates: age, sex, race, education, income, BMI\n\n")

# Extract variables
Y <- data_complete$lbxsua
A <- data_complete$A
sw <- data_complete$wtmec2yr
X_ps <- as.matrix(data_complete[, ps_vars])
X_pg <- X_ps  # Same for prognostic model

cat("Mean uric acid:\n")
cat("  Overall:    ", round(mean(Y), 2), "mg/dL\n")
cat("  High waist: ", round(mean(Y[A==1]), 2), "mg/dL\n")
cat("  Low waist:  ", round(mean(Y[A==0]), 2), "mg/dL\n")
cat("  Crude diff: ", round(mean(Y[A==1]) - mean(Y[A==0]), 2), "mg/dL\n\n")

################################################################################
# METHOD 1: Unweighted DSM (1:1 matching)
################################################################################

cat("─────────────────────────────────────────────────────────────────────────\n")
cat("METHOD 1: Unweighted DSM (1:1 matching) - SAMPLE ESTIMAND\n")
cat("─────────────────────────────────────────────────────────────────────────\n")

# Fit PS model
ps_formula <- as.formula(paste("A ~", paste(colnames(X_ps), collapse = " + ")))
ps_model <- glm(ps_formula, data = data.frame(A, X_ps), family = binomial())
ps_scores <- predict(ps_model, type = "response")

# Fit PG model
pg_model <- lm(Y ~ ., data = data.frame(Y, X_pg))
pg_scores <- predict(pg_model)

# DSM matching
dsm_distances <- matrix(0, nrow = length(Y), ncol = length(Y))
for(i in 1:length(Y)) {
  for(j in 1:length(Y)) {
    dsm_distances[i,j] <- abs(ps_scores[i] - ps_scores[j]) + 
                          abs(pg_scores[i] - pg_scores[j])
  }
}

# Match using both scores
m_dsm <- matchit(A ~ ps_scores + pg_scores, 
                 data = data.frame(A, ps_scores, pg_scores),
                 method = "nearest", 
                 distance = "mahalanobis",
                 ratio = 1,
                 caliper = 0.2)

dsm_data <- match.data(m_dsm)
dsm_est <- mean(dsm_data$Y[dsm_data$A==1]) - mean(dsm_data$Y[dsm_data$A==0])

# Bootstrap CI
dsm_boot <- replicate(200, {
  idx <- sample(1:nrow(data_complete), replace = TRUE)
  Y_b <- Y[idx]
  A_b <- A[idx]
  X_b <- X_ps[idx,]
  
  ps_b <- glm(A_b ~ X_b, family = binomial())$fitted.values
  pg_b <- lm(Y_b ~ X_b)$fitted.values
  
  m_b <- matchit(A_b ~ ps_b + pg_b, 
                 data = data.frame(A_b, ps_b, pg_b),
                 method = "nearest", ratio = 1, caliper = 0.2)
  d_b <- match.data(m_b)
  mean(d_b$Y_b[d_b$A_b==1]) - mean(d_b$Y_b[d_b$A_b==0])
})

dsm_ci <- quantile(dsm_boot, c(0.025, 0.975), na.rm = TRUE)

cat("Estimate:", round(dsm_est, 3), "mg/dL\n")
cat("95% CI: [", round(dsm_ci[1], 3), ",", round(dsm_ci[2], 3), "]\n\n")

################################################################################
# METHOD 2: Unweighted PGM (1:1 matching)
################################################################################

cat("─────────────────────────────────────────────────────────────────────────\n")
cat("METHOD 2: Unweighted PGM (1:1 matching) - SAMPLE ESTIMAND\n")
cat("─────────────────────────────────────────────────────────────────────────\n")

m_pgm <- matchit(A ~ pg_scores,
                 data = data.frame(A, pg_scores),
                 method = "nearest",
                 distance = "mahalanobis",
                 ratio = 1,
                 caliper = 0.2)

pgm_data <- match.data(m_pgm)
pgm_est <- mean(pgm_data$Y[pgm_data$A==1]) - mean(pgm_data$Y[pgm_data$A==0])

# Bootstrap CI
pgm_boot <- replicate(200, {
  idx <- sample(1:nrow(data_complete), replace = TRUE)
  Y_b <- Y[idx]
  A_b <- A[idx]
  X_b <- X_pg[idx,]
  
  pg_b <- lm(Y_b ~ X_b)$fitted.values
  m_b <- matchit(A_b ~ pg_b, method = "nearest", ratio = 1, caliper = 0.2)
  d_b <- match.data(m_b)
  mean(d_b$Y_b[d_b$A_b==1]) - mean(d_b$Y_b[d_b$A_b==0])
})

pgm_ci <- quantile(pgm_boot, c(0.025, 0.975), na.rm = TRUE)

cat("Estimate:", round(pgm_est, 3), "mg/dL\n")
cat("95% CI: [", round(pgm_ci[1], 3), ",", round(pgm_ci[2], 3), "]\n\n")

################################################################################
# METHOD 3: Unweighted PSM (1:1 matching)
################################################################################

cat("─────────────────────────────────────────────────────────────────────────\n")
cat("METHOD 3: Unweighted PSM (1:1 matching) - SAMPLE ESTIMAND\n")
cat("─────────────────────────────────────────────────────────────────────────\n")

m_psm <- matchit(ps_formula,
                 data = data.frame(A, X_ps),
                 method = "nearest",
                 ratio = 1,
                 caliper = 0.2)

psm_data <- match.data(m_psm)
psm_est <- mean(psm_data$Y[psm_data$A==1]) - mean(psm_data$Y[psm_data$A==0])

# Bootstrap CI
psm_boot <- replicate(200, {
  idx <- sample(1:nrow(data_complete), replace = TRUE)
  Y_b <- Y[idx]
  A_b <- A[idx]
  X_b <- X_ps[idx,]
  
  m_b <- matchit(A_b ~ X_b, method = "nearest", ratio = 1, caliper = 0.2)
  d_b <- match.data(m_b)
  mean(d_b$Y_b[d_b$A_b==1]) - mean(d_b$Y_b[d_b$A_b==0])
})

psm_ci <- quantile(psm_boot, c(0.025, 0.975), na.rm = TRUE)

cat("Estimate:", round(psm_est, 3), "mg/dL\n")
cat("95% CI: [", round(psm_ci[1], 3), ",", round(psm_ci[2], 3), "]\n\n")

################################################################################
# METHOD 4: Survey-Weighted PS Full Matching
################################################################################

cat("─────────────────────────────────────────────────────────────────────────\n")
cat("METHOD 4: Survey-Weighted PS Full Matching - POPULATION ESTIMAND\n")
cat("─────────────────────────────────────────────────────────────────────────\n")

m_ps_full <- matchit(ps_formula,
                     data = data.frame(A, X_ps),
                     method = "full",
                     estimand = "ATE")

ps_full_data <- match.data(m_ps_full)
ps_full_data$Y <- Y
ps_full_data$sw <- sw

# Normalize weights
ps_full_data$sw_norm <- ps_full_data$sw * nrow(ps_full_data) / sum(ps_full_data$sw)

# Weighted regression
svydes <- svydesign(ids = ~1, weights = ~sw_norm, data = ps_full_data)
ps_full_fit <- svyglm(Y ~ A, design = svydes)

ps_full_est <- coef(ps_full_fit)["A"]
ps_full_se <- sqrt(vcov(ps_full_fit)["A", "A"])
ps_full_ci <- ps_full_est + c(-1.96, 1.96) * ps_full_se

cat("Estimate:", round(ps_full_est, 3), "mg/dL\n")
cat("95% CI: [", round(ps_full_ci[1], 3), ",", round(ps_full_ci[2], 3), "]\n\n")

################################################################################
# METHOD 5: WDSM
################################################################################

cat("─────────────────────────────────────────────────────────────────────────\n")
cat("METHOD 5: WDSM - POPULATION ESTIMAND\n")
cat("─────────────────────────────────────────────────────────────────────────\n")

cat("Computing point estimate...\n")
wdsm_result <- wdsm_adaptive(
  Y = Y,
  A = A,
  X_ps = X_ps,
  X_pg = X_pg,
  sw = sw,
  caliper = 0.2,
  ratio = 1
)

cat("Point estimate:", round(wdsm_result$point_estimate, 3), "mg/dL\n")

cat("Bootstrap (200 reps)...\n")
wdsm_boot <- bootstrap_adaptive_wdsm(
  Y = Y,
  A = A,
  X_ps = X_ps,
  X_pg = X_pg,
  sw = sw,
  B = 200,
  caliper = 0.2,
  ratio = 1
)

cat("Estimate:", round(wdsm_boot$point_estimate, 3), "mg/dL\n")
cat("95% CI: [", round(wdsm_boot$ci[1], 3), ",", round(wdsm_boot$ci[2], 3), "]\n\n")

################################################################################
# SAVE RESULTS
################################################################################

results <- list(
  dsm = list(
    estimate = dsm_est,
    ci_lower = dsm_ci[1],
    ci_upper = dsm_ci[2]
  ),
  pgm = list(
    estimate = pgm_est,
    ci_lower = pgm_ci[1],
    ci_upper = pgm_ci[2]
  ),
  psm = list(
    estimate = psm_est,
    ci_lower = psm_ci[1],
    ci_upper = psm_ci[2]
  ),
  ps_full = list(
    estimate = as.numeric(ps_full_est),
    ci_lower = as.numeric(ps_full_ci[1]),
    ci_upper = as.numeric(ps_full_ci[2])
  ),
  wdsm = list(
    estimate = wdsm_boot$point_estimate,
    ci_lower = wdsm_boot$ci[1],
    ci_upper = wdsm_boot$ci[2]
  )
)

save(data_complete, results, waist_median, 
     file = "CHEN_2025_COMPLETE_RESULTS.rda")

cat("\n")
cat("==============================================================================\n")
cat("   FINAL RESULTS SUMMARY\n")
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

# Calculate bias
sample_avg <- mean(c(dsm_est, pgm_est, psm_est))
pop_avg <- mean(c(ps_full_est, wdsm_boot$point_estimate))
bias_pct <- (sample_avg - pop_avg) / pop_avg * 100

cat("\n")
cat("Sample average (unweighted):   ", sprintf("%.3f", sample_avg), "mg/dL\n")
cat("Population average (weighted): ", sprintf("%.3f", pop_avg), "mg/dL\n")
cat("Bias:                          ", sprintf("%+.1f%%", bias_pct), "\n")

cat("\n✅ Results saved: CHEN_2025_COMPLETE_RESULTS.rda\n")
cat("\n🔥 KEY FINDING: ", round(abs(bias_pct)), "% sample-population difference!\n")

cat("\n")
cat("==============================================================================\n")
cat("   ANALYSIS COMPLETE\n")
cat("==============================================================================\n")







