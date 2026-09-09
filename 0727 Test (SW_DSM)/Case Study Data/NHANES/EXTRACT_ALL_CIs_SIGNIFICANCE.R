################################################################################
# EXTRACT CONFIDENCE INTERVALS & SIGNIFICANCE FOR ALL 4 CONTINUOUS OUTCOMES
# Check if significance changes between sample and population estimates
################################################################################

rm(list = ls())
options(scipen = 999)

cat("\n")
cat("==============================================================================\n")
cat("   CONFIDENCE INTERVALS & SIGNIFICANCE CHANGES\n")
cat("   (Does nonsignificant become significant or vice versa?)\n")
cat("==============================================================================\n")

# Load all continuous outcome results
load("analysis_results/continuous1_waist_uric_acid.rda")
load("analysis_results/continuous2_obesity_sbp.rda")
load("analysis_results/continuous3_mvpa_hba1c.rda")
if(file.exists("analysis_results/continuous4_lead_egfr.rda")) {
  load("analysis_results/continuous4_lead_egfr.rda")
  has_lead <- TRUE
} else {
  has_lead <- FALSE
}

check_significance <- function(est, ci_lower, ci_upper, outcome_name, method_name) {
  significant <- !(ci_lower <= 0 & ci_upper >= 0)
  
  cat(sprintf("\n%-30s | Est: %+.3f | 95%% CI: [%+.3f, %+.3f] | %s\n",
              method_name, est, ci_lower, ci_upper,
              ifelse(significant, "✓ SIGNIFICANT", "✗ NOT significant")))
  
  return(list(sig = significant, est = est, ci_lower = ci_lower, ci_upper = ci_upper))
}

################################################################################
# ANALYSIS #1: HIGH WAIST → URIC ACID
################################################################################

cat("\n")
cat("========================================================================\n")
cat("  ANALYSIS #1: High Waist → Serum Uric Acid (mg/dL)\n")
cat("========================================================================\n")

sig1_unwt <- check_significance(
  uric_results$unweighted_psm$ate,
  uric_results$unweighted_psm$ci_lower,
  uric_results$unweighted_psm$ci_upper,
  "Uric Acid", "Unwt PSM (SAMPLE)"
)

sig1_wt <- check_significance(
  uric_results$weighted_reg$ate,
  uric_results$weighted_reg$ci_lower,
  uric_results$weighted_reg$ci_upper,
  "Uric Acid", "Weighted Reg (POPULATION)"
)

sig1_dsm <- check_significance(
  uric_results$dsm$ate,
  uric_results$dsm$ci_lower,
  uric_results$dsm$ci_upper,
  "Uric Acid", "Unwt DSM (SAMPLE)"
)

cat("\n💡 SIGNIFICANCE COMPARISON:\n")
if(sig1_unwt$sig != sig1_wt$sig) {
  cat("   ⚠️  SIGNIFICANCE CHANGES!\n")
  if(sig1_unwt$sig & !sig1_wt$sig) {
    cat("   Sample: Significant → Population: NOT significant\n")
  } else {
    cat("   Sample: NOT significant → Population: Significant\n")
  }
} else {
  if(sig1_unwt$sig) {
    cat("   Both sample AND population are SIGNIFICANT ✓\n")
  } else {
    cat("   Both sample AND population are NOT significant\n")
  }
}

cat("   Sample estimate:", round(sig1_unwt$est, 3), "mg/dL\n")
cat("   Population estimate:", round(sig1_wt$est, 3), "mg/dL\n")
cat("   Difference:", round(100*(sig1_unwt$est - sig1_wt$est)/sig1_wt$est, 1), "%\n")

################################################################################
# ANALYSIS #2: OBESITY → SYSTOLIC BP
################################################################################

cat("\n")
cat("========================================================================\n")
cat("  ANALYSIS #2: Obesity → Systolic Blood Pressure (mmHg)\n")
cat("========================================================================\n")

cat("\n⚠️  Note: Need to re-extract CIs from sbp_results\n")
cat("Current results only have point estimates\n")
cat("Re-running to get CIs...\n")

