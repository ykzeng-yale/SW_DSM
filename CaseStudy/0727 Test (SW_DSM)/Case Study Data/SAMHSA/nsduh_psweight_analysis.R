# NSDUH 2023 Propensity Score Weighting Analysis using PSweight
# Estimating Population Average Treatment Effect (PATE) with Survey Weights

# Install and load required packages
if (!require("PSweight")) {
  install.packages("PSweight")
  library(PSweight)
}

library(dplyr)
library(ggplot2)
library(tidyr)

# Load the NSDUH 2023 data
load("NSDUH_2023.Rdata")
data <- puf2023_102124

cat("=== NSDUH 2023 PROPENSITY SCORE WEIGHTING ANALYSIS ===\n\n")

# ============================================================================
# RESEARCH QUESTION: 
# What is the causal effect of tobacco use on mental health outcomes?
# Treatment: Past year tobacco use (TOBYR)
# Outcome: General health status (HEALTH2) - we'll create a binary outcome
# ============================================================================

cat("RESEARCH QUESTION:\n")
cat("Causal effect of past-year tobacco use on self-reported health status\n")
cat("Treatment: TOBYR (0=No tobacco use, 1=Tobacco use in past year)\n")
cat("Outcome: Poor/Fair health vs Good/Very Good/Excellent health\n\n")

# Prepare the analysis dataset
analysis_data <- data %>%
  # Select key variables for analysis
  select(
    # Treatment
    TOBYR,
    # Outcome
    HEALTH2,
    # Demographics and covariates
    AGE3, IRSEX, NEWRACE2, IREDUHIGHST2, INCOME,
    # Survey design variables
    ANALWT2_C, VESTR_C, VEREP,
    # Additional health/behavioral covariates
    HEALTH, MILSTAT, NOMARR2, SEXATRACT2
  ) %>%
  # Create binary outcome: 1 = Poor/Fair health, 0 = Good/Very Good/Excellent
  mutate(
    poor_health = case_when(
      HEALTH2 %in% c(1, 2) ~ 1,  # Poor or Fair health
      HEALTH2 %in% c(3, 4, 5) ~ 0,  # Good, Very Good, or Excellent health
      TRUE ~ NA_real_
    ),
    # Ensure treatment is binary
    tobacco_use = case_when(
      TOBYR == 1 ~ 1,
      TOBYR == 0 ~ 0,
      TRUE ~ NA_real_
    ),
    # Create age groups for easier interpretation
    age_group = case_when(
      AGE3 %in% 1:3 ~ 1,  # 12-17 years (adolescents)
      AGE3 %in% 4:6 ~ 2,  # 18-25 years (young adults)
      AGE3 %in% 7:9 ~ 3,  # 26-49 years (adults)
      AGE3 %in% 10:11 ~ 4, # 50+ years (older adults)
      TRUE ~ NA_real_
    ),
    # Sex (1=Male, 2=Female)
    male = ifelse(IRSEX == 1, 1, 0),
    # Race/ethnicity (simplified)
    white = ifelse(NEWRACE2 == 1, 1, 0),
    # Education (college vs no college)
    college = case_when(
      IREDUHIGHST2 >= 11 ~ 1,  # College graduate or higher
      IREDUHIGHST2 < 11 ~ 0,   # Less than college
      TRUE ~ NA_real_
    ),
    # Income (above median vs below)
    high_income = case_when(
      INCOME >= 7 ~ 1,  # $50,000+ (simplified)
      INCOME < 7 ~ 0,
      TRUE ~ NA_real_
    ),
    # Marital status
    married = ifelse(NOMARR2 == 1, 0, 1)  # 1=currently married
  ) %>%
  # Remove missing values for key variables
  filter(
    !is.na(tobacco_use),
    !is.na(poor_health),
    !is.na(age_group),
    !is.na(male),
    !is.na(ANALWT2_C)
  )

cat("ANALYSIS DATASET SUMMARY:\n")
cat("Sample size after cleaning:", nrow(analysis_data), "\n")
cat("Treatment prevalence:", round(mean(analysis_data$tobacco_use, na.rm=TRUE)*100, 1), "%\n")
cat("Outcome prevalence:", round(mean(analysis_data$poor_health, na.rm=TRUE)*100, 1), "%\n\n")

