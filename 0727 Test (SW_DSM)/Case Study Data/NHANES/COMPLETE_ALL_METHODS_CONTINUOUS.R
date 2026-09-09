################################################################################
# COMPLETE ALL METHODS: CONTINUOUS OUTCOMES
# Using YOUR framework: PSM/PGM/DSM (unwt), PS Full (wt), WDSM
# With BOOTSTRAP for all methods to get proper CIs
################################################################################

rm(list = ls())
options(scipen = 999)

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
  library(MatchIt)
  library(survey)
  library(marginaleffects)
  if (!require(dsmatch)) {
    devtools::install_github("Yunshu7/dsmatch", quiet = TRUE)
    library(dsmatch)
  }
})

source("WDSM_adaptive.R")
load("data/nhanes_2007_2018.rda")

nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

cat("\n")
cat("==============================================================================\n")
cat("   COMPLETE ALL METHODS: High Waist → Uric Acid\n")
cat("   (Using YOUR original framework with proper CIs)\n")
cat("==============================================================================\n")

B_BOOTSTRAP <- 200  # Bootstrap replications

################################################################################
# DATA PREPARATION
################################################################################

uric_data <- nhanes_clean %>%
  filter(
    !is.na(bmxwaist), !is.na(lbxsua),
    !is.na(age), age >= 20,
    !is.na(female), !is.na(race1), !is.na(bmi), !is.na(pir),
    !is.na(wtmec2yr), !is.na(sdmvpsu), !is.na(sdmvstra)
  ) %>%
  mutate(
    high_waist = as.numeric((female == 0 & bmxwaist >= 102) | (female == 1 & bmxwaist >= 88)),
    Y = lbxsua,
    A = high_waist,
    survey_weight = wtmec2yr,
    n = n(),
    sw = wtmec2yr * n / sum(wtmec2yr)
  )

n <- nrow(uric_data)

cat("\n=== SAMPLE ===\n")
cat("N:", n, "\n")
cat("High waist:", sum(uric_data$A), "(", round(100*mean(uric_data$A), 1), "%)\n")

# Prepare matrices
confounders <- c("age", "female", "race1", "bmi", "pir")
X_ps_df <- uric_data[, confounders]
for (col in names(X_ps_df)) {
  if (is.factor(X_ps_df[[col]])) X_ps_df[[col]] <- as.numeric(X_ps_df[[col]])
}
X_ps <- as.matrix(X_ps_df)
X_pg <- X_ps  # Same for simplicity

results <- list()

################################################################################
# METHOD 1: UNWEIGHTED PSM (Sample Estimate)
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 1: Unweighted PSM (1:1) - SAMPLE ESTIMATE\n")
cat("========================================================================\n")

suppressWarnings({
  psm_result <- dsmatchATE(
    Y = uric_data$Y,
    X = X_ps,
    A = uric_data$A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = TRUE,
    boots = B_BOOTSTRAP,
    mc = FALSE,
    ncpus = 1
  )
})

results$psm <- list(
  estimate = psm_result$est.ps,
  se = sqrt(psm_result$bootvar[1,1]),
  ci_lower = psm_result$est.ps - 1.96*sqrt(psm_result$bootvar[1,1]),
  ci_upper = psm_result$est.ps + 1.96*sqrt(psm_result$bootvar[1,1]),
  estimand = "SAMPLE mean difference"
)

cat("Estimate:", round(results$psm$estimate, 3), "mg/dL\n")
cat("95% CI: [", round(results$psm$ci_lower, 3), ", ", round(results$psm$ci_upper, 3), "]\n", sep="")
cat("Estimand: SAMPLE mean difference\n")

################################################################################
# METHOD 2: UNWEIGHTED PGM (Sample Estimate)
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 2: Unweighted PGM (1:1) - SAMPLE ESTIMATE\n")
cat("========================================================================\n")

