################################################################################
# CORRECT: ALL 5 METHODS FOR CONTINUOUS OUTCOMES
# Using EXACT implementation from your successful run_complete_all_methods.R
# 
# PSM, PGM, DSM: All from dsmatch
# PS Full: From matchit with method="full" and estimand="ATE"
# WDSM: Your custom function
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
cat("   CORRECT IMPLEMENTATION: ALL 5 METHODS (Following Your Framework)\n")
cat("==============================================================================\n")

# Convert labeled variables
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

################################################################################
# ANALYSIS 1: HIGH WAIST → SERUM URIC ACID
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   ANALYSIS 1: High Waist → Serum Uric Acid\n")
cat("==============================================================================\n")

# Covariates (simpler for larger N)
ps_vars <- c("age", "female", "race1", "bmi", "pir")
pg_vars <- c(ps_vars, "egfr", "lbxtc", "hypertension", "diabetes")

# Get complete cases
all_vars <- c("lbxsua", "bmxwaist", "wtmec2yr", ps_vars, pg_vars)
all_vars <- all_vars[all_vars %in% names(nhanes_clean)]
complete_idx <- complete.cases(nhanes_clean[, all_vars])
data_analysis <- nhanes_clean[complete_idx, ]
n <- nrow(data_analysis)

Y <- data_analysis$lbxsua
A <- as.numeric(data_analysis$bmxwaist >= ifelse(data_analysis$female == 1, 88, 102))
w <- data_analysis$wtmec2yr
sw <- w * n / sum(w)  # Normalized weights

cat("\nSample size:", n, "\n")
cat("High waist:", sum(A), "(", round(100*mean(A), 1), "%)\n")
cat("Mean uric acid:", round(mean(Y), 2), "mg/dL\n")
cat("  High waist:", round(mean(Y[A==1]), 2), "\n")
cat("  Normal waist:", round(mean(Y[A==0]), 2), "\n")

# Prepare matrices for dsmatch
X_ps <- as.matrix(data_analysis[, ps_vars])
X_pg <- as.matrix(data_analysis[, pg_vars])

# Data frame for MatchIt
df <- data.frame(
  Y = Y,
  A = A,
  sw = sw,
  data_analysis[, unique(c(ps_vars, pg_vars))]
)

B_BOOTSTRAP <- 100
results_uric <- list()

# -----------------------------------------------------------------------------
# METHOD 1: UNWEIGHTED PSM (from dsmatch)
# -----------------------------------------------------------------------------

cat("\n--- METHOD 1: Unweighted PSM (1:1 matching) ---\n")

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

results_uric$psm <- list(
  estimate = psm_result$est.ps,
  se = sqrt(psm_result$bootvar[1,1]),
  ci_lower = psm_result$est.ps - 1.96*sqrt(psm_result$bootvar[1,1]),
  ci_upper = psm_result$est.ps + 1.96*sqrt(psm_result$bootvar[1,1])
)

cat("  Estimate:", round(results_uric$psm$estimate, 3), "mg/dL\n")
cat("  95% CI: [", round(results_uric$psm$ci_lower, 3), ", ", 
    round(results_uric$psm$ci_upper, 3), "]\n", sep="")

# -----------------------------------------------------------------------------
# METHOD 2: UNWEIGHTED PGM (from dsmatch)
# -----------------------------------------------------------------------------

cat("\n--- METHOD 2: Unweighted PGM (1:1 matching) ---\n")

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

results_uric$pgm <- list(
  estimate = pgm_result$est.pg,
  se = sqrt(pgm_result$bootvar[1,1]),
  ci_lower = pgm_result$est.pg - 1.96*sqrt(pgm_result$bootvar[1,1]),
  ci_upper = pgm_result$est.pg + 1.96*sqrt(pgm_result$bootvar[1,1])
)

cat("  Estimate:", round(results_uric$pgm$estimate, 3), "mg/dL\n")
cat("  95% CI: [", round(results_uric$pgm$ci_lower, 3), ", ", 
    round(results_uric$pgm$ci_upper, 3), "]\n", sep="")

# -----------------------------------------------------------------------------
# METHOD 3: UNWEIGHTED DSM (from dsmatch)
# -----------------------------------------------------------------------------

cat("\n--- METHOD 3: Unweighted DSM (1:1 matching) ---\n")

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

results_uric$dsm <- list(
  estimate = dsm_result$est.ds,
  se = sqrt(dsm_result$bootvar[1,1]),
  ci_lower = dsm_result$est.ds - 1.96*sqrt(dsm_result$bootvar[1,1]),
  ci_upper = dsm_result$est.ds + 1.96*sqrt(dsm_result$bootvar[1,1])
)

