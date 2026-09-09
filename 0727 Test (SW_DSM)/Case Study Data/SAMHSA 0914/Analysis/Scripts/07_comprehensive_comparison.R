#!/usr/bin/env Rscript

#' =============================================================================
#' Script: 07_comprehensive_comparison.R
#' Purpose: Compare WDSM with Unweighted DSM and Survey-Weighted PS Full Matching
#' Author: Data Analysis Team
#' Date: 2025-09-14
#' =============================================================================

cat("\n============================================================\n")
cat("COMPREHENSIVE COMPARISON OF MATCHING METHODS\n")
cat("NSDUH 2023 Data Analysis\n")
cat("============================================================\n")

# Load required libraries
suppressPackageStartupMessages({
  library(tidyverse)
  library(survey)
  library(MatchIt)
  library(marginaleffects)
  library(Matching)
  library(devtools)
})

# Set working directory
setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914")

# ============================================================================
# 1. Install and Load dsmatch Package
# ============================================================================

cat("\n--- Setting up dsmatch package ---\n")

# Check if dsmatch functions are available, if not, source from GitHub
if (!exists("dsmatchATE")) {
  cat("Loading dsmatch functions from local files...\n")
  
  # Try to source from local dsmatch-master folder if it exists
  dsmatch_files <- c(
    "dsmatch-master/R/bisect.R",
    "dsmatch-master/R/is.lp.R",
    "dsmatch-master/R/is.ps.R", 
    "dsmatch-master/R/is.pg.R",
    "dsmatch-master/R/estforboot_dsATE.R",
    "dsmatch-master/R/estforboot_psATE.R",
    "dsmatch-master/R/estforboot_pgATE.R",
    "dsmatch-master/R/estforboot_covATE.R",
    "dsmatch-master/R/dsmatchATE.R"
  )
  
  # Check if files exist locally
  if (!file.exists(dsmatch_files[1])) {
    cat("Downloading dsmatch from GitHub...\n")
    # Clone the repository
    system("git clone https://github.com/Yunshu7/dsmatch.git dsmatch-master")
  }
  
  # Source the functions
  for (file in dsmatch_files) {
    if (file.exists(file)) {
      source(file)
    } else {
      cat("Warning: Could not find", file, "\n")
    }
  }
}

# Source WDSM function
source("Analysis/Scripts/wdsm_flexible.R")

# Create output directory
dir.create("Analysis/Results/07_comprehensive_comparison", showWarnings = FALSE)

# ============================================================================
# 2. Load and Prepare Data
# ============================================================================

cat("\n--- Loading and Preparing Data ---\n")

# Load the analytic dataset
analytic_data <- readRDS("Analysis/Results/03_analytic_dataset/complete_case_data.rds")

