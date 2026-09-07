################################################################################
# LI 2025 - CORRECTED STEP 2: ALL 5 MATCHING METHODS
#
# CORRECT Methods:
# 1. Unweighted PSM (dsmatch)
# 2. Unweighted PGM (dsmatch)
# 3. Unweighted DSM (dsmatch)
# 4. Survey-Weighted PSM (MatchIt PS Full) ← CORRECTED!
# 5. WDSM (our method)
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

load("LI_2025_VERIFIED_DATA.rda")

set.seed(2025)
B_BOOTSTRAP <- 100

cat("\n")
cat("==============================================================================\n")
cat("   LI 2025 - ALL 5 MATCHING METHODS (CORRECTED)\n")
cat("   High vs Low Fiber → Hypertension\n")
cat("==============================================================================\n")

################################################################################
# PREPARE DATA
################################################################################

# Create tertiles
fiber_tertiles <- quantile(complete_data[[fiber_var]], c(0, 1/3, 2/3, 1), na.rm = TRUE)
complete_data$fiber_group <- cut(complete_data[[fiber_var]],
                                 breaks = fiber_tertiles,
                                 labels = c("Low", "Medium", "High"),
                                 include.lowest = TRUE)

# Filter to High vs Low
matching_data <- complete_data %>%
  filter(fiber_group %in% c("Low", "High"))

matching_data$high_fiber <- as.numeric(matching_data$fiber_group == "High")

cat("\nSample: N =", nrow(matching_data), "\n")
cat("Low fiber:  ", sum(matching_data$high_fiber == 0), "\n")
cat("High fiber: ", sum(matching_data$high_fiber == 1), "\n")

# Covariates
ps_vars <- c("age", "female", "race1", "bmi", "education")
pg_vars <- available_covs

# Prepare matrices
X_ps <- as.matrix(matching_data[, ps_vars])
X_pg <- as.matrix(matching_data[, pg_vars])
Y <- matching_data$hypertension
A <- matching_data$high_fiber

results <- data.frame(
  Method = character(),
  OR = numeric(),
  CI_Lower = numeric(),
  CI_Upper = numeric(),
  Estimand = character(),
  stringsAsFactors = FALSE
)

################################################################################
# METHOD 1: UNWEIGHTED PSM
################################################################################

cat("\n--- METHOD 1: Unweighted PSM (1:1) - SAMPLE ESTIMATE ---\n")

suppressWarnings({
  psm_result <- dsmatchATE(
    Y = Y,
    X = X_ps,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = TRUE,
    boots = B_BOOTSTRAP,
    mc = FALSE,
    ncpus = 1
  )
})

rd_psm <- psm_result$est.ps
p0 <- mean(Y[A==0])
or_psm <- (p0 + rd_psm)/(1 - p0 - rd_psm) * (1-p0)/p0

cat("  Risk Difference:", round(rd_psm, 3), "\n")
cat("  OR:", round(or_psm, 3), "\n")

results <- rbind(results, data.frame(
  Method = "Unwt PSM",
  OR = or_psm,
  CI_Lower = NA,
  CI_Upper = NA,
  Estimand = "Sample"
))

################################################################################
# METHOD 2: UNWEIGHTED PGM
################################################################################

cat("\n--- METHOD 2: Unweighted PGM (1:1) - SAMPLE ESTIMATE ---\n")

