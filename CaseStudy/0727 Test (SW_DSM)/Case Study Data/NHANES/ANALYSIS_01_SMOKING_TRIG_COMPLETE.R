################################################################################
# ANALYSIS 1: Smoking Status → Triglycerides  
# FOLLOWING EXACT PATTERN FROM run_complete_all_methods.R
#
# All 5 Methods: DSM, PGM, PSM, PS Full, WDSM
################################################################################

rm(list = ls())

# Load libraries
suppressPackageStartupMessages({
  library(dplyr)
  library(MatchIt)
  library(marginaleffects)
})

# Source ALL dsmatch R files to ensure all dependencies
dsm_dir <- "../SAMHSA 0914/dsmatch-master/R/"
dsm_files <- c("is.lp.R", "is.ps.R", "is.pg.R", "bisect.R",
               "estforboot_dsATE.R", "estforboot_pgATE.R", "estforboot_psATE.R",
               "dsmatchATE.R")
for(f in dsm_files) {
  if(file.exists(paste0(dsm_dir, f))) {
    source(paste0(dsm_dir, f))
  }
}

# Load adaptive WDSM function
source("WDSM_adaptive.R")

# Set seed
set.seed(2024)
B_BOOTSTRAP <- 200

cat("\n")
cat("===============================================================================\n")
cat("  ANALYSIS 1: Current Smoking → Serum Triglycerides\n")
cat("  ALL 5 METHODS (Following run_complete_all_methods.R Pattern)\n")
cat("===============================================================================\n")

################################################################################
# STEP 1: DATA PREPARATION
################################################################################

cat("\n─────────────────────────────────────────────────────────────────────────\n")
cat(" STEP 1: DATA PREPARATION\n")
cat("─────────────────────────────────────────────────────────────────────────\n\n")

# Load data
load("data/nhanes_2007_2018.rda")
nhanes <- nhanes_2007_2018

# Create smoking variable
nhanes <- nhanes %>%
  mutate(
    current_smoker = case_when(
      smq020 == 2 ~ 0,  # Never smoker
      smq020 == 1 & smq040 %in% c(1, 2) ~ 1,  # Current smoker (daily or some days)
      smq020 == 1 & smq040 == 3 ~ 0,  # Former smoker
      TRUE ~ NA_real_
    )
  )

# Define complete case dataset
covars <- c("ridageyr", "riagendr", "ridreth1", "dmdeduc2", "indfmpir", "bmxbmi")
all_vars <- c("current_smoker", "lbxtr", "wtmec2yr", covars)

data_complete <- nhanes %>%
  filter(
    ridageyr >= 20,  # Adults only
    !is.na(wtmec2yr) & wtmec2yr > 0
  ) %>%
  select(all_of(all_vars)) %>%
  na.omit()  # Complete cases

n_total <- nrow(data_complete)

cat("Sample size: N =", n_total, "\n")
cat("  Current smokers:", sum(data_complete$current_smoker == 1), "\n")
cat("  Non-smokers:", sum(data_complete$current_smoker == 0), "\n\n")

# Define variables (following exact pattern from run_complete_all_methods.R)
Y <- data_complete$lbxtr
A <- data_complete$current_smoker
w <- data_complete$wtmec2yr
sw <- w * n_total / sum(w)  # Normalized weights

# Prepare covariate matrices
X_ps_df <- data_complete[, covars]
# Convert factors to numeric
for (col in names(X_ps_df)) {
  if (is.factor(X_ps_df[[col]])) {
    X_ps_df[[col]] <- as.numeric(X_ps_df[[col]])
  }
}
X_ps <- as.matrix(X_ps_df)

# For PG, use same covariates (in real analysis could add more)
X_pg <- X_ps

cat("Covariates:\n")
cat("  PS model: age, sex, race, education, income, BMI (", ncol(X_ps), "predictors)\n")
cat("  PG model: same as PS model\n\n")

# Create data frame for MatchIt
df_analysis <- data.frame(
  Y = Y,
  A = A,
  sw = sw,
  data_complete[, covars]
)

# Initialize results storage
results <- list()

################################################################################
# METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING (DSM)
################################################################################

