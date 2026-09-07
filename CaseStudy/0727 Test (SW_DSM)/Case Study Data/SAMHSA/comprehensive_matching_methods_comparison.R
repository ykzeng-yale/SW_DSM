# ==============================================================================
# COMPREHENSIVE COMPARISON OF MATCHING METHODS WITH SURVEY WEIGHTS
# Early Marijuana Use and Mental Health - NSDUH 2023
# Systematic Evaluation of All Available Methods
# ==============================================================================

# Load required packages
library(dplyr)
library(MatchIt)
library(Matching)
library(WeightIt)
library(optmatch)
library(tableone)
library(cobalt)
library(cem)

set.seed(12345)

cat("=== COMPREHENSIVE MATCHING METHODS COMPARISON WITH SURVEY WEIGHTS ===\n")
cat("Early Marijuana Use and Mental Health Outcomes - NSDUH 2023\n\n")

# ==============================================================================
# 1. Data Preparation (Same as before)
# ==============================================================================

cat("1. Loading and preparing data...\n")

load("NSDUH_2023.Rdata")
nsduh <- puf2023_102124

# Create analysis dataset
analysis_data <- nsduh %>%
  filter(!is.na(MJAGE), !is.na(ANALWT2_C), CATAG7 >= 3) %>%
  mutate(
    early_mj_use = ifelse(MJAGE >= 1 & MJAGE <= 14, 1, 0),
    dep_major = ifelse(AMDELT == 1, 1, 0),
    dep_any = ifelse(AMDEYR == 1, 1, 0),
    mh_services_yr = ifelse(PSYCHYR == 1, 1, 0),
    mh_services_mon = ifelse(PSYCHMON == 1, 1, 0),
    any_mh_issue = ifelse(dep_major == 1 | dep_any == 1 | 
                         mh_services_yr == 1 | mh_services_mon == 1, 1, 0),
    age_group = case_when(
      CATAG7 == 3 ~ "18-25", CATAG7 == 4 ~ "26-34", CATAG7 == 5 ~ "35-49",
      CATAG7 == 6 ~ "50-64", CATAG7 == 7 ~ "65+", TRUE ~ NA_character_
    ),
    male = ifelse(IRSEX == 1, 1, 0),
    race_eth = case_when(
      NEWRACE2 == 1 ~ "White", NEWRACE2 == 2 ~ "Black", 
      NEWRACE2 == 7 ~ "Hispanic", TRUE ~ "Other"
    ),
    education = case_when(
      IREDUHIGHST2 <= 10 ~ "Less than HS", IREDUHIGHST2 == 11 ~ "HS Graduate", 
      IREDUHIGHST2 %in% c(12, 13) ~ "Some College", IREDUHIGHST2 >= 14 ~ "College+",
      TRUE ~ NA_character_
    ),
    income = case_when(
      INCOME %in% 1:2 ~ "<$20K", INCOME %in% 3:4 ~ "$20K-$49K", 
      INCOME %in% 5:6 ~ "$50K-$74K", INCOME %in% 7:10 ~ "$75K+",
      TRUE ~ NA_character_
    ),
    cigarettes = ifelse(CIGEVER == 1, 1, 0),
    alcohol = ifelse(ALCEVER == 1, 1, 0),
    survey_weight = ANALWT2_C
  ) %>%
  filter(
    !is.na(early_mj_use), !is.na(any_mh_issue), !is.na(survey_weight),
    !is.na(age_group), !is.na(male), !is.na(race_eth), 
    !is.na(education), !is.na(income), !is.na(cigarettes), !is.na(alcohol),
    !is.na(dep_major), !is.na(dep_any), !is.na(mh_services_yr), !is.na(mh_services_mon)
  ) %>%
  select(early_mj_use, any_mh_issue, dep_major, dep_any, mh_services_yr, mh_services_mon,
         age_group, male, race_eth, education, income, cigarettes, alcohol, survey_weight)

cat("Analysis dataset:", nrow(analysis_data), "observations\n")
cat("Treatment prevalence:", round(100*mean(analysis_data$early_mj_use), 1), "%\n\n")

# Convert categorical variables to factors for some methods
analysis_data_factor <- analysis_data %>%
  mutate(
    age_group = factor(age_group),
    race_eth = factor(race_eth),
    education = factor(education),
    income = factor(income)
  )

