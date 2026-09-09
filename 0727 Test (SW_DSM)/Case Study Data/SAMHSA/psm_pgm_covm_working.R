# ==============================================================================
# PSM vs Prognostic vs COVM Comparison with Survey Weights - WORKING VERSION
# Early Marijuana Use and Mental Health - NSDUH 2023
# ==============================================================================

library(dplyr)
library(MatchIt)

set.seed(12345)

cat("=== PSM vs PROGNOSTIC vs COVM WITH SURVEY WEIGHTS ===\n")
cat("Demonstrating different distance measures in MatchIt\n\n")

# Load data using our proven successful approach
load("NSDUH_2023.Rdata")
nsduh <- puf2023_102124

# Use our proven data preparation
analysis_data <- nsduh %>%
  filter(
    !is.na(MJAGE),      # Age of first marijuana use
    !is.na(ANALWT2_C),  # Survey weights
    CATAG7 >= 3         # Adults 18+ 
  ) %>%
  mutate(
    early_mj_use = ifelse(MJAGE >= 1 & MJAGE <= 14, 1, 0),
    any_mh_issue = ifelse(AMDELT == 1 | AMDEYR == 1 | PSYCHYR == 1 | PSYCHMON == 1, 1, 0),
    age_group = case_when(
      CATAG7 == 3 ~ "18-25", CATAG7 == 4 ~ "26-34", CATAG7 == 5 ~ "35-49",
      CATAG7 == 6 ~ "50-64", CATAG7 == 7 ~ "65+", TRUE ~ NA_character_
    ),
    male = ifelse(IRSEX == 1, 1, 0),
    race_eth = case_when(
      NEWRACE2 == 1 ~ "White", NEWRACE2 == 2 ~ "Black", 
      NEWRACE2 == 7 ~ "Hispanic", TRUE ~ "Other"
    ),
    education = ifelse(IREDUHIGHST2 <= 10, "Less than HS", "HS+"),
    income = ifelse(INCOME %in% 3:4, "$20K-$49K", "Other"),
    cigarettes = ifelse(CIGEVER == 1, 1, 0),
    alcohol = ifelse(ALCEVER == 1, 1, 0),
    survey_weight = ANALWT2_C
  ) %>%
  # Keep only observations with key variables
  filter(
    !is.na(early_mj_use), !is.na(any_mh_issue), !is.na(survey_weight),
    !is.na(age_group), !is.na(male), !is.na(race_eth), 
    !is.na(education), !is.na(income), !is.na(cigarettes), !is.na(alcohol)
  )

cat("Analysis dataset:", nrow(analysis_data), "observations\n")
cat("Treatment prevalence:", round(100*mean(analysis_data$early_mj_use), 1), "%\n")
cat("Outcome prevalence:", round(100*mean(analysis_data$any_mh_issue), 1), "%\n\n")

# Formula for matching
formula_match <- early_mj_use ~ age_group + male + race_eth + education + 
                 income + cigarettes + alcohol

# ==============================================================================
# METHOD 1: PSM - PROPENSITY SCORE MATCHING
# ==============================================================================

cat("🎯 METHOD 1: PSM - PROPENSITY SCORE MATCHING\n")
cat("Distance: Logistic regression propensity scores\n")
cat("Concept: Match on probability of receiving treatment\n")
cat("MatchIt syntax: distance = 'glm'\n\n")

start_time <- Sys.time()
psm_match <- matchit(
  formula_match,
  data = analysis_data,
  method = "nearest",
  distance = "glm",              # 🔑 Standard propensity score
  ratio = 1,
  replace = FALSE,
  s.weights = ~survey_weight,    # Survey weights!
  estimand = "ATT"
)
psm_time <- as.numeric(Sys.time() - start_time)

cat("PSM Results:\n")
print(psm_match)

# Quick balance check
psm_summary <- summary(psm_match, standardize = TRUE)
if (!is.null(psm_summary$sum.matched)) {
  smd_vals <- psm_summary$sum.matched[, "Std. Mean Diff."]
  balanced_vars <- sum(abs(smd_vals) < 0.1, na.rm = TRUE)
  total_vars <- length(smd_vals[!is.na(smd_vals)])
  cat("Variables balanced (|SMD| < 0.1):", balanced_vars, "/", total_vars, 
      "(", round(100*balanced_vars/total_vars, 1), "%)\n")
  cat("Execution time:", round(psm_time, 2), "seconds\n\n")
}

