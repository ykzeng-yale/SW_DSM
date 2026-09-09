################################################################################
# PAPER 1: Waist → Uric Acid (Chen et al. PLOS ONE 2024)
# Using YOUR EXACT 5-METHOD FRAMEWORK from run_complete_all_methods.R
#
# Methods: PSM, PGM, DSM (unweighted), PS Full (survey-weighted), WDSM
# Covariates: EXACT from Chen et al. paper
# Bootstrap: 200 reps for all methods
################################################################################

rm(list = ls())
options(scipen = 999)

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
  library(MatchIt)
  library(marginaleffects)
  if (!require(dsmatch)) {
    devtools::install_github("Yunshu7/dsmatch", quiet = TRUE)
    library(dsmatch)
  }
})

source("WDSM_adaptive.R")
load("data/nhanes_2007_2018.rda")

cat("\n")
cat("==============================================================================\n")
cat("   PAPER 1: Waist Circumference → Serum Uric Acid\n")
cat("   Chen et al. PLOS ONE 2024 (NHANES 2007-2018)\n")
cat("   ALL 5 METHODS WITH EXACT COVARIATES\n")
cat("==============================================================================\n")

################################################################################
# DATA PREPARATION WITH EXACT COVARIATES FROM PAPER
################################################################################

# Convert labeled variables
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

# Define covariate sets FROM CHEN ET AL. PAPER
# PS model: Demographics + anthropometric (for confounding)
ps_vars <- c("age", "female", "race1", "education", "dmdmartl", "pir", "bmi")

# PG model: PS vars + labs + clinical (for outcome prediction)
pg_vars <- c(ps_vars, "egfr", "lbxtr", "lbxscr", "lbxtc", "lbdldl", "lbdhdd", 
             "lbxgh", "bpxsy1", "bpxdi1", "hypertension", "diabetes", 
             "smokestatus", "alcoholstatus")

# Get complete cases
all_vars <- c("lbxsua", "bmxwaist", "wtmec2yr", "sdmvpsu", "sdmvstra", 
              unique(c(ps_vars, pg_vars)))
all_vars <- all_vars[all_vars %in% names(nhanes_clean)]

complete_idx <- complete.cases(nhanes_clean[, all_vars])
data_analysis <- nhanes_clean[complete_idx, ]
n <- nrow(data_analysis)

# Define variables
Y <- data_analysis$lbxsua  # Serum uric acid (mg/dL)
A <- as.numeric((data_analysis$female == 0 & data_analysis$bmxwaist >= 102) | 
                (data_analysis$female == 1 & data_analysis$bmxwaist >= 88))
w <- data_analysis$wtmec2yr
sw <- w * n / sum(w)

cat("\n=== SAMPLE CHARACTERISTICS ===\n")
cat("Total N:", n, "\n")
cat("High waist:", sum(A), "(", round(100*mean(A), 1), "%)\n")
cat("Mean uric acid:", round(mean(Y), 2), "mg/dL\n")
cat("  High waist:", round(mean(Y[A==1]), 2), "mg/dL\n")
cat("  Normal waist:", round(mean(Y[A==0]), 2), "mg/dL\n")

# Prepare matrices for dsmatch
X_ps_df <- data_analysis[, ps_vars]
for (col in names(X_ps_df)) {
  if (is.factor(X_ps_df[[col]])) {
    X_ps_df[[col]] <- as.numeric(X_ps_df[[col]])
  }
}
X_ps <- as.matrix(X_ps_df)

pg_vars_available <- pg_vars[pg_vars %in% names(data_analysis)]
X_pg_df <- data_analysis[, pg_vars_available]
for (col in names(X_pg_df)) {
  if (is.factor(X_pg_df[[col]])) {
    X_pg_df[[col]] <- as.numeric(X_pg_df[[col]])
  }
}
X_pg <- as.matrix(X_pg_df)

# Data frame for MatchIt
df_analysis <- data.frame(
  Y = Y,
  A = A,
  sw = sw,
  data_analysis[, unique(c(ps_vars, pg_vars_available))]
)

# Bootstrap count
B_BOOTSTRAP <- 200