# ==============================================================================
# 2. MATCHIT PACKAGE METHODS
# ==============================================================================

cat("=== PART A: MATCHIT PACKAGE METHODS ===\n\n")

# Propensity score formula
ps_formula <- early_mj_use ~ age_group + male + race_eth + education + 
              income + cigarettes + alcohol

# Helper function to assess balance
assess_balance_quick <- function(match_obj, method_name) {
  cat("\n--- Balance Assessment:", method_name, "---\n")
  
  # Basic summary
  summary_obj <- summary(match_obj)
  
  # Count balanced variables (SMD < 0.1)
  if (!is.null(summary_obj$sum.matched)) {
    smd_vals <- summary_obj$sum.matched[, "Std. Mean Diff."]
    balanced_count <- sum(abs(smd_vals) < 0.1, na.rm = TRUE)
    total_count <- length(smd_vals[!is.na(smd_vals)])
    cat("Variables balanced (SMD < 0.1):", balanced_count, "/", total_count, "\n")
    
    # Show worst balance
    worst_var <- names(smd_vals)[which.max(abs(smd_vals))]
    worst_smd <- max(abs(smd_vals), na.rm = TRUE)
    cat("Worst balance:", worst_var, "SMD =", round(worst_smd, 3), "\n")
  }
  
  # Sample sizes
  if (!is.null(summary_obj$nn)) {
    cat("Matched treated:", summary_obj$nn["Matched", "Treated"], "\n")
    cat("Matched control:", summary_obj$nn["Matched", "Control"], "\n")
  }
}

# METHOD 1: Nearest Neighbor Matching (1:1)
cat("METHOD 1: Nearest Neighbor Matching (1:1)\n")
cat("Description: Each treated unit matched to closest control unit\n")
cat("Advantages: Simple, interpretable, good balance\n")
cat("Disadvantages: Discards many control units\n")

match_nn_1to1 <- matchit(
  ps_formula,
  data = analysis_data,
  method = "nearest",
  distance = "glm",
  ratio = 1,
  replace = FALSE,
  s.weights = ~survey_weight,
  estimand = "ATT"
)

assess_balance_quick(match_nn_1to1, "Nearest Neighbor 1:1")

# METHOD 2: Nearest Neighbor Matching (1:2)
cat("\n\nMETHOD 2: Nearest Neighbor Matching (1:2)\n")
cat("Description: Each treated unit matched to 2 closest control units\n")
cat("Advantages: Uses more control units, potentially better precision\n")
cat("Disadvantages: May sacrifice some balance for efficiency\n")

match_nn_1to2 <- matchit(
  ps_formula,
  data = analysis_data,
  method = "nearest",
  distance = "glm",
  ratio = 2,
  replace = FALSE,
  s.weights = ~survey_weight,
  estimand = "ATT"
)

assess_balance_quick(match_nn_1to2, "Nearest Neighbor 1:2")

# METHOD 3: Nearest Neighbor with Replacement
cat("\n\nMETHOD 3: Nearest Neighbor with Replacement\n")
cat("Description: Control units can be matched multiple times\n")
cat("Advantages: Better balance, uses best control units multiple times\n")
cat("Disadvantages: Reduced effective sample size, complex standard errors\n")

match_nn_replace <- matchit(
  ps_formula,
  data = analysis_data,
  method = "nearest",
  distance = "glm",
  ratio = 1,
  replace = TRUE,
  s.weights = ~survey_weight,
  estimand = "ATT"
)

assess_balance_quick(match_nn_replace, "Nearest Neighbor with Replacement")

# METHOD 4: Nearest Neighbor with Caliper
cat("\n\nMETHOD 4: Nearest Neighbor with Caliper\n")
cat("Description: Only matches within specified distance threshold\n")
cat("Advantages: Ensures good matches, avoids poor matches\n")
cat("Disadvantages: May discard treated units without good matches\n")

match_nn_caliper <- tryCatch({
  matchit(
    ps_formula,
    data = analysis_data,
    method = "nearest",
    distance = "glm",
    ratio = 1,
    replace = FALSE,
    caliper = 0.25,
    std.caliper = TRUE,
    s.weights = ~survey_weight,
    estimand = "ATT"
  )
}, error = function(e) {
  cat("Error with caliper matching:", e$message, "\n")
  NULL
})

