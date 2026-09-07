#!/usr/bin/env Rscript

#' =============================================================================
#' Script: 04_wdsm_analysis_nsduh.R
#' Purpose: Apply WDSM to estimate causal effect of early marijuana use on mental health
#' Author: Data Analysis Team
#' Date: 2025-09-14
#' =============================================================================

cat("\n============================================================\n")
cat("WDSM Analysis of NSDUH 2023 Data\n")
cat("Research Question: Effect of Early Marijuana Use on Mental Health\n")
cat("============================================================\n")

# Load required libraries
library(tidyverse)
library(survey)
library(MatchIt)
library(marginaleffects)
library(tableone)
library(ggplot2)

# Set working directory
setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914")

# Source WDSM functions
source("Analysis/Scripts/wdsm_flexible.R")

# Create output directory
dir.create("Analysis/Results/04_wdsm_analysis", showWarnings = FALSE)

# ============================================================================
# 1. Load and Prepare Data
# ============================================================================

cat("\n--- Loading Data ---\n")

# Load the prepared analytic dataset
analytic_data <- readRDS("Analysis/Results/03_analytic_dataset/complete_case_data.rds")

cat("Sample size:", nrow(analytic_data), "\n")
cat("Treatment distribution:\n")
print(table(analytic_data$early_mj_use))

# ============================================================================
# 2. Define Model Specifications
# ============================================================================

cat("\n--- Defining Model Specifications ---\n")

# Based on NSDUH literature and substantive knowledge:
# Key confounders include demographics, family income, education, urbanicity,
# and other substance use behaviors that predict both early marijuana use
# and mental health outcomes

# Handle missing values in covariates
analytic_data <- analytic_data %>%
  mutate(
    # Recode categorical variables to ensure proper handling
    IRSEX = as.factor(IRSEX),
    NEWRACE2 = as.factor(NEWRACE2),
    COUTYP4 = as.factor(COUTYP4),
    
    # Create binary indicators for substance use
    early_alcohol = ifelse(IRALCAGE < 15 & IRALCAGE < 900, 1, 0),
    early_alcohol = ifelse(is.na(early_alcohol), 0, early_alcohol),
    
    # Create age group indicators
    age_18_20 = ifelse(AGE3 == 4, 1, 0),
    age_21_23 = ifelse(AGE3 == 5, 1, 0),
    age_24_25 = ifelse(AGE3 == 6, 1, 0),
    age_26_29 = ifelse(AGE3 == 7, 1, 0)
  )

# Define propensity score model formula
# Predicting probability of early marijuana use
ps_formula <- as.formula(
  "A ~ IRSEX + NEWRACE2 + IRFAMIN3 + COUTYP4 + early_alcohol + 
   ALCEVER + CIGEVER + age_18_20 + age_21_23 + age_24_25"
)

# Define prognostic score model formula  
# Predicting mental health outcomes
pgs_formula <- as.formula(
  "Y ~ IRSEX + NEWRACE2 + IRFAMIN3 + COUTYP4 + early_alcohol + 
   ALCEVER + CIGEVER + age_18_20 + age_21_23 + age_24_25"
)

cat("Propensity Score Model:\n")
print(ps_formula)
cat("\nPrognostic Score Model:\n")
print(pgs_formula)

# ============================================================================
# 3. Run WDSM Analysis for Primary Outcome (AMIPY)
# ============================================================================

cat("\n============================================================\n")
cat("PRIMARY ANALYSIS: Any Mental Illness (AMIPY)\n")
cat("============================================================\n")

# Prepare data for WDSM
wdsm_data <- analytic_data %>%
  filter(!is.na(AMIPY) & !is.na(early_mj_use) & !is.na(ANALWT2_C))

