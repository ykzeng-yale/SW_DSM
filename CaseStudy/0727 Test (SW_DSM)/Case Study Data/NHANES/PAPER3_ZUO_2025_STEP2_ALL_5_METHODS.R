################################################################################
# ZUO 2025 - STEP 2: APPLY ALL 5 MATCHING METHODS
#
# Data handling VERIFIED in Step 1
# High BMI (Q4) vs Low BMI (Q1) → Hypertension
# Bootstrap = 200 for full CIs
################################################################################

rm(list = ls())
library(dplyr)
library(survey)
library(MatchIt)
library(marginaleffects)

if (!require(dsmatch)) {
  install.packages("dsmatch")
  library(dsmatch)
}

source("WDSM_adaptive.R")

load("ZUO_2025_VERIFIED_DATA.rda")

set.seed(2025)
B_BOOTSTRAP <- 200

cat("\n")
cat("==============================================================================\n")
cat("   ZUO 2025 - STEP 2: ALL 5 MATCHING METHODS\n")
cat("   High BMI (Q4) vs Low BMI (Q1) → Hypertension\n")
cat("==============================================================================\n")

################################################################################
# PREPARE FOR MATCHING
################################################################################

# Filter to Q4 vs Q1 (extreme comparison)
matching_data <- complete_data %>%
  filter(bmi_quartile %in% c("Q1", "Q4"))

matching_data$high_bmi <- as.numeric(matching_data$bmi_quartile == "Q4")

cat("\nSample for matching:\n")
cat("Total N:", nrow(matching_data), "\n")
cat("Low BMI (Q1):", sum(matching_data$high_bmi == 0), "\n")
cat("High BMI (Q4):", sum(matching_data$high_bmi == 1), "\n")
cat("Ratio:", round(sum(matching_data$high_bmi)/sum(matching_data$high_bmi == 0), 2), ":1\n")

# Covariates
ps_vars <- c("age", "female", "race1", "education")
pg_vars <- zuo_covs_core

cat("\nPS covariates:", paste(ps_vars, collapse=", "), "\n")
cat("PG covariates:", paste(pg_vars, collapse=", "), "\n")

# Baseline risk
p0 <- mean(matching_data$hypertension[matching_data$high_bmi == 0])

# Results storage
results <- data.frame(
  Method = character(),
  OR = numeric(),
  CI_Lower = numeric(),
  CI_Upper = numeric(),
  RD = numeric(),
  RD_CI_Lower = numeric(),
  RD_CI_Upper = numeric(),
  Estimand = character(),
  stringsAsFactors = FALSE
)

# Matrices for dsmatch
X_ps <- as.matrix(matching_data[, ps_vars])
X_pg <- as.matrix(matching_data[, pg_vars])
Y <- matching_data$hypertension
A <- matching_data$high_bmi

################################################################################
# METHOD 1-3: UNWEIGHTED MATCHING
################################################################################

cat("\n--- METHOD 1: Unweighted PSM (1:1) ---\n")

suppressWarnings({
  psm_result <- dsmatchATE(
    Y = Y, X = X_ps, A = A,
    method = "ps", model.ps = "logit",
    cov.balance = FALSE, varest = TRUE,
    boots = B_BOOTSTRAP, mc = FALSE, ncpus = 1
  )
})

rd_psm <- psm_result$est.ps
rd_ci_psm <- c(rd_psm - 1.96*sqrt(psm_result$bootvar[1,1]),
               rd_psm + 1.96*sqrt(psm_result$bootvar[1,1]))
or_psm <- (p0 + rd_psm)/(1 - p0 - rd_psm) * (1-p0)/p0
or_ci_psm <- c((p0 + rd_ci_psm[1])/(1 - p0 - rd_ci_psm[1]) * (1-p0)/p0,
               (p0 + rd_ci_psm[2])/(1 - p0 - rd_ci_psm[2]) * (1-p0)/p0)

cat("  OR =", round(or_psm, 3), "[", round(or_ci_psm[1], 3), ",", round(or_ci_psm[2], 3), "]\n")

results <- rbind(results, data.frame(
  Method = "Unwt PSM", OR = or_psm, CI_Lower = or_ci_psm[1], CI_Upper = or_ci_psm[2],
  RD = rd_psm, RD_CI_Lower = rd_ci_psm[1], RD_CI_Upper = rd_ci_psm[2],
  Estimand = "Sample"
))

cat("\n--- METHOD 2: Unweighted PGM (1:1) ---\n")

suppressWarnings({
  pgm_result <- dsmatchATE(
    Y = Y, X = X_ps, A = A,
    method = "pg", model.ps = "logit",
    model.pg = "linpred", lp.pg = X_pg,
    cov.balance = FALSE, varest = TRUE,
    boots = B_BOOTSTRAP, mc = FALSE, ncpus = 1
  )
})

rd_pgm <- pgm_result$est.pg
rd_ci_pgm <- c(rd_pgm - 1.96*sqrt(pgm_result$bootvar[1,1]),
               rd_pgm + 1.96*sqrt(pgm_result$bootvar[1,1]))
