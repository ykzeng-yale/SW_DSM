# NSDUH 2023 Propensity Score Weighting Analysis using PSweight (Fixed Version)
# Estimating Population Average Treatment Effect (PATE) with Survey Weights

# Install and load required packages
if (!require("PSweight")) {
  install.packages("PSweight")
  library(PSweight)
}

library(dplyr)
library(ggplot2)

# Load the NSDUH 2023 data
load("NSDUH_2023.Rdata")
data <- puf2023_102124

cat("=== NSDUH 2023 PROPENSITY SCORE WEIGHTING ANALYSIS ===\n\n")

# ============================================================================
# RESEARCH QUESTION: 
# What is the causal effect of tobacco use on health outcomes?
# Treatment: Past year tobacco use (TOBYR)
# Outcome: Poor health status (binary)
# ============================================================================

cat("RESEARCH QUESTION:\n")
cat("Causal effect of past-year tobacco use on self-reported poor health\n")
cat("Treatment: TOBYR (0=No tobacco use, 1=Tobacco use in past year)\n")
cat("Outcome: Poor/Fair health (1) vs Good/Very Good/Excellent health (0)\n\n")

# Prepare the analysis dataset with careful data cleaning
analysis_data <- data %>%
  filter(
    !is.na(TOBYR),      # Treatment variable
    !is.na(HEALTH2),    # Outcome variable
    !is.na(AGE3),       # Age
    !is.na(IRSEX),      # Sex
    !is.na(ANALWT2_C),  # Survey weights
    TOBYR %in% c(0, 1), # Valid treatment values
    HEALTH2 %in% 1:5    # Valid health values
  ) %>%
  mutate(
    # Binary outcome: 1 = Poor/Fair health, 0 = Good/Very Good/Excellent
    poor_health = ifelse(HEALTH2 %in% c(1, 2), 1, 0),
    
    # Treatment (already binary)
    tobacco_use = TOBYR,
    
    # Age groups (simplified)
    age_18_25 = ifelse(AGE3 %in% 4:6, 1, 0),
    age_26_49 = ifelse(AGE3 %in% 7:9, 1, 0),
    age_50plus = ifelse(AGE3 %in% 10:11, 1, 0),
    # Reference: 12-17 years (AGE3 1-3)
    
    # Male indicator
    male = ifelse(IRSEX == 1, 1, 0),
    
    # Race indicators (simplified, handling missing values)
    white = ifelse(!is.na(NEWRACE2) & NEWRACE2 == 1, 1, 0),
    
    # Education (handling missing values)
    college = case_when(
      is.na(IREDUHIGHST2) ~ 0,
      IREDUHIGHST2 >= 11 ~ 1,
      TRUE ~ 0
    ),
    
    # Income (handling missing values)
    high_income = case_when(
      is.na(INCOME) ~ 0,
      INCOME >= 7 ~ 1,
      TRUE ~ 0
    )
  ) %>%
  select(tobacco_use, poor_health, age_18_25, age_26_49, age_50plus, 
         male, white, college, high_income, ANALWT2_C) %>%
  # Ensure no missing values in final dataset
  filter(complete.cases(.))

cat("ANALYSIS DATASET SUMMARY:\n")
cat("Sample size after cleaning:", nrow(analysis_data), "\n")
cat("Treatment prevalence:", round(mean(analysis_data$tobacco_use)*100, 1), "%\n")
cat("Outcome prevalence:", round(mean(analysis_data$poor_health)*100, 1), "%\n\n")

# Check covariate balance
cat("COVARIATE BALANCE (Unweighted):\n")
balance_check <- analysis_data %>%
  group_by(tobacco_use) %>%
  summarise(
    n = n(),
    poor_health_pct = round(mean(poor_health)*100, 1),
    age_18_25_pct = round(mean(age_18_25)*100, 1),
    age_26_49_pct = round(mean(age_26_49)*100, 1),
    age_50plus_pct = round(mean(age_50plus)*100, 1),
    male_pct = round(mean(male)*100, 1),
    white_pct = round(mean(white)*100, 1),
    college_pct = round(mean(college)*100, 1),
    high_income_pct = round(mean(high_income)*100, 1),
    .groups = 'drop'
  )

print(balance_check)

# ============================================================================
# PREPARE DATA FOR PSweight (Convert to base R data.frame)
# ============================================================================

# Convert to base R data.frame format (PSweight may have issues with tibbles)
psweight_data <- as.data.frame(analysis_data)

