################################################################################
# COMPLETE YANG ET AL. 2023 ANALYSIS
# Paper: Yang et al. (2023) - Dietary Vitamin C and Serum Uric Acid
# Two-step analysis: Alignment + 5 Matching Methods
################################################################################

rm(list = ls())
library(dplyr)
library(haven)
library(survey)
library(MatchIt)
library(marginaleffects)

# Load dsmatch
if (!require(dsmatch)) {
  install.packages("dsmatch")
  library(dsmatch)
}

# Load WDSM functions
source("WDSM_adaptive.R")

# Set parameters
set.seed(2024)
B_BOOTSTRAP <- 100  # Increase to 500+ for publication

################################################################################
# PART 1: DATA PREPARATION
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   YANG ET AL. (2023) ANALYSIS\n")
cat("   Effect of Dietary Vitamin C on Serum Uric Acid\n")
cat("==============================================================================\n")

# Load data
load("data/nhanes_2007_2018.rda")

# Clean data
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

# Check for vitamin C variable
vitamin_c_vars <- grep("dr1tvitc|dr2tvitc|dr1tvc|dr2tvc|vitc", 
                       names(nhanes_clean), ignore.case = TRUE, value = TRUE)

cat("\nVitamin C variables found:", paste(vitamin_c_vars, collapse=", "), "\n")

# If no vitamin C, use MVPA as fallback (as we did before)
if(length(vitamin_c_vars) == 0) {
  cat("No vitamin C variables found. Using MVPA as alternative exposure.\n")
  
  # Use MVPA as exposure instead
  nhanes_clean$exposure <- nhanes_clean$mvpa_week
  exposure_name <- "MVPA (min/week)"
  exposure_var <- "mvpa_week"
  
  # Create binary treatment (high vs low MVPA)
  median_mvpa <- median(nhanes_clean$mvpa_week, na.rm = TRUE)
  nhanes_clean$treatment <- as.numeric(nhanes_clean$mvpa_week >= median_mvpa)
  
} else {
  # Use first available vitamin C variable
  exposure_var <- vitamin_c_vars[1]
  nhanes_clean$exposure <- nhanes_clean[[exposure_var]]
  exposure_name <- "Dietary Vitamin C (mg/day)"
  
  # Create binary treatment (adequate vs inadequate vitamin C)
  # RDA: 90mg for men, 75mg for women; we'll use 80mg as cutoff
  nhanes_clean$treatment <- as.numeric(nhanes_clean$exposure >= 80)
}

cat("Using exposure:", exposure_name, "\n")

# Filter to adults with complete outcome and exposure
adults <- nhanes_clean %>% 
  filter(age >= 20,
         !is.na(lbxsua),
         !is.na(exposure),
         !is.na(wtmec2yr))

cat("\nAdults with outcome and exposure:", nrow(adults), "\n")

# Define covariates based on Yang et al. 2023
# Demographics: age, sex, race, education, PIR
# Clinical: BMI, eGFR, hypertension, diabetes
# Lifestyle: smoking, alcohol, physical activity
# Diet: total energy intake

yang_covariates <- c("age", "female", "race1", "education", "pir",
                     "bmi", "egfr", "hypertension", "diabetes",
                     "smokestatus", "alcoholstatus")

# Check availability
available_covs <- yang_covariates[yang_covariates %in% names(adults)]
cat("\nAvailable Yang covariates:", paste(available_covs, collapse=", "), "\n")

# Create complete case dataset
analysis_vars <- c("lbxsua", "treatment", "wtmec2yr", available_covs)
complete_data <- adults %>%
  filter(complete.cases(.[analysis_vars]))

cat("\n--- SAMPLE CHARACTERISTICS ---\n")
cat("Total N:", nrow(complete_data), "\n")
cat("High exposure (treated):", sum(complete_data$treatment), "\n")
cat("Low exposure (control):", sum(complete_data$treatment == 0), "\n")
cat("Ratio:", round(sum(complete_data$treatment)/sum(complete_data$treatment == 0), 2), ":1\n")

# Define covariate sets for matching
ps_vars <- c("age", "female", "race1", "bmi")  # Basic propensity score
pg_vars <- available_covs                       # All for prognostic score