# Prepare data with properly coded variables (same as corrected analysis)
comparison_data <- analytic_data %>%
  mutate(
    # Demographics
    male = ifelse(IRSEX == 1, 1, 0),
    
    # Race/ethnicity
    white = ifelse(NEWRACE2 == 1, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    
    # Income categories
    income_cat = case_when(
      IRFAMIN3 <= 2 ~ "low",
      IRFAMIN3 <= 4 ~ "medium",
      IRFAMIN3 <= 6 ~ "high",
      TRUE ~ "very_high"
    ),
    income_low = ifelse(income_cat == "low", 1, 0),
    income_medium = ifelse(income_cat == "medium", 1, 0),
    income_high = ifelse(income_cat == "high", 1, 0),
    
    # County type
    large_metro = ifelse(COUTYP4 == 1, 1, 0),
    small_metro = ifelse(COUTYP4 == 2, 1, 0),
    
    # Substance use
    ever_alcohol = ifelse(ALCEVER == 1 | (ALCEVER >= 2 & ALCEVER <= 85), 1, 0),
    ever_cigarette = ifelse(CIGEVER == 1, 1, 0),
    early_alcohol = ifelse(IRALCAGE < 15 & IRALCAGE < 900, 1, 0),
    early_alcohol = ifelse(is.na(early_alcohol), 0, early_alcohol),
    
    # Age groups
    age_18_20 = ifelse(AGE3 == 4, 1, 0),
    age_21_23 = ifelse(AGE3 == 5, 1, 0),
    age_24_25 = ifelse(AGE3 == 6, 1, 0),
    age_26_29 = ifelse(AGE3 == 7, 1, 0)
  ) %>%
  filter(!is.na(AMIPY) & !is.na(early_mj_use) & !is.na(ANALWT2_C))

cat("Sample size:", nrow(comparison_data), "\n")
cat("Treated (early marijuana):", sum(comparison_data$early_mj_use == 1), "\n")
cat("Control:", sum(comparison_data$early_mj_use == 0), "\n")

# Extract variables for analysis
Y <- comparison_data$AMIPY
A <- comparison_data$early_mj_use
w <- comparison_data$ANALWT2_C

# Create covariate matrix (consistent across all methods)
X <- comparison_data[, c("male", "white", "black", "hispanic",
                         "income_low", "income_medium", "income_high",
                         "large_metro", "small_metro",
                         "early_alcohol", "ever_cigarette",
                         "age_21_23", "age_24_25", "age_26_29")]
X <- as.matrix(X)

colnames(X) <- c("male", "white", "black", "hispanic",
                  "income_low", "income_medium", "income_high",
                  "large_metro", "small_metro",
                  "early_alcohol", "ever_cigarette",
                  "age_21_23", "age_24_25", "age_26_29")

cat("\nCovariate matrix dimensions:", dim(X), "\n")

# ============================================================================
# 3. METHOD 1: WDSM (Survey-Weighted Double Score Matching)
# ============================================================================

cat("\n============================================================\n")
cat("METHOD 1: WDSM (Survey-Weighted Double Score Matching)\n")
cat("============================================================\n")

# Define formulas
ps_formula <- as.formula(
  "A ~ male + white + black + hispanic + 
   income_low + income_medium + income_high +
   large_metro + small_metro + 
   early_alcohol + ever_cigarette + 
   age_21_23 + age_24_25 + age_26_29"
)

pgs_formula <- as.formula(
  "Y ~ male + white + black + hispanic + 
   income_low + income_medium + income_high +
   large_metro + small_metro + 
   early_alcohol + ever_cigarette + 
   age_21_23 + age_24_25 + age_26_29"
)

set.seed(2024)
wdsm_result <- wdsm_flexible(
  data = comparison_data,
  outcome_var = "AMIPY",
  treatment_var = "early_mj_use",
  ps_formula = ps_formula,
  pgs_formula = pgs_formula,
  weight_var = "ANALWT2_C",
  M = 5,
  B = 200,  # Use 200 for comparison
  alpha = 0.05,
  verbose = TRUE
)

# ============================================================================
# 4. METHOD 2: UNWEIGHTED DSM (dsmatch package)
# ============================================================================

cat("\n============================================================\n")
cat("METHOD 2: UNWEIGHTED DSM (dsmatch package)\n")
cat("============================================================\n")

if (exists("dsmatchATE")) {
  
  cat("Running unweighted double score matching...\n")
  
  set.seed(2024)
  dsm_unweighted <- tryCatch({
    dsmatchATE(
      Y = Y,
      X = X,
      A = A,
      method = "dsm",
      model.ps = "logit",
      model.pg = "linpred",
      lp.pg = X,  # Use same covariates for prognostic score
      cov.balance = FALSE,
      varest = TRUE,
      boots = 200,
      mc = FALSE,
      ncpus = 1
    )
  }, error = function(e) {
    cat("Error in DSM:", e$message, "\n")
    list(est.ds = NA, bootvar = matrix(NA, 1, 1))
  })
  
  dsm_unweighted_result <- list(
    estimate = dsm_unweighted$est.ds,
    se = sqrt(dsm_unweighted$bootvar[1,1]),
    ci_lower = dsm_unweighted$est.ds - 1.96 * sqrt(dsm_unweighted$bootvar[1,1]),
    ci_upper = dsm_unweighted$est.ds + 1.96 * sqrt(dsm_unweighted$bootvar[1,1])
  )
  
  cat("Unweighted DSM Estimate:", round(dsm_unweighted_result$estimate, 4), "\n")
  cat("SE:", round(dsm_unweighted_result$se, 4), "\n")
  cat("95% CI: [", round(dsm_unweighted_result$ci_lower, 4), ",",
      round(dsm_unweighted_result$ci_upper, 4), "]\n")
  
} else {
  cat("dsmatchATE function not available. Skipping unweighted DSM.\n")
  dsm_unweighted_result <- list(
    estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
  )
}

# ============================================================================
# 5. METHOD 3: SURVEY-WEIGHTED PS FULL MATCHING (MatchIt)
# ============================================================================

cat("\n============================================================\n")
cat("METHOD 3: SURVEY-WEIGHTED PS FULL MATCHING (MatchIt)\n")
cat("============================================================\n")

# Normalize weights as in simulation
w_normalized <- w * length(w) / sum(w)

# Create data frame for MatchIt
matchit_data <- data.frame(
  Y = Y,
  A = A,
  X,  # Include all covariates
  sw = w_normalized
)

cat("Running survey-weighted PS Full matching...\n")

# PS formula for MatchIt (using column names from X matrix)
ps_formula_matchit <- as.formula(
  "A ~ male + white + black + hispanic + 
   income_low + income_medium + income_high +
   large_metro + small_metro + 
   early_alcohol + ever_cigarette + 
   age_21_23 + age_24_25 + age_26_29"
)

set.seed(2024)
ps_full_sw <- tryCatch({
  matchit(
    ps_formula_matchit,
    data = matchit_data,
    method = "full",
    distance = "glm",
    link = "logit",
    s.weights = ~ sw,
    estimand = "ATE"
  )
}, error = function(e) {
  cat("Error in MatchIt:", e$message, "\n")
  NULL
})

if (!is.null(ps_full_sw)) {
  # Extract matched data
  matched_data <- match.data(ps_full_sw)
  
  # Fit outcome model
  outcome_formula <- as.formula(
    "Y ~ A * (male + white + black + hispanic + 
     income_low + income_medium + income_high +
     large_metro + small_metro + 
     early_alcohol + ever_cigarette + 
     age_21_23 + age_24_25 + age_26_29)"
  )
  
  fit_sw <- lm(outcome_formula, 
               data = matched_data,
               weights = weights)
  
  # Compute marginal ATE
  ate_result <- avg_comparisons(
    fit_sw,
    variables = "A",
    vcov = ~subclass,
    wts = "sw"
  )
  
  ps_full_result <- list(
    estimate = ate_result$estimate[1],
    se = ate_result$std.error[1],
    ci_lower = ate_result$conf.low[1],
    ci_upper = ate_result$conf.high[1]
  )
  
  cat("PS Full (Survey-Weighted) Estimate:", round(ps_full_result$estimate, 4), "\n")
  cat("SE:", round(ps_full_result$se, 4), "\n")
  cat("95% CI: [", round(ps_full_result$ci_lower, 4), ",",
      round(ps_full_result$ci_upper, 4), "]\n")
  
} else {
  ps_full_result <- list(
    estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
  )
}