# Rename variables for PSweight
names(psweight_data)[names(psweight_data) == "tobacco_use"] <- "zname"
names(psweight_data)[names(psweight_data) == "poor_health"] <- "yname"

cat("\n=== PROPENSITY SCORE ESTIMATION ===\n")
cat("Final analysis sample:", nrow(psweight_data), "observations\n")

# Define covariates
covariates <- c("age_18_25", "age_26_49", "age_50plus", "male", "white", "college", "high_income")

# Create formula
ps_formula <- as.formula(paste("zname ~", paste(covariates, collapse = " + ")))
cat("Propensity score model:", deparse(ps_formula), "\n\n")

# ============================================================================
# Method 1: Inverse Probability Weighting (IPW)
# ============================================================================

cat("=== METHOD 1: IPW WEIGHTING ===\n")

tryCatch({
  # Estimate IPW
  ps_ipw <- PSweight(
    ps.formula = ps_formula,
    yname = "yname",
    data = psweight_data,
    weight = "IPW"
  )
  
  cat("IPW TREATMENT EFFECT ESTIMATE:\n")
  print(ps_ipw$estimates)
  
  # Store propensity scores and weights
  psweight_data$ps <- ps_ipw$propensity[,2]
  psweight_data$ipw_weights <- ps_ipw$W
  
  # Show propensity score summary
  cat("\nPROPENSITY SCORE DISTRIBUTION:\n")
  ps_summary <- aggregate(psweight_data$ps, 
                         by = list(Treatment = psweight_data$zname), 
                         FUN = function(x) c(min = min(x), median = median(x), max = max(x)))
  print(ps_summary)
  
}, error = function(e) {
  cat("Error in IPW estimation:", e$message, "\n")
})

# ============================================================================
# Method 2: Overlap Weighting (Recommended method)
# ============================================================================

cat("\n=== METHOD 2: OVERLAP WEIGHTING ===\n")

tryCatch({
  # Estimate Overlap Weights
  ps_ow <- PSweight(
    ps.formula = ps_formula,
    yname = "yname",
    data = psweight_data,
    weight = "overlap"
  )
  
  cat("OVERLAP WEIGHTING TREATMENT EFFECT ESTIMATE:\n")
  print(ps_ow$estimates)
  
  # Store overlap weights
  psweight_data$ow_weights <- ps_ow$W
  
}, error = function(e) {
  cat("Error in Overlap Weight estimation:", e$message, "\n")
})

# ============================================================================
# Method 3: Manual IPW calculation for comparison
# ============================================================================

cat("\n=== METHOD 3: MANUAL IPW CALCULATION ===\n")

# Manual propensity score estimation using logistic regression
ps_model <- glm(ps_formula, family = binomial, data = psweight_data)

cat("PROPENSITY SCORE MODEL SUMMARY:\n")
print(summary(ps_model))

# Calculate propensity scores
psweight_data$ps_manual <- predict(ps_model, type = "response")

# Calculate IPW weights manually
psweight_data$ipw_manual <- ifelse(psweight_data$zname == 1, 
                                  1/psweight_data$ps_manual,
                                  1/(1 - psweight_data$ps_manual))

# Estimate treatment effect
treated_outcome <- with(psweight_data[psweight_data$zname == 1, ], 
                       sum(yname * ipw_manual) / sum(ipw_manual))
control_outcome <- with(psweight_data[psweight_data$zname == 0, ], 
                       sum(yname * ipw_manual) / sum(ipw_manual))

ate_manual <- treated_outcome - control_outcome

cat("\nMANUAL IPW ESTIMATES:\n")
cat("Treated group outcome:", round(treated_outcome, 4), "\n")
cat("Control group outcome:", round(control_outcome, 4), "\n")
cat("Average Treatment Effect:", round(ate_manual, 4), "\n")

# ============================================================================
# Method 4: Incorporating Survey Weights
# ============================================================================

cat("\n=== METHOD 4: IPW WITH SURVEY WEIGHTS ===\n")

# Combine IPW weights with survey weights
psweight_data$combined_weights <- psweight_data$ipw_manual * psweight_data$ANALWT2_C

# Estimate treatment effect with combined weights
treated_outcome_survey <- with(psweight_data[psweight_data$zname == 1, ], 
                              sum(yname * combined_weights) / sum(combined_weights))
control_outcome_survey <- with(psweight_data[psweight_data$zname == 0, ], 
                              sum(yname * combined_weights) / sum(combined_weights))

ate_survey <- treated_outcome_survey - control_outcome_survey

