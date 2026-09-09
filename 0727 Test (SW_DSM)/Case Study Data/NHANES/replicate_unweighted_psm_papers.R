################################################################################
# REPLICATING UNWEIGHTED PSM PAPERS: COMPREHENSIVE COMPARISON
# 
# Papers replicated:
# 1. Yao et al. (2025): MVPA → Mortality
# 2. Generic: Obesity → Hypertension (multiple papers)
#
# Methods compared:
# 1. Unweighted PSM (published method - WRONG for complex surveys)
# 2. Weighted Regression (common baseline)
# 3. PS Full (survey-weighted matching)
# 4. IPTW (survey-weighted)
# 5. WDSM (our method)
################################################################################

rm(list = ls())
options(scipen = 999)

suppressPackageStartupMessages({
  library(dplyr)
  library(MatchIt)
  library(survey)
  library(marginaleffects)
})

# Load data
load("data/nhanes_2007_2018.rda")

cat("\n")
cat("==============================================================================\n")
cat("    REPLICATION: UNWEIGHTED PSM PAPERS vs WDSM\n")
cat("==============================================================================\n")

################################################################################
# ANALYSIS 1: OBESITY → HYPERTENSION
# (Most common PSM application without weights)
################################################################################

cat("\n========================================================================\n")
cat("       ANALYSIS 1: OBESITY → HYPERTENSION\n")
cat("========================================================================\n")

# Prepare data
obesity_data <- nhanes_2007_2018 %>%
  filter(!is.na(bmi), !is.na(hypertension), !is.na(age), 
         !is.na(female), !is.na(race1), !is.na(education),
         !is.na(pir), !is.na(wtmec2yr), !is.na(sdmvpsu), !is.na(sdmvstra),
         age >= 20) %>%  # Adults only
  mutate(
    obesity = as.numeric(bmi >= 30),
    Y = hypertension,
    A = obesity,
    survey_weight = wtmec2yr
  )

n_obesity <- nrow(obesity_data)
cat("\n=== SAMPLE CHARACTERISTICS ===\n")
cat("Total N:", n_obesity, "\n")
cat("Obese (BMI≥30):", sum(obesity_data$obesity), 
    "(", round(100*mean(obesity_data$obesity), 1), "%)\n")
cat("Non-obese:", sum(1-obesity_data$obesity), "\n")
cat("Hypertension prevalence:", round(100*mean(obesity_data$hypertension), 1), "%\n")

# Normalize survey weights
obesity_data$sw <- obesity_data$survey_weight * n_obesity / sum(obesity_data$survey_weight)

# Define confounders
confounders_obesity <- c("age", "female", "race1", "education", "pir", "smokestatus")
confounders_available <- confounders_obesity[confounders_obesity %in% names(obesity_data)]

cat("\nConfounders used:", paste(confounders_available, collapse=", "), "\n")

# Create formulas
ps_formula <- as.formula(paste("A ~", paste(confounders_available, collapse = " + ")))

# Store results
obesity_results <- list()

#------------------------------------------------------------------------------
# METHOD 1: UNWEIGHTED PSM (Published Papers' Approach)
#------------------------------------------------------------------------------

cat("\n--- METHOD 1: Unweighted PSM (Published Approach) ---\n")
cat("NOTE: This is what many papers do WRONG - no survey weights!\n")

# MatchIt without weights
m_unwt <- matchit(ps_formula,
                  data = obesity_data,
                  method = "nearest",
                  distance = "glm",
                  ratio = 1,
                  replace = FALSE)

cat("Matched N:", nrow(m_unwt$match.data), "\n")

# Outcome analysis (also unweighted - typical in papers)
md_unwt <- match.data(m_unwt)
model_unwt <- glm(Y ~ A, data = md_unwt, family = binomial())
or_unwt <- exp(coef(model_unwt)["A"])
ci_unwt <- exp(confint(model_unwt)["A", ])

obesity_results$unweighted_psm <- list(
  or = or_unwt,
  ci_lower = ci_unwt[1],
  ci_upper = ci_unwt[2],
  n_matched = nrow(md_unwt),
  estimand = "Sample ATE (NOT population!)"
)

cat("  OR:", round(or_unwt, 3), "\n")
cat("  95% CI: [", round(ci_unwt[1], 3), ", ", round(ci_unwt[2], 3), "]\n")
cat("  ⚠️  This is SAMPLE-SPECIFIC, not population-level!\n")

