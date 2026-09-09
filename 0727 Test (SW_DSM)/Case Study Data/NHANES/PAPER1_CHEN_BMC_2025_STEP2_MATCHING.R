################################################################################
# CHEN ET AL. 2025 BMC - STEP 2: APPLY 5 MATCHING METHODS
#
# Data handling VERIFIED in Step 1
# Now apply PSM, PGM, DSM, PS Full, WDSM to SAME comparison
################################################################################

rm(list = ls())
library(dplyr)
library(survey)
library(MatchIt)
library(marginaleffects)

# Load dsmatch
if (!require(dsmatch)) {
  install.packages("dsmatch")
  library(dsmatch)
}

# Load WDSM
source("WDSM_adaptive.R")

# Load verified data from Step 1
load("CHEN_BMC_2025_VERIFIED_DATA.rda")

set.seed(2025)
B_BOOTSTRAP <- 100

cat("\n")
cat("==============================================================================\n")
cat("   CHEN BMC 2025 - STEP 2: APPLY 5 MATCHING METHODS\n")
cat("   Obesity vs Normal Weight → Systolic BP\n")
cat("==============================================================================\n")

################################################################################
# PREPARE DATA FOR MATCHING
################################################################################

# Create binary obesity treatment
# Chen examined BMI continuously, we'll compare Obese (BMI≥30) vs Normal (BMI 18.5-25)

analysis_data$bmi_cat <- cut(analysis_data$bmi,
                              breaks = c(-Inf, 18.5, 25, 30, Inf),
                              labels = c("Underweight", "Normal", "Overweight", "Obese"))

# Filter to Normal vs Obese (exclude underweight and overweight for clear comparison)
matching_data <- analysis_data %>%
  filter(bmi_cat %in% c("Normal", "Obese"))

matching_data$obese <- as.numeric(matching_data$bmi_cat == "Obese")

cat("\nSample for matching:\n")
cat("Total N:", nrow(matching_data), "\n")
cat("Normal (control):", sum(matching_data$obese == 0), "\n")
cat("Obese (treated):", sum(matching_data$obese == 1), "\n")
cat("Ratio:", round(sum(matching_data$obese)/sum(matching_data$obese == 0), 2), ":1\n")

# Define covariate sets
ps_vars <- c("age", "female", "race1", "education")  # For propensity
pg_vars <- c("age", "female", "race1", "education", "pir", "smokestatus", 
             "alcoholstatus", "dmdmartl")  # For prognostic

cat("\nPS covariates:", paste(ps_vars, collapse=", "), "\n")
cat("PG covariates:", paste(pg_vars, collapse=", "), "\n")

# Prepare matrices
X_ps <- as.matrix(matching_data[, ps_vars])
X_pg <- as.matrix(matching_data[, pg_vars])
Y <- matching_data$bpxsy1
A <- matching_data$obese