# Check overlap by treatment group
cat("COVARIATE BALANCE (Unweighted):\n")
balance_check <- analysis_data %>%
  group_by(tobacco_use) %>%
  summarise(
    n = n(),
    age_mean = round(mean(age_group, na.rm=TRUE), 2),
    male_pct = round(mean(male, na.rm=TRUE)*100, 1),
    white_pct = round(mean(white, na.rm=TRUE)*100, 1),
    college_pct = round(mean(college, na.rm=TRUE)*100, 1),
    high_income_pct = round(mean(high_income, na.rm=TRUE)*100, 1),
    poor_health_pct = round(mean(poor_health, na.rm=TRUE)*100, 1),
    .groups = 'drop'
  )

print(balance_check)

# ============================================================================
# PROPENSITY SCORE ESTIMATION AND WEIGHTING USING PSweight
# ============================================================================

cat("\n=== PROPENSITY SCORE ESTIMATION ===\n")

# Prepare data for PSweight
# PSweight expects specific variable names and formats
psweight_data <- analysis_data %>%
  select(
    zname = tobacco_use,  # Treatment variable
    yname = poor_health,  # Outcome variable
    age_group, male, white, college, high_income, married,
    survey_weight = ANALWT2_C  # Survey weights
  ) %>%
  filter(!is.na(zname), !is.na(yname)) %>%
  # Remove any remaining missing values in covariates
  filter(complete.cases(.))

cat("Final analysis sample:", nrow(psweight_data), "observations\n")

# Define covariates for propensity score model
covariates <- c("age_group", "male", "white", "college", "high_income", "married")

# Create formula for propensity score estimation
ps_formula <- as.formula(paste("zname ~", paste(covariates, collapse = " + ")))

cat("Propensity score model:", deparse(ps_formula), "\n\n")

# ============================================================================
# Method 1: Inverse Probability Weighting (IPW) with Survey Weights
# ============================================================================

cat("=== METHOD 1: IPW WEIGHTING ===\n")

# Estimate propensity scores and IPW weights
# Note: PSweight can incorporate survey weights in the estimation
ps_ipw <- PSweight(
  ps.formula = ps_formula,
  yname = "yname", 
  data = psweight_data,
  weight = "IPW",  # Inverse Probability Weighting
  trtgrp = c(0, 1)  # Treatment levels
)

# Extract propensity scores and weights
psweight_data$ps <- ps_ipw$propensity[,2]  # Propensity for treatment=1
psweight_data$ipw_weight <- ps_ipw$W

# Check propensity score distribution
cat("PROPENSITY SCORE SUMMARY:\n")
ps_summary <- psweight_data %>%
  group_by(zname) %>%
  summarise(
    n = n(),
    ps_min = round(min(ps, na.rm=TRUE), 3),
    ps_q25 = round(quantile(ps, 0.25, na.rm=TRUE), 3),
    ps_median = round(median(ps, na.rm=TRUE), 3),
    ps_q75 = round(quantile(ps, 0.75, na.rm=TRUE), 3),
    ps_max = round(max(ps, na.rm=TRUE), 3),
    .groups = 'drop'
  )
print(ps_summary)

# Estimate treatment effect using IPW
ipw_result <- PSweight(
  ps.formula = ps_formula,
  yname = "yname",
  data = psweight_data,
  weight = "IPW",
  augmentation = FALSE,  # Simple weighting estimator
  bootstrap = TRUE,      # For confidence intervals
  R = 200               # Bootstrap replicates
)

cat("\nIPW TREATMENT EFFECT ESTIMATE:\n")
print(ipw_result$estimates)

# ============================================================================
# Method 2: Overlap Weighting (OW) - Optimal for efficiency
# ============================================================================

cat("\n=== METHOD 2: OVERLAP WEIGHTING ===\n")

# Overlap weights achieve optimal covariate balance
ow_result <- PSweight(
  ps.formula = ps_formula,
  yname = "yname",
  data = psweight_data,
  weight = "overlap",    # Overlap weights
  augmentation = FALSE,
  bootstrap = TRUE,
  R = 200
)

cat("OVERLAP WEIGHTING TREATMENT EFFECT ESTIMATE:\n")
print(ow_result$estimates)

# Extract overlap weights for further analysis
psweight_data$ow_weight <- ow_result$W