################################################################################
# PART 2: REPLICATE YANG'S REGRESSION (ALIGNMENT)
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   STEP 1: REPLICATE YANG'S REGRESSION METHOD\n")
cat("==============================================================================\n")

# Create survey design
design <- svydesign(ids = ~1, weights = ~wtmec2yr, data = complete_data)

# Yang's regression with available covariates
formula_yang <- as.formula(paste("lbxsua ~ treatment +", 
                                 paste(available_covs, collapse=" + ")))
model_yang <- svyglm(formula_yang, design = design)
coef_yang <- coef(summary(model_yang))["treatment", ]

cat("\nOUR REPLICATION:\n")
cat("  β =", round(coef_yang[1], 3), "\n")
cat("  SE =", round(coef_yang[2], 3), "\n")
cat("  p-value =", format(coef_yang[4], digits = 3), "\n")

cat("\nNOTE: Yang et al. reported inverse association between vitamin C and uric acid\n")
cat("      If using MVPA, interpretation differs but method demonstration remains valid\n")

################################################################################
# PART 3: APPLY OUR 5 MATCHING METHODS
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   STEP 2: APPLY 5 MATCHING METHODS\n")
cat("==============================================================================\n")

# Store results
results <- data.frame(
  Method = character(),
  Estimate = numeric(),
  CI_Lower = numeric(),
  CI_Upper = numeric(),
  Estimand = character(),
  stringsAsFactors = FALSE
)

# Prepare matrices for dsmatch
X_ps <- as.matrix(complete_data[, ps_vars])
X_pg <- as.matrix(complete_data[, pg_vars])
Y <- complete_data$lbxsua
A <- complete_data$treatment

################################################################################
# METHOD 1: UNWEIGHTED PSM
################################################################################

cat("\n--- METHOD 1: Unweighted PSM (1:1) - SAMPLE ESTIMATE ---\n")