suppressWarnings({
  pgm_result <- dsmatchATE(
    Y = Y,
    X = X_ps,
    A = A,
    method = "pg",
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

rd_pgm <- pgm_result$est.pg
or_pgm <- (p0 + rd_pgm)/(1 - p0 - rd_pgm) * (1-p0)/p0

cat("  Risk Difference:", round(rd_pgm, 3), "\n")
cat("  OR:", round(or_pgm, 3), "\n")

results <- rbind(results, data.frame(
  Method = "Unwt PGM",
  OR = or_pgm,
  CI_Lower = NA,
  CI_Upper = NA,
  Estimand = "Sample"
))

################################################################################
# METHOD 3: UNWEIGHTED DSM
################################################################################

cat("\n--- METHOD 3: Unweighted DSM (1:1) - SAMPLE ESTIMATE ---\n")

suppressWarnings({
  dsm_result <- dsmatchATE(
    Y = Y,
    X = X_ps,
    A = A,
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

rd_dsm <- dsm_result$est.ds
or_dsm <- (p0 + rd_dsm)/(1 - p0 - rd_dsm) * (1-p0)/p0

cat("  Risk Difference:", round(rd_dsm, 3), "\n")
cat("  OR:", round(or_dsm, 3), "\n")

results <- rbind(results, data.frame(
  Method = "Unwt DSM",
  OR = or_dsm,
  CI_Lower = NA,
  CI_Upper = NA,
  Estimand = "Sample"
))

################################################################################
# METHOD 4: SURVEY-WEIGHTED PSM (PS FULL MATCHING) ← CORRECTED!
################################################################################

cat("\n--- METHOD 4: Survey-Weighted PS Full Matching - POPULATION ESTIMATE ---\n")

ps_formula <- as.formula(paste("high_fiber ~", paste(ps_vars, collapse=" + ")))

tryCatch({
  # Try full matching with survey weights
  match_ps_full <- matchit(ps_formula, data = matching_data,
                          method = "full", estimand = "ATE",
                          s.weights = matching_data$wtmec2yr)
  
  matched_full <- match.data(match_ps_full, weights = "weights",
                            distance = "distance", drop.unmatched = FALSE)
  matched_full$combined_weight <- matched_full$weights * matched_full$wtmec2yr
  
  # Survey-weighted logistic on matched data
  design_full <- svydesign(ids = ~1, weights = ~combined_weight, data = matched_full)
  model_ps_full <- svyglm(hypertension ~ high_fiber, design = design_full, family = binomial())
  
  coef_ps_full <- summary(model_ps_full)$coefficients["high_fiber", ]
  or_ps_full <- exp(coef_ps_full[1])
  or_ci_ps_full <- exp(c(coef_ps_full[1] - 1.96*coef_ps_full[2],
                          coef_ps_full[1] + 1.96*coef_ps_full[2]))
  
  cat("  OR =", round(or_ps_full, 3), "\n")
  cat("  95% CI = [", round(or_ci_ps_full[1], 2), ",", round(or_ci_ps_full[2], 2), "]\n")
  
  results <- rbind(results, data.frame(
    Method = "Wt PS Full",
    OR = or_ps_full,
    CI_Lower = or_ci_ps_full[1],
    CI_Upper = or_ci_ps_full[2],
    Estimand = "Population"
  ))
  
}, error = function(e) {
  cat("  Full matching failed, trying nearest neighbor...\n")
  
  match_ps_nn <- matchit(ps_formula, data = matching_data,
                        method = "nearest", ratio = 5, estimand = "ATE",
                        s.weights = matching_data$wtmec2yr)
  
  matched_nn <- match.data(match_ps_nn, weights = "weights",
                          distance = "distance", drop.unmatched = FALSE)
  matched_nn$combined_weight <- matched_nn$weights * matched_nn$wtmec2yr
  
  design_nn <- svydesign(ids = ~1, weights = ~combined_weight, data = matched_nn)
  model_ps_nn <- svyglm(hypertension ~ high_fiber, design = design_nn, family = binomial())
  
  coef_ps_nn <- summary(model_ps_nn)$coefficients["high_fiber", ]
  or_ps_nn <- exp(coef_ps_nn[1])
  or_ci_ps_nn <- exp(c(coef_ps_nn[1] - 1.96*coef_ps_nn[2],
                        coef_ps_nn[1] + 1.96*coef_ps_nn[2]))
  
  cat("  OR =", round(or_ps_nn, 3), "\n")
  cat("  95% CI = [", round(or_ci_ps_nn[1], 2), ",", round(or_ci_ps_nn[2], 2), "]\n")
  
  results <- rbind(results, data.frame(
    Method = "Wt PS NN",
    OR = or_ps_nn,
    CI_Lower = or_ci_ps_nn[1],
    CI_Upper = or_ci_ps_nn[2],
    Estimand = "Population"
  ))
})

################################################################################
# METHOD 5: WDSM
################################################################################

cat("\n--- METHOD 5: WDSM - POPULATION ESTIMATE ---\n")

ps_formula_wdsm <- as.formula(paste("high_fiber ~", paste(ps_vars, collapse=" + ")))
pg_formula_wdsm <- as.formula(paste("hypertension ~", paste(pg_vars, collapse=" + ")))

cat("  Computing point estimate...")
result_wdsm <- wdsm_adaptive(
  data = matching_data,
  ps_formula = ps_formula_wdsm,
  pg_formula = pg_formula_wdsm,
  outcome_var = "hypertension",
  treatment_var = "high_fiber",
  weight_var = "wtmec2yr",
  M = 5,
  use_bias_correction = TRUE,
  verbose = FALSE
)
est_wdsm_rd <- result_wdsm$tau
or_wdsm <- (p0 + est_wdsm_rd)/(1 - p0 - est_wdsm_rd) * (1-p0)/p0
cat(" Done!\n")

cat("  Risk Difference:", round(est_wdsm_rd, 3), "\n")
cat("  OR:", round(or_wdsm, 3), "\n")

results <- rbind(results, data.frame(
  Method = "WDSM",
  OR = or_wdsm,
  CI_Lower = NA,
  CI_Upper = NA,
  Estimand = "Population"
))

################################################################################
# COMPARISON WITH LI'S ORIGINAL METHOD
################################################################################

cat("\n--- Li's Original Method (for comparison) ---\n")
design_li <- svydesign(ids = ~1, weights = ~wtmec2yr, data = matching_data)
model_li <- svyglm(hypertension ~ high_fiber, design = design_li, family = binomial())
coef_li <- summary(model_li)$coefficients["high_fiber", ]
or_li <- exp(coef_li[1])
or_ci_li <- exp(c(coef_li[1] - 1.96*coef_li[2], coef_li[1] + 1.96*coef_li[2]))

cat("  Survey-Weighted Logistic (Li's method):\n")
cat("  OR =", round(or_li, 3), "[", round(or_ci_li[1], 2), ",", round(or_ci_li[2], 2), "]\n")

################################################################################
# FINAL SUMMARY
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   CORRECTED RESULTS: ALL 5 MATCHING METHODS\n")
cat("==============================================================================\n")

cat("\nLi's Reported (DI-GM): OR = 0.79 [0.71, 0.88]\n")
cat("Li's Method Replicated: OR =", round(or_li, 2), "[", round(or_ci_li[2], 2), ",", round(or_ci_li[2], 2), "]\n\n")

cat("ALL 5 MATCHING METHODS:\n")
print(results, row.names = FALSE)

cat("\n--- EXPLANATION ---\n")
cat("Methods 1-3: Unweighted matching (Sample estimates)\n")
cat("Method 4:    Survey-weighted PSM matching (Population estimate)\n")
cat("Method 5:    WDSM - Weighted double score matching (Population estimate)\n")
cat("Li's method: Survey-weighted logistic regression (for comparison)\n")

cat("\n--- COMPARISON ---\n")
sample_ors <- results$OR[results$Estimand == "Sample"]
pop_ors <- results$OR[results$Estimand == "Population"]

cat("Sample methods (unwt):  OR =", round(mean(sample_ors), 3), "(average)\n")
cat("Population methods (wt): OR =", round(mean(pop_ors, na.rm=TRUE), 3), "(average)\n")
cat("Li's original method:    OR =", round(or_li, 3), "\n")

save(results, matching_data, or_li, or_ci_li,
     file = "LI_2025_CORRECTED_RESULTS.rda")

cat("\n✅ Results saved: LI_2025_CORRECTED_RESULTS.rda\n")

cat("\n")
cat("==============================================================================\n")
cat("   ANALYSIS COMPLETE\n")
cat("==============================================================================\n")