# Load the full data and recompute with CIs
if(exists("sbp_data")) {
  
  # Unwt PSM - need to recompute with CI
  library(MatchIt)
  ps_formula_sbp <- as.formula(paste("A ~", paste(c("age", "female", "race1", "pir"), collapse = " + ")))
  m_unwt_sbp <- matchit(ps_formula_sbp, data = sbp_data, method = "nearest", ratio = 1)
  md_unwt_sbp <- match.data(m_unwt_sbp)
  model_unwt_sbp <- lm(Y ~ A, data = md_unwt_sbp)
  
  est_unwt_sbp <- coef(model_unwt_sbp)["A"]
  ci_unwt_sbp <- confint(model_unwt_sbp)["A", ]
  
  sig2_unwt <- check_significance(
    est_unwt_sbp, ci_unwt_sbp[1], ci_unwt_sbp[2],
    "SBP", "Unwt PSM (SAMPLE)"
  )
  
  # Weighted - need CI
  library(survey)
  options(survey.lonely.psu = "adjust")
  svy_sbp <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, weights = ~wtmec2yr,
                       nest = TRUE, data = sbp_data)
  formula_adj_sbp <- as.formula(paste("Y ~ A +", paste(c("age", "female", "race1", "pir"), collapse = " + ")))
  model_wt_sbp <- svyglm(formula_adj_sbp, design = svy_sbp)
  
  est_wt_sbp <- coef(model_wt_sbp)["A"]
  ci_wt_sbp <- confint(model_wt_sbp)["A", ]
  
  sig2_wt <- check_significance(
    est_wt_sbp, ci_wt_sbp[1], ci_wt_sbp[2],
    "SBP", "Weighted Reg (POPULATION)"
  )
  
  cat("\n💡 SIGNIFICANCE COMPARISON:\n")
  if(sig2_unwt$sig != sig2_wt$sig) {
    cat("   ⚠️  SIGNIFICANCE CHANGES!\n")
  } else {
    if(sig2_unwt$sig) {
      cat("   Both sample AND population are SIGNIFICANT ✓\n")
    }
  }
  
} else {
  cat("   Data not available in current environment\n")
}

################################################################################
# ANALYSIS #3: MVPA → HbA1c
################################################################################

cat("\n")
cat("========================================================================\n")
cat("  ANALYSIS #3: MVPA → HbA1c (%)\n")
cat("========================================================================\n")

if(exists("hba1c_data")) {
  
  # Unwt PSM
  ps_formula_hba <- as.formula(paste("A ~", paste(c("age", "female", "race1", "bmi", "pir"), collapse = " + ")))
  m_unwt_hba <- matchit(ps_formula_hba, data = hba1c_data, method = "nearest", ratio = 1)
  md_unwt_hba <- match.data(m_unwt_hba)
  model_unwt_hba <- lm(Y ~ A, data = md_unwt_hba)
  
  est_unwt_hba <- coef(model_unwt_hba)["A"]
  ci_unwt_hba <- confint(model_unwt_hba)["A", ]
  
  sig3_unwt <- check_significance(
    est_unwt_hba, ci_unwt_hba[1], ci_unwt_hba[2],
    "HbA1c", "Unwt PSM (SAMPLE)"
  )
  
  # Weighted
  svy_hba <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, weights = ~wtmec2yr,
                       nest = TRUE, data = hba1c_data)
  formula_adj_hba <- as.formula(paste("Y ~ A +", paste(c("age", "female", "race1", "bmi", "pir"), collapse = " + ")))
  model_wt_hba <- svyglm(formula_adj_hba, design = svy_hba)
  
  est_wt_hba <- coef(model_wt_hba)["A"]
  ci_wt_hba <- confint(model_wt_hba)["A", ]
  
  sig3_wt <- check_significance(
    est_wt_hba, ci_wt_hba[1], ci_wt_hba[2],
    "HbA1c", "Weighted Reg (POPULATION)"
  )
  
  cat("\n💡 SIGNIFICANCE COMPARISON:\n")
  if(sig3_unwt$sig != sig3_wt$sig) {
    cat("   ⚠️  SIGNIFICANCE CHANGES!\n")
  } else {
    if(sig3_unwt$sig) {
      cat("   Both sample AND population are SIGNIFICANT ✓\n")
    }
  }
}

################################################################################
# ANALYSIS #4: LEAD → eGFR
################################################################################

cat("\n")
cat("========================================================================\n")
cat("  ANALYSIS #4: Lead → eGFR (mL/min/1.73m²)\n")
cat("========================================================================\n")

