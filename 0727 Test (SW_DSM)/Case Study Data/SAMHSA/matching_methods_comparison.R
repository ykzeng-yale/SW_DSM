# ==============================================================================
# COMPREHENSIVE COMPARISON OF MATCHING METHODS WITH SURVEY WEIGHTS
# Early Marijuana Use and Mental Health - NSDUH 2023
# ==============================================================================

library(dplyr)
library(MatchIt)
library(tableone)
# Skip Matching package to avoid conflicts

# Load cobalt if available
cobalt_available <- require(cobalt, quietly = TRUE)
# Skip Matching package for now to avoid MASS conflicts
# matching_available <- require(Matching, quietly = TRUE)
weightit_available <- require(WeightIt, quietly = TRUE)

set.seed(12345)

cat("=== COMPREHENSIVE MATCHING METHODS WITH SURVEY WEIGHTS ===\n")
cat("Comparing Different Approaches for Causal Inference\n\n")

# Load and prepare data
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
  filter(complete.cases(.)) %>%
  dplyr::select(early_mj_use, any_mh_issue, age_group, male, race_eth, 
         education, income, cigarettes, alcohol, survey_weight)

cat("Analysis dataset:", nrow(analysis_data), "observations\n")
cat("Treatment prevalence:", round(100*mean(analysis_data$early_mj_use), 1), "%\n\n")

# Propensity score formula
ps_formula <- early_mj_use ~ age_group + male + race_eth + education + 
              income + cigarettes + alcohol

# Helper function for balance assessment
assess_method <- function(match_obj, method_name, execution_time) {
  cat("\n=== METHOD:", method_name, "===\n")
  cat("Execution time:", round(execution_time, 2), "seconds\n")
  
  # Get summary
  if (class(match_obj)[1] == "matchit") {
    summary_obj <- summary(match_obj, standardize = TRUE)
    
    # Sample sizes
    if (!is.null(summary_obj$nn)) {
      cat("Original treated:", summary_obj$nn["All", "Treated"], "\n")
      cat("Original control:", summary_obj$nn["All", "Control"], "\n")
      cat("Matched treated:", summary_obj$nn["Matched", "Treated"], "\n")
      cat("Matched control:", summary_obj$nn["Matched", "Control"], "\n")
    }
    
    # Balance assessment
    if (!is.null(summary_obj$sum.matched)) {
      smd_vals <- summary_obj$sum.matched[, "Std. Mean Diff."]
      balanced_vars <- sum(abs(smd_vals) < 0.1, na.rm = TRUE)
      total_vars <- length(smd_vals[!is.na(smd_vals)])
      
      cat("Variables balanced (|SMD| < 0.1):", balanced_vars, "/", total_vars, "\n")
      
      # Show worst balance
      worst_idx <- which.max(abs(smd_vals))
      if (length(worst_idx) > 0) {
        worst_var <- names(smd_vals)[worst_idx]
        worst_smd <- smd_vals[worst_idx]
        cat("Worst balance:", worst_var, "SMD =", round(worst_smd, 3), "\n")
      }
    }
    
    # Enhanced balance with cobalt if available
    if (cobalt_available) {
      balance_tab <- bal.tab(match_obj, m.threshold = 0.1, v.threshold = 2)
      print(balance_tab)
    }
  }
  
  return(match_obj)
}

# ==============================================================================
# METHOD COMPARISONS
# ==============================================================================

cat("\n*** STARTING COMPREHENSIVE METHOD COMPARISON ***\n")

methods_results <- list()

# METHOD 1: Nearest Neighbor 1:1
cat("\n" , rep("=", 60), "\n")
cat("TESTING: Nearest Neighbor Matching (1:1)\n")
cat("Description: Each treated unit matched to closest control\n")
cat("Advantages: Simple, interpretable, good balance\n")
cat("Best for: Standard analysis, moderate datasets\n")

start_time <- Sys.time()
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
end_time <- Sys.time()

methods_results[["NN_1to1"]] <- assess_method(match_nn_1to1, "Nearest Neighbor 1:1", 
                                             as.numeric(end_time - start_time))