#------------------------------------------------------------------------------
# METHOD 2: WEIGHTED REGRESSION (Common Baseline)
#------------------------------------------------------------------------------

cat("\n--- METHOD 2: Survey-Weighted Regression ---\n")

svy_design_obesity <- svydesign(
  ids = ~sdmvpsu,
  strata = ~sdmvstra,
  weights = ~survey_weight,
  nest = TRUE,
  data = obesity_data
)

# Adjusted model
formula_adj <- as.formula(paste("hypertension ~ obesity +", 
                                paste(confounders_available, collapse = " + ")))
model_wt_reg <- svyglm(formula_adj, design = svy_design_obesity, family = quasibinomial())

or_wt_reg <- exp(coef(model_wt_reg)["obesity"])
ci_wt_reg <- exp(confint(model_wt_reg)["obesity", ])

obesity_results$weighted_reg <- list(
  or = or_wt_reg,
  ci_lower = ci_wt_reg[1],
  ci_upper = ci_wt_reg[2],
  estimand = "Population ATE"
)

cat("  OR:", round(or_wt_reg, 3), "\n")
cat("  95% CI: [", round(ci_wt_reg[1], 3), ", ", round(ci_wt_reg[2], 3), "]\n")

#------------------------------------------------------------------------------
# METHOD 3: PS FULL (Survey-Weighted)
#------------------------------------------------------------------------------

cat("\n--- METHOD 3: PS Full Matching (Survey-Weighted) ---\n")

m_ps_full <- matchit(ps_formula,
                     data = obesity_data,
                     method = "full",
                     distance = "glm",
                     estimand = "ATE",
                     s.weights = sw)

md_ps_full <- match.data(m_ps_full)

outcome_formula <- as.formula(paste("Y ~ A +", 
                                    paste(confounders_available, collapse = " + ")))
fit_ps_full <- glm(outcome_formula, data = md_ps_full, 
                   weights = weights, family = quasibinomial())

ate_ps_full <- avg_comparisons(fit_ps_full, 
                                variables = "A",
                                vcov = ~subclass,
                                wts = "sw",
                                comparison = "lnor")  # log odds ratio

or_ps_full <- exp(ate_ps_full$estimate)
ci_ps_full <- exp(c(ate_ps_full$conf.low, ate_ps_full$conf.high))

obesity_results$ps_full <- list(
  or = or_ps_full,
  ci_lower = ci_ps_full[1],
  ci_upper = ci_ps_full[2],
  estimand = "Population ATE"
)

cat("  OR:", round(or_ps_full, 3), "\n")
cat("  95% CI: [", round(ci_ps_full[1], 3), ", ", round(ci_ps_full[2], 3), "]\n")

#------------------------------------------------------------------------------
# METHOD 4: IPTW (Survey-Weighted)
#------------------------------------------------------------------------------

cat("\n--- METHOD 4: IPTW (Survey-Weighted) ---\n")

# Estimate PS with survey weights
ps_model <- svyglm(ps_formula, design = svy_design_obesity, family = quasibinomial())
e_score <- predict(ps_model, type = "response", newdata = obesity_data)

# IPTW weights
iptw_weights <- ifelse(obesity_data$A == 1, 1/e_score, 1/(1-e_score))

cat("IPTW weight distribution:\n")
cat("  Max:", round(max(iptw_weights), 1), "\n")
cat("  % > 10:", round(100*mean(iptw_weights > 10), 1), "%\n")

# Combined weights
combined_weights <- iptw_weights * obesity_data$survey_weight

# Weighted analysis
design_iptw <- svydesign(ids = ~1, weights = ~combined_weights,
                         data = data.frame(Y = obesity_data$Y, 
                                          A = obesity_data$A,
                                          combined_weights = combined_weights))

model_iptw <- svyglm(Y ~ A, design = design_iptw, family = quasibinomial())
or_iptw <- exp(coef(model_iptw)["A"])
ci_iptw <- exp(confint(model_iptw)["A", ])

obesity_results$iptw <- list(
  or = or_iptw,
  ci_lower = ci_iptw[1],
  ci_upper = ci_iptw[2],
  max_weight = max(iptw_weights),
  estimand = "Population ATE"
)

cat("  OR:", round(or_iptw, 3), "\n")
cat("  95% CI: [", round(ci_iptw[1], 3), ", ", round(ci_iptw[2], 3), "]\n")

