################################################################################
# PAPER 2: Miketinas et al. 2023 - Dietary Fiber → Fasting Glucose
# STEP 1: REPLICATE EXACT RESULTS
################################################################################

rm(list = ls())
library(dplyr)
library(haven)

cat("\n")
cat("==============================================================================\n")
cat("   PAPER 2: Miketinas et al. 2023 - Fiber → Glucose\n")
cat("   STEP 1: REPLICATE EXACT RESULTS\n")
cat("==============================================================================\n")

# Load data
cat("\nLoading NHANES data...\n")
load("data/nhanes_2007_2018.rda")
nhanes <- nhanes_2007_2018

cat("Total observations:", nrow(nhanes), "\n")

# Miketinas 2023 specifications
cat("\n")
cat("==============================================================================\n")
cat("   MIKETINAS 2023 SPECIFICATIONS\n")
cat("==============================================================================\n")
cat("\nCitation: Miketinas et al. (2023) Cambridge University Press\n")
cat("Research Question: Does dietary fiber reduce fasting glucose?\n")
cat("\nData:\n")
cat("  - NHANES 2013-2018\n")
cat("  - Non-diabetics only\n")
cat("\nMethod:\n")
cat("  - Linear regression, Model 3 (fully adjusted)\n")
cat("\nTarget Result:\n")
cat("  - β = -0.92 mg/dL [95% CI: -1.82, -0.02]\n")
cat("  - Per gram increase in dietary fiber\n")
cat("  - Also reports HOMA-IR: β = -0.05 [-0.19, 0.09] (NS)\n")

# Check variables
cat("\n")
cat("==============================================================================\n")
cat("   VARIABLE CHECK\n")
cat("==============================================================================\n")

vars_check <- c("dr1tfibe", "dr2tfibe", "lbxsgl", "diq010", "year")

cat("\nChecking required variables:\n")
for(v in vars_check) {
  if(v %in% names(nhanes)) {
    cat("  ✅", v, "\n")
  } else {
    cat("  ❌ MISSING:", v, "\n")
    # Try alternatives
    alt <- names(nhanes)[grep(gsub("[0-9]", "", v), names(nhanes), ignore.case = TRUE)]
    if(length(alt) > 0) {
      cat("    Alternatives:", paste(head(alt, 5), collapse = ", "), "\n")
    }
  }
}

# Filter to 2013-2018
cat("\n")
cat("==============================================================================\n")
cat("   DATA PREPARATION\n")
cat("==============================================================================\n")

cat("\nStep 1: Filter to NHANES 2013-2018...\n")
data_1318 <- nhanes %>%
  filter(year >= 2013 & year <= 2018)
cat("  N =", nrow(data_1318), "\n")

# Exclude diabetics
cat("\nStep 2: Exclude diabetics...\n")
if("diq010" %in% names(data_1318)) {
  cat("  Diabetes distribution:\n")
  print(table(data_1318$diq010, useNA = "always"))
  
  data_nodiab <- data_1318 %>%
    filter(diq010 == 2 | is.na(diq010))
  
  cat("  Non-diabetics: N =", nrow(data_nodiab), "\n")
} else {
  cat("  ⚠️ diq010 not found\n")
  data_nodiab <- data_1318
}

# Calculate average dietary fiber
cat("\nStep 3: Calculate average dietary fiber intake...\n")

if("dr1tfibe" %in% names(data_nodiab) & "dr2tfibe" %in% names(data_nodiab)) {
  data_nodiab <- data_nodiab %>%
    mutate(
      fiber_avg = case_when(
        !is.na(dr1tfibe) & !is.na(dr2tfibe) ~ (dr1tfibe + dr2tfibe) / 2,
        !is.na(dr1tfibe) ~ dr1tfibe,
        !is.na(dr2tfibe) ~ dr2tfibe,
        TRUE ~ NA_real_
      )
    )
  
  cat("  Fiber variable created (average of 2 recalls)\n")
  cat("  Day 1 recall available:", sum(!is.na(data_nodiab$dr1tfibe)), "\n")
  cat("  Day 2 recall available:", sum(!is.na(data_nodiab$dr2tfibe)), "\n")
  cat("  Average fiber available:", sum(!is.na(data_nodiab$fiber_avg)), "\n")
  
} else {
  cat("  ❌ Dietary recall variables not found\n")
  stop("Cannot proceed without fiber data")
}

# Require serum glucose
cat("\nStep 4: Require serum glucose...\n")

if("lbxsgl" %in% names(data_nodiab)) {
  analytic_data <- data_nodiab %>%
    filter(!is.na(fiber_avg) & !is.na(lbxsgl)) %>%
    filter(fiber_avg > 0 & lbxsgl > 0)
  
  cat("  Complete cases: N =", nrow(analytic_data), "\n")
  
} else {
  cat("  ❌ Serum glucose (lbxsgl) not found\n")
  stop("Cannot proceed without glucose data")
}

# Descriptive statistics
cat("\n")
cat("==============================================================================\n")
cat("   DESCRIPTIVE STATISTICS\n")
cat("==============================================================================\n")