# METHOD 2: Nearest Neighbor 1:2  
cat("\n" , rep("=", 60), "\n")
cat("TESTING: Nearest Neighbor Matching (1:2)\n")
cat("Description: Each treated unit matched to 2 closest controls\n")
cat("Advantages: Better precision, uses more controls\n")
cat("Best for: When you have many controls available\n")

start_time <- Sys.time()
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
end_time <- Sys.time()

methods_results[["NN_1to2"]] <- assess_method(match_nn_1to2, "Nearest Neighbor 1:2",
                                             as.numeric(end_time - start_time))

# METHOD 3: Nearest Neighbor with Replacement
cat("\n" , rep("=", 60), "\n")
cat("TESTING: Nearest Neighbor with Replacement\n")
cat("Description: Control units can be matched multiple times\n")
cat("Advantages: Better balance, optimal use of good controls\n")
cat("Best for: When balance is priority over sample size\n")

start_time <- Sys.time()
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
end_time <- Sys.time()

methods_results[["NN_Replace"]] <- assess_method(match_nn_replace, "NN with Replacement",
                                                as.numeric(end_time - start_time))

# METHOD 4: Optimal Matching
cat("\n" , rep("=", 60), "\n")
cat("TESTING: Optimal Matching\n")
cat("Description: Minimizes total distance across all matches\n")
cat("Advantages: Globally optimal solution, excellent balance\n")
cat("Best for: When computational time is not a constraint\n")

start_time <- Sys.time()
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
    cat("optmatch package not available\n")
    NULL
  }
}, error = function(e) {
  cat("Error:", e$message, "\n")
  NULL
})
end_time <- Sys.time()

if (!is.null(match_optimal)) {
  methods_results[["Optimal"]] <- assess_method(match_optimal, "Optimal Matching",
                                               as.numeric(end_time - start_time))
} else {
  cat("Optimal matching not available or failed\n")
}

# METHOD 5: Subclassification
cat("\n" , rep("=", 60), "\n")
cat("TESTING: Subclassification\n")
cat("Description: Stratification by propensity score quintiles\n")
cat("Advantages: Uses all data, simple implementation\n")
cat("Best for: Large datasets, when you want to retain all units\n")

start_time <- Sys.time()
match_subclass <- matchit(
  ps_formula,
  data = analysis_data,
  method = "subclass",
  distance = "glm",
  subclass = 5,
  s.weights = ~survey_weight,
  estimand = "ATT"
)
end_time <- Sys.time()

methods_results[["Subclass"]] <- assess_method(match_subclass, "Subclassification",
                                              as.numeric(end_time - start_time))

# METHOD 6: WeightIt (if available)
if (weightit_available) {
  cat("\n" , rep("=", 60), "\n")
  cat("TESTING: WeightIt Balancing Weights\n")
  cat("Description: Propensity score weighting with survey weights\n")
  cat("Advantages: Retains all data, flexible\n")
  cat("Best for: When matching discards too many units\n")
  
  start_time <- Sys.time()
  weight_it <- tryCatch({
    weightit(ps_formula,
             data = analysis_data,
             estimand = "ATT",
             method = "ps",
             s.weights = analysis_data$survey_weight)
  }, error = function(e) {
    cat("Error:", e$message, "\n")
    NULL
  })
  end_time <- Sys.time()
  
  if (!is.null(weight_it)) {
    cat("\n=== METHOD: WeightIt Balancing ===\n")
    cat("Execution time:", round(as.numeric(end_time - start_time), 2), "seconds\n")
    print(summary(weight_it))
    
    if (cobalt_available) {
      balance_tab <- bal.tab(weight_it, m.threshold = 0.1)
      print(balance_tab)
    }
    
    methods_results[["WeightIt"]] <- weight_it
  }
}

# ==============================================================================
# COMPARISON SUMMARY TABLE
# ==============================================================================

cat("\n\n", rep("=", 80), "\n")
cat("COMPREHENSIVE COMPARISON SUMMARY\n")
cat(rep("=", 80), "\n\n")