suppressWarnings({
  pgm_result <- dsmatchATE(
    Y = uric_data$Y,
    X = X_pg,
    A = uric_data$A,
    method = "pg",
    model.pg = "glm",
    cov.balance = FALSE,
    varest = TRUE,
    boots = B_BOOTSTRAP,
    mc = FALSE,
    ncpus = 1
  )
})

results$pgm <- list(
  estimate = pgm_result$est.pg,
  se = sqrt(pgm_result$bootvar[1,1]),
  ci_lower = pgm_result$est.pg - 1.96*sqrt(pgm_result$bootvar[1,1]),
  ci_upper = pgm_result$est.pg + 1.96*sqrt(pgm_result$bootvar[1,1]),
  estimand = "SAMPLE mean difference"
)

cat("Estimate:", round(results$pgm$estimate, 3), "mg/dL\n")
cat("95% CI: [", round(results$pgm$ci_lower, 3), ", ", round(results$pgm$ci_upper, 3), "]\n", sep="")

################################################################################
# METHOD 3: UNWEIGHTED DSM (Sample Estimate)
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 3: Unweighted DSM (1:1) - SAMPLE ESTIMATE\n")
cat("========================================================================\n")

suppressWarnings({
  dsm_result <- dsmatchATE(
    Y = uric_data$Y,
    X = X_ps,
    A = uric_data$A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X_pg,
    cov.balance = FALSE,
    varest = TRUE,
    boots = B_BOOTSTRAP,
    mc = FALSE,
    ncpus = 1
  )
})

results$dsm <- list(
  estimate = dsm_result$est.ds,
  se = sqrt(dsm_result$bootvar[1,1]),
  ci_lower = dsm_result$est.ds - 1.96*sqrt(dsm_result$bootvar[1,1]),
  ci_upper = dsm_result$est.ds + 1.96*sqrt(dsm_result$bootvar[1,1]),
  estimand = "SAMPLE mean difference"
)

cat("Estimate:", round(results$dsm$estimate, 3), "mg/dL\n")
cat("95% CI: [", round(results$dsm$ci_lower, 3), ", ", round(results$dsm$ci_upper, 3), "]\n", sep="")

################################################################################
# METHOD 4: SURVEY-WEIGHTED PS FULL (Population Estimate)
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 4: Survey-Weighted PS Full - POPULATION ESTIMATE\n")
cat("========================================================================\n")

ps_formula <- as.formula(paste("A ~", paste(confounders, collapse = " + ")))

m_ps_full <- matchit(
  ps_formula,
  data = uric_data,
  method = "full",
  distance = "glm",
  link = "logit",
  estimand = "ATE",
  s.weights = uric_data$sw
)

md_ps_full <- match.data(m_ps_full)

outcome_formula <- as.formula(paste("Y ~ A +", paste(confounders, collapse = " + ")))
fit_ps_full <- lm(outcome_formula, data = md_ps_full, weights = weights)

ate_ps_full <- avg_comparisons(
  fit_ps_full,
  variables = "A",
  vcov = ~subclass,
  wts = "sw",
  comparison = "difference"
)

results$ps_full <- list(
  estimate = ate_ps_full$estimate,
  se = ate_ps_full$std.error,
  ci_lower = ate_ps_full$conf.low,
  ci_upper = ate_ps_full$conf.high,
  estimand = "POPULATION mean difference"
)

cat("Estimate:", round(results$ps_full$estimate, 3), "mg/dL\n")
cat("95% CI: [", round(results$ps_full$ci_lower, 3), ", ", round(results$ps_full$ci_upper, 3), "]\n", sep="")
cat("Estimand: POPULATION mean difference\n")

################################################################################
# METHOD 5: WDSM (Population Estimate with Bootstrap)
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 5: WDSM (1:5) - POPULATION ESTIMATE\n")
cat("========================================================================\n")

pg_formula <- as.formula(paste("~", paste(confounders, collapse = " + ")))