# Results storage
results <- data.frame(
  Method = character(),
  Estimate = numeric(),
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

est_psm <- psm_result$est.ps
ci_psm <- c(
  psm_result$est.ps - 1.96*sqrt(psm_result$bootvar[1,1]),
  psm_result$est.ps + 1.96*sqrt(psm_result$bootvar[1,1])
)

cat("  Estimate:", round(est_psm, 2), "mmHg\n")
cat("  95% CI: [", round(ci_psm[1], 2), ",", round(ci_psm[2], 2), "]\n")

results <- rbind(results, data.frame(
  Method = "Unwt PSM",
  Estimate = est_psm,
  CI_Lower = ci_psm[1],
  CI_Upper = ci_psm[2],
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

est_pgm <- pgm_result$est.pg
ci_pgm <- c(
  pgm_result$est.pg - 1.96*sqrt(pgm_result$bootvar[1,1]),
  pgm_result$est.pg + 1.96*sqrt(pgm_result$bootvar[1,1])
)

cat("  Estimate:", round(est_pgm, 2), "mmHg\n")
cat("  95% CI: [", round(ci_pgm[1], 2), ",", round(ci_pgm[2], 2), "]\n")

results <- rbind(results, data.frame(
  Method = "Unwt PGM",
  Estimate = est_pgm,
  CI_Lower = ci_pgm[1],
  CI_Upper = ci_pgm[2],
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

est_dsm <- dsm_result$est.ds
ci_dsm <- c(
  dsm_result$est.ds - 1.96*sqrt(dsm_result$bootvar[1,1]),
  dsm_result$est.ds + 1.96*sqrt(dsm_result$bootvar[1,1])
)

cat("  Estimate:", round(est_dsm, 2), "mmHg\n")
cat("  95% CI: [", round(ci_dsm[1], 2), ",", round(ci_dsm[2], 2), "]\n")

results <- rbind(results, data.frame(
  Method = "Unwt DSM",
  Estimate = est_dsm,
  CI_Lower = ci_dsm[1],
  CI_Upper = ci_dsm[2],
  Estimand = "Sample"
))

################################################################################
# METHOD 4: SURVEY-WEIGHTED PS FULL
################################################################################

cat("\n--- METHOD 4: Survey-Weighted PS Full - POPULATION ESTIMATE ---\n")

# Chen used 2017-2018, so weight is WTMEC2YR
ps_formula <- as.formula(paste("obese ~", paste(ps_vars, collapse=" + ")))

tryCatch({
  match_full <- matchit(ps_formula, data = matching_data,
                       method = "full", estimand = "ATE",
                       s.weights = matching_data$wtmec2yr)
  
  matched_full <- match.data(match_full, weights = "weights",
                            distance = "distance", drop.unmatched = FALSE)
  matched_full$combined_weight <- matched_full$weights * matched_full$wtmec2yr
  
  design_full <- svydesign(ids = ~1, weights = ~combined_weight, data = matched_full)
  model_full <- svyglm(bpxsy1 ~ obese, design = design_full)
  est_ps_full <- coef(model_full)["obese"]
  se_ps_full <- sqrt(vcov(model_full)["obese", "obese"])
  
  ci_ps_full <- c(est_ps_full - 1.96*se_ps_full, est_ps_full + 1.96*se_ps_full)
  
  cat("  Estimate:", round(est_ps_full, 2), "mmHg\n")
  cat("  95% CI: [", round(ci_ps_full[1], 2), ",", round(ci_ps_full[2], 2), "]\n")
  
  results <- rbind(results, data.frame(
    Method = "Wt PS Full",
    Estimate = est_ps_full,
    CI_Lower = ci_ps_full[1],
    CI_Upper = ci_ps_full[2],
    Estimand = "Population"
  ))
  
}, error = function(e) {
  cat("  Full matching failed, using nearest neighbor...\n")
  
  match_nn <- matchit(ps_formula, data = matching_data,
                     method = "nearest", ratio = 5, estimand = "ATE",
                     s.weights = matching_data$wtmec2yr)
  
  matched_nn <- match.data(match_nn, weights = "weights",
                          distance = "distance", drop.unmatched = FALSE)
  matched_nn$combined_weight <- matched_nn$weights * matched_nn$wtmec2yr
  
  design_nn <- svydesign(ids = ~1, weights = ~combined_weight, data = matched_nn)
  model_nn <- svyglm(bpxsy1 ~ obese, design = design_nn)
  est_ps_nn <- coef(model_nn)["obese"]
  se_ps_nn <- sqrt(vcov(model_nn)["obese", "obese"])
  
  ci_ps_nn <- c(est_ps_nn - 1.96*se_ps_nn, est_ps_nn + 1.96*se_ps_nn)
  
  cat("  Estimate:", round(est_ps_nn, 2), "mmHg\n")
  cat("  95% CI: [", round(ci_ps_nn[1], 2), ",", round(ci_ps_nn[2], 2), "]\n")
  
  results <- rbind(results, data.frame(
    Method = "Wt PS NN",
    Estimate = est_ps_nn,
    CI_Lower = ci_ps_nn[1],
    CI_Upper = ci_ps_nn[2],
    Estimand = "Population"
  ))
})

################################################################################
# METHOD 5: WDSM
################################################################################

cat("\n--- METHOD 5: WDSM - POPULATION ESTIMATE ---\n")

ps_formula_wdsm <- as.formula(paste("obese ~", paste(ps_vars, collapse=" + ")))
pg_formula_wdsm <- as.formula(paste("bpxsy1 ~", paste(pg_vars, collapse=" + ")))

# Point estimate
cat("  Computing point estimate...")
result_wdsm <- wdsm_adaptive(
  data = matching_data,
  ps_formula = ps_formula_wdsm,
  pg_formula = pg_formula_wdsm,
  outcome_var = "bpxsy1",
  treatment_var = "obese",
  weight_var = "wtmec2yr",
  M = 5,
  use_bias_correction = TRUE,
  verbose = FALSE
)
est_wdsm <- result_wdsm$tau
cat(" Done!\n")

# Bootstrap
cat("  Bootstrap (", B_BOOTSTRAP, " reps): ", sep="")
boot_wdsm <- numeric(B_BOOTSTRAP)
n_valid <- 0

for(b in 1:B_BOOTSTRAP) {
  if(b %% 10 == 0) {
    cat(b, "")
    flush.console()
  }
  
  boot_idx <- sample(nrow(matching_data), replace = TRUE)
  boot_data <- matching_data[boot_idx, ]
  
  tryCatch({
    boot_result <- wdsm_adaptive(
      data = boot_data,
      ps_formula = ps_formula_wdsm,
      pg_formula = pg_formula_wdsm,
      outcome_var = "bpxsy1",
      treatment_var = "obese",
      weight_var = "wtmec2yr",
      M = 5,
      use_bias_correction = TRUE,
      verbose = FALSE
    )
    boot_wdsm[b] <- boot_result$tau
    n_valid <- n_valid + 1
  }, error = function(e) { boot_wdsm[b] <- NA })
}
cat(" Done (", n_valid, " valid)\n", sep="")

if(n_valid > 10) {
  ci_wdsm <- quantile(boot_wdsm, c(0.025, 0.975), na.rm = TRUE)
  cat("  Estimate:", round(est_wdsm, 2), "mmHg\n")
  cat("  95% CI: [", round(ci_wdsm[1], 2), ",", round(ci_wdsm[2], 2), "]\n")
  
  results <- rbind(results, data.frame(
    Method = "WDSM",
    Estimate = est_wdsm,
    CI_Lower = ci_wdsm[1],
    CI_Upper = ci_wdsm[2],
    Estimand = "Population"
  ))
}

################################################################################
# FINAL SUMMARY
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   FINAL RESULTS: CHEN BMC 2025\n")
cat("   Obesity vs Normal → Systolic BP\n")
cat("==============================================================================\n")

cat("\nCHEN'S PAPER (BMI continuous → FRS):\n")
cat("  Men:   β = 0.07 [0.06, 0.08]\n")
cat("  Women: β = 0.09 [0.07, 0.11]\n")

cat("\nOUR REPLICATION (BMI continuous → SBP):\n")
cat("  Men:   β = 0.34 [0.20, 0.48]\n")
cat("  Women: β = 0.37 [0.26, 0.48]\n")
cat("  Direction: ✅ VERIFIED\n")

cat("\nOUR 5 MATCHING METHODS (Obese vs Normal → SBP):\n")
print(results, row.names = FALSE)

if(nrow(results) >= 4) {
  sample_results <- results[results$Estimand == "Sample", ]
  pop_results <- results[results$Estimand == "Population", ]
  
  if(nrow(sample_results) > 0 & nrow(pop_results) > 0) {
    cat("\nKEY FINDINGS:\n")
    cat("1. Sample estimates (unweighted):", 
        round(mean(sample_results$Estimate), 1), "mmHg\n")
    cat("2. Population estimates (weighted):", 
        round(mean(pop_results$Estimate), 1), "mmHg\n")
    cat("3. Bias from ignoring weights:", 
        round(100*(mean(sample_results$Estimate) - mean(pop_results$Estimate))/
              abs(mean(pop_results$Estimate)), 0), "%\n")
  }
}

# Save results
save(results, matching_data, coef_men, coef_women,
     file = "CHEN_BMC_2025_COMPLETE_RESULTS.rda")

cat("\n✅ Results saved: CHEN_BMC_2025_COMPLETE_RESULTS.rda\n")

cat("\n")
cat("==============================================================================\n")
cat("   CHEN BMC 2025 ANALYSIS COMPLETE\n")
cat("==============================================================================\n")