or_pgm <- (p0 + rd_pgm)/(1 - p0 - rd_pgm) * (1-p0)/p0
or_ci_pgm <- c((p0 + rd_ci_pgm[1])/(1 - p0 - rd_ci_pgm[1]) * (1-p0)/p0,
               (p0 + rd_ci_pgm[2])/(1 - p0 - rd_ci_pgm[2]) * (1-p0)/p0)

cat("  OR =", round(or_pgm, 3), "[", round(or_ci_pgm[1], 3), ",", round(or_ci_pgm[2], 3), "]\n")

results <- rbind(results, data.frame(
  Method = "Unwt PGM", OR = or_pgm, CI_Lower = or_ci_pgm[1], CI_Upper = or_ci_pgm[2],
  RD = rd_pgm, RD_CI_Lower = rd_ci_pgm[1], RD_CI_Upper = rd_ci_pgm[2],
  Estimand = "Sample"
))

cat("\n--- METHOD 3: Unweighted DSM (1:1) ---\n")

suppressWarnings({
  dsm_result <- dsmatchATE(
    Y = Y, X = X_ps, A = A,
    method = "dsm", model.ps = "logit",
    model.pg = "linpred", lp.pg = X_pg,
    cov.balance = FALSE, varest = TRUE,
    boots = B_BOOTSTRAP, mc = FALSE, ncpus = 1
  )
})

rd_dsm <- dsm_result$est.ds
rd_ci_dsm <- c(rd_dsm - 1.96*sqrt(dsm_result$bootvar[1,1]),
               rd_dsm + 1.96*sqrt(dsm_result$bootvar[1,1]))
or_dsm <- (p0 + rd_dsm)/(1 - p0 - rd_dsm) * (1-p0)/p0
or_ci_dsm <- c((p0 + rd_ci_dsm[1])/(1 - p0 - rd_ci_dsm[1]) * (1-p0)/p0,
               (p0 + rd_ci_dsm[2])/(1 - p0 - rd_ci_dsm[2]) * (1-p0)/p0)

cat("  OR =", round(or_dsm, 3), "[", round(or_ci_dsm[1], 3), ",", round(or_ci_dsm[2], 3), "]\n")

results <- rbind(results, data.frame(
  Method = "Unwt DSM", OR = or_dsm, CI_Lower = or_ci_dsm[1], CI_Upper = or_ci_dsm[2],
  RD = rd_dsm, RD_CI_Lower = rd_ci_dsm[1], RD_CI_Upper = rd_ci_dsm[2],
  Estimand = "Sample"
))

################################################################################
# METHOD 4: SURVEY-WEIGHTED PS FULL
################################################################################

cat("\n--- METHOD 4: Survey-Weighted PS Full ---\n")

ps_formula <- as.formula(paste("high_bmi ~", paste(ps_vars, collapse=" + ")))

tryCatch({
  match_full <- matchit(ps_formula, data = matching_data,
                       method = "full", estimand = "ATE",
                       s.weights = matching_data$wtmec2yr)
  
  matched_full <- match.data(match_full, weights = "weights",
                            distance = "distance", drop.unmatched = FALSE)
  matched_full$combined_weight <- matched_full$weights * matched_full$wtmec2yr
  
  design_full <- svydesign(ids = ~1, weights = ~combined_weight, data = matched_full)
  model_full <- svyglm(hypertension ~ high_bmi, design = design_full, family = binomial())
  
  coef_full <- summary(model_full)$coefficients["high_bmi", ]
  or_full <- exp(coef_full[1])
  or_ci_full <- exp(c(coef_full[1] - 1.96*coef_full[2],
                       coef_full[1] + 1.96*coef_full[2]))
  
  cat("  OR =", round(or_full, 3), "[", round(or_ci_full[1], 3), ",", round(or_ci_full[2], 3), "]\n")
  
  results <- rbind(results, data.frame(
    Method = "Wt PS Full", OR = or_full, CI_Lower = or_ci_full[1], CI_Upper = or_ci_full[2],
    RD = coef_full[1], RD_CI_Lower = coef_full[1] - 1.96*coef_full[2],
    RD_CI_Upper = coef_full[1] + 1.96*coef_full[2],
    Estimand = "Population"
  ))
}, error = function(e) cat("  Failed:", e$message, "\n"))

################################################################################
# METHOD 5: WDSM with BOOTSTRAP
################################################################################

cat("\n--- METHOD 5: WDSM with Bootstrap ---\n")

ps_formula_wdsm <- as.formula(paste("high_bmi ~", paste(ps_vars, collapse=" + ")))
pg_formula_wdsm <- as.formula(paste("hypertension ~", paste(pg_vars, collapse=" + ")))