# ============================================================================
# Method 3: Augmented IPW (AIPW) for Double Robustness
# ============================================================================

cat("\n=== METHOD 3: AUGMENTED IPW (AIPW) ===\n")

# AIPW provides double robustness - consistent if either PS or outcome model is correct
aipw_result <- PSweight(
  ps.formula = ps_formula,
  yname = "yname",
  data = psweight_data,
  weight = "IPW",
  augmentation = TRUE,   # Include outcome model
  bootstrap = TRUE,
  R = 200
)

cat("AIPW TREATMENT EFFECT ESTIMATE:\n")
print(aipw_result$estimates)

# ============================================================================
# Method 4: Incorporating Survey Weights
# ============================================================================

cat("\n=== METHOD 4: IPW WITH SURVEY WEIGHTS ===\n")

# Create composite weights: IPW weights × Survey weights
psweight_data$composite_weight <- psweight_data$ipw_weight * psweight_data$survey_weight

# Estimate treatment effect with survey weights
# We'll use a manual calculation approach to properly incorporate survey weights
survey_weighted_est <- psweight_data %>%
  group_by(zname) %>%
  summarise(
    n = n(),
    # Weighted outcomes using IPW × Survey weights
    weighted_outcome = sum(yname * ipw_weight * survey_weight, na.rm=TRUE) / 
                      sum(ipw_weight * survey_weight, na.rm=TRUE),
    # Standard IPW estimate for comparison
    ipw_outcome = sum(yname * ipw_weight, na.rm=TRUE) / sum(ipw_weight, na.rm=TRUE),
    .groups = 'drop'
  )

# Calculate treatment effect
ate_survey_weighted <- survey_weighted_est$weighted_outcome[2] - survey_weighted_est$weighted_outcome[1]
ate_ipw_only <- survey_weighted_est$ipw_outcome[2] - survey_weighted_est$ipw_outcome[1]

cat("Treatment Effect Estimates:\n")
cat("IPW only:", round(ate_ipw_only, 4), "\n")
cat("IPW + Survey weights:", round(ate_survey_weighted, 4), "\n")

print(survey_weighted_est)

# ============================================================================
# COVARIATE BALANCE ASSESSMENT
# ============================================================================

cat("\n=== COVARIATE BALANCE ASSESSMENT ===\n")

# Calculate standardized mean differences before and after weighting
balance_assessment <- function(data, weight_var = NULL, weight_name = "Unweighted") {
  if(is.null(weight_var)) {
    weight_var <- rep(1, nrow(data))
  }
  
  treated <- data[data$zname == 1, ]
  control <- data[data$zname == 0, ]
  wt_treated <- weight_var[data$zname == 1]
  wt_control <- weight_var[data$zname == 0]
  
  balance_results <- tibble()
  
  for(var in covariates) {
    # Weighted means
    mean_t <- sum(treated[[var]] * wt_treated, na.rm=TRUE) / sum(wt_treated, na.rm=TRUE)
    mean_c <- sum(control[[var]] * wt_control, na.rm=TRUE) / sum(wt_control, na.rm=TRUE)
    
    # Weighted variances
    var_t <- sum(wt_treated * (treated[[var]] - mean_t)^2, na.rm=TRUE) / sum(wt_treated, na.rm=TRUE)
    var_c <- sum(wt_control * (control[[var]] - mean_c)^2, na.rm=TRUE) / sum(wt_control, na.rm=TRUE)
    
    # Standardized mean difference
    smd <- (mean_t - mean_c) / sqrt((var_t + var_c) / 2)
    
    balance_results <- bind_rows(balance_results, 
                               tibble(variable = var, 
                                     method = weight_name,
                                     mean_treated = round(mean_t, 3),
                                     mean_control = round(mean_c, 3),
                                     smd = round(smd, 3)))
  }
  return(balance_results)
}

# Calculate balance for different weighting schemes
balance_unweighted <- balance_assessment(psweight_data, weight_name = "Unweighted")
balance_ipw <- balance_assessment(psweight_data, psweight_data$ipw_weight, "IPW")
balance_ow <- balance_assessment(psweight_data, psweight_data$ow_weight, "Overlap")
balance_survey <- balance_assessment(psweight_data, psweight_data$composite_weight, "IPW+Survey")

# Combine results
balance_results <- bind_rows(balance_unweighted, balance_ipw, balance_ow, balance_survey)