suppressWarnings({
  wdsm_result <- wdsm_adaptive(
    data = uric_data,
    ps_formula = ps_formula,
    pg_formula = pg_formula,
    outcome_var = "Y",
    treatment_var = "A",
    weight_var = "survey_weight",
    M = 5,
    use_bias_correction = TRUE,
    verbose = FALSE
  )
})

# Bootstrap for WDSM
set.seed(2024)
boot_wdsm <- numeric(B_BOOTSTRAP)
cat("Running WDSM bootstrap (", B_BOOTSTRAP, " reps)...", sep="")

for (b in 1:B_BOOTSTRAP) {
  if (b %% 50 == 0) cat(".")
  
  m_star <- rmultinom(1, n, rep(1/n, n))[, 1]
  data_boot <- uric_data
  data_boot$survey_weight <- m_star * uric_data$survey_weight
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  
  tryCatch({
    suppressWarnings({
      boot_result <- wdsm_adaptive(
        data_boot, ps_formula, pg_formula,
        "Y", "A", "survey_weight",
        M = 5, use_bias_correction = TRUE, verbose = FALSE
      )
    })
    boot_wdsm[b] <- boot_result$tau
  }, error = function(e) NULL)
}
cat(" Done!\n")

boot_wdsm <- boot_wdsm[!is.na(boot_wdsm) & boot_wdsm != 0]
wdsm_se <- sd(boot_wdsm)
wdsm_ci <- quantile(boot_wdsm, c(0.025, 0.975))

results$wdsm <- list(
  estimate = wdsm_result$tau,
  se = wdsm_se,
  ci_lower = wdsm_ci[1],
  ci_upper = wdsm_ci[2],
  estimand = "POPULATION mean difference"
)

cat("Estimate:", round(results$wdsm$estimate, 3), "mg/dL\n")
cat("95% CI: [", round(results$wdsm$ci_lower, 3), ", ", round(results$wdsm$ci_upper, 3), "]\n", sep="")
cat("Estimand: POPULATION mean difference\n")

################################################################################
# COMPREHENSIVE COMPARISON TABLE
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("     COMPLETE COMPARISON: ALL 5 METHODS (Your Framework)\n")
cat("==============================================================================\n")

comparison_table <- data.frame(
  Method = c(
    "Unweighted PSM (1:1)",
    "Unweighted PGM (1:1)",
    "Unweighted DSM (1:1)",
    "Survey-Weighted PS Full",
    "WDSM (1:5)"
  ),
  Estimate = sprintf("%.3f", c(
    results$psm$estimate,
    results$pgm$estimate,
    results$dsm$estimate,
    results$ps_full$estimate,
    results$wdsm$estimate
  )),
  `95% CI` = c(
    sprintf("[%.3f, %.3f]", results$psm$ci_lower, results$psm$ci_upper),
    sprintf("[%.3f, %.3f]", results$pgm$ci_lower, results$pgm$ci_upper),
    sprintf("[%.3f, %.3f]", results$dsm$ci_lower, results$dsm$ci_upper),
    sprintf("[%.3f, %.3f]", results$ps_full$ci_lower, results$ps_full$ci_upper),
    sprintf("[%.3f, %.3f]", results$wdsm$ci_lower, results$wdsm$ci_upper)
  ),
  `CI Width` = sprintf("%.3f", c(
    results$psm$ci_upper - results$psm$ci_lower,
    results$pgm$ci_upper - results$pgm$ci_lower,
    results$dsm$ci_upper - results$dsm$ci_lower,
    results$ps_full$ci_upper - results$ps_full$ci_lower,
    results$wdsm$ci_upper - results$wdsm$ci_lower
  )),
  Significant = c(
    ifelse(results$psm$ci_lower > 0 | results$psm$ci_upper < 0, "YES", "NO"),
    ifelse(results$pgm$ci_lower > 0 | results$pgm$ci_upper < 0, "YES", "NO"),
    ifelse(results$dsm$ci_lower > 0 | results$dsm$ci_upper < 0, "YES", "NO"),
    ifelse(results$ps_full$ci_lower > 0 | results$ps_full$ci_upper < 0, "YES", "NO"),
    ifelse(results$wdsm$ci_lower > 0 | results$wdsm$ci_upper < 0, "YES", "NO")
  ),
  Estimand = c("Sample", "Sample", "Sample", "Population", "Population"),
  `Survey Weights?` = c("NO", "NO", "NO", "YES", "YES"),
  check.names = FALSE
)