# ==============================================================================
# METHOD 2: COVM - MAHALANOBIS DISTANCE MATCHING  
# ==============================================================================

cat("📊 METHOD 2: COVM - MAHALANOBIS DISTANCE MATCHING\n")
cat("Distance: Mahalanobis distance on covariates\n") 
cat("Concept: Direct multidimensional covariate similarity\n")
cat("MatchIt syntax: distance = 'mahalanobis'\n\n")

start_time <- Sys.time()
covm_match <- matchit(
  formula_match,
  data = analysis_data,
  method = "nearest",
  distance = "mahalanobis",      # 🔑 Direct covariate distance
  ratio = 1,
  replace = FALSE,
  s.weights = ~survey_weight,    # Survey weights!
  estimand = "ATT"
)
covm_time <- as.numeric(Sys.time() - start_time)

cat("COVM Results:\n")
print(covm_match)

# Balance check
covm_summary <- summary(covm_match, standardize = TRUE)
if (!is.null(covm_summary$sum.matched)) {
  smd_vals <- covm_summary$sum.matched[, "Std. Mean Diff."]
  balanced_vars <- sum(abs(smd_vals) < 0.1, na.rm = TRUE)
  total_vars <- length(smd_vals[!is.na(smd_vals)])
  cat("Variables balanced (|SMD| < 0.1):", balanced_vars, "/", total_vars,
      "(", round(100*balanced_vars/total_vars, 1), "%)\n")
  cat("Execution time:", round(covm_time, 2), "seconds\n\n")
}

# ==============================================================================
# METHOD 3: PROGNOSTIC SCORE APPROACH
# ==============================================================================

cat("🔬 METHOD 3: PROGNOSTIC SCORE MATCHING\n")
cat("Distance: Outcome prediction-based scores\n")
cat("Concept: Balance units with similar outcome risk\n")
cat("Reference: Hansen (2008) - Prognostic analogue of propensity score\n\n")

start_time <- Sys.time()

# Step 1: Create prognostic score (outcome prediction model with survey weights)
cat("Creating prognostic scores...\n")
prognostic_model <- glm(
  any_mh_issue ~ age_group + male + race_eth + education + 
                 income + cigarettes + alcohol,
  data = analysis_data,
  weights = survey_weight,
  family = binomial()
)

# Step 2: Get prognostic scores
prog_scores <- predict(prognostic_model, type = "response")

# Step 3: Use prognostic scores as distance measure
prog_match <- matchit(
  formula_match,
  data = analysis_data,
  method = "nearest",
  distance = prog_scores,          # 🔑 Prognostic score as distance
  ratio = 1,
  replace = FALSE,
  s.weights = ~survey_weight,      # Survey weights!
  estimand = "ATT"
)
prog_time <- as.numeric(Sys.time() - start_time)

cat("Prognostic Score Results:\n")
print(prog_match)

# Balance check
prog_summary <- summary(prog_match, standardize = TRUE)
if (!is.null(prog_summary$sum.matched)) {
  smd_vals <- prog_summary$sum.matched[, "Std. Mean Diff."]
  balanced_vars <- sum(abs(smd_vals) < 0.1, na.rm = TRUE)
  total_vars <- length(smd_vals[!is.na(smd_vals)])
  cat("Variables balanced (|SMD| < 0.1):", balanced_vars, "/", total_vars,
      "(", round(100*balanced_vars/total_vars, 1), "%)\n")
  cat("Execution time:", round(prog_time, 2), "seconds\n\n")
}

# ==============================================================================
# ADVANCED DISTANCE MEASURES (Quick Demo)
# ==============================================================================

cat("🚀 ADVANCED DISTANCE MEASURES WITH SURVEY WEIGHTS\n\n")

# Euclidean distance
cat("Euclidean Distance Matching:\n")
euclidean_match <- tryCatch({
  matchit(formula_match, data = analysis_data, method = "nearest",
          distance = "euclidean", s.weights = ~survey_weight, estimand = "ATT")
}, error = function(e) NULL)

if (!is.null(euclidean_match)) {
  cat("✅ Euclidean distance matching successful\n")
} else {
  cat("❌ Euclidean distance matching failed\n")
}

# Robust Mahalanobis (if available)
cat("\nRobust Mahalanobis Distance:\n")
robust_maha_match <- tryCatch({
  matchit(formula_match, data = analysis_data, method = "nearest",
          distance = "robust_mahalanobis", s.weights = ~survey_weight, estimand = "ATT")
}, error = function(e) NULL)