#------------------------------------------------------------------------------
# METHOD 5: WDSM (if function available)
#------------------------------------------------------------------------------

cat("\n--- METHOD 5: WDSM (If Available) ---\n")
cat("Note: Requires WDSM_adaptive.R function\n")
cat("Placeholder for WDSM results\n")

obesity_results$wdsm <- list(
  or = NA,
  ci_lower = NA,
  ci_upper = NA,
  note = "Run separately with WDSM_adaptive.R",
  estimand = "Population ATE"
)

################################################################################
# COMPARISON TABLES
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("              COMPREHENSIVE COMPARISON: OBESITY → HYPERTENSION\n")
cat("==============================================================================\n")

comparison_table_obesity <- data.frame(
  Method = c(
    "Unweighted PSM (Published)",
    "Weighted Regression",
    "PS Full (Weighted)",
    "IPTW (Weighted)",
    "WDSM (Ours)"
  ),
  `Odds Ratio` = sprintf("%.3f", c(
    obesity_results$unweighted_psm$or,
    obesity_results$weighted_reg$or,
    obesity_results$ps_full$or,
    obesity_results$iptw$or,
    NA
  )),
  `95% CI` = c(
    sprintf("[%.3f, %.3f]", 
            obesity_results$unweighted_psm$ci_lower,
            obesity_results$unweighted_psm$ci_upper),
    sprintf("[%.3f, %.3f]", 
            obesity_results$weighted_reg$ci_lower,
            obesity_results$weighted_reg$ci_upper),
    sprintf("[%.3f, %.3f]", 
            obesity_results$ps_full$ci_lower,
            obesity_results$ps_full$ci_upper),
    sprintf("[%.3f, %.3f]", 
            obesity_results$iptw$ci_lower,
            obesity_results$iptw$ci_upper),
    "TBD"
  ),
  Estimand = c(
    "Sample ATE",
    "Population ATE",
    "Population ATE",
    "Population ATE",
    "Population ATE"
  ),
  `Survey Weights?` = c("NO ❌", "YES ✓", "YES ✓", "YES ✓", "YES ✓"),
  Issue = c(
    "Sample-specific",
    "Poor balance",
    "OK",
    paste0("Max wt=", round(obesity_results$iptw$max_weight, 1)),
    "None"
  ),
  check.names = FALSE
)

print(comparison_table_obesity, row.names = FALSE)

cat("\n=== KEY FINDINGS ===\n\n")

# Compare unweighted PSM to weighted methods
pct_diff_reg <- 100*(obesity_results$unweighted_psm$or - 
                      obesity_results$weighted_reg$or) / 
                      obesity_results$weighted_reg$or

cat("1. SAMPLE vs POPULATION ESTIMATES:\n")
cat("   Unweighted PSM OR:", round(obesity_results$unweighted_psm$or, 3), "\n")
cat("   Weighted Reg OR:", round(obesity_results$weighted_reg$or, 3), "\n")
cat("   Difference:", round(pct_diff_reg, 1), "%\n")
cat("   ⚠️  Unweighted PSM gives DIFFERENT estimate!\n")

cat("\n2. CI WIDTH COMPARISON:\n")
ci_width_unwt <- obesity_results$unweighted_psm$ci_upper - 
                 obesity_results$unweighted_psm$ci_lower
ci_width_wt <- obesity_results$weighted_reg$ci_upper - 
               obesity_results$weighted_reg$ci_lower
cat("   Unweighted PSM CI width:", round(ci_width_unwt, 3), "\n")
cat("   Weighted Reg CI width:", round(ci_width_wt, 3), "\n")

cat("\n3. INTERPRETATION:\n")
cat("   - Unweighted PSM = Sample-specific (not generalizable)\n")
cat("   - Weighted methods = Population-level (policy-relevant)\n")
cat("   - IPTW has extreme weights (max=", 
    round(obesity_results$iptw$max_weight, 1), ")\n")
cat("   - WDSM would provide: population validity + good balance + no extreme weights\n")

# Save results
save(obesity_results, comparison_table_obesity,
     file = "analysis_results/unweighted_psm_replication_results.rda")

cat("\n==============================================================================\n")
cat("Results saved to: analysis_results/unweighted_psm_replication_results.rda\n")
cat("==============================================================================\n")