cat("\nAnalysis sample size:", nrow(wdsm_data), "\n")
cat("  Treated (early use):", sum(wdsm_data$early_mj_use == 1), "\n")
cat("  Control:", sum(wdsm_data$early_mj_use == 0), "\n")
cat("  Outcome prevalence:\n")
cat("    Treated group:", mean(wdsm_data$AMIPY[wdsm_data$early_mj_use == 1]), "\n")
cat("    Control group:", mean(wdsm_data$AMIPY[wdsm_data$early_mj_use == 0]), "\n")

# Run WDSM with M = 5
set.seed(2024)
wdsm_result_ami <- wdsm_flexible(
  data = wdsm_data,
  outcome_var = "AMIPY",
  treatment_var = "early_mj_use",
  ps_formula = ps_formula,
  pgs_formula = pgs_formula,
  weight_var = "ANALWT2_C",
  M = 5,
  B = 500,  # 500 bootstrap samples
  alpha = 0.05,
  verbose = TRUE
)

# ============================================================================
# 4. Comparison Methods
# ============================================================================

cat("\n============================================================\n")
cat("COMPARISON METHODS\n")
cat("============================================================\n")

# --- Method 1: Survey-Weighted Logistic Regression ---
cat("\n--- Survey-Weighted Logistic Regression ---\n")

design_ami <- svydesign(
  ids = ~VEREP,
  strata = ~VESTR_C,
  weights = ~ANALWT2_C,
  data = wdsm_data,
  nest = TRUE
)

# Outcome model with covariates
outcome_model <- svyglm(
  AMIPY ~ early_mj_use + IRSEX + NEWRACE2 + IRFAMIN3 + COUTYP4 + 
    early_alcohol + ALCEVER + CIGEVER + age_18_20 + age_21_23 + age_24_25,
  design = design_ami,
  family = quasibinomial(link = "logit")
)

# Get marginal effect
log_reg_effect <- coef(outcome_model)["early_mj_use"]
log_reg_se <- sqrt(vcov(outcome_model)["early_mj_use", "early_mj_use"])

cat("Effect (log-odds):", round(log_reg_effect, 4), "\n")
cat("SE:", round(log_reg_se, 4), "\n")

# Convert to risk difference scale using marginal effects
library(marginaleffects)
avg_slopes <- avg_slopes(outcome_model, variables = "early_mj_use", 
                        vcov = ~VESTR_C + VEREP)
log_reg_rd <- avg_slopes$estimate[1]
log_reg_rd_se <- avg_slopes$std.error[1]

cat("Risk difference:", round(log_reg_rd, 4), "\n")
cat("SE:", round(log_reg_rd_se, 4), "\n")

# --- Method 2: Inverse Probability Weighting (IPW) ---
cat("\n--- Inverse Probability Weighting ---\n")

# Fit propensity score model
ps_model_ipw <- svyglm(
  early_mj_use ~ IRSEX + NEWRACE2 + IRFAMIN3 + COUTYP4 + 
    early_alcohol + ALCEVER + CIGEVER + age_18_20 + age_21_23 + age_24_25,
  design = design_ami,
  family = quasibinomial(link = "logit")
)

# Get propensity scores
ps_ipw <- fitted(ps_model_ipw)
ps_ipw <- pmax(0.01, pmin(0.99, ps_ipw))  # Trim

# Create IPW weights
wdsm_data$ipw_weight <- ifelse(
  wdsm_data$early_mj_use == 1,
  wdsm_data$ANALWT2_C / ps_ipw,
  wdsm_data$ANALWT2_C / (1 - ps_ipw)
)

# IPW estimator
ipw_treated <- weighted.mean(wdsm_data$AMIPY[wdsm_data$early_mj_use == 1], 
                             wdsm_data$ipw_weight[wdsm_data$early_mj_use == 1])
ipw_control <- weighted.mean(wdsm_data$AMIPY[wdsm_data$early_mj_use == 0], 
                             wdsm_data$ipw_weight[wdsm_data$early_mj_use == 0])
ipw_effect <- ipw_treated - ipw_control

cat("IPW Effect:", round(ipw_effect, 4), "\n")