cat("  Point estimate...")
result_wdsm <- wdsm_adaptive(
  data = matching_data, ps_formula = ps_formula_wdsm, pg_formula = pg_formula_wdsm,
  outcome_var = "hypertension", treatment_var = "high_bmi", weight_var = "wtmec2yr",
  M = 5, use_bias_correction = TRUE, verbose = FALSE
)
rd_wdsm <- result_wdsm$tau
cat(" Done!\n")

cat("  Bootstrap (", B_BOOTSTRAP, " reps): ", sep="")
boot_rd_wdsm <- numeric(B_BOOTSTRAP)
n_valid <- 0

for(b in 1:B_BOOTSTRAP) {
  if(b %% 20 == 0) cat(b, "")
  
  boot_idx <- sample(nrow(matching_data), replace = TRUE)
  boot_data <- matching_data[boot_idx, ]
  
  tryCatch({
    boot_result <- wdsm_adaptive(
      data = boot_data, ps_formula = ps_formula_wdsm, pg_formula = pg_formula_wdsm,
      outcome_var = "hypertension", treatment_var = "high_bmi", weight_var = "wtmec2yr",
      M = 5, use_bias_correction = TRUE, verbose = FALSE
    )
    boot_rd_wdsm[b] <- boot_result$tau
    n_valid <- n_valid + 1
  }, error = function(e) { boot_rd_wdsm[b] <- NA })
}
cat(" Done (", n_valid, " valid)\n", sep="")

rd_ci_wdsm <- quantile(boot_rd_wdsm, c(0.025, 0.975), na.rm = TRUE)
or_wdsm <- (p0 + rd_wdsm)/(1 - p0 - rd_wdsm) * (1-p0)/p0
or_ci_wdsm <- c((p0 + rd_ci_wdsm[1])/(1 - p0 - rd_ci_wdsm[1]) * (1-p0)/p0,
                (p0 + rd_ci_wdsm[2])/(1 - p0 - rd_ci_wdsm[2]) * (1-p0)/p0)

cat("  OR =", round(or_wdsm, 3), "[", round(or_ci_wdsm[1], 3), ",", round(or_ci_wdsm[2], 3), "]\n")

results <- rbind(results, data.frame(
  Method = "WDSM", OR = or_wdsm, CI_Lower = or_ci_wdsm[1], CI_Upper = or_ci_wdsm[2],
  RD = rd_wdsm, RD_CI_Lower = rd_ci_wdsm[1], RD_CI_Upper = rd_ci_wdsm[2],
  Estimand = "Population"
))

################################################################################
# COMPARISON WITH ZUO'S METHOD
################################################################################

cat("\n--- Zuo's Original Method (for comparison) ---\n")
design_zuo <- svydesign(ids = ~1, weights = ~wtmec2yr, data = matching_data)
model_zuo <- svyglm(hypertension ~ high_bmi, design = design_zuo, family = binomial())
coef_zuo <- summary(model_zuo)$coefficients["high_bmi", ]
or_zuo <- exp(coef_zuo[1])
or_ci_zuo <- exp(c(coef_zuo[1] - 1.96*coef_zuo[2], coef_zuo[1] + 1.96*coef_zuo[2]))

cat("  OR =", round(or_zuo, 3), "[", round(or_ci_zuo[1], 3), ",", round(or_ci_zuo[2], 3), "]\n")

################################################################################
# FINAL SUMMARY
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   COMPLETE RESULTS: ZUO 2025\n")
cat("==============================================================================\n")

cat("\nZUO'S PAPER (VAI Q4 vs Q1):\n")
cat("  OR ≈ 2.0 (p<0.001)\n")

cat("\nOUR REPLICATION (BMI Q4 vs Q1, all subjects):\n")
cat("  OR = 4.80 [3.95, 5.84] (p<0.001)\n")

cat("\nALL 5 METHODS (Q4 vs Q1, N=", nrow(matching_data), "):\n", sep="")
print(results[, c("Method", "OR", "CI_Lower", "CI_Upper", "Estimand")], row.names = FALSE)

sample_ors <- results$OR[results$Estimand == "Sample"]
pop_ors <- results$OR[results$Estimand == "Population"]

cat("\n--- KEY FINDINGS ---\n")
cat("Sample methods:    Average OR =", round(mean(sample_ors), 2), "\n")
cat("Population methods: Average OR =", round(mean(pop_ors, na.rm=TRUE), 2), "\n")

if(length(sample_ors) > 0 & length(pop_ors) > 0) {
  bias_pct <- 100 * (mean(sample_ors) - mean(pop_ors, na.rm=TRUE)) / mean(pop_ors, na.rm=TRUE)
  cat("Bias:", round(bias_pct, 0), "%\n")
}

# Save
save(results, matching_data, or_zuo, or_ci_zuo,
     file = "ZUO_2025_COMPLETE_RESULTS.rda")

cat("\n✅ Results saved: ZUO_2025_COMPLETE_RESULTS.rda\n")

cat("\n")
cat("==============================================================================\n")
cat("   ZUO 2025 ANALYSIS COMPLETE\n")
cat("==============================================================================\n")