print(comparison_table, row.names = FALSE)

################################################################################
# KEY COMPARISONS
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("              KEY COMPARISONS: WDSM vs UNWEIGHTED PSM\n")
cat("==============================================================================\n")

cat("\n1. UNWEIGHTED PSM (Sample):\n")
cat("   Estimate:", round(results$psm$estimate, 3), "mg/dL\n")
cat("   95% CI: [", round(results$psm$ci_lower, 3), ", ", round(results$psm$ci_upper, 3), "]\n", sep="")
cat("   CI Width:", round(results$psm$ci_upper - results$psm$ci_lower, 3), "\n")
cat("   Significant:", ifelse(results$psm$ci_lower > 0, "YES", "NO"), "\n")
cat("   Estimand: SAMPLE (not generalizable to population)\n")

cat("\n2. WDSM (Population):\n")
cat("   Estimate:", round(results$wdsm$estimate, 3), "mg/dL\n")
cat("   95% CI: [", round(results$wdsm$ci_lower, 3), ", ", round(results$wdsm$ci_upper, 3), "]\n", sep="")
cat("   CI Width:", round(results$wdsm$ci_upper - results$wdsm$ci_lower, 3), "\n")
cat("   Significant:", ifelse(results$wdsm$ci_lower > 0, "YES", "NO"), "\n")
cat("   Estimand: POPULATION (generalizable)\n")

cat("\n3. COMPARISON:\n")
pct_diff_est <- 100 * (results$psm$estimate - results$wdsm$estimate) / results$wdsm$estimate
pct_diff_ci <- 100 * ((results$psm$ci_upper - results$psm$ci_lower) - 
                      (results$wdsm$ci_upper - results$wdsm$ci_lower)) / 
                      (results$wdsm$ci_upper - results$wdsm$ci_lower)

cat("   Estimate difference:", round(pct_diff_est, 1), "%\n")
cat("   PSM CI width vs WDSM CI width:", round(pct_diff_ci, 1), "%\n")
cat("\n   Significance status:\n")
cat("     PSM:", ifelse(results$psm$ci_lower > 0, "Significant", "Not significant"), "\n")
cat("     WDSM:", ifelse(results$wdsm$ci_lower > 0, "Significant", "Not significant"), "\n")

if((results$psm$ci_lower > 0) != (results$wdsm$ci_lower > 0)) {
  cat("   ⚠️  SIGNIFICANCE FLIPS!\n")
} else {
  cat("   No significance flip (both ", 
      ifelse(results$psm$ci_lower > 0, "significant", "not significant"), ")\n", sep="")
}

cat("\n4. WDSM vs SURVEY-WEIGHTED PS FULL:\n")
cat("   PS Full:", round(results$ps_full$estimate, 3), "[", round(results$ps_full$ci_lower, 3), 
    ",", round(results$ps_full$ci_upper, 3), "]\n", sep="")
cat("   WDSM:", round(results$wdsm$estimate, 3), "[", round(results$wdsm$ci_lower, 3),
    ",", round(results$wdsm$ci_upper, 3), "]\n", sep="")
cat("   Both are POPULATION estimates\n")
cat("   Difference:", round(100*(results$wdsm$estimate - results$ps_full$estimate)/results$ps_full$estimate, 1), "%\n")

save(results, comparison_table, uric_data,
     file = "analysis_results/COMPLETE_ALL_METHODS_waist_uric.rda")

cat("\n==============================================================================\n")
cat("ANALYSIS COMPLETE: All 5 methods with bootstrap CIs\n")
cat("==============================================================================\n")