# Bootstrap for IPW SE
set.seed(2024)
ipw_boot <- replicate(500, {
  idx <- sample(nrow(wdsm_data), replace = TRUE)
  boot_data <- wdsm_data[idx, ]
  
  # Refit PS model
  boot_design <- svydesign(ids = ~1, weights = ~ANALWT2_C, data = boot_data)
  boot_ps_model <- glm(
    early_mj_use ~ IRSEX + NEWRACE2 + IRFAMIN3 + COUTYP4 + 
      early_alcohol + ALCEVER + CIGEVER + age_18_20 + age_21_23 + age_24_25,
    data = boot_data,
    weights = ANALWT2_C,
    family = binomial(link = "logit")
  )
  
  boot_ps <- fitted(boot_ps_model)
  boot_ps <- pmax(0.01, pmin(0.99, boot_ps))
  
  boot_data$ipw_weight <- ifelse(
    boot_data$early_mj_use == 1,
    boot_data$ANALWT2_C / boot_ps,
    boot_data$ANALWT2_C / (1 - boot_ps)
  )
  
  boot_treated <- weighted.mean(boot_data$AMIPY[boot_data$early_mj_use == 1], 
                                boot_data$ipw_weight[boot_data$early_mj_use == 1])
  boot_control <- weighted.mean(boot_data$AMIPY[boot_data$early_mj_use == 0], 
                                boot_data$ipw_weight[boot_data$early_mj_use == 0])
  boot_treated - boot_control
})

ipw_se <- sd(ipw_boot, na.rm = TRUE)
cat("IPW SE (bootstrap):", round(ipw_se, 4), "\n")

# ============================================================================
# 5. Secondary Outcomes Analysis
# ============================================================================

cat("\n============================================================\n")
cat("SECONDARY OUTCOMES ANALYSIS\n")
cat("============================================================\n")

# Define secondary outcomes
secondary_outcomes <- list(
  SMIPY = "Serious Mental Illness",
  IRAMDEYR = "Major Depressive Episode",
  IRSUICTHNK = "Suicidal Thoughts"
)

secondary_results <- list()