# ============================================================================
# 6. SECONDARY OUTCOMES COMPARISON
# ============================================================================

cat("\n============================================================\n")
cat("SECONDARY OUTCOMES COMPARISON\n")
cat("============================================================\n")

secondary_outcomes <- c("SMIPY", "IRAMDEYR", "IRSUICTHNK")
secondary_names <- c("Serious Mental Illness", "Depression", "Suicidal Thoughts")

secondary_results <- list()

for (i in seq_along(secondary_outcomes)) {
  outcome <- secondary_outcomes[i]
  outcome_name <- secondary_names[i]
  
  cat("\n---", outcome_name, "---\n")
  
  # Filter for non-missing outcome
  outcome_data <- comparison_data %>%
    filter(!is.na(!!sym(outcome)))
  
  Y_sec <- outcome_data[[outcome]]
  A_sec <- outcome_data$early_mj_use
  w_sec <- outcome_data$ANALWT2_C
  
  X_sec <- outcome_data[, c("male", "white", "black", "hispanic",
                            "income_low", "income_medium", "income_high",
                            "large_metro", "small_metro",
                            "early_alcohol", "ever_cigarette",
                            "age_21_23", "age_24_25", "age_26_29")]
  X_sec <- as.matrix(X_sec)
  
  # WDSM for secondary outcome
  set.seed(2024)
  wdsm_sec <- tryCatch({
    wdsm_flexible(
      data = outcome_data,
      outcome_var = outcome,
      treatment_var = "early_mj_use",
      ps_formula = ps_formula,
      pgs_formula = pgs_formula,
      weight_var = "ANALWT2_C",
      M = 5,
      B = 100,
      alpha = 0.05,
      verbose = FALSE
    )
  }, error = function(e) {
    list(estimate = NA, se = NA)
  })
  
  # Unweighted DSM for secondary outcome
  if (exists("dsmatchATE")) {
    dsm_sec <- tryCatch({
      dsmatchATE(
        Y = Y_sec,
        X = X_sec,
        A = A_sec,
        method = "dsm",
        model.ps = "logit",
        model.pg = "linpred",
        lp.pg = X_sec,
        cov.balance = FALSE,
        varest = TRUE,
        boots = 100,
        mc = FALSE,
        ncpus = 1
      )
    }, error = function(e) {
      list(est.ds = NA, bootvar = matrix(NA, 1, 1))
    })
    
    dsm_sec_result <- list(
      estimate = dsm_sec$est.ds,
      se = sqrt(dsm_sec$bootvar[1,1])
    )
  } else {
    dsm_sec_result <- list(estimate = NA, se = NA)
  }
  
  secondary_results[[outcome]] <- list(
    wdsm = list(estimate = wdsm_sec$estimate, se = wdsm_sec$se),
    dsm_unweighted = dsm_sec_result
  )
  
  cat("WDSM:", round(wdsm_sec$estimate, 4), "(SE:", round(wdsm_sec$se, 4), ")\n")
  cat("DSM Unweighted:", round(dsm_sec_result$estimate, 4), 
      "(SE:", round(dsm_sec_result$se, 4), ")\n")
}