cat("SURVEY-WEIGHTED IPW ESTIMATES:\n")
cat("Treated group outcome:", round(treated_outcome_survey, 4), "\n")
cat("Control group outcome:", round(control_outcome_survey, 4), "\n")
cat("Population Average Treatment Effect:", round(ate_survey, 4), "\n")

# ============================================================================
# Covariate Balance Assessment
# ============================================================================

cat("\n=== COVARIATE BALANCE ASSESSMENT ===\n")

# Function to calculate standardized mean differences
calc_smd <- function(data, treatment_var, weight_var = NULL) {
  if (is.null(weight_var)) {
    weight_var <- rep(1, nrow(data))
  }
  
  smd_results <- data.frame()
  
  for (var in covariates) {
    # Treated group
    treated_data <- data[data[[treatment_var]] == 1, ]
    treated_weights <- weight_var[data[[treatment_var]] == 1]
    treated_mean <- sum(treated_data[[var]] * treated_weights) / sum(treated_weights)
    treated_var <- sum(treated_weights * (treated_data[[var]] - treated_mean)^2) / sum(treated_weights)
    
    # Control group
    control_data <- data[data[[treatment_var]] == 0, ]
    control_weights <- weight_var[data[[treatment_var]] == 0]
    control_mean <- sum(control_data[[var]] * control_weights) / sum(control_weights)
    control_var <- sum(control_weights * (control_data[[var]] - control_mean)^2) / sum(control_weights)
    
    # Standardized mean difference
    pooled_sd <- sqrt((treated_var + control_var) / 2)
    smd <- (treated_mean - control_mean) / pooled_sd
    
    smd_results <- rbind(smd_results, 
                        data.frame(variable = var, 
                                  treated_mean = treated_mean,
                                  control_mean = control_mean,
                                  smd = smd))
  }
  
  return(smd_results)
}

# Calculate SMD before and after weighting
smd_unweighted <- calc_smd(psweight_data, "zname")
smd_ipw <- calc_smd(psweight_data, "zname", psweight_data$ipw_manual)
smd_survey <- calc_smd(psweight_data, "zname", psweight_data$combined_weights)

cat("STANDARDIZED MEAN DIFFERENCES:\n")
cat("\nUnweighted:\n")
print(round(smd_unweighted, 3))

cat("\nIPW Weighted:\n")
print(round(smd_ipw, 3))

cat("\nIPW + Survey Weighted:\n")
print(round(smd_survey, 3))

# ============================================================================
# Summary of Results
# ============================================================================

cat("\n=== FINAL RESULTS SUMMARY ===\n")
cat("Research Question: Causal effect of tobacco use on poor health status\n")
cat("Population: US population aged 12+ (NSDUH 2023)\n")
cat("Sample size:", nrow(psweight_data), "observations\n")
cat("Treatment prevalence:", round(mean(psweight_data$zname)*100, 1), "%\n")
cat("Outcome prevalence:", round(mean(psweight_data$yname)*100, 1), "%\n\n")

cat("TREATMENT EFFECT ESTIMATES:\n")
cat("Manual IPW:", sprintf("%.4f", ate_manual), 
    "(", sprintf("%.1f", ate_manual*100), "percentage points)\n")
cat("IPW + Survey Weights (PATE):", sprintf("%.4f", ate_survey), 
    "(", sprintf("%.1f", ate_survey*100), "percentage points)\n\n")

cat("INTERPRETATION:\n")
if(ate_survey > 0) {
  cat("Tobacco use is associated with a", sprintf("%.1f", ate_survey*100), 
      "percentage point INCREASE in probability of poor/fair health status.\n")
} else {
  cat("Tobacco use is associated with a", sprintf("%.1f", abs(ate_survey)*100), 
      "percentage point DECREASE in probability of poor/fair health status.\n")
}

cat("\nCOVARIATE BALANCE IMPROVEMENT:\n")
mean_smd_unweighted <- mean(abs(smd_unweighted$smd))
mean_smd_weighted <- mean(abs(smd_survey$smd))
cat("Mean absolute SMD before weighting:", sprintf("%.3f", mean_smd_unweighted), "\n")
cat("Mean absolute SMD after weighting:", sprintf("%.3f", mean_smd_weighted), "\n")
cat("Balance improvement:", sprintf("%.1f%%", (1 - mean_smd_weighted/mean_smd_unweighted)*100), "\n")

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("This analysis demonstrates propensity score weighting with NSDUH survey data.\n")
cat("The Population Average Treatment Effect (PATE) incorporates survey weights\n")
cat("for proper population-level inference.\n") 