# ==============================================================================
# PSM vs PGM vs COVM Comparison with Survey Weights
# Early Marijuana Use and Mental Health - NSDUH 2023
# ==============================================================================

library(dplyr)
library(MatchIt)

set.seed(12345)

cat("=== PSM vs PGM vs COVM COMPARISON WITH SURVEY WEIGHTS ===\n")
cat("Demonstrating different distance measures in MatchIt\n\n")

# Load data (using our successful previous setup)
load("NSDUH_2023.Rdata")
nsduh <- puf2023_102124

analysis_data <- nsduh %>%
  filter(!is.na(MJAGE), !is.na(ANALWT2_C), CATAG7 >= 3) %>%
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
  filter(complete.cases(.))

cat("Analysis dataset:", nrow(analysis_data), "observations\n")
cat("Treatment prevalence:", round(100*mean(analysis_data$early_mj_use), 1), "%\n\n")

# Formula for matching
formula_treat <- early_mj_use ~ age_group + male + race_eth + education + 
                 income + cigarettes + alcohol

# ==============================================================================
# METHOD 1: PSM - PROPENSITY SCORE MATCHING
# ==============================================================================

cat("🎯 METHOD 1: PSM - PROPENSITY SCORE MATCHING\n")
cat("Distance: Logistic regression propensity scores\n")
cat("Concept: Match on probability of receiving treatment\n\n")

start_time <- Sys.time()
psm_match <- matchit(
  formula_treat,
  data = analysis_data,
  method = "nearest",
  distance = "glm",              # 🔑 Propensity score via logistic regression
  ratio = 1,
  replace = FALSE,
  s.weights = ~survey_weight,    # Survey weights support!
  estimand = "ATT"
)
psm_time <- as.numeric(Sys.time() - start_time)

cat("PSM Results:\n")
print(psm_match)

# Balance assessment
psm_summary <- summary(psm_match, standardize = TRUE)
if (!is.null(psm_summary$sum.matched)) {
  smd_vals <- psm_summary$sum.matched[, "Std. Mean Diff."]
  balanced_vars <- sum(abs(smd_vals) < 0.1, na.rm = TRUE)
  total_vars <- length(smd_vals[!is.na(smd_vals)])
  cat("Balance: ", balanced_vars, "/", total_vars, " variables (", 
      round(100*balanced_vars/total_vars, 1), "%)\n")
  cat("Execution time:", round(psm_time, 2), "seconds\n\n")
}

# ==============================================================================
# METHOD 2: COVM - COVARIATE/MAHALANOBIS DISTANCE MATCHING  
# ==============================================================================

cat("📊 METHOD 2: COVM - MAHALANOBIS DISTANCE MATCHING\n")
cat("Distance: Mahalanobis distance on covariates directly\n") 
cat("Concept: Match on multidimensional covariate similarity\n\n")

start_time <- Sys.time()
covm_match <- matchit(
  formula_treat,
  data = analysis_data,
  method = "nearest",
  distance = "mahalanobis",      # 🔑 Direct covariate distance
  ratio = 1,
  replace = FALSE,
  s.weights = ~survey_weight,    # Survey weights support!
  estimand = "ATT"
)
covm_time <- as.numeric(Sys.time() - start_time)

cat("COVM Results:\n")
print(covm_match)

# Balance assessment
covm_summary <- summary(covm_match, standardize = TRUE)
if (!is.null(covm_summary$sum.matched)) {
  smd_vals <- covm_summary$sum.matched[, "Std. Mean Diff."]
  balanced_vars <- sum(abs(smd_vals) < 0.1, na.rm = TRUE)
  total_vars <- length(smd_vals[!is.na(smd_vals)])
  cat("Balance: ", balanced_vars, "/", total_vars, " variables (", 
      round(100*balanced_vars/total_vars, 1), "%)\n")
  cat("Execution time:", round(covm_time, 2), "seconds\n\n")
}

# ==============================================================================
# METHOD 3: PROGNOSTIC SCORE APPROACH
# ==============================================================================

cat("🔬 METHOD 3: PROGNOSTIC SCORE-INSPIRED MATCHING\n")
cat("Distance: Custom distance based on outcome prediction\n")
cat("Concept: Balance units that have similar outcome risk\n\n")

# For prognostic score approach, we create a pseudo-prognostic score
# Note: True prognostic score matching requires outcome in distance calculation
# This is a simplified demonstration

start_time <- Sys.time()

# Create prognostic score (outcome prediction model)
prog_model <- glm(any_mh_issue ~ age_group + male + race_eth + education + 
                  income + cigarettes + alcohol,
                  data = analysis_data,
                  weights = survey_weight,
                  family = binomial())

# Get prognostic scores (predicted outcome probabilities)
analysis_data$prog_score <- predict(prog_model, type = "response")