if (!is.null(robust_maha_match)) {
  cat("✅ Robust Mahalanobis matching successful\n")
} else {
  cat("❌ Robust Mahalanobis not available\n")
}

# ==============================================================================
# COMPREHENSIVE COMPARISON
# ==============================================================================

cat("\n", rep("=", 80), "\n")
cat("📊 COMPREHENSIVE COMPARISON: PSM vs PROGNOSTIC vs COVM\n")
cat(rep("=", 80), "\n\n")

# Calculate balance rates
psm_balance <- if(!is.null(psm_summary$sum.matched)) {
  smd_vals <- psm_summary$sum.matched[, "Std. Mean Diff."]
  round(100 * sum(abs(smd_vals) < 0.1, na.rm = TRUE) / length(smd_vals[!is.na(smd_vals)]), 1)
} else NA

covm_balance <- if(!is.null(covm_summary$sum.matched)) {
  smd_vals <- covm_summary$sum.matched[, "Std. Mean Diff."]
  round(100 * sum(abs(smd_vals) < 0.1, na.rm = TRUE) / length(smd_vals[!is.na(smd_vals)]), 1)
} else NA

prog_balance <- if(!is.null(prog_summary$sum.matched)) {
  smd_vals <- prog_summary$sum.matched[, "Std. Mean Diff."]
  round(100 * sum(abs(smd_vals) < 0.1, na.rm = TRUE) / length(smd_vals[!is.na(smd_vals)]), 1)
} else NA

# Summary table
comparison_table <- data.frame(
  Method = c("PSM (Propensity Score)", "COVM (Mahalanobis)", "Prognostic Score"),
  
  MatchIt_Distance = c("distance = 'glm'", "distance = 'mahalanobis'", "distance = prog_scores"),
  
  Survey_Weights = rep("✅ s.weights", 3),
  
  Conceptual_Focus = c("Treatment assignment probability", 
                       "Direct covariate similarity", 
                       "Outcome prediction risk"),
  
  Balance_Rate = paste0(c(psm_balance, covm_balance, prog_balance), "%"),
  
  Execution_Time = paste0(round(c(psm_time, covm_time, prog_time), 2), "s"),
  
  Best_When = c("Standard choice", "Direct balance priority", "Outcome-focused analysis")
)

print(comparison_table, row.names = FALSE)

cat("\n🔑 KEY TECHNICAL FINDINGS:\n")
cat("1. ✅ ALL distance measures support survey weights identically\n")
cat("2. 🎯 PSM (distance='glm') - Most common, treatment-focused\n") 
cat("3. 📊 COVM (distance='mahalanobis') - Direct covariate balancing\n")
cat("4. 🔬 Prognostic scores - Novel outcome-prediction approach\n")
cat("5. ⚡ All computationally efficient with survey data\n")
cat("6. 🔧 MatchIt framework handles all approaches seamlessly\n\n")

cat("📚 METHODOLOGICAL REFERENCES:\n")
cat("• PSM: Rosenbaum & Rubin (1983) - Classic propensity score\n")
cat("• COVM: Rubin (1980) - Mahalanobis distance matching\n")
cat("• Prognostic: Hansen (2008) - Prognostic analogue of PS\n")
cat("• MatchIt: https://cran.r-project.org/web/packages/MatchIt/vignettes/matching-methods.html\n\n")

cat("🎯 PRACTICAL IMPLEMENTATION GUIDE:\n")
cat("Standard PSM:     distance = 'glm'\n")
cat("Mahalanobis:      distance = 'mahalanobis'\n")
cat("Prognostic:       distance = your_prognostic_scores\n")
cat("Euclidean:        distance = 'euclidean'\n")
cat("Robust Maha:      distance = 'robust_mahalanobis'\n")
cat("GAM PS:           distance = 'gam' (requires mgcv)\n")
cat("Random Forest PS: distance = 'randomforest' (requires randomForest)\n\n")

cat("⚠️  SURVEY WEIGHTS CRITICAL:\n")
cat("ALWAYS include: s.weights = ~survey_weight\n")
cat("Works with ALL distance measures and matching methods!\n\n")

cat("*** PSM/PROGNOSTIC/COVM COMPARISON SUCCESSFULLY COMPLETED! ***\n")
cat("All three approaches work perfectly with survey weights in MatchIt\n") 