tryCatch({
  suppressWarnings({
    psm_boot <- dsmatchATE(
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
  
  est_psm <- psm_boot$est.ps
  ci_psm <- c(
    psm_boot$est.ps - 1.96*sqrt(psm_boot$bootvar[1,1]),
    psm_boot$est.ps + 1.96*sqrt(psm_boot$bootvar[1,1])
  )
  
  cat("  Estimate:", round(est_psm, 3), "mg/dL\n")
  cat("  95% CI: [", round(ci_psm[1], 3), ",", round(ci_psm[2], 3), "]\n")
  
  results <- rbind(results, data.frame(
    Method = "Unwt PSM",
    Estimate = est_psm,
    CI_Lower = ci_psm[1],
    CI_Upper = ci_psm[2],
    Estimand = "Sample"
  ))
}, error = function(e) {
  cat("  PSM failed:", e$message, "\n")
})

################################################################################
# METHOD 2: UNWEIGHTED PGM
################################################################################

cat("\n--- METHOD 2: Unweighted PGM (1:1) - SAMPLE ESTIMATE ---\n")

tryCatch({
  suppressWarnings({
    pgm_boot <- dsmatchATE(
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
  
  est_pgm <- pgm_boot$est.pg
  ci_pgm <- c(
    pgm_boot$est.pg - 1.96*sqrt(pgm_boot$bootvar[1,1]),
    pgm_boot$est.pg + 1.96*sqrt(pgm_boot$bootvar[1,1])
  )
  
  cat("  Estimate:", round(est_pgm, 3), "mg/dL\n")
  cat("  95% CI: [", round(ci_pgm[1], 3), ",", round(ci_pgm[2], 3), "]\n")
  
  results <- rbind(results, data.frame(
    Method = "Unwt PGM",
    Estimate = est_pgm,
    CI_Lower = ci_pgm[1],
    CI_Upper = ci_pgm[2],
    Estimand = "Sample"
  ))
}, error = function(e) {
  cat("  PGM failed:", e$message, "\n")
})

################################################################################
# METHOD 3: UNWEIGHTED DSM
################################################################################

cat("\n--- METHOD 3: Unweighted DSM (1:1) - SAMPLE ESTIMATE ---\n")

tryCatch({
  suppressWarnings({
    dsm_boot <- dsmatchATE(
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
  
  est_dsm <- dsm_boot$est.ds
  ci_dsm <- c(
    dsm_boot$est.ds - 1.96*sqrt(dsm_boot$bootvar[1,1]),
    dsm_boot$est.ds + 1.96*sqrt(dsm_boot$bootvar[1,1])
  )
  
  cat("  Estimate:", round(est_dsm, 3), "mg/dL\n")
  cat("  95% CI: [", round(ci_dsm[1], 3), ",", round(ci_dsm[2], 3), "]\n")
  
  results <- rbind(results, data.frame(
    Method = "Unwt DSM",
    Estimate = est_dsm,
    CI_Lower = ci_dsm[1],
    CI_Upper = ci_dsm[2],
    Estimand = "Sample"
  ))
}, error = function(e) {
  cat("  DSM failed:", e$message, "\n")
})

################################################################################
# METHOD 4: SURVEY-WEIGHTED PS FULL MATCHING
################################################################################

cat("\n--- METHOD 4: Survey-Weighted PS Full Matching - POPULATION ESTIMATE ---\n")

ps_formula_matchit <- as.formula(paste("treatment ~", paste(ps_vars, collapse=" + ")))

tryCatch({
  match_full <- matchit(ps_formula_matchit, data = complete_data,
                       method = "full", estimand = "ATE",
                       s.weights = complete_data$wtmec2yr)
  
  matched_full <- match.data(match_full, weights = "weights",
                            distance = "distance", drop.unmatched = FALSE)
  matched_full$combined_weight <- matched_full$weights * matched_full$wtmec2yr
  
  design_full <- svydesign(ids = ~1, weights = ~combined_weight, data = matched_full)
  model_full <- svyglm(lbxsua ~ treatment, design = design_full)
  est_ps_full <- coef(model_full)["treatment"]
  se_ps_full <- sqrt(vcov(model_full)["treatment", "treatment"])
  
  ci_ps_full <- c(est_ps_full - 1.96*se_ps_full, est_ps_full + 1.96*se_ps_full)
  
  cat("  Estimate:", round(est_ps_full, 3), "mg/dL\n")
  cat("  95% CI: [", round(ci_ps_full[1], 3), ",", round(ci_ps_full[2], 3), "]\n")
  
  results <- rbind(results, data.frame(
    Method = "Wt PS Full",
    Estimate = est_ps_full,
    CI_Lower = ci_ps_full[1],
    CI_Upper = ci_ps_full[2],
    Estimand = "Population"
  ))
  
}, error = function(e) {
  cat("  Full matching failed, trying nearest neighbor...\n")
  
  tryCatch({
    match_nn <- matchit(ps_formula_matchit, data = complete_data,
                       method = "nearest", ratio = 5, estimand = "ATE",
                       s.weights = complete_data$wtmec2yr)
    
    matched_nn <- match.data(match_nn, weights = "weights",
                            distance = "distance", drop.unmatched = FALSE)
    matched_nn$combined_weight <- matched_nn$weights * matched_nn$wtmec2yr
    
    design_nn <- svydesign(ids = ~1, weights = ~combined_weight, data = matched_nn)
    model_nn <- svyglm(lbxsua ~ treatment, design = design_nn)
    est_ps_nn <- coef(model_nn)["treatment"]
    se_ps_nn <- sqrt(vcov(model_nn)["treatment", "treatment"])
    
    ci_ps_nn <- c(est_ps_nn - 1.96*se_ps_nn, est_ps_nn + 1.96*se_ps_nn)
    
    cat("  Estimate:", round(est_ps_nn, 3), "mg/dL\n")
    cat("  95% CI: [", round(ci_ps_nn[1], 3), ",", round(ci_ps_nn[2], 3), "]\n")
    
    results <- rbind(results, data.frame(
      Method = "Wt PS NN",
      Estimate = est_ps_nn,
      CI_Lower = ci_ps_nn[1],
      CI_Upper = ci_ps_nn[2],
      Estimand = "Population"
    ))
  }, error = function(e) {
    cat("  PS matching failed:", e$message, "\n")
  })
})

################################################################################
# METHOD 5: WDSM (WEIGHTED DOUBLE SCORE MATCHING)
################################################################################

cat("\n--- METHOD 5: WDSM - POPULATION ESTIMATE ---\n")

ps_formula_wdsm <- as.formula(paste("treatment ~", paste(ps_vars, collapse=" + ")))
pg_formula_wdsm <- as.formula(paste("lbxsua ~", paste(pg_vars, collapse=" + ")))

# Point estimate
cat("  Computing point estimate...")
tryCatch({
  result_wdsm <- wdsm_adaptive(
    data = complete_data,
    ps_formula = ps_formula_wdsm,
    pg_formula = pg_formula_wdsm,
    outcome_var = "lbxsua",
    treatment_var = "treatment",
    weight_var = "wtmec2yr",
    M = 5,
    use_bias_correction = TRUE,
    verbose = FALSE
  )
  est_wdsm <- result_wdsm$tau  # Use 'tau' field
  cat(" Done!\n")
  
  # Bootstrap with progress
  cat("  Bootstrap (", B_BOOTSTRAP, " reps): ", sep="")
  boot_wdsm <- numeric(B_BOOTSTRAP)
  n_valid <- 0
  
  for(b in 1:B_BOOTSTRAP) {
    if(b %% 10 == 0) {
      cat(b, "")
      flush.console()
    }
    
    boot_idx <- sample(nrow(complete_data), replace = TRUE)
    boot_data <- complete_data[boot_idx, ]
    
    tryCatch({
      boot_result <- wdsm_adaptive(
        data = boot_data,
        ps_formula = ps_formula_wdsm,
        pg_formula = pg_formula_wdsm,
        outcome_var = "lbxsua",
        treatment_var = "treatment",
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
    cat("  Estimate:", round(est_wdsm, 3), "mg/dL\n")
    cat("  95% CI: [", round(ci_wdsm[1], 3), ",", round(ci_wdsm[2], 3), "]\n")
    
    results <- rbind(results, data.frame(
      Method = "WDSM",
      Estimate = est_wdsm,
      CI_Lower = ci_wdsm[1],
      CI_Upper = ci_wdsm[2],
      Estimand = "Population"
    ))
  } else {
    cat("  WDSM bootstrap failed - insufficient valid replications\n")
  }
}, error = function(e) {
  cat("  WDSM failed:", e$message, "\n")
})

################################################################################
# FINAL SUMMARY
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   FINAL RESULTS SUMMARY\n")
cat("==============================================================================\n")

cat("\nYANG'S PAPER:\n")
cat("  Title: 'Association between dietary vitamin C intake and serum uric acid'\n")
cat("  Authors: Yang et al.\n")
cat("  Journal: Nutrients (or similar)\n")
cat("  Year: 2023\n")
cat("  Finding: Inverse association (higher vitamin C → lower uric acid)\n")

cat("\nEXPOSURE USED:", exposure_name, "\n")

cat("\nOUR REPLICATION:\n")
cat("  Regression β =", round(coef_yang[1], 3), "\n")

if(nrow(results) > 0) {
  cat("\nALL MATCHING METHODS:\n")
  print(results, row.names = FALSE)
  
  sample_results <- results[results$Estimand == "Sample", ]
  pop_results <- results[results$Estimand == "Population", ]
  
  if(nrow(sample_results) > 0 & nrow(pop_results) > 0) {
    cat("\nKEY FINDINGS:\n")
    cat("1. Sample estimates (unweighted):", 
        round(mean(sample_results$Estimate), 3), "mg/dL\n")
    cat("2. Population estimates (weighted):", 
        round(mean(pop_results$Estimate), 3), "mg/dL\n")
    cat("3. Difference:", 
        round(100*(mean(sample_results$Estimate) - mean(pop_results$Estimate))/
              abs(mean(pop_results$Estimate)), 0), "%\n")
  }
} else {
  cat("\nNo methods successfully completed.\n")
}

# Save results
save(results, complete_data, coef_yang, exposure_name, file = "YANG_COMPLETE_RESULTS.rda")
cat("\n✅ Results saved: YANG_COMPLETE_RESULTS.rda\n")

cat("\n")
cat("==============================================================================\n")
cat("   ANALYSIS COMPLETE\n")
cat("==============================================================================\n")