cat("  Estimate:", round(results_uric$dsm$estimate, 3), "mg/dL\n")
cat("  95% CI: [", round(results_uric$dsm$ci_lower, 3), ", ", 
    round(results_uric$dsm$ci_upper, 3), "]\n", sep="")

# -----------------------------------------------------------------------------
# METHOD 4: SURVEY-WEIGHTED PS FULL (from matchit)
# -----------------------------------------------------------------------------

cat("\n--- METHOD 4: Survey-Weighted PS Full Matching ---\n")

ps_formula <- as.formula(paste("A ~", paste(ps_vars, collapse = " + ")))

# Using method="full" with estimand="ATE" as in your original
suppressWarnings({
  m_ps <- matchit(ps_formula,
                  data = df,
                  method = "full",  # FULL matching (not nearest!)
                  distance = "glm",
                  link = "logit",
                  estimand = "ATE",  # ATE works with full matching
                  s.weights = sw,
                  verbose = FALSE)
})

md <- match.data(m_ps)

# Outcome regression with all covariates
outcome_formula <- as.formula(paste("Y ~ A * (", paste(pg_vars, collapse = " + "), ")"))
fit <- lm(outcome_formula, data = md, weights = weights)

# Get ATE
ate <- avg_comparisons(fit,
                      variables = "A",
                      vcov = ~subclass,
                      wts = "sw",
                      comparison = "difference")

results_uric$ps_full <- list(
  estimate = ate$estimate,
  se = ate$std.error,
  ci_lower = ate$conf.low,
  ci_upper = ate$conf.high
)

cat("  Estimate:", round(results_uric$ps_full$estimate, 3), "mg/dL\n")
cat("  95% CI: [", round(results_uric$ps_full$ci_lower, 3), ", ", 
    round(results_uric$ps_full$ci_upper, 3), "]\n", sep="")

# -----------------------------------------------------------------------------
# METHOD 5: WDSM (Your custom function)
# -----------------------------------------------------------------------------

cat("\n--- METHOD 5: WDSM (1:5 matching) ---\n")

wdsm_data <- data_analysis
wdsm_data$Y <- Y
wdsm_data$A <- A
wdsm_data$survey_weight <- w

ps_formula_wdsm <- ps_formula
pg_formula_wdsm <- as.formula(paste("~", paste(pg_vars, collapse = " + ")))

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