if(nrow(analytic_data) > 0) {
  cat("\nDietary Fiber (g/day):\n")
  cat("  Mean (SD):", round(mean(analytic_data$fiber_avg, na.rm=T), 2),
      "(", round(sd(analytic_data$fiber_avg, na.rm=T), 2), ")\n")
  cat("  Range:", round(min(analytic_data$fiber_avg, na.rm=T), 2), "-",
      round(max(analytic_data$fiber_avg, na.rm=T), 2), "\n")
  
  cat("\nSerum Glucose (mg/dL):\n")
  cat("  Mean (SD):", round(mean(analytic_data$lbxsgl, na.rm=T), 2),
      "(", round(sd(analytic_data$lbxsgl, na.rm=T), 2), ")\n")
  cat("  Range:", round(min(analytic_data$lbxsgl, na.rm=T), 2), "-",
      round(max(analytic_data$lbxsgl, na.rm=T), 2), "\n")
}

# Regression analysis
cat("\n")
cat("==============================================================================\n")
cat("   REGRESSION ANALYSIS\n")
cat("==============================================================================\n")

if(nrow(analytic_data) >= 100) {
  
  # Unadjusted model
  cat("\nMODEL 1: UNADJUSTED\n")
  model1 <- lm(lbxsgl ~ fiber_avg, data = analytic_data)
  
  beta1 <- coef(model1)["fiber_avg"]
  ci1 <- confint(model1)["fiber_avg", ]
  
  cat("  β =", round(beta1, 3), "mg/dL per gram fiber\n")
  cat("  95% CI: [", round(ci1[1], 3), ", ", round(ci1[2], 3), "]\n", sep="")
  cat("  p-value:", format.pval(summary(model1)$coefficients["fiber_avg", "Pr(>|t|)"], digits=3), "\n")
  
  # Adjusted model (if covariates available)
  covs_available <- intersect(c("ridageyr", "riagendr", "ridreth1", "dmdeduc2", 
                                "indfmpir", "smq020", "bmxbmi"), 
                              names(analytic_data))
  
  if(length(covs_available) > 0) {
    cat("\nMODEL 2: ADJUSTED\n")
    cat("  Covariates:", paste(covs_available, collapse = ", "), "\n")
    
    # Complete cases for adjusted model
    complete_adj <- analytic_data[complete.cases(analytic_data[, c("lbxsgl", "fiber_avg", covs_available)]), ]
    cat("  N (complete):", nrow(complete_adj), "\n")
    
    formula_adj <- as.formula(paste("lbxsgl ~ fiber_avg +", 
                                     paste(covs_available, collapse = " + ")))
    model2 <- lm(formula_adj, data = complete_adj)
    
    beta2 <- coef(model2)["fiber_avg"]
    ci2 <- confint(model2)["fiber_avg", ]
    
    cat("  β =", round(beta2, 3), "mg/dL per gram fiber\n")
    cat("  95% CI: [", round(ci2[1], 3), ", ", round(ci2[2], 3), "]\n", sep="")
    cat("  p-value:", format.pval(summary(model2)$coefficients["fiber_avg", "Pr(>|t|)"], digits=3), "\n")
  }
  
  # Alignment check
  cat("\n")
  cat("==============================================================================\n")
  cat("   ALIGNMENT CHECK\n")
  cat("==============================================================================\n")
  
  cat("\nMiketinas 2023 (Target, Model 3 fully adjusted):\n")
  cat("  β = -0.92 [-1.82, -0.02] mg/dL\n")
  
  cat("\nOur Replication:\n")
  if(exists("beta2")) {
    cat("  Adjusted β =", round(beta2, 3), 
        " [", round(ci2[1], 3), ", ", round(ci2[2], 3), "]\n", sep="")
    
    match_pct <- round(100 * abs(beta2 / -0.92), 1)
    cat("\nβ Match:", match_pct, "%\n")
    
    if(abs(abs(beta2) - 0.92) / 0.92 < 0.2) {
      cat("✅ GOOD ALIGNMENT (within 20%)\n")
      cat("\nNote: Direction should be negative (fiber ↓ glucose)\n")
    } else {
      cat("⚠️ PARTIAL ALIGNMENT (>20% difference)\n")
      cat("\nPossible reasons:\n")
      cat("  - Different covariate adjustment (we may not have all Model 3 vars)\n")
      cat("  - Different handling of dietary recalls\n")
      cat("  - Different diabetes exclusion criteria\n")
    }
  } else {
    cat("  Unadjusted β =", round(beta1, 3), 
        " [", round(ci1[1], 3), ", ", round(ci1[2], 3), "]\n", sep="")
    cat("\n⚠️ No adjusted model (missing covariates)\n")
  }
  
  # Save
  save(analytic_data, model1, 
       file = "PAPER2_MIKETINAS_2023_VERIFIED_DATA.rda")
  if(exists("model2")) {
    save(analytic_data, model1, model2, complete_adj,
         file = "PAPER2_MIKETINAS_2023_VERIFIED_DATA.rda")
  }
  
  cat("\n✅ Data saved: PAPER2_MIKETINAS_2023_VERIFIED_DATA.rda\n")
  
} else {
  cat("❌ Insufficient data (N < 100)\n")
}

cat("\n")
cat("==============================================================================\n")
cat("   STEP 1 COMPLETE\n")
cat("==============================================================================\n")

cat("\nNext step:\n")
cat("  If alignment is good (≥80%), proceed to Step 2:\n")
cat("  - Apply all 5 matching methods\n")
cat("  - Compare sample vs population estimates\n")