# ============================================================================
# 7. COMPILE RESULTS
# ============================================================================

cat("\n============================================================\n")
cat("COMPREHENSIVE RESULTS SUMMARY\n")
cat("============================================================\n")

# Create comprehensive results table
results_table <- data.frame(
  Outcome = rep("Any Mental Illness (Primary)", 3),
  Method = c("WDSM (Survey-Weighted DSM)",
             "DSM (Unweighted)",
             "PS Full (Survey-Weighted)"),
  Estimate = c(wdsm_result$estimate,
               dsm_unweighted_result$estimate,
               ps_full_result$estimate),
  SE = c(wdsm_result$se,
         dsm_unweighted_result$se,
         ps_full_result$se),
  CI_Lower = c(wdsm_result$ci_lower,
               dsm_unweighted_result$ci_lower,
               ps_full_result$ci_lower),
  CI_Upper = c(wdsm_result$ci_upper,
               dsm_unweighted_result$ci_upper,
               ps_full_result$ci_upper),
  stringsAsFactors = FALSE
)

# Add secondary outcomes
for (outcome in names(secondary_results)) {
  outcome_label <- switch(outcome,
                         SMIPY = "Serious Mental Illness",
                         IRAMDEYR = "Depression",
                         IRSUICTHNK = "Suicidal Thoughts")
  
  secondary_table <- data.frame(
    Outcome = rep(outcome_label, 2),
    Method = c("WDSM (Survey-Weighted DSM)",
               "DSM (Unweighted)"),
    Estimate = c(secondary_results[[outcome]]$wdsm$estimate,
                 secondary_results[[outcome]]$dsm_unweighted$estimate),
    SE = c(secondary_results[[outcome]]$wdsm$se,
           secondary_results[[outcome]]$dsm_unweighted$se),
    CI_Lower = c(secondary_results[[outcome]]$wdsm$estimate - 1.96 * secondary_results[[outcome]]$wdsm$se,
                 secondary_results[[outcome]]$dsm_unweighted$estimate - 1.96 * secondary_results[[outcome]]$dsm_unweighted$se),
    CI_Upper = c(secondary_results[[outcome]]$wdsm$estimate + 1.96 * secondary_results[[outcome]]$wdsm$se,
                 secondary_results[[outcome]]$dsm_unweighted$estimate + 1.96 * secondary_results[[outcome]]$dsm_unweighted$se),
    stringsAsFactors = FALSE
  )
  
  results_table <- rbind(results_table, secondary_table)
}