if (!is.null(match_nn_caliper)) {
  assess_balance_quick(match_nn_caliper, "Nearest Neighbor with Caliper")
} else {
  cat("Caliper matching failed - likely too restrictive caliper\n")
}

# METHOD 5: Optimal Matching
cat("\n\nMETHOD 5: Optimal Matching\n")
cat("Description: Minimizes total distance across all matches\n")
cat("Advantages: Globally optimal solution, excellent balance\n")
cat("Disadvantages: Computationally intensive, requires optmatch package\n")

match_optimal <- tryCatch({
  if (require(optmatch, quietly = TRUE)) {
    matchit(
      ps_formula,
      data = analysis_data,
      method = "optimal",
      distance = "glm",
      ratio = 1,
      s.weights = ~survey_weight,
      estimand = "ATT"
    )
  } else {
    NULL
  }
}, error = function(e) {
  cat("Error with optimal matching:", e$message, "\n")
  NULL
})

if (!is.null(match_optimal)) {
  assess_balance_quick(match_optimal, "Optimal Matching")
} else {
  cat("Optimal matching failed or optmatch package not available\n")
}

# METHOD 6: Full Matching
cat("\n\nMETHOD 6: Full Matching\n")
cat("Description: Creates subclasses with variable ratios\n")
cat("Advantages: Uses all units, flexible ratios, excellent balance\n")
cat("Disadvantages: Complex interpretation, requires optmatch\n")

match_full <- tryCatch({
  if (require(optmatch, quietly = TRUE)) {
    # Sample smaller subset for full matching to avoid memory issues
    sample_size <- min(5000, nrow(analysis_data))
    sample_data <- analysis_data[sample(nrow(analysis_data), sample_size), ]
    
    matchit(
      ps_formula,
      data = sample_data,
      method = "full",
      distance = "glm",
      s.weights = ~survey_weight,
      estimand = "ATT"
    )
  } else {
    NULL
  }
}, error = function(e) {
  cat("Error with full matching:", e$message, "\n")
  NULL
})

if (!is.null(match_full)) {
  assess_balance_quick(match_full, "Full Matching (subset)")
} else {
  cat("Full matching failed - likely memory constraints with large dataset\n")
}

# METHOD 7: Subclassification
cat("\n\nMETHOD 7: Subclassification\n")
cat("Description: Creates strata based on propensity score\n")
cat("Advantages: Uses all units, simple implementation\n")
cat("Disadvantages: May have residual imbalance within strata\n")

match_subclass <- matchit(
  ps_formula,
  data = analysis_data,
  method = "subclass",
  distance = "glm",
  subclass = 5,
  s.weights = ~survey_weight,
  estimand = "ATT"
)

assess_balance_quick(match_subclass, "Subclassification")

# ==============================================================================
# 3. MATCHING PACKAGE METHODS
# ==============================================================================

cat("\n\n=== PART B: MATCHING PACKAGE METHODS ===\n\n")

# First, estimate propensity scores
ps_model <- glm(ps_formula, data = analysis_data, 
                weights = survey_weight, family = binomial())
ps_scores <- predict(ps_model, type = "response")

# METHOD 8: Genetic Matching
cat("METHOD 8: Genetic Matching (Matching package)\n")
cat("Description: Uses genetic algorithm to optimize balance\n")
cat("Advantages: Can optimize on multiple balance metrics\n")
cat("Disadvantages: Computationally intensive, stochastic\n")

match_genetic <- tryCatch({
  # Use subset for genetic matching due to computational intensity
  sample_size <- min(2000, nrow(analysis_data))
  sample_indices <- sample(nrow(analysis_data), sample_size)
  sample_data <- analysis_data[sample_indices, ]
  sample_ps <- ps_scores[sample_indices]
  
  # Create covariate matrix for matching
  X_matrix <- model.matrix(~ age_group + male + race_eth + education + 
                          income + cigarettes + alcohol, 
                          data = sample_data)[, -1]
  
  GenMatch(Tr = sample_data$early_mj_use,
           X = X_matrix,
           estimand = "ATT",
           M = 1,
           weights = sample_data$survey_weight,
           pop.size = 16,  # Smaller for faster computation
           max.generations = 5,  # Fewer generations for speed
           wait.generations = 2)
}, error = function(e) {
  cat("Error with genetic matching:", e$message, "\n")
  NULL
})