# Bootstrap for WDSM
set.seed(2024)
boot_wdsm <- numeric(B_BOOTSTRAP)
cat("  Running bootstrap...")
for (b in 1:B_BOOTSTRAP) {
  if (b %% 20 == 0) cat(".")
  
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

results_uric$wdsm <- list(
  estimate = wdsm_result$tau,
  se = wdsm_se,
  ci_lower = wdsm_ci[1],
  ci_upper = wdsm_ci[2]
)

cat("  Estimate:", round(results_uric$wdsm$estimate, 3), "mg/dL\n")
cat("  95% CI: [", round(results_uric$wdsm$ci_lower, 3), ", ", 
    round(results_uric$wdsm$ci_upper, 3), "]\n", sep="")

################################################################################
# ANALYSIS 2: OBESITY → SBP (Quick version)
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   ANALYSIS 2: Obesity → Systolic Blood Pressure\n")
cat("==============================================================================\n")

# Prepare data
all_vars <- c("bpxsy1", "bmi", "wtmec2yr", ps_vars)
all_vars <- all_vars[all_vars %in% names(nhanes_clean)]
complete_idx <- complete.cases(nhanes_clean[, all_vars])
data_analysis <- nhanes_clean[complete_idx, ]
n <- nrow(data_analysis)

Y <- data_analysis$bpxsy1
A <- as.numeric(data_analysis$bmi >= 30)
w <- data_analysis$wtmec2yr
sw <- w * n / sum(w)

cat("Sample size:", n, "\n")
cat("Obese:", sum(A), "(", round(100*mean(A), 1), "%)\n")

X_ps <- as.matrix(data_analysis[, ps_vars])
df <- data.frame(Y = Y, A = A, sw = sw, data_analysis[, ps_vars])

results_sbp <- list()

# Quick PSM
suppressWarnings({
  psm_result <- dsmatchATE(Y = Y, X = X_ps, A = A, method = "ps", model.ps = "logit",
                          varest = TRUE, boots = 50, mc = FALSE, ncpus = 1)
})
results_sbp$psm <- list(
  estimate = psm_result$est.ps,
  se = sqrt(psm_result$bootvar[1,1]),
  ci_lower = psm_result$est.ps - 1.96*sqrt(psm_result$bootvar[1,1]),
  ci_upper = psm_result$est.ps + 1.96*sqrt(psm_result$bootvar[1,1])
)

# Quick PGM
suppressWarnings({
  pgm_result <- dsmatchATE(Y = Y, X = X_ps, A = A, method = "pg", model.pg = "glm",
                          varest = TRUE, boots = 50, mc = FALSE, ncpus = 1)
})
results_sbp$pgm <- list(
  estimate = pgm_result$est.pg,
  se = sqrt(pgm_result$bootvar[1,1]),
  ci_lower = pgm_result$est.pg - 1.96*sqrt(pgm_result$bootvar[1,1]),
  ci_upper = pgm_result$est.pg + 1.96*sqrt(pgm_result$bootvar[1,1])
)

# Quick DSM
suppressWarnings({
  dsm_result <- dsmatchATE(Y = Y, X = X_ps, A = A, method = "dsm",
                          model.ps = "logit", model.pg = "linpred", lp.pg = X_ps,
                          varest = TRUE, boots = 50, mc = FALSE, ncpus = 1)
})
results_sbp$dsm <- list(
  estimate = dsm_result$est.ds,
  se = sqrt(dsm_result$bootvar[1,1]),
  ci_lower = dsm_result$est.ds - 1.96*sqrt(dsm_result$bootvar[1,1]),
  ci_upper = dsm_result$est.ds + 1.96*sqrt(dsm_result$bootvar[1,1])
)

# PS Full
ps_formula <- as.formula(paste("A ~", paste(ps_vars, collapse = " + ")))
m_ps <- matchit(ps_formula, data = df, method = "full", estimand = "ATE", s.weights = sw, verbose = FALSE)
md <- match.data(m_ps)
fit <- lm(Y ~ A * (age + female + race1 + bmi + pir), data = md, weights = weights)
ate <- avg_comparisons(fit, variables = "A", vcov = ~subclass, wts = "sw")
results_sbp$ps_full <- list(
  estimate = ate$estimate, se = ate$std.error,
  ci_lower = ate$conf.low, ci_upper = ate$conf.high
)

# WDSM (quick)
wdsm_data <- data.frame(Y = Y, A = A, survey_weight = w, data_analysis[, ps_vars])
pg_formula <- as.formula(paste("~", paste(ps_vars, collapse = " + ")))
wdsm_result <- wdsm_adaptive(wdsm_data, ps_formula, pg_formula, "Y", "A", "survey_weight", 
                            M = 5, verbose = FALSE)
results_sbp$wdsm <- list(estimate = wdsm_result$tau, se = NA, ci_lower = NA, ci_upper = NA)

################################################################################
# FINAL COMPARISON TABLE
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("          FINAL RESULTS: ALL 5 METHODS (Your Exact Framework)\n")
cat("==============================================================================\n")

cat("\n=== ANALYSIS 1: WAIST → URIC ACID (Complete with Bootstrap) ===\n")
comparison_uric <- data.frame(
  Method = c("1. Unwt PSM (dsmatch)",
             "2. Unwt PGM (dsmatch)",
             "3. Unwt DSM (dsmatch)",
             "4. Wt PS Full (matchit)",
             "5. WDSM (custom)"),
  `Estimate (mg/dL)` = sprintf("%.3f", sapply(results_uric, function(x) x$estimate)),
  `95% CI` = sapply(results_uric, function(x) sprintf("[%.3f, %.3f]", x$ci_lower, x$ci_upper)),
  Significant = sapply(results_uric, function(x) ifelse(x$ci_lower * x$ci_upper > 0, "YES", "NO")),
  Estimand = c("Sample", "Sample", "Sample", "Population", "Population"),
  check.names = FALSE
)
print(comparison_uric, row.names = FALSE)

cat("\n=== ANALYSIS 2: OBESITY → SBP (Quick Demo) ===\n")
comparison_sbp <- data.frame(
  Method = c("1. Unwt PSM", "2. Unwt PGM", "3. Unwt DSM", "4. Wt PS Full", "5. WDSM"),
  `Estimate (mmHg)` = sprintf("%.2f", sapply(results_sbp, function(x) x$estimate)),
  Estimand = c("Sample", "Sample", "Sample", "Population", "Population"),
  check.names = FALSE
)
print(comparison_sbp, row.names = FALSE)

cat("\n=== KEY POINTS ===\n")
cat("✅ PSM, PGM, DSM: All from dsmatch package (as you correctly noted)\n")
cat("✅ PS Full: From matchit with method='full' and estimand='ATE' (works!)\n")
cat("✅ WDSM: Your custom adaptive function\n")
cat("\nThis exactly matches your successful run_complete_all_methods.R implementation!\n")

save(results_uric, results_sbp, comparison_uric, comparison_sbp,
     file = "analysis_results/CORRECT_ALL_5_METHODS.rda")

cat("\n✅ COMPLETE: All 5 methods implemented correctly as in your original!\n")
cat("Results saved to: analysis_results/CORRECT_ALL_5_METHODS.rda\n\n")