# Results storage
results <- list()

################################################################################
# METHOD 1: UNWEIGHTED PSM (Sample Estimate)
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 1: Unweighted PSM (1:1 matching) - SAMPLE ESTIMATE\n")
cat("========================================================================\n")
cat("PS model covariates:", paste(ps_vars, collapse=", "), "\n")

suppressWarnings({
  psm_result <- dsmatchATE(
    Y = Y,
    X = X_ps,
    A = A,
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
cat("Significant:", ifelse(results$psm$ci_lower > 0, "YES", "NO"), "\n")

################################################################################
# METHOD 2: UNWEIGHTED PGM (Sample Estimate)
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 2: Unweighted PGM (1:1 matching) - SAMPLE ESTIMATE\n")
cat("========================================================================\n")
cat("PG model covariates:", length(pg_vars_available), "variables\n")

suppressWarnings({
  pgm_result <- dsmatchATE(
    Y = Y,
    X = X_pg,
    A = A,
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
cat("  METHOD 3: Unweighted DSM (1:1 matching) - SAMPLE ESTIMATE\n")
cat("========================================================================\n")

suppressWarnings({
  dsm_result <- dsmatchATE(
    Y = Y,
    X = X_ps,
    A = A,
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

ps_formula <- as.formula(paste("A ~", paste(ps_vars, collapse = " + ")))

# Use nearest matching instead of full (memory issue)
m_ps <- matchit(ps_formula,
                data = df_analysis,
                method = "nearest",
                distance = "glm",
                link = "logit",
                ratio = 5,  # 1:5 like WDSM
                estimand = "ATE",
                s.weights = sw)

md <- match.data(m_ps)

outcome_formula <- as.formula(paste("Y ~ A +", paste(pg_vars_available, collapse = " + ")))
fit <- lm(outcome_formula, data = md, weights = weights)

ate <- avg_comparisons(fit,
                       variables = "A",
                       vcov = ~subclass,
                       wts = "sw",
                       comparison = "difference")

results$ps_full <- list(
  estimate = ate$estimate,
  se = ate$std.error,
  ci_lower = ate$conf.low,
  ci_upper = ate$conf.high,
  estimand = "POPULATION mean difference"
)

cat("Estimate:", round(results$ps_full$estimate, 3), "mg/dL\n")
cat("95% CI: [", round(results$ps_full$ci_lower, 3), ", ", round(results$ps_full$ci_upper, 3), "]\n", sep="")

################################################################################
# METHOD 5: WDSM (Population Estimate with Bootstrap)
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 5: WDSM (1:5 matching) - POPULATION ESTIMATE\n")
cat("========================================================================\n")

wdsm_data <- data_analysis
wdsm_data$Y <- Y
wdsm_data$A <- A
wdsm_data$survey_weight <- w

ps_formula_wdsm <- ps_formula
pg_formula_wdsm <- as.formula(paste("~ ", paste(pg_vars_available, collapse = " + ")))

suppressWarnings({
  wdsm_result <- wdsm_adaptive(
    data = wdsm_data,
    ps_formula = ps_formula_wdsm,
    pg_formula = pg_formula_wdsm,
    outcome_var = "Y",
    treatment_var = "A",
    weight_var = "survey_weight",
    M = 5,
    use_bias_correction = TRUE,
    verbose = FALSE
  )
})

# Bootstrap
set.seed(2024)
boot_wdsm <- numeric(B_BOOTSTRAP)
cat("Running WDSM bootstrap (", B_BOOTSTRAP, " reps)...", sep="")

for (b in 1:B_BOOTSTRAP) {
  if (b %% 50 == 0) cat(".")
  
  m_star <- rmultinom(1, n, rep(1/n, n))[, 1]
  data_boot <- wdsm_data
  data_boot$survey_weight <- m_star * w
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  
  tryCatch({
    suppressWarnings({
      boot_result <- wdsm_adaptive(data_boot, ps_formula_wdsm, pg_formula_wdsm,
                                   "Y", "A", "survey_weight",
                                   M = 5, use_bias_correction = TRUE, verbose = FALSE)
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

################################################################################
# FINAL COMPARISON TABLE
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("          FINAL RESULTS: ALL 5 METHODS (Your Framework)\n")
cat("==============================================================================\n")

comparison_table <- data.frame(
  Method = c("Unweighted PSM (1:1)",
             "Unweighted PGM (1:1)",
             "Unweighted DSM (1:1)",
             "Survey-Weighted PS Full",
             "WDSM (1:5)"),
  `Estimate (mg/dL)` = sprintf("%.3f", c(results$psm$estimate,
                                         results$pgm$estimate,
                                         results$dsm$estimate,
                                         results$ps_full$estimate,
                                         results$wdsm$estimate)),
  `95% CI` = c(
    sprintf("[%.3f, %.3f]", results$psm$ci_lower, results$psm$ci_upper),
    sprintf("[%.3f, %.3f]", results$pgm$ci_lower, results$pgm$ci_upper),
    sprintf("[%.3f, %.3f]", results$dsm$ci_lower, results$dsm$ci_upper),
    sprintf("[%.3f, %.3f]", results$ps_full$ci_lower, results$ps_full$ci_upper),
    sprintf("[%.3f, %.3f]", results$wdsm$ci_lower, results$wdsm$ci_upper)
  ),
  Significant = c(
    ifelse(results$psm$ci_lower > 0, "YES", "NO"),
    ifelse(results$pgm$ci_lower > 0, "YES", "NO"),
    ifelse(results$dsm$ci_lower > 0, "YES", "NO"),
    ifelse(results$ps_full$ci_lower > 0, "YES", "NO"),
    ifelse(results$wdsm$ci_lower > 0, "YES", "NO")
  ),
  Estimand = c("Sample", "Sample", "Sample", "Population", "Population"),
  `Survey Weights?` = c("NO", "NO", "NO", "YES", "YES"),
  Bootstrap = c("200", "200", "200", "N/A (Delta)", "200"),
  check.names = FALSE
)

print(comparison_table, row.names = FALSE)

cat("\n=== KEY COMPARISONS ===\n")

cat("\n1. UNWEIGHTED PSM vs WDSM:\n")
cat("   PSM (SAMPLE):", round(results$psm$estimate, 3), 
    " [", round(results$psm$ci_lower, 3), ",", round(results$psm$ci_upper, 3), "]\n", sep="")
cat("   WDSM (POPULATION):", round(results$wdsm$estimate, 3),
    " [", round(results$wdsm$ci_lower, 3), ",", round(results$wdsm$ci_upper, 3), "]\n", sep="")

pct_diff <- 100*(results$psm$estimate - results$wdsm$estimate)/abs(results$wdsm$estimate)
cat("   Difference:", round(pct_diff, 1), "%\n")

cat("\n2. SIGNIFICANCE STATUS:\n")
cat("   PSM:", ifelse(results$psm$ci_lower > 0, "Significant", "Not significant"), "\n")
cat("   WDSM:", ifelse(results$wdsm$ci_lower > 0, "Significant", "Not significant"), "\n")

if((results$psm$ci_lower > 0) != (results$wdsm$ci_lower > 0)) {
  cat("   ⚠️  SIGNIFICANCE FLIPS!\n")
} else {
  cat("   No significance flip\n")
}

cat("\n3. SURVEY-WEIGHTED METHODS COMPARISON:\n")
cat("   PS Full:", round(results$ps_full$estimate, 3), 
    " [", round(results$ps_full$ci_lower, 3), ",", round(results$ps_full$ci_upper, 3), "]\n", sep="")
cat("   WDSM:", round(results$wdsm$estimate, 3),
    " [", round(results$wdsm$ci_lower, 3), ",", round(results$wdsm$ci_upper, 3), "]\n", sep="")

# Save
save(results, comparison_table, data_analysis,
     file = "analysis_results/CHEN_waist_uric_ALL_5_METHODS.rda")

cat("\n==============================================================================\n")
cat("COMPLETE: All 5 methods with bootstrap CIs\n")
cat("Results saved to: analysis_results/CHEN_waist_uric_ALL_5_METHODS.rda\n")
cat("==============================================================================\n")