for (outcome in names(secondary_outcomes)) {
  cat("\n---", secondary_outcomes[[outcome]], "---\n")
  
  # Filter data for this outcome
  outcome_data <- analytic_data %>%
    filter(!is.na(!!sym(outcome)) & !is.na(early_mj_use) & !is.na(ANALWT2_C))
  
  cat("Sample size:", nrow(outcome_data), "\n")
  cat("Outcome prevalence:\n")
  cat("  Treated:", mean(outcome_data[[outcome]][outcome_data$early_mj_use == 1]), "\n")
  cat("  Control:", mean(outcome_data[[outcome]][outcome_data$early_mj_use == 0]), "\n")
  
  # Run WDSM
  set.seed(2024)
  result <- tryCatch({
    wdsm_flexible(
      data = outcome_data,
      outcome_var = outcome,
      treatment_var = "early_mj_use",
      ps_formula = ps_formula,
      pgs_formula = pgs_formula,
      weight_var = "ANALWT2_C",
      M = 5,
      B = 200,  # Fewer bootstrap samples for secondary outcomes
      alpha = 0.05,
      verbose = FALSE
    )
  }, error = function(e) {
    cat("Error:", e$message, "\n")
    list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  secondary_results[[outcome]] <- result
  
  cat("WDSM Estimate:", round(result$estimate, 4), "\n")
  cat("SE:", round(result$se, 4), "\n")
  cat("95% CI: [", round(result$ci_lower, 4), ",", round(result$ci_upper, 4), "]\n")
}

# ============================================================================
# 6. Compile and Save Results
# ============================================================================

cat("\n============================================================\n")
cat("RESULTS SUMMARY\n")
cat("============================================================\n")

# Create results table
results_table <- data.frame(
  Outcome = c("Any Mental Illness (Primary)",
              "Serious Mental Illness",
              "Major Depressive Episode", 
              "Suicidal Thoughts"),
  Method = "WDSM",
  Estimate = c(wdsm_result_ami$estimate,
               secondary_results$SMIPY$estimate,
               secondary_results$IRAMDEYR$estimate,
               secondary_results$IRSUICTHNK$estimate),
  SE = c(wdsm_result_ami$se,
         secondary_results$SMIPY$se,
         secondary_results$IRAMDEYR$se,
         secondary_results$IRSUICTHNK$se),
  CI_Lower = c(wdsm_result_ami$ci_lower,
               secondary_results$SMIPY$ci_lower,
               secondary_results$IRAMDEYR$ci_lower,
               secondary_results$IRSUICTHNK$ci_lower),
  CI_Upper = c(wdsm_result_ami$ci_upper,
               secondary_results$SMIPY$ci_upper,
               secondary_results$IRAMDEYR$ci_upper,
               secondary_results$IRSUICTHNK$ci_upper),
  stringsAsFactors = FALSE
)

# Add comparison methods for primary outcome
comparison_table <- data.frame(
  Outcome = rep("Any Mental Illness (Primary)", 2),
  Method = c("Weighted Regression", "IPW"),
  Estimate = c(log_reg_rd, ipw_effect),
  SE = c(log_reg_rd_se, ipw_se),
  CI_Lower = c(log_reg_rd - 1.96*log_reg_rd_se, ipw_effect - 1.96*ipw_se),
  CI_Upper = c(log_reg_rd + 1.96*log_reg_rd_se, ipw_effect + 1.96*ipw_se),
  stringsAsFactors = FALSE
)

full_results <- rbind(results_table, comparison_table)

# Round for display
full_results[, 3:6] <- round(full_results[, 3:6], 4)

cat("\n")
print(full_results)

# Save results
write.csv(full_results, 
          "Analysis/Results/04_wdsm_analysis/wdsm_results_table.csv",
          row.names = FALSE)

saveRDS(list(
  primary = wdsm_result_ami,
  secondary = secondary_results,
  comparison = list(
    log_reg = list(estimate = log_reg_rd, se = log_reg_rd_se),
    ipw = list(estimate = ipw_effect, se = ipw_se)
  ),
  data_info = list(
    n = nrow(wdsm_data),
    n_treated = sum(wdsm_data$early_mj_use == 1),
    n_control = sum(wdsm_data$early_mj_use == 0),
    weighted_n = sum(wdsm_data$ANALWT2_C)
  )
), "Analysis/Results/04_wdsm_analysis/wdsm_full_results.rds")

# ============================================================================
# 7. Create Visualizations
# ============================================================================

cat("\n--- Creating Visualizations ---\n")

# Plot 1: Propensity Score Distribution
pdf("Analysis/Results/04_wdsm_analysis/propensity_scores.pdf", width = 10, height = 6)
par(mfrow = c(1, 2))

# By treatment group
hist(wdsm_result_ami$e_hat[wdsm_data$early_mj_use == 1], 
     main = "Propensity Scores - Treated",
     xlab = "Propensity Score", col = "lightblue", breaks = 30)
hist(wdsm_result_ami$e_hat[wdsm_data$early_mj_use == 0], 
     main = "Propensity Scores - Control",
     xlab = "Propensity Score", col = "lightgreen", breaks = 30)
dev.off()

# Plot 2: Forest Plot of Results
library(ggplot2)

forest_data <- full_results %>%
  mutate(
    Outcome_Method = paste0(Outcome, " (", Method, ")"),
    ypos = n():1
  )

p_forest <- ggplot(forest_data, aes(x = Estimate, y = ypos)) +
  geom_point(size = 3) +
  geom_errorbarh(aes(xmin = CI_Lower, xmax = CI_Upper), height = 0.2) +
  geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5) +
  scale_y_continuous(breaks = forest_data$ypos,
                     labels = forest_data$Outcome_Method) +
  labs(x = "Treatment Effect (Risk Difference)",
       y = "",
       title = "Effect of Early Marijuana Use on Mental Health Outcomes",
       subtitle = "WDSM and Comparison Methods") +
  theme_minimal() +
  theme(axis.text.y = element_text(hjust = 0))

ggsave("Analysis/Results/04_wdsm_analysis/forest_plot.pdf", 
       p_forest, width = 12, height = 8)

cat("\nAnalysis complete!\n")
cat("Results saved to: Analysis/Results/04_wdsm_analysis/\n")

# ============================================================================
# 8. Generate Report
# ============================================================================

sink("Analysis/Results/04_wdsm_analysis/analysis_report.txt")
cat("WDSM ANALYSIS REPORT\n")
cat("====================\n")
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("RESEARCH QUESTION\n")
cat("-----------------\n")
cat("What is the population-level causal effect of early marijuana use\n")
cat("(before age 15) on adult mental health outcomes?\n\n")

cat("SAMPLE\n")
cat("------\n")
cat("Source: NSDUH 2023 Public Use File\n")
cat("Analytic sample: Adults aged 18-29\n")
cat("N =", nrow(wdsm_data), "(unweighted)\n")
cat("N =", format(sum(wdsm_data$ANALWT2_C), big.mark = ","), "(weighted)\n")
cat("Treated (early use):", sum(wdsm_data$early_mj_use == 1), 
    "(", round(mean(wdsm_data$early_mj_use == 1)*100, 1), "%)\n")
cat("Control:", sum(wdsm_data$early_mj_use == 0),
    "(", round(mean(wdsm_data$early_mj_use == 0)*100, 1), "%)\n\n")

cat("METHODS\n")
cat("-------\n")
cat("Primary: Survey-Weighted Double Score Matching (WDSM)\n")
cat("  - Matching ratio: M = 5\n")
cat("  - Bootstrap samples: B = 500\n")
cat("  - Doubly robust with polynomial sieve correction\n")
cat("Comparison: Weighted regression, IPW\n\n")

cat("PRIMARY RESULTS\n")
cat("---------------\n")
cat("Outcome: Any Mental Illness (AMIPY)\n")
cat("\nWDSM Estimate:", round(wdsm_result_ami$estimate, 3), "\n")
cat("Standard Error:", round(wdsm_result_ami$se, 3), "\n")
cat("95% CI: [", round(wdsm_result_ami$ci_lower, 3), ",", 
    round(wdsm_result_ami$ci_upper, 3), "]\n")

if (wdsm_result_ami$ci_lower > 0) {
  cat("\nInterpretation: Early marijuana use is associated with a statistically\n")
  cat("significant increase in any mental illness prevalence of", 
      round(wdsm_result_ami$estimate * 100, 1), "percentage points.\n")
} else if (wdsm_result_ami$ci_upper < 0) {
  cat("\nInterpretation: Early marijuana use is associated with a statistically\n")
  cat("significant decrease in any mental illness prevalence.\n")
} else {
  cat("\nInterpretation: No statistically significant effect detected.\n")
}

cat("\nSECONDARY OUTCOMES\n")
cat("------------------\n")
for (outcome in names(secondary_results)) {
  cat("\n", secondary_outcomes[[outcome]], ":\n", sep = "")
  cat("  Estimate:", round(secondary_results[[outcome]]$estimate, 3), "\n")
  cat("  95% CI: [", round(secondary_results[[outcome]]$ci_lower, 3), ",",
      round(secondary_results[[outcome]]$ci_upper, 3), "]\n")
}

cat("\nROBUSTNESS\n")
cat("----------\n")
cat("Valid bootstrap samples:", wdsm_result_ami$n_boot_valid, "/ 500\n")
cat("Average reuse factor (Ktilde):", round(mean(wdsm_result_ami$Ktilde), 2), "\n")

sink()

cat("\n============================================================\n")
cat("WDSM ANALYSIS COMPLETED SUCCESSFULLY!\n")
cat("============================================================\n")

