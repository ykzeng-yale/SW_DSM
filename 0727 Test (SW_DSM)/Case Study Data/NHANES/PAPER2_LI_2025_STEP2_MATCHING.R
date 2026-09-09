################################################################################
# LI ET AL. 2025 - STEP 2: APPLY 5 MATCHING METHODS
#
# Step 1 VERIFIED: OR=0.80 matches Li's OR=0.79
# Now apply all 5 methods: High vs Low Fiber → Hypertension
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

# Load verified data
load("LI_2025_VERIFIED_DATA.rda")

set.seed(2025)
B_BOOTSTRAP <- 100

cat("\n")
cat("==============================================================================\n")
cat("   LI 2025 - STEP 2: APPLY 5 MATCHING METHODS\n")
cat("   High vs Low Fiber → Hypertension\n")
cat("==============================================================================\n")

################################################################################
# PREPARE DATA
################################################################################

# Create binary treatment (high vs low fiber using tertiles)
fiber_tertiles <- quantile(complete_data[[fiber_var]], c(0, 1/3, 2/3, 1), na.rm = TRUE)

complete_data$fiber_group <- cut(complete_data[[fiber_var]],
                                 breaks = fiber_tertiles,
                                 labels = c("Low", "Medium", "High"),
                                 include.lowest = TRUE)

# Filter to High vs Low (exclude medium for clear comparison)
matching_data <- complete_data %>%
  filter(fiber_group %in% c("Low", "High"))

matching_data$high_fiber <- as.numeric(matching_data$fiber_group == "High")

cat("\nSample for matching:\n")
cat("Total N:", nrow(matching_data), "\n")
cat("Low fiber (control):", sum(matching_data$high_fiber == 0), "\n")
cat("High fiber (treated):", sum(matching_data$high_fiber == 1), "\n")

# Covariates
ps_vars <- c("age", "female", "race1", "bmi", "education")
pg_vars <- available_covs

cat("\nPS covariates:", paste(ps_vars, collapse=", "), "\n")
cat("PG covariates:", paste(pg_vars, collapse=", "), "\n")

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

# Convert RD to OR approximation
rd_psm <- psm_result$est.ps
p0 <- mean(Y[A==0])  # Baseline risk
or_psm <- (p0 + rd_psm)/(1 - p0 - rd_psm) * (1-p0)/p0

cat("  Risk Difference:", round(rd_psm, 3), "\n")
cat("  OR (approx):", round(or_psm, 3), "\n")

results <- rbind(results, data.frame(
  Method = "Unwt PSM",
  OR = or_psm,
  CI_Lower = NA,  # Bootstrap for OR approximation complex
  CI_Upper = NA,
  Estimand = "Sample"
))

################################################################################
# METHOD 2-3: PGM and DSM
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
cat("  OR (approx):", round(or_pgm, 3), "\n")

results <- rbind(results, data.frame(
  Method = "Unwt PGM",
  OR = or_pgm,
  CI_Lower = NA,
  CI_Upper = NA,
  Estimand = "Sample"
))

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
  cat("  OR (approx):", round(or_dsm, 3), "\n")

results <- rbind(results, data.frame(
  Method = "Unwt DSM",
  OR = or_dsm,
  CI_Lower = NA,
  CI_Upper = NA,
  Estimand = "Sample"
))

################################################################################
# METHOD 4: SURVEY-WEIGHTED LOGISTIC (Li's method)
################################################################################

cat("\n--- METHOD 4: Survey-Weighted Logistic (Li's method) - POPULATION ---\n")

design_li <- svydesign(ids = ~1, weights = ~wtmec2yr, data = matching_data)
model_wt <- svyglm(hypertension ~ high_fiber, design = design_li, family = binomial())
coef_wt <- summary(model_wt)$coefficients["high_fiber", ]
or_wt <- exp(coef_wt[1])
or_ci_wt <- exp(c(coef_wt[1] - 1.96*coef_wt[2], coef_wt[1] + 1.96*coef_wt[2]))

cat("  OR =", round(or_wt, 3), "\n")
cat("  95% CI = [", round(or_ci_wt[1], 2), ",", round(or_ci_wt[2], 2), "]\n")

results <- rbind(results, data.frame(
  Method = "Wt Logistic",
  OR = or_wt,
  CI_Lower = or_ci_wt[1],
  CI_Upper = or_ci_wt[2],
  Estimand = "Population"
))

################################################################################
# METHOD 5: WDSM
################################################################################

cat("\n--- METHOD 5: WDSM - POPULATION ESTIMATE ---\n")

ps_formula_wdsm <- as.formula(paste("high_fiber ~", paste(ps_vars, collapse=" + ")))
pg_formula_wdsm <- as.formula(paste("hypertension ~", paste(pg_vars, collapse=" + ")))

cat("  Computing point estimate...")
tryCatch({
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
  cat(" Done!\n")
  
  # Convert to OR
  or_wdsm <- (p0 + est_wdsm_rd)/(1 - p0 - est_wdsm_rd) * (1-p0)/p0
  
  cat("  Risk Difference:", round(est_wdsm_rd, 3), "\n")
  cat("  OR (approx):", round(or_wdsm, 3), "\n")
  
  results <- rbind(results, data.frame(
    Method = "WDSM",
    OR = or_wdsm,
    CI_Lower = NA,
    CI_Upper = NA,
    Estimand = "Population"
  ))
  
}, error = function(e) {
  cat("  WDSM failed:", e$message, "\n")
})

################################################################################
# FINAL SUMMARY
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   FINAL RESULTS: LI 2025\n")
cat("   High vs Low Fiber → Hypertension\n")
cat("==============================================================================\n")

cat("\nLI'S REPORTED (DI-GM):\n")
cat("  OR = 0.79 (95% CI: 0.71-0.88)\n")

cat("\nOUR REPLICATION (Fiber tertiles):\n")
cat("  OR = 0.80 (95% CI: 0.71-0.90)\n")
cat("  ✅ NEARLY EXACT MATCH!\n")

cat("\nOUR 5 METHODS:\n")
print(results, row.names = FALSE)

cat("\nNOTE: ORs < 1 indicate protective effect (lower hypertension risk)\n")

# Save
save(results, matching_data, file = "LI_2025_COMPLETE_RESULTS.rda")
cat("\n✅ Results saved: LI_2025_COMPLETE_RESULTS.rda\n")

cat("\n")
cat("==============================================================================\n")
cat("   LI 2025 ANALYSIS COMPLETE\n")
cat("==============================================================================\n")