# Create summary comparison
comparison_summary <- data.frame(
  Method = c(
    "Nearest Neighbor 1:1",
    "Nearest Neighbor 1:2", 
    "NN with Replacement",
    "Optimal Matching",
    "Subclassification",
    if(weightit_available) "WeightIt" else NULL
  ),
  
  Survey_Weights = c(
    "✓ (s.weights)",
    "✓ (s.weights)",
    "✓ (s.weights)", 
    "✓ (s.weights)",
    "✓ (s.weights)",
    if(weightit_available) "✓ (s.weights)" else NULL
  ),
  
  Discards_Units = c(
    "Many controls",
    "Some controls",
    "No",
    "Many controls", 
    "No",
    if(weightit_available) "No" else NULL
  ),
  
  Computation = c(
    "Fast",
    "Fast",
    "Fast",
    "Slow",
    "Fast", 
    if(weightit_available) "Fast" else NULL
  ),
  
  Balance_Quality = c(
    "Good",
    "Good", 
    "Very Good",
    "Excellent",
    "Moderate",
    if(weightit_available) "Good" else NULL
  ),
  
  Best_Use_Case = c(
    "Standard analysis",
    "Need more precision",
    "Prioritize balance",
    "Best possible balance",
    "Large datasets",
    if(weightit_available) "Weight-based analysis" else NULL
  )
)

print(comparison_summary, row.names = FALSE)

# ==============================================================================
# PRACTICAL RECOMMENDATIONS
# ==============================================================================

cat("\n\n", rep("=", 80), "\n")
cat("PRACTICAL RECOMMENDATIONS BY SCENARIO\n")
cat(rep("=", 80), "\n\n")

recommendations <- list(
  "New to Matching" = "Start with Nearest Neighbor 1:1 - simple and interpretable",
  "Large Dataset (N>50K)" = "Use Subclassification - handles large data efficiently", 
  "Poor Initial Balance" = "Try Optimal Matching - best balance optimization",
  "Need All Data" = "Use Subclassification or WeightIt - retains all observations",
  "Limited Time/Resources" = "Use Nearest Neighbor - fastest computation",
  "Best Possible Balance" = "Use Optimal Matching or NN with Replacement",
  "Complex Survey Design" = "All methods work with s.weights argument",
  "Publication/Presentation" = "Nearest Neighbor 1:1 - easiest to explain"
)

for (scenario in names(recommendations)) {
  cat("SCENARIO:", scenario, "\n")
  cat("RECOMMENDATION:", recommendations[[scenario]], "\n\n")
}

# ==============================================================================
# TECHNICAL IMPLEMENTATION GUIDE
# ==============================================================================

cat(rep("=", 80), "\n")
cat("TECHNICAL IMPLEMENTATION GUIDE\n")
cat(rep("=", 80), "\n\n")

cat("KEY SYNTAX FOR SURVEY WEIGHTS:\n\n")

cat("# MatchIt Methods (ALL use same syntax)\n")
cat('matchit(formula, data = data, method = "METHOD",\n')
cat('        s.weights = ~survey_weight,  # KEY!\n')
cat('        estimand = "ATT")\n\n')

cat("# WeightIt Method\n")
cat('weightit(formula, data = data, method = "ps",\n')
cat('         s.weights = data$survey_weight)  # KEY!\n\n')

cat("CRITICAL STEPS:\n")
cat("1. ALWAYS include survey weights in propensity score estimation\n")
cat("2. Use survey weights × matching weights in outcome analysis\n")
cat("3. For MatchIt: use match_data(include.s.weights = TRUE)\n")
cat("4. Check balance with standardized mean differences < 0.1\n")
cat("5. Use robust standard errors in final models\n\n")

cat("BALANCE ASSESSMENT:\n")
cat("- Primary metric: Standardized Mean Differences (SMD)\n")
cat("- Target: |SMD| < 0.1 for good balance\n")
cat("- Use cobalt package: bal.tab(match_object)\n")
cat("- Visual assessment: love plots, density plots\n\n")

cat("OUTCOME ANALYSIS TEMPLATE:\n")
cat("matched_data <- match_data(match_obj, include.s.weights = TRUE)\n")
cat("model <- glm(outcome ~ treatment + covariates,\n")
cat("             data = matched_data,\n")
cat("             weights = weights,  # Combined weights\n")
cat("             family = binomial())\n\n")

cat("*** COMPREHENSIVE MATCHING METHODS COMPARISON COMPLETED! ***\n")
cat("Choose the method that best fits your specific research needs.\n") 