if(exists("egfr_data") && has_lead) {
  
  # Extract CIs
  ps_formula_egfr <- as.formula(paste("A ~", paste(c("age", "female", "race1", "bmi", "pir", "hypertension", "diabetes"), collapse = " + ")))
  m_unwt_egfr <- matchit(ps_formula_egfr, data = egfr_data, method = "nearest", ratio = 1)
  md_unwt_egfr <- match.data(m_unwt_egfr)
  model_unwt_egfr <- lm(Y ~ A, data = md_unwt_egfr)
  
  est_unwt_egfr <- coef(model_unwt_egfr)["A"]
  ci_unwt_egfr <- confint(model_unwt_egfr)["A", ]
  
  sig4_unwt <- check_significance(
    est_unwt_egfr, ci_unwt_egfr[1], ci_unwt_egfr[2],
    "eGFR", "Unwt PSM (SAMPLE)"
  )
  
  # Weighted
  svy_egfr <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, weights = ~wtmec2yr,
                        nest = TRUE, data = egfr_data)
  formula_adj_egfr <- as.formula(paste("Y ~ A +", paste(c("age", "female", "race1", "bmi", "pir", "hypertension", "diabetes"), collapse = " + ")))
  model_wt_egfr <- svyglm(formula_adj_egfr, design = svy_egfr)
  
  est_wt_egfr <- coef(model_wt_egfr)["A"]
  ci_wt_egfr <- confint(model_wt_egfr)["A", ]
  
  sig4_wt <- check_significance(
    est_wt_egfr, ci_wt_egfr[1], ci_wt_egfr[2],
    "eGFR", "Weighted Reg (POPULATION)"
  )
  
  cat("\n💡 SIGNIFICANCE COMPARISON:\n")
  if(sig4_unwt$sig != sig4_wt$sig) {
    cat("   ⚠️  SIGNIFICANCE CHANGES!\n")
  } else {
    if(sig4_unwt$sig) {
      cat("   Both sample AND population are SIGNIFICANT ✓\n")
    }
  }
}

################################################################################
# MASTER SUMMARY TABLE
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("        MASTER SUMMARY: CONFIDENCE INTERVALS & SIGNIFICANCE\n")
cat("==============================================================================\n")

cat("\n")
cat("Analysis          | Method      | Estimate  | 95% CI                | Significant? | Estimand\n")
cat("------------------|-------------|-----------|------------------------|--------------|----------\n")

# Analysis 1: Uric Acid
cat(sprintf("Waist → Uric Acid | Unwt PSM    | %+.3f    | [%+.3f, %+.3f]      | %-12s | Sample\n",
    sig1_unwt$est, sig1_unwt$ci_lower, sig1_unwt$ci_upper,
    ifelse(sig1_unwt$sig, "YES", "NO")))
cat(sprintf("                  | Weighted    | %+.3f    | [%+.3f, %+.3f]      | %-12s | Population\n",
    sig1_wt$est, sig1_wt$ci_lower, sig1_wt$ci_upper,
    ifelse(sig1_wt$sig, "YES", "NO")))
cat(sprintf("                  | Unwt DSM    | %+.3f    | [%+.3f, %+.3f]      | %-12s | Sample\n",
    sig1_dsm$est, sig1_dsm$ci_lower, sig1_dsm$ci_upper,
    ifelse(sig1_dsm$sig, "YES", "NO")))

# Analysis 2: SBP
if(exists("sig2_unwt")) {
  cat(sprintf("Obesity → SBP     | Unwt PSM    | %+.2f     | [%+.2f, %+.2f]        | %-12s | Sample\n",
      sig2_unwt$est, sig2_unwt$ci_lower, sig2_unwt$ci_upper,
      ifelse(sig2_unwt$sig, "YES", "NO")))
  cat(sprintf("                  | Weighted    | %+.2f     | [%+.2f, %+.2f]        | %-12s | Population\n",
      sig2_wt$est, sig2_wt$ci_lower, sig2_wt$ci_upper,
      ifelse(sig2_wt$sig, "YES", "NO")))
}

# Analysis 3: HbA1c  
if(exists("sig3_unwt")) {
  cat(sprintf("MVPA → HbA1c      | Unwt PSM    | %+.3f    | [%+.3f, %+.3f]      | %-12s | Sample\n",
      sig3_unwt$est, sig3_unwt$ci_lower, sig3_unwt$ci_upper,
      ifelse(sig3_unwt$sig, "YES", "NO")))
  cat(sprintf("                  | Weighted    | %+.3f    | [%+.3f, %+.3f]      | %-12s | Population\n",
      sig3_wt$est, sig3_wt$ci_lower, sig3_wt$ci_upper,
      ifelse(sig3_wt$sig, "YES", "NO")))
}