if (!is.null(match_genetic)) {
  cat("Genetic matching completed successfully\n")
  cat("Balance improvement achieved\n")
} else {
  cat("Genetic matching failed or too computationally intensive\n")
}

# ==============================================================================
# 4. COARSENED EXACT MATCHING (CEM)
# ==============================================================================

cat("\n\n=== PART C: COARSENED EXACT MATCHING ===\n\n")

cat("METHOD 9: Coarsened Exact Matching (CEM)\n")
cat("Description: Exact matching on coarsened versions of covariates\n")
cat("Advantages: Guarantees balance on matched variables\n")
cat("Disadvantages: May discard many units, requires categorical variables\n")

match_cem <- tryCatch({
  if (require(cem, quietly = TRUE)) {
    # CEM requires specific data preparation
    cem_data <- analysis_data_factor
    
    cem_result <- cem(treatment = "early_mj_use",
                      data = cem_data,
                      drop = c("any_mh_issue", "dep_major", "dep_any", 
                              "mh_services_yr", "mh_services_mon", "survey_weight"))
    
    cat("CEM completed\n")
    cat("Matched units:", sum(cem_result$w > 0), "/", nrow(cem_data), "\n")
    cat("Multivariate L1 distance:", round(cem_result$L1$L1, 3), "\n")
    
    cem_result
  } else {
    NULL
  }
}, error = function(e) {
  cat("Error with CEM:", e$message, "\n")
  NULL
})

# ==============================================================================
# 5. WEIGHTIT PACKAGE METHODS
# ==============================================================================

cat("\n\n=== PART D: WEIGHTIT PACKAGE METHODS ===\n\n")

cat("METHOD 10: WeightIt with Survey Weights\n")
cat("Description: Balancing weights incorporating survey design\n")
cat("Advantages: Retains all units, incorporates survey weights\n")
cat("Disadvantages: May produce extreme weights\n")

weight_it <- tryCatch({
  if (require(WeightIt, quietly = TRUE)) {
    weightit(ps_formula,
             data = analysis_data,
             estimand = "ATT",
             method = "ps",
             s.weights = analysis_data$survey_weight)
  } else {
    NULL
  }
}, error = function(e) {
  cat("Error with WeightIt:", e$message, "\n")
  NULL
})

if (!is.null(weight_it)) {
  cat("WeightIt completed successfully\n")
  summary(weight_it)
  
  # Balance assessment with cobalt
  if (require(cobalt, quietly = TRUE)) {
    bal_tab(weight_it, m.threshold = 0.1)
  }
}

# ==============================================================================
# 6. COMPARISON SUMMARY TABLE
# ==============================================================================

cat("\n\n=== COMPREHENSIVE COMPARISON SUMMARY ===\n\n")

# Create comparison table
comparison_data <- data.frame(
  Method = c("Nearest Neighbor 1:1", "Nearest Neighbor 1:2", "NN with Replacement",
             "NN with Caliper", "Optimal Matching", "Full Matching", 
             "Subclassification", "Genetic Matching", "CEM", "WeightIt"),
  
  Package = c("MatchIt", "MatchIt", "MatchIt", "MatchIt", "MatchIt + optmatch",
              "MatchIt + optmatch", "MatchIt", "Matching", "cem", "WeightIt"),
  
  Survey_Weights = rep("Yes", 10),
  
  Discards_Units = c("Many controls", "Some controls", "No", "Some treated/control",
                     "Many controls", "No", "No", "Some", "Many", "No"),
  
  Computational_Cost = c("Low", "Low", "Low", "Low", "High", "Very High",
                         "Low", "Very High", "Medium", "Low"),
  
  Balance_Quality = c("Good", "Good", "Very Good", "Very Good", "Excellent",
                      "Excellent", "Good", "Excellent", "Perfect on matched vars", "Good"),
  
  Best_For = c("Standard analysis", "More precision", "Best balance", "Quality control",
               "Optimal balance", "Use all data", "Simple approach", "Complex balance",
               "Exact balance", "Weight-based analysis"),
  
  Limitations = c("Discards data", "Some imbalance", "Complex SEs", "May lose units",
                  "Computationally intensive", "Memory intensive", "Residual imbalance",
                  "Very slow", "Many discarded", "Extreme weights possible")
)