cat("───────────────────────────────────────────────────────────────────────────\n")
cat(" METHOD 1: Unweighted DSM (1:1 matching) - SAMPLE ESTIMAND\n")
cat("───────────────────────────────────────────────────────────────────────────\n\n")

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
  ci_upper = dsm_result$est.ds + 1.96*sqrt(dsm_result$bootvar[1,1])
)

cat("✅ DSM Complete\n")
cat("  Estimate:", round(results$dsm$estimate, 2), "mg/dL\n")
cat("  95% CI: [", round(results$dsm$ci_lower, 2), ",", 
    round(results$dsm$ci_upper, 2), "]\n\n")

################################################################################
# METHOD 2: UNWEIGHTED PROGNOSTIC SCORE MATCHING (PGM)
################################################################################

cat("───────────────────────────────────────────────────────────────────────────\n")
cat(" METHOD 2: Unweighted PGM (1:1 matching) - SAMPLE ESTIMAND\n")
cat("───────────────────────────────────────────────────────────────────────────\n\n")

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
  ci_upper = pgm_result$est.pg + 1.96*sqrt(pgm_result$bootvar[1,1])
)

cat("✅ PGM Complete\n")
cat("  Estimate:", round(results$pgm$estimate, 2), "mg/dL\n")
cat("  95% CI: [", round(results$pgm$ci_lower, 2), ",", 
    round(results$pgm$ci_upper, 2), "]\n\n")

################################################################################
# METHOD 3: UNWEIGHTED PROPENSITY SCORE MATCHING (PSM)
################################################################################

cat("───────────────────────────────────────────────────────────────────────────\n")
cat(" METHOD 3: Unweighted PSM (1:1 matching) - SAMPLE ESTIMAND\n")
cat("───────────────────────────────────────────────────────────────────────────\n\n")

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
  ci_upper = psm_result$est.ps + 1.96*sqrt(psm_result$bootvar[1,1])
)

cat("✅ PSM Complete\n")
cat("  Estimate:", round(results$psm$estimate, 2), "mg/dL\n")
cat("  95% CI: [", round(results$psm$ci_lower, 2), ",", 
    round(results$psm$ci_upper, 2), "]\n\n")

################################################################################
# METHOD 4: SURVEY-WEIGHTED PS FULL MATCHING
################################################################################

cat("───────────────────────────────────────────────────────────────────────────\n")
cat(" METHOD 4: Survey-Weighted PS Full Matching - POPULATION ESTIMAND\n")
cat("───────────────────────────────────────────────────────────────────────────\n\n")

ps_formula_matchit <- as.formula(paste("A ~", paste(covars, collapse = " + ")))

suppressWarnings({
  m_ps_full <- matchit(ps_formula_matchit,
                       data = df_analysis,
                       method = "full",
                       distance = "glm",
                       link = "logit",
                       estimand = "ATE",
                       s.weights = sw,
                       verbose = FALSE)
})

md_full <- match.data(m_ps_full)

# Outcome model with interactions
outcome_formula <- as.formula(paste("Y ~ A * (", paste(covars, collapse = " + "), ")"))
fit_full <- lm(outcome_formula, data = md_full, weights = weights)

ate_full <- avg_comparisons(fit_full, 
                           variables = "A",
                           vcov = ~subclass,
                           wts = "sw",
                           comparison = "difference")

results$ps_full <- list(
  estimate = ate_full$estimate,
  se = ate_full$std.error,
  ci_lower = ate_full$conf.low,
  ci_upper = ate_full$conf.high
)

cat("✅ PS Full Complete\n")
cat("  Estimate:", round(results$ps_full$estimate, 2), "mg/dL\n")
cat("  95% CI: [", round(results$ps_full$ci_lower, 2), ",", 
    round(results$ps_full$ci_upper, 2), "]\n\n")

################################################################################
# METHOD 5: WEIGHTED DOUBLE SCORE MATCHING (WDSM)
################################################################################

cat("───────────────────────────────────────────────────────────────────────────\n")
cat(" METHOD 5: WDSM (1:5 matching) - POPULATION ESTIMAND\n")
cat("───────────────────────────────────────────────────────────────────────────\n\n")

wdsm_data <- data_complete
wdsm_data$Y <- Y
wdsm_data$A <- A
wdsm_data$survey_weight <- w

ps_formula_wdsm <- as.formula(paste("A ~", paste(covars, collapse = " + ")))
pg_formula_wdsm <- as.formula(paste("~", paste(covars, collapse = " + ")))

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

cat("Point estimate:", round(wdsm_result$tau, 2), "mg/dL\n")

# Bootstrap for WDSM
cat("Running bootstrap (", B_BOOTSTRAP, "reps)...\n")
boot_wdsm <- numeric(B_BOOTSTRAP)

for (b in 1:B_BOOTSTRAP) {
  if(b %% 50 == 0) cat("  ", b, "...")
  
  m_star <- rmultinom(1, n_total, rep(1/n_total, n_total))[, 1]
  data_boot <- wdsm_data
  data_boot$survey_weight <- m_star * w
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  
  tryCatch({
    suppressWarnings({
      boot_result <- wdsm_adaptive(data_boot, ps_formula_wdsm, pg_formula_wdsm,
                                  "Y", "A", "survey_weight",
                                  M = 5,
                                  use_bias_correction = TRUE, 
                                  verbose = FALSE)
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
  ci_upper = wdsm_ci[2]
)

cat("\n✅ WDSM Complete\n")
cat("  Estimate:", round(results$wdsm$estimate, 2), "mg/dL\n")
cat("  95% CI: [", round(results$wdsm$ci_lower, 2), ",", 
    round(results$wdsm$ci_upper, 2), "]\n\n")

################################################################################
# FINAL RESULTS
################################################################################

cat("\n")
cat("===============================================================================\n")
cat(" FINAL RESULTS: Smoking → Triglycerides (N=", n_total, ")\n")
cat("===============================================================================\n\n")

cat("Research Question: Does current smoking increase serum triglycerides?\n")
cat("Sample: NHANES 2007-2018, Adults ≥20 years\n")
cat("Treatment: Current smokers (n=", sum(A==1), ") vs Non-smokers (n=", sum(A==0), ")\n")
cat("Outcome: Serum triglycerides (mg/dL)\n")
cat("Covariates: Age, sex, race, education, income (PIR), BMI\n\n")

cat("Table 1: Effect of Current Smoking on Serum Triglycerides\n")
cat("───────────────────────────────────────────────────────────────────────────\n")
cat(sprintf("%-30s %10s  %25s  %s\n", "Method", "Estimate", "95% CI", "Estimand"))
cat("───────────────────────────────────────────────────────────────────────────\n")

for(method in c("dsm", "pgm", "psm", "ps_full", "wdsm")) {
  r <- results[[method]]
  method_name <- c(dsm="Unweighted DSM", pgm="Unweighted PGM", 
                   psm="Unweighted PSM", ps_full="Survey-Weighted PS Full",
                   wdsm="WDSM")[method]
  estimand <- ifelse(method %in% c("ps_full", "wdsm"), "Population", "Sample")
  
  cat(sprintf("%-30s %7.2f     [%6.2f, %6.2f]     %s\n",
              method_name,
              r$estimate,
              r$ci_lower,
              r$ci_upper,
              estimand))
}

cat("───────────────────────────────────────────────────────────────────────────\n")
cat("Estimates = Mean difference in triglycerides (mg/dL): Smokers vs Non-smokers\n\n")

# Calculate summary
sample_avg <- mean(c(results$dsm$estimate, results$pgm$estimate, results$psm$estimate))
pop_avg <- mean(c(results$ps_full$estimate, results$wdsm$estimate))
bias_pct <- (sample_avg - pop_avg) / pop_avg * 100

cat("Summary Statistics:\n")
cat("  Sample average (3 unweighted):", round(sample_avg, 2), "mg/dL\n")
cat("  Population average (2 weighted):", round(pop_avg, 2), "mg/dL\n")
cat("  Absolute difference:", round(sample_avg - pop_avg, 2), "mg/dL\n")
cat("  Relative bias:", sprintf("%+.1f%%", bias_pct), "\n\n")

# Save results
save(data_complete, results, sample_avg, pop_avg, bias_pct,
     file = "ANALYSIS_01_SMOKING_TRIGLYCERIDES_COMPLETE.rda")

cat("✅ Results saved: ANALYSIS_01_SMOKING_TRIGLYCERIDES_COMPLETE.rda\n")

cat("\n")
cat("===============================================================================\n")
cat(" ANALYSIS 1 COMPLETE - ALL 5 METHODS\n")
cat("===============================================================================\n")

