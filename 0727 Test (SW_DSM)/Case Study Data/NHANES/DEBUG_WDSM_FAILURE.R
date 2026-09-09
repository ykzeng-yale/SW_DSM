################################################################################
# DEBUG: Why is WDSM failing for Chen analysis?
# Test each component separately
################################################################################

rm(list = ls())
library(dplyr)
library(haven)

# Load WDSM
source("WDSM_adaptive.R")

# Load data
load("data/nhanes_2007_2018.rda")

cat("\n")
cat("==============================================================================\n")
cat("   DEBUGGING WDSM FAILURE\n")
cat("==============================================================================\n")

# Prepare data exactly as in the main script
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

adults <- nhanes_clean %>% filter(age >= 20)
adults$bmi_cat <- cut(adults$bmi,
                      breaks = c(-Inf, 18.5, 25, 30, Inf),
                      labels = c("Underweight", "Normal", "Overweight", "Obese"))

# Core variables
core_vars <- c("age", "race1", "pir", "education", "egfr", "lbxscr", "lbxtc", "lbxsph")
available_vars <- core_vars[core_vars %in% names(adults)]

# Filter to women with O vs U
analysis_vars <- c("lbxsua", "bmi_cat", "female", "wtmec2yr", available_vars)
complete_data <- adults %>%
  filter(complete.cases(.[analysis_vars]),
         female == 1,
         bmi_cat %in% c("Underweight", "Obese"))

complete_data$obese <- as.numeric(complete_data$bmi_cat == "Obese")

cat("Sample size:", nrow(complete_data), "\n")
cat("Obese:", sum(complete_data$obese), "\n")
cat("Underweight:", sum(complete_data$obese == 0), "\n")
cat("Ratio:", round(sum(complete_data$obese)/sum(complete_data$obese == 0), 1), ":1\n\n")

# Check data issues
cat("--- DATA CHECK ---\n")
cat("Any NA in outcome?", any(is.na(complete_data$lbxsua)), "\n")
cat("Any NA in treatment?", any(is.na(complete_data$obese)), "\n")
cat("Any NA in weights?", any(is.na(complete_data$wtmec2yr)), "\n")
cat("Weight range:", range(complete_data$wtmec2yr), "\n")
cat("Outcome range:", range(complete_data$lbxsua), "\n")

################################################################################
# TEST 1: Propensity Score Model
################################################################################
cat("\n--- TEST 1: PROPENSITY SCORE MODEL ---\n")

ps_vars <- c("age", "race1")
ps_formula <- as.formula(paste("obese ~", paste(ps_vars, collapse=" + ")))

# Fit PS model
ps_model <- glm(ps_formula, data = complete_data, family = binomial)
cat("PS model converged?", ps_model$converged, "\n")

# Check PS values
ps_values <- predict(ps_model, type = "response")
cat("PS range:", range(ps_values), "\n")
cat("PS near 0 or 1?", sum(ps_values < 0.01 | ps_values > 0.99), "cases\n")

# Problem if PS extreme?
if(any(ps_values < 0.001 | ps_values > 0.999)) {
  cat("⚠️ WARNING: Extreme propensity scores detected!\n")
  cat("  Min PS:", min(ps_values), "\n")
  cat("  Max PS:", max(ps_values), "\n")
}

################################################################################
# TEST 2: Prognostic Score Model
################################################################################
cat("\n--- TEST 2: PROGNOSTIC SCORE MODEL ---\n")

pg_vars <- available_vars
pg_formula <- as.formula(paste("lbxsua ~", paste(pg_vars, collapse=" + ")))

# Fit PG model on controls only
control_data <- complete_data[complete_data$obese == 0, ]
cat("N controls for PG model:", nrow(control_data), "\n")

pg_model <- lm(pg_formula, data = control_data)
cat("PG model R-squared:", summary(pg_model)$r.squared, "\n")

# Check PG predictions
pg_values <- predict(pg_model, newdata = complete_data)
cat("PG range:", range(pg_values), "\n")
cat("Any NA in PG?", any(is.na(pg_values)), "\n")

################################################################################
# TEST 3: Simple WDSM Call
################################################################################
cat("\n--- TEST 3: SIMPLE WDSM CALL ---\n")

# Try with minimal arguments
tryCatch({
  result <- wdsm_adaptive(
    data = complete_data,
    ps_formula = ps_formula,
    pg_formula = pg_formula,
    outcome_var = "lbxsua",
    treatment_var = "obese",
    weight_var = "wtmec2yr",
    M = 1,  # Just 1:1 matching
    use_bias_correction = FALSE,  # Skip bias correction
    verbose = TRUE  # Show what's happening
  )
  
  if(!is.null(result$estimate)) {
    cat("✅ WDSM succeeded! Estimate:", result$estimate, "\n")
  } else {
    cat("❌ WDSM returned NULL estimate\n")
  }
  
}, error = function(e) {
  cat("❌ WDSM FAILED with error:\n")
  cat("  ", e$message, "\n")
})

################################################################################
# TEST 4: Manual Double Score Calculation
################################################################################
cat("\n--- TEST 4: MANUAL DOUBLE SCORE TEST ---\n")

# Calculate scores manually
X_ps <- as.matrix(complete_data[, ps_vars])
X_pg <- as.matrix(complete_data[, pg_vars])

# Propensity scores
ps_manual <- predict(ps_model, type = "response")
logit_ps <- log(ps_manual / (1 - ps_manual))

# Prognostic scores
pg_manual <- predict(pg_model, newdata = complete_data)

# Combine scores
double_score <- cbind(logit_ps, pg_manual)
cat("Double score dimensions:", dim(double_score), "\n")
cat("Any NA in double score?", any(is.na(double_score)), "\n")

# Check for issues
if(any(is.infinite(logit_ps))) {
  cat("⚠️ Infinite logit PS values:", sum(is.infinite(logit_ps)), "\n")
  cat("  This happens when PS = 0 or 1\n")
}

################################################################################
# TEST 5: Weighted Standardization
################################################################################
cat("\n--- TEST 5: WEIGHTED STANDARDIZATION TEST ---\n")

# Try the standardization function directly
tryCatch({
  S_std <- standardize_with_weights(double_score, complete_data$wtmec2yr)
  cat("✅ Weighted standardization succeeded\n")
  cat("  Standardized score dimensions:", dim(S_std), "\n")
}, error = function(e) {
  cat("❌ Weighted standardization failed:\n")
  cat("  ", e$message, "\n")
  
  # Debug weighted covariance
  w <- complete_data$wtmec2yr
  S_mean <- colSums(double_score * w) / sum(w)
  S_centered <- double_score - matrix(S_mean, nrow(double_score), 2, byrow = TRUE)
  S_cov <- t(S_centered) %*% diag(w) %*% S_centered / sum(w)
  
  cat("\n  Covariance matrix:\n")
  print(S_cov)
  
  eigen_vals <- eigen(S_cov)$values
  cat("\n  Eigenvalues:", eigen_vals, "\n")
  
  if(any(eigen_vals <= 0)) {
    cat("  ⚠️ Non-positive eigenvalues - covariance matrix not positive definite!\n")
  }
})

################################################################################
# DIAGNOSIS
################################################################################
cat("\n")
cat("==============================================================================\n")
cat("   DIAGNOSIS\n")
cat("==============================================================================\n")

cat("Likely issues:\n")
cat("1. Extreme imbalance (20:1 ratio) → extreme PS values\n")
cat("2. Small control group (N=239) → unstable PG model\n")
cat("3. Extreme PS → infinite logit(PS) → standardization fails\n")

cat("\nSOLUTION: Try with PS truncation or different PS model\n")