cat("STANDARDIZED MEAN DIFFERENCES:\n")
balance_wide <- balance_results %>%
  select(variable, method, smd) %>%
  pivot_wider(names_from = method, values_from = smd)

print(balance_wide)

# ============================================================================
# VISUALIZATION
# ============================================================================

cat("\n=== Creating Balance Plot ===\n")

# Create balance plot
pdf("covariate_balance_plot.pdf", width = 10, height = 6)

p1 <- ggplot(balance_results, aes(x = variable, y = abs(smd), fill = method)) +
  geom_col(position = "dodge", alpha = 0.8) +
  geom_hline(yintercept = 0.1, linetype = "dashed", color = "red") +
  labs(
    title = "Covariate Balance Assessment: Standardized Mean Differences",
    subtitle = "Red line indicates SMD = 0.1 threshold for good balance",
    x = "Covariates",
    y = "Absolute Standardized Mean Difference",
    fill = "Weighting Method"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  scale_fill_brewer(type = "qual", palette = "Set2")

print(p1)
dev.off()

# Propensity score distribution plot
pdf("propensity_score_distribution.pdf", width = 10, height = 6)

p2 <- ggplot(psweight_data, aes(x = ps, fill = factor(zname))) +
  geom_histogram(alpha = 0.7, bins = 30, position = "identity") +
  labs(
    title = "Propensity Score Distribution by Treatment Group",
    x = "Propensity Score",
    y = "Frequency",
    fill = "Treatment"
  ) +
  scale_fill_manual(values = c("0" = "blue", "1" = "red"), 
                   labels = c("0" = "No Tobacco", "1" = "Tobacco Use")) +
  theme_minimal()

print(p2)
dev.off()

# ============================================================================
# FINAL RESULTS SUMMARY
# ============================================================================

cat("\n=== FINAL RESULTS SUMMARY ===\n")
cat("Research Question: Causal effect of tobacco use on poor health status\n")
cat("Population: US adults and adolescents (NSDUH 2023)\n")
cat("Sample size:", nrow(psweight_data), "observations\n\n")

cat("TREATMENT EFFECT ESTIMATES (Risk Difference):\n")
cat("Method 1 - IPW:", sprintf("%.4f", ipw_result$estimates[1,1]), 
    "(95% CI:", sprintf("%.4f", ipw_result$estimates[1,3]), "to", 
    sprintf("%.4f", ipw_result$estimates[1,4]), ")\n")

cat("Method 2 - Overlap Weights:", sprintf("%.4f", ow_result$estimates[1,1]), 
    "(95% CI:", sprintf("%.4f", ow_result$estimates[1,3]), "to", 
    sprintf("%.4f", ow_result$estimates[1,4]), ")\n")

cat("Method 3 - AIPW:", sprintf("%.4f", aipw_result$estimates[1,1]), 
    "(95% CI:", sprintf("%.4f", aipw_result$estimates[1,3]), "to", 
    sprintf("%.4f", aipw_result$estimates[1,4]), ")\n")

cat("Method 4 - IPW + Survey Weights:", sprintf("%.4f", ate_survey_weighted), "\n\n")

cat("INTERPRETATION:\n")
effect_size <- ow_result$estimates[1,1]  # Use overlap weights as primary estimate
if(effect_size > 0) {
  cat("Tobacco use is associated with a", sprintf("%.1f", effect_size*100), 
      "percentage point INCREASE in probability of poor/fair health.\n")
} else {
  cat("Tobacco use is associated with a", sprintf("%.1f", abs(effect_size)*100), 
      "percentage point DECREASE in probability of poor/fair health.\n")
}

cat("\nCOVARIATE BALANCE:\n")
best_balance <- balance_wide %>%
  summarise(across(where(is.numeric), ~mean(abs(.x), na.rm=TRUE))) %>%
  pivot_longer(everything(), names_to = "method", values_to = "mean_abs_smd")

print(best_balance)

cat("\nFILES CREATED:\n")
cat("- covariate_balance_plot.pdf\n")
cat("- propensity_score_distribution.pdf\n")

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("This analysis demonstrates proper use of PSweight package with survey data.\n")
cat("Overlap weights generally provide the best balance and efficiency.\n")
cat("Survey weights should be incorporated for population-level inference.\n") 