# Round for display
results_table[, 3:6] <- round(results_table[, 3:6], 4)

cat("\n")
print(results_table, row.names = FALSE)

# Calculate relative efficiency (using WDSM as reference)
wdsm_var <- wdsm_result$se^2
dsm_var <- dsm_unweighted_result$se^2
ps_var <- ps_full_result$se^2

cat("\n--- Relative Efficiency (vs WDSM) ---\n")
cat("DSM Unweighted:", round(wdsm_var / dsm_var, 3), "\n")
cat("PS Full Weighted:", round(wdsm_var / ps_var, 3), "\n")

# Save results
write.csv(results_table, 
          "Analysis/Results/07_comprehensive_comparison/comparison_results_table.csv",
          row.names = FALSE)

saveRDS(list(
  wdsm = wdsm_result,
  dsm_unweighted = dsm_unweighted_result,
  ps_full_weighted = ps_full_result,
  secondary = secondary_results,
  data_info = list(
    n = nrow(comparison_data),
    n_treated = sum(comparison_data$early_mj_use == 1),
    n_control = sum(comparison_data$early_mj_use == 0),
    weighted_n = sum(comparison_data$ANALWT2_C)
  )
), "Analysis/Results/07_comprehensive_comparison/all_comparison_results.rds")

# ============================================================================
# 8. CREATE VISUALIZATION
# ============================================================================

cat("\n--- Creating Comparison Visualization ---\n")

library(ggplot2)

# Prepare data for plotting
plot_data <- results_table %>%
  filter(Outcome == "Any Mental Illness (Primary)") %>%
  mutate(
    Method = factor(Method, levels = c("WDSM (Survey-Weighted DSM)",
                                       "DSM (Unweighted)",
                                       "PS Full (Survey-Weighted)"))
  )

# Create forest plot
p_comparison <- ggplot(plot_data, aes(x = Estimate, y = Method)) +
  geom_point(size = 3) +
  geom_errorbarh(aes(xmin = CI_Lower, xmax = CI_Upper), height = 0.2) +
  geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5) +
  labs(x = "Treatment Effect (Risk Difference)",
       y = "",
       title = "Comparison of Matching Methods",
       subtitle = "Effect of Early Marijuana Use on Any Mental Illness") +
  theme_minimal() +
  theme(axis.text.y = element_text(hjust = 0))

ggsave("Analysis/Results/07_comprehensive_comparison/methods_comparison.pdf", 
       p_comparison, width = 10, height = 6)

cat("\n============================================================\n")
cat("COMPREHENSIVE COMPARISON COMPLETE!\n")
cat("Results saved to: Analysis/Results/07_comprehensive_comparison/\n")
cat("============================================================\n")