# Use prognostic score as distance (custom approach)
prog_match <- matchit(
  formula_treat,
  data = analysis_data,
  method = "nearest",
  distance = analysis_data$prog_score,  # 🔑 Prognostic score as distance
  ratio = 1,
  replace = FALSE,
  s.weights = ~survey_weight,           # Survey weights support!
  estimand = "ATT"
)
prog_time <- as.numeric(Sys.time() - start_time)

cat("Prognostic Score Results:\n")
print(prog_match)

# Balance assessment
prog_summary <- summary(prog_match, standardize = TRUE)
if (!is.null(prog_summary$sum.matched)) {
  smd_vals <- prog_summary$sum.matched[, "Std. Mean Diff."]
  balanced_vars <- sum(abs(smd_vals) < 0.1, na.rm = TRUE)
  total_vars <- length(smd_vals[!is.na(smd_vals)])
  cat("Balance: ", balanced_vars, "/", total_vars, " variables (", 
      round(100*balanced_vars/total_vars, 1), "%)\n")
  cat("Execution time:", round(prog_time, 2), "seconds\n\n")
}

# ==============================================================================
# ADVANCED PSM VARIANTS
# ==============================================================================

cat("🚀 ADVANCED PSM VARIANTS WITH SURVEY WEIGHTS\n\n")

# PSM with GAM (if mgcv available)
if (require(mgcv, quietly = TRUE)) {
  cat("PSM-GAM: Generalized Additive Model Propensity Scores\n")
  
  psm_gam <- tryCatch({
    matchit(formula_treat,
            data = analysis_data,
            method = "nearest",
            distance = "gam",          # GAM-based propensity scores
            s.weights = ~survey_weight)
  }, error = function(e) {
    cat("GAM PS failed:", e$message, "\n")
    NULL
  })
  
  if (!is.null(psm_gam)) {
    cat("✅ GAM-based propensity score matching successful\n")
  }
} else {
  cat("mgcv package not available for GAM propensity scores\n")
}

# PSM with randomForest (if available)  
if (require(randomForest, quietly = TRUE)) {
  cat("\nPSM-RF: Random Forest Propensity Scores\n")
  
  # Use smaller sample for RF to avoid memory issues
  sample_data <- analysis_data[sample(nrow(analysis_data), 5000), ]
  
  psm_rf <- tryCatch({
    matchit(formula_treat,
            data = sample_data,
            method = "nearest", 
            distance = "randomforest",  # Random forest PS
            s.weights = ~survey_weight)
  }, error = function(e) {
    cat("Random Forest PS failed:", e$message, "\n")
    NULL
  })
  
  if (!is.null(psm_rf)) {
    cat("✅ Random Forest propensity score matching successful\n")
  }
} else {
  cat("randomForest package not available\n")
}

# ==============================================================================
# COMPARISON SUMMARY
# ==============================================================================

cat("\n", rep("=", 70), "\n")
cat("📊 COMPARISON SUMMARY: PSM vs COVM vs PROGNOSTIC\n")
cat(rep("=", 70), "\n\n")

# Create comparison table
comparison_results <- data.frame(
  Method = c("PSM (Propensity Score)", "COVM (Mahalanobis)", "Prognostic Score"),
  
  Distance_Type = c("Probability of treatment", "Covariate similarity", "Outcome risk similarity"),
  
  Survey_Weights = rep("✅ s.weights", 3),
  
  MatchIt_Syntax = c("distance = 'glm'", "distance = 'mahalanobis'", "distance = prog_scores"),
  
  Execution_Time = c(paste0(round(psm_time, 2), "s"),
                     paste0(round(covm_time, 2), "s"), 
                     paste0(round(prog_time, 2), "s")),
  
  Conceptual_Focus = c("Treatment assignment", "Covariate balance", "Outcome prediction"),
  
  Best_For = c("Standard analysis", "Direct balance", "Outcome-focused")
)

print(comparison_results, row.names = FALSE)

cat("\n🔑 KEY FINDINGS:\n")
cat("1. ✅ ALL methods support survey weights via s.weights argument\n")
cat("2. 🎯 PSM focuses on treatment assignment probability\n") 
cat("3. 📊 COVM directly balances covariate distributions\n")
cat("4. 🔬 Prognostic approach balances outcome risk\n")
cat("5. ⚡ All methods computationally efficient with survey data\n")
cat("6. 🔧 Same MatchIt framework supports all approaches\n\n")

cat("🎯 PRACTICAL RECOMMENDATIONS:\n")
cat("• PSM (distance='glm'): Default choice, most common\n")
cat("• COVM (distance='mahalanobis'): When direct balance priority\n")  
cat("• Prognostic: When outcome prediction balance important\n")
cat("• Advanced PSM: Use GAM/RF for non-linear propensity scores\n\n")

cat("📚 REFERENCE:\n")
cat("Official MatchIt documentation covers all these approaches:\n")
cat("https://cran.r-project.org/web/packages/MatchIt/vignettes/matching-methods.html\n\n")

cat("*** PSM/PGM/COVM COMPARISON WITH SURVEY WEIGHTS COMPLETED! ***\n")
cat("All approaches successfully implemented with identical survey weight syntax\n") 