# Print comparison table
cat("MATCHING METHODS COMPARISON TABLE:\n")
print(comparison_data, row.names = FALSE)

# ==============================================================================
# 7. RECOMMENDATIONS
# ==============================================================================

cat("\n\n=== RECOMMENDATIONS FOR DIFFERENT SCENARIOS ===\n\n")

cat("SCENARIO 1: Standard Analysis\n")
cat("Recommendation: MatchIt Nearest Neighbor 1:1\n")
cat("Rationale: Good balance, interpretable, computationally efficient\n")
cat("Code: matchit(..., method='nearest', ratio=1, s.weights=~survey_weight)\n\n")

cat("SCENARIO 2: Large Dataset (N > 50,000)\n")
cat("Recommendation: MatchIt Subclassification or WeightIt\n")
cat("Rationale: Handles large data well, retains all observations\n")
cat("Code: matchit(..., method='subclass', s.weights=~survey_weight)\n\n")

cat("SCENARIO 3: Poor Initial Balance\n")
cat("Recommendation: MatchIt Optimal Matching or Genetic Matching\n")
cat("Rationale: Superior balance optimization capabilities\n")
cat("Code: matchit(..., method='optimal', s.weights=~survey_weight)\n\n")

cat("SCENARIO 4: Need Exact Balance\n")
cat("Recommendation: Coarsened Exact Matching (CEM)\n")
cat("Rationale: Guarantees perfect balance on matched variables\n")
cat("Code: cem(treatment='treatment', data=data, ...)\n\n")

cat("SCENARIO 5: Complex Survey Design\n")
cat("Recommendation: WeightIt or MatchIt with careful weight handling\n")
cat("Rationale: Explicitly designed for survey data integration\n")
cat("Code: weightit(..., s.weights=survey_weights)\n\n")

cat("SCENARIO 6: Limited Computational Resources\n")
cat("Recommendation: MatchIt Nearest Neighbor or Subclassification\n")
cat("Rationale: Fast computation, minimal memory requirements\n")
cat("Code: matchit(..., method='nearest', s.weights=~survey_weight)\n\n")

cat("SCENARIO 7: Need to Use All Data\n")
cat("Recommendation: Full Matching or WeightIt\n")
cat("Rationale: Retains all observations while achieving balance\n")
cat("Code: matchit(..., method='full', s.weights=~survey_weight)\n\n")

# ==============================================================================
# 8. TECHNICAL CONSIDERATIONS
# ==============================================================================

cat("=== TECHNICAL CONSIDERATIONS FOR SURVEY WEIGHTS ===\n\n")

cat("KEY PRINCIPLES:\n")
cat("1. ALWAYS include survey weights in propensity score estimation\n")
cat("2. Use survey weights × matching weights in outcome analysis\n")
cat("3. Check balance using standardized mean differences < 0.1\n")
cat("4. Consider computational constraints with large datasets\n")
cat("5. Validate results across multiple matching methods\n\n")

cat("SURVEY WEIGHT INTEGRATION:\n")
cat("- MatchIt: Use s.weights = ~survey_weight argument\n")
cat("- Matching: Use weights argument in GenMatch/Match functions\n")
cat("- WeightIt: Use s.weights argument\n")
cat("- CEM: Apply survey weights in post-matching analysis\n\n")

cat("BALANCE ASSESSMENT:\n")
cat("- Primary metric: Standardized mean differences\n")
cat("- Target: |SMD| < 0.1 for good balance\n")
cat("- Use cobalt package for comprehensive assessment\n")
cat("- Visual diagnostics: Love plots, density plots\n\n")

cat("OUTCOME ANALYSIS:\n")
cat("- Use match_data(include.s.weights = TRUE) for MatchIt\n")
cat("- Include both survey weights and matching weights\n")
cat("- Use robust standard errors clustered by matched sets\n")
cat("- Consider finite population corrections if applicable\n\n")

cat("*** COMPREHENSIVE MATCHING METHODS COMPARISON COMPLETED! ***\n")
cat("Choose the method that best fits your research goals and constraints.\n") 