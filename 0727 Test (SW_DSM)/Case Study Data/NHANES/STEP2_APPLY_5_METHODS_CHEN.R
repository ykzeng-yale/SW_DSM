################################################################################
# STEP 2: APPLY OUR 5 MATCHING METHODS TO CHEN DATA
# Now that data handling is verified, apply our framework
# PSM, PGM, DSM (unweighted) + PS Full, WDSM (survey-weighted)
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
load("analysis_results/chen_data_prepared.rda")  # From Step 1

cat("\n")
cat("==============================================================================\n")
cat("   STEP 2: APPLY 5 MATCHING METHODS TO CHEN DATA\n")
cat("   Obese (BMI≥30) vs Normal (BMI 18.5-25) → Uric Acid\n")
cat("==============================================================================\n")

n <- nrow(data_binary)
cat("\nSample size:", n, "\n")
cat("Obese:", sum(data_binary$obese), "(", round(100*mean(data_binary$obese), 1), "%)\n")

# Prepare variables
Y <- data_binary$lbxsua
A <- data_binary$obese
w <- data_binary$wtmec2yr
sw <- w * n / sum(w)  # Normalized weights

# Define covariate sets
# PS model: Key confounders
ps_vars <- c("age", "female", "race1")
# PG model: PS vars + additional predictors
pg_vars <- c(ps_vars, "pir", "education")

# Remove any missing vars
ps_vars <- ps_vars[ps_vars %in% names(data_binary)]
pg_vars <- pg_vars[pg_vars %in% names(data_binary)]

cat("\nPS model covariates:", paste(ps_vars, collapse=", "), "\n")
cat("PG model covariates:", paste(pg_vars, collapse=", "), "\n")

# Prepare matrices for dsmatch
X_ps <- as.matrix(data_binary[, ps_vars])
X_pg <- as.matrix(data_binary[, pg_vars])

# Data frame for MatchIt
df <- data.frame(
  Y = Y,
  A = A,
  sw = sw,
  data_binary[, unique(c(ps_vars, pg_vars))]
)

B_BOOTSTRAP <- 200
results <- list()

################################################################################
# METHOD 1: UNWEIGHTED PSM (from dsmatch)
################################################################################

cat("\n--- METHOD 1: Unweighted PSM (1:1 matching) - SAMPLE ESTIMATE ---\n")
cat("  Running bootstrap (", B_BOOTSTRAP, " replications):\n", sep="")
cat("  Progress: ")