# Analysis 4: eGFR
if(exists("sig4_unwt") && has_lead) {
  cat(sprintf("Lead → eGFR       | Unwt PSM    | %+.2f     | [%+.2f, %+.2f]        | %-12s | Sample\n",
      sig4_unwt$est, sig4_unwt$ci_lower, sig4_unwt$ci_upper,
      ifelse(sig4_unwt$sig, "YES", "NO")))
  cat(sprintf("                  | Weighted    | %+.2f     | [%+.2f, %+.2f]        | %-12s | Population\n",
      sig4_wt$est, sig4_wt$ci_lower, sig4_wt$ci_upper,
      ifelse(sig4_wt$sig, "YES", "NO")))
}

################################################################################
# SIGNIFICANCE FLIP SUMMARY
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("               SIGNIFICANCE CHANGES: DETAILED ANALYSIS\n")
cat("==============================================================================\n")

flips <- list()

# Check Analysis 1
flips$uric <- list(
  sample_sig = sig1_unwt$sig,
  pop_sig = sig1_wt$sig,
  flipped = sig1_unwt$sig != sig1_wt$sig
)

if(exists("sig2_unwt")) {
  flips$sbp <- list(
    sample_sig = sig2_unwt$sig,
    pop_sig = sig2_wt$sig,
    flipped = sig2_unwt$sig != sig2_wt$sig
  )
}

if(exists("sig3_unwt")) {
  flips$hba1c <- list(
    sample_sig = sig3_unwt$sig,
    pop_sig = sig3_wt$sig,
    flipped = sig3_unwt$sig != sig3_wt$sig
  )
}

if(exists("sig4_unwt")) {
  flips$egfr <- list(
    sample_sig = sig4_unwt$sig,
    pop_sig = sig4_wt$sig,
    flipped = sig4_unwt$sig != sig4_wt$sig
  )
}

cat("\n")
cat("Analysis                | Sample Sig? | Population Sig? | Inference Changes?\n")
cat("------------------------|-------------|-----------------|--------------------\n")
cat(sprintf("1. Waist → Uric Acid    | %-11s | %-15s | %s\n",
    ifelse(flips$uric$sample_sig, "YES", "NO"),
    ifelse(flips$uric$pop_sig, "YES", "NO"),
    ifelse(flips$uric$flipped, "⚠️  YES - FLIPS!", "No change")))

if(!is.null(flips$sbp)) {
  cat(sprintf("2. Obesity → SBP        | %-11s | %-15s | %s\n",
      ifelse(flips$sbp$sample_sig, "YES", "NO"),
      ifelse(flips$sbp$pop_sig, "YES", "NO"),
      ifelse(flips$sbp$flipped, "⚠️  YES - FLIPS!", "No change")))
}

if(!is.null(flips$hba1c)) {
  cat(sprintf("3. MVPA → HbA1c         | %-11s | %-15s | %s\n",
      ifelse(flips$hba1c$sample_sig, "YES", "NO"),
      ifelse(flips$hba1c$pop_sig, "YES", "NO"),
      ifelse(flips$hba1c$flipped, "⚠️  YES - FLIPS!", "No change")))
}

if(!is.null(flips$egfr)) {
  cat(sprintf("4. Lead → eGFR          | %-11s | %-15s | %s\n",
      ifelse(flips$egfr$sample_sig, "YES", "NO"),
      ifelse(flips$egfr$pop_sig, "YES", "NO"),
      ifelse(flips$egfr$flipped, "⚠️  YES - FLIPS!", "No change")))
}

n_flips <- sum(sapply(flips, function(x) x$flipped))
cat("\n📊 TOTAL SIGNIFICANCE FLIPS:", n_flips, "of", length(flips), "analyses\n")

if(n_flips > 0) {
  cat("\n⚠️  CRITICAL: Using wrong estimand (sample vs population) changes\n")
  cat("   statistical inference in", n_flips, "out of", length(flips), "analyses!\n")
  cat("   This demonstrates the importance of population-valid methods.\n")
}

################################################################################
# SAVE
################################################################################

save(flips, file = "analysis_results/significance_flips_analysis.rda")

cat("\n==============================================================================\n")
cat("CONFIDENCE INTERVAL ANALYSIS COMPLETE\n")
cat("==============================================================================\n")