suppressWarnings({
  # Note: dsmatch handles bootstrap internally but we can't easily show progress
  # It will show progress if verbose=TRUE but that's too much output
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
cat(" Complete!\n")

results$psm <- list(
  estimate = psm_result$est.ps,
  se = sqrt(psm_result$bootvar[1,1]),
  ci_lower = psm_result$est.ps - 1.96*sqrt(psm_result$bootvar[1,1]),
  ci_upper = psm_result$est.ps + 1.96*sqrt(psm_result$bootvar[1,1]),
  method = "Unweighted PSM",
  estimand = "Sample ATE"
)

cat("  Estimate:", round(results$psm$estimate, 3), "mg/dL\n")
cat("  95% CI: [", round(results$psm$ci_lower, 3), ", ", round(results$psm$ci_upper, 3), "]\n")
cat("  Significant:", ifelse(results$psm$ci_lower > 0 | results$psm$ci_upper < 0, "YES", "NO"), "\n")

################################################################################
# METHOD 2: UNWEIGHTED PGM (from dsmatch)
################################################################################

cat("\n--- METHOD 2: Unweighted PGM (1:1 matching) - SAMPLE ESTIMATE ---\n")
cat("  Running bootstrap (", B_BOOTSTRAP, " replications):\n", sep="")
cat("  Progress: ")

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
cat(" Complete!\n")

results$pgm <- list(
  estimate = pgm_result$est.pg,
  se = sqrt(pgm_result$bootvar[1,1]),
  ci_lower = pgm_result$est.pg - 1.96*sqrt(pgm_result$bootvar[1,1]),
  ci_upper = pgm_result$est.pg + 1.96*sqrt(pgm_result$bootvar[1,1]),
  method = "Unweighted PGM",
  estimand = "Sample ATE"
)

cat("  Estimate:", round(results$pgm$estimate, 3), "mg/dL\n")
cat("  95% CI: [", round(results$pgm$ci_lower, 3), ", ", round(results$pgm$ci_upper, 3), "]\n")

################################################################################
# METHOD 3: UNWEIGHTED DSM (from dsmatch)
################################################################################

cat("\n--- METHOD 3: Unweighted DSM (1:1 matching) - SAMPLE ESTIMATE ---\n")
cat("  Running bootstrap (", B_BOOTSTRAP, " replications):\n", sep="")
cat("  Progress: ")

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
cat(" Complete!\n")

results$dsm <- list(
  estimate = dsm_result$est.ds,
  se = sqrt(dsm_result$bootvar[1,1]),
  ci_lower = dsm_result$est.ds - 1.96*sqrt(dsm_result$bootvar[1,1]),
  ci_upper = dsm_result$est.ds + 1.96*sqrt(dsm_result$bootvar[1,1]),
  method = "Unweighted DSM",
  estimand = "Sample ATE"
)

cat("  Estimate:", round(results$dsm$estimate, 3), "mg/dL\n")
cat("  95% CI: [", round(results$dsm$ci_lower, 3), ", ", round(results$dsm$ci_upper, 3), "]\n")

################################################################################
# METHOD 4: SURVEY-WEIGHTED PS FULL (from matchit)
################################################################################

cat("\n--- METHOD 4: Survey-Weighted PS Full Matching - POPULATION ESTIMATE ---\n")

ps_formula <- as.formula(paste("A ~", paste(ps_vars, collapse = " + ")))

# Try full matching first
tryCatch({
  cat("  Attempting full matching...")
  m_ps <- matchit(ps_formula,
                  data = df,
                  method = "full",
                  distance = "glm",
                  link = "logit",
                  estimand = "ATE",
                  s.weights = sw,
                  verbose = FALSE)
  cat(" Success!\n")
}, error = function(e) {
  if(grepl("exceed|memory", e$message, ignore.case = TRUE)) {
    cat(" Memory issue!\n")
    cat("  Falling back to 1:5 nearest matching...\n")
    m_ps <<- matchit(ps_formula,
                     data = df,
                     method = "nearest",
                     distance = "glm",
                     link = "logit",
                     ratio = 5,
                     estimand = "ATE",
                     s.weights = sw,
                     verbose = FALSE)
    cat("  Fallback successful!\n")
  } else {
    stop(e)
  }
})

# Get matched data and fit outcome model
md <- match.data(m_ps)

# Outcome model with all PG covariates
outcome_formula <- as.formula(paste("Y ~ A * (", paste(pg_vars, collapse = " + "), ")"))
fit <- lm(outcome_formula, data = md, weights = weights)

# Get ATE with proper variance
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
  method = "Survey-Weighted PS Full",
  estimand = "Population ATE"
)

cat("  Estimate:", round(results$ps_full$estimate, 3), "mg/dL\n")
cat("  95% CI: [", round(results$ps_full$ci_lower, 3), ", ", round(results$ps_full$ci_upper, 3), "]\n")

################################################################################
# METHOD 5: WDSM (Your custom function)
################################################################################

cat("\n--- METHOD 5: WDSM (1:5 matching) - POPULATION ESTIMATE ---\n")

# Prepare WDSM data
wdsm_data <- data_binary
wdsm_data$Y <- Y
wdsm_data$A <- A
wdsm_data$survey_weight <- w

ps_formula_wdsm <- ps_formula
pg_formula_wdsm <- as.formula(paste("~", paste(pg_vars, collapse = " + ")))

# Run WDSM point estimate
cat("  Computing point estimate...")
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
cat(" Done!\n")

# Bootstrap for WDSM with detailed progress
set.seed(2024)
cat("  Running bootstrap (", B_BOOTSTRAP, " replications):\n", sep="")
cat("  Progress: 0%")
boot_wdsm <- numeric(B_BOOTSTRAP)
n_valid <- 0

for (b in 1:B_BOOTSTRAP) {
  # Update progress every 10 iterations
  if (b %% 10 == 0) {
    cat("\r  Progress: ", round(100*b/B_BOOTSTRAP), "%", sep="")
    flush.console()
  }
  
  # Multinomial weights
  m_star <- rmultinom(1, n, rep(1/n, n))[, 1]
  data_boot <- wdsm_data
  data_boot$survey_weight <- m_star * w
  
  # Skip if degenerate
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  
  # Try bootstrap iteration
  tryCatch({
    suppressWarnings({
      boot_result <- wdsm_adaptive(
        data = data_boot,
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
    boot_wdsm[b] <- boot_result$tau
    n_valid <- n_valid + 1
  }, error = function(e) NULL)
}
cat("\r  Progress: 100% Complete! (", n_valid, " valid bootstraps)\n", sep="")

# Calculate bootstrap statistics
boot_wdsm <- boot_wdsm[!is.na(boot_wdsm) & boot_wdsm != 0]
wdsm_se <- sd(boot_wdsm)
wdsm_ci <- quantile(boot_wdsm, c(0.025, 0.975))

results$wdsm <- list(
  estimate = wdsm_result$tau,
  se = wdsm_se,
  ci_lower = wdsm_ci[1],
  ci_upper = wdsm_ci[2],
  method = "WDSM",
  estimand = "Population ATE"
)

cat("  Estimate:", round(results$wdsm$estimate, 3), "mg/dL\n")
cat("  SE:", round(results$wdsm$se, 3), "\n")
cat("  95% CI: [", round(results$wdsm$ci_lower, 3), ", ", round(results$wdsm$ci_upper, 3), "]\n")

################################################################################
# FINAL COMPARISON TABLE
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   COMPLETE RESULTS: All 5 Methods Applied to Chen Data\n")
cat("   Obese (BMI≥30) vs Normal (BMI 18.5-25) → Uric Acid\n")
cat("==============================================================================\n")

comparison_table <- data.frame(
  Method = c("1. Unwt PSM (dsmatch)",
             "2. Unwt PGM (dsmatch)",
             "3. Unwt DSM (dsmatch)",
             "4. Wt PS Full (matchit)",
             "5. WDSM (custom)"),
  `Estimate (mg/dL)` = sprintf("%.3f", sapply(results, function(x) x$estimate)),
  `SE` = sprintf("%.3f", sapply(results, function(x) x$se)),
  `95% CI` = sapply(results, function(x) sprintf("[%.3f, %.3f]", x$ci_lower, x$ci_upper)),
  Significant = sapply(results, function(x) {
    ifelse(x$ci_lower > 0, "YES (+)", 
           ifelse(x$ci_upper < 0, "YES (-)", "NO"))
  }),
  Estimand = sapply(results, function(x) x$estimand),
  check.names = FALSE
)

print(comparison_table, row.names = FALSE)

# Key comparison
cat("\n=== KEY COMPARISON: Sample vs Population Estimates ===\n")
cat("\nUNWEIGHTED METHODS (Sample ATE):\n")
cat("  PSM:", round(results$psm$estimate, 3), "mg/dL\n")
cat("  PGM:", round(results$pgm$estimate, 3), "mg/dL\n")
cat("  DSM:", round(results$dsm$estimate, 3), "mg/dL\n")
cat("  Average:", round(mean(c(results$psm$estimate, results$pgm$estimate, results$dsm$estimate)), 3), "\n")

cat("\nSURVEY-WEIGHTED METHODS (Population ATE):\n")
cat("  PS Full:", round(results$ps_full$estimate, 3), "mg/dL\n")
cat("  WDSM:", round(results$wdsm$estimate, 3), "mg/dL\n")
cat("  Average:", round(mean(c(results$ps_full$estimate, results$wdsm$estimate)), 3), "\n")

# Calculate percentage difference
sample_avg <- mean(c(results$psm$estimate, results$pgm$estimate, results$dsm$estimate))
pop_avg <- mean(c(results$ps_full$estimate, results$wdsm$estimate))
pct_diff <- 100 * (sample_avg - pop_avg) / abs(pop_avg)

cat("\n*** DIFFERENCE: Sample estimates are", round(pct_diff, 1), "% different from population estimates ***\n")

# Compare to Chen's regression
cat("\n=== REFERENCE: Chen's Regression Results ===\n")
cat("Chen (Women, adjusted): β = 0.51 for Obese vs Underweight\n")
cat("Our regression (Step 1): β = 1.148 for Obese vs Underweight\n")
cat("Our survey-weighted regression: β ≈ 0.96 for Obese vs Normal\n")

# Save results
save(results, comparison_table, file = "analysis_results/CHEN_ALL_5_METHODS_FINAL.rda")

cat("\n")
cat("==============================================================================\n")
cat("✅ SUCCESS: All 5 methods properly applied to verified Chen data!\n")
cat("Results saved to: analysis_results/CHEN_ALL_5_METHODS_FINAL.rda\n")
cat("==============================================================================\n")