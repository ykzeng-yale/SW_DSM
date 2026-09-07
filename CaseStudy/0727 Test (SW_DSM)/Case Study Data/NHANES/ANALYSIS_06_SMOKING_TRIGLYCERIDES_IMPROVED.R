################################################################################
# ANALYSIS 6: Smoking Status → Triglycerides
# FOLLOWING EXACT PATTERN FROM PAPER1_LIN_2024_BMI_HBA1C_STEP2.R
################################################################################

rm(list = ls())
library(dplyr)
library(haven)
library(MatchIt)
library(marginaleffects)
library(survey)

if (!require(dsmatch)) {
  install.packages("dsmatch")
  library(dsmatch)
}

source("WDSM_adaptive.R")

set.seed(2024)
B_BOOTSTRAP <- 50  # Fast version for initial results

cat("\n=== PROFESSIONAL BIOSTATISTICAL IMPROVEMENTS ===\n")
cat("1. Exclude triglycerides >1000 mg/dL (extreme outliers)\n")
cat("2. Exclude pregnant women (affects lipid metabolism)\n")
cat("3. Include alcohol as covariate (strongly affects triglycerides)\n")
cat("4. Include physical activity as covariate\n")
cat("5. Restrict to adults 20+ years\n\n")

cat("\n")
cat("===============================================================================\n")
cat("   ANALYSIS 6: Current Smoking → Serum Triglycerides\n")
cat("   ALL 5 MATCHING METHODS\n")
cat("===============================================================================\n")

################################################################################
# STEP 1: PREPARE DATA
################################################################################

load("data/nhanes_2007_2018.rda")
nhanes <- nhanes_2007_2018

# Professional biostatistical data preparation
analytic_data <- nhanes %>%
  mutate(
    current_smoker = case_when(
      smq020 == 2 ~ 0,  # Never smoker
      smq020 == 1 & smq040 %in% c(1, 2) ~ 1,  # Current smoker
      smq020 == 1 & smq040 == 3 ~ 0,  # Former smoker
      TRUE ~ NA_real_
    )
  ) %>%
  filter(
    !is.na(current_smoker),
    !is.na(lbxtr),
    lbxtr >= 10 & lbxtr <= 1000,  # Exclude biologically implausible/extreme values
    ridageyr >= 20,
    # Exclude pregnant women (affects lipid metabolism)
    !(!is.na(ridexprg) & ridexprg == 1),
    # Exclude those on lipid-lowering medications if available
    is.na(bpq100d) | bpq100d != 1  # Not taking cholesterol meds (if variable exists)
  )

cat("\nSample: N =", nrow(analytic_data), "\n")
cat("Mean triglycerides:", round(mean(analytic_data$lbxtr, na.rm=TRUE), 1), "mg/dL\n")

# Prepare data
Y <- analytic_data$lbxtr
A <- analytic_data$current_smoker
sw <- analytic_data$wtmec2yr

cat("\nTreatment (current smokers):", sum(A == 1), "\n")
cat("Control (non-smokers):", sum(A == 0), "\n")

# Professional covariate selection for smoking-triglycerides analysis
# Include all relevant confounders per epidemiological literature
ps_vars <- c("ridageyr", "riagendr", "ridreth1")
available_vars <- names(analytic_data)

# Socioeconomic (affect both smoking and lipids)
if("dmdeduc2" %in% available_vars) ps_vars <- c(ps_vars, "dmdeduc2")
if("indfmpir" %in% available_vars) ps_vars <- c(ps_vars, "indfmpir")

# Metabolic (strong confounder for lipids)
if("bmxbmi" %in% available_vars) ps_vars <- c(ps_vars, "bmxbmi")

# Behavioral (alcohol strongly affects triglycerides - critical covariate!)
if("alq130" %in% available_vars) ps_vars <- c(ps_vars, "alq130")

# Physical activity (affects both smoking patterns and lipids)
if("paq605" %in% available_vars) ps_vars <- c(ps_vars, "paq605")

# For PG model, can add prognostic variables (predict outcome regardless of treatment)
pg_vars <- ps_vars
if("lbxgh" %in% available_vars) pg_vars <- c(pg_vars, "lbxgh")  # Diabetes marker affects lipids

cat("\nPS variables:", paste(ps_vars, collapse = ", "), "\n")
cat("PG variables:", paste(pg_vars, collapse = ", "), "\n")

# Complete cases for covariates
complete_idx <- complete.cases(analytic_data[, c("lbxtr", "current_smoker", ps_vars, "wtmec2yr")])
data_complete <- analytic_data[complete_idx, ]

cat("\nComplete cases with covariates: N =", nrow(data_complete), "\n")

# Update vectors
Y <- data_complete$lbxtr
A <- data_complete$current_smoker
sw <- data_complete$wtmec2yr

X_ps <- as.matrix(data_complete[, ps_vars])
X_pg <- as.matrix(data_complete[, pg_vars])

# Results storage
results <- list()

################################################################################
# METHOD 1: UNWEIGHTED DSM
################################################################################

cat("\n--- METHOD 1: Unweighted DSM (1:1 matching) ---\n")

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
  ci = c(dsm_result$est.ds - 1.96*sqrt(dsm_result$bootvar[1,1]),
         dsm_result$est.ds + 1.96*sqrt(dsm_result$bootvar[1,1]))
)

cat("  Estimate:", round(results$dsm$estimate, 2), "mg/dL\n")
cat("  95% CI: [", round(results$dsm$ci[1], 2), ", ", 
    round(results$dsm$ci[2], 2), "]\n", sep="")

################################################################################
# METHOD 2: UNWEIGHTED PGM
################################################################################

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

results$pgm <- list(
  estimate = pgm_result$est.pg,
  se = sqrt(pgm_result$bootvar[1,1]),
  ci = c(pgm_result$est.pg - 1.96*sqrt(pgm_result$bootvar[1,1]),
         pgm_result$est.pg + 1.96*sqrt(pgm_result$bootvar[1,1]))
)

cat("  Estimate:", round(results$pgm$estimate, 2), "mg/dL\n")
cat("  95% CI: [", round(results$pgm$ci[1], 2), ", ", 
    round(results$pgm$ci[2], 2), "]\n", sep="")

################################################################################
# METHOD 3: UNWEIGHTED PSM
################################################################################

cat("\n--- METHOD 3: Unweighted PSM (1:1 matching) ---\n")

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
  ci = c(psm_result$est.ps - 1.96*sqrt(psm_result$bootvar[1,1]),
         psm_result$est.ps + 1.96*sqrt(psm_result$bootvar[1,1]))
)

cat("  Estimate:", round(results$psm$estimate, 2), "mg/dL\n")
cat("  95% CI: [", round(results$psm$ci[1], 2), ", ", 
    round(results$psm$ci[2], 2), "]\n", sep="")

################################################################################
# METHOD 4: SURVEY-WEIGHTED PS FULL MATCHING
################################################################################

cat("\n--- METHOD 4: Survey-Weighted PS Full Matching ---\n")

# Create dataframe for MatchIt
df_match <- data.frame(
  Y = Y,
  A = A,
  sw = sw,
  data_complete[, ps_vars]
)

# Normalize weights
df_match$sw_norm <- df_match$sw * nrow(df_match) / sum(df_match$sw)

# PS Full matching
ps_formula <- as.formula(paste("A ~", paste(ps_vars, collapse = " + ")))

suppressWarnings({
  m_ps_full <- matchit(ps_formula,
                       data = df_match,
                       method = "full",
                       estimand = "ATE")
})

md_full <- match.data(m_ps_full)
md_full$sw <- df_match$sw_norm[as.numeric(rownames(md_full))]

# Outcome model
outcome_formula <- as.formula(paste("Y ~ A * (", paste(ps_vars, collapse = " + "), ")"))
fit_full <- lm(outcome_formula, data = md_full, weights = weights)

ate_full <- avg_comparisons(fit_full, 
                           variables = "A",
                           vcov = ~subclass,
                           wts = "sw")

results$ps_full <- list(
  estimate = ate_full$estimate,
  se = ate_full$std.error,
  ci = c(ate_full$conf.low, ate_full$conf.high)
)

cat("  Estimate:", round(results$ps_full$estimate, 2), "mg/dL\n")
cat("  95% CI: [", round(results$ps_full$ci[1], 2), ", ", 
    round(results$ps_full$ci[2], 2), "]\n", sep="")

################################################################################
# METHOD 5: WDSM
################################################################################

cat("\n--- METHOD 5: WDSM (Weighted Double Score Matching) ---\n")

cat("  Computing point estimate... ")
wdsm_result <- wdsm_adaptive(
  Y = Y,
  A = A,
  X_ps = X_ps,
  X_pg = X_pg,
  sw = sw,
  caliper = 0.2,
  ratio = 1
)
cat("Done!\n")

cat("  Bootstrap (200 reps): ")
wdsm_boot <- bootstrap_adaptive_wdsm(
  Y = Y,
  A = A,
  X_ps = X_ps,
  X_pg = X_pg,
  sw = sw,
  B = 200,
  caliper = 0.2,
  ratio = 1
)
cat(" Done\n")

results$wdsm <- list(
  estimate = wdsm_boot$point_estimate,
  se = wdsm_boot$se,
  ci = wdsm_boot$ci
)

cat("  Estimate:", round(results$wdsm$estimate, 2), "mg/dL\n")
cat("  95% CI: [", round(results$wdsm$ci[1], 2), ", ", 
    round(results$wdsm$ci[2], 2), "]\n", sep="")

################################################################################
# FINAL RESULTS
################################################################################

cat("\n")
cat("===============================================================================\n")
cat("   FINAL RESULTS: Smoking → Triglycerides\n")
cat("===============================================================================\n\n")

cat("Research Question: Does current smoking increase serum triglycerides?\n")
cat("Sample: NHANES 2007-2018, N =", nrow(data_complete), "adults\n")
cat("Treatment: Current smokers (n=", sum(A==1), ") vs Non-smokers (n=", sum(A==0), ")\n")
cat("Outcome: Serum triglycerides (mg/dL)\n")
cat("Covariates:", paste(ps_vars, collapse = ", "), "\n\n")

cat("Table: Effect of Current Smoking on Serum Triglycerides\n")
cat("───────────────────────────────────────────────────────────────────────────\n")
cat(sprintf("%-30s %10s  %25s  %s\n", "Method", "Estimate", "95% CI", "Estimand"))
cat("───────────────────────────────────────────────────────────────────────────\n")

cat(sprintf("%-30s %7.2f     [%6.2f, %6.2f]     Sample\n",
            "Unweighted DSM", results$dsm$estimate, results$dsm$ci[1], results$dsm$ci[2]))
cat(sprintf("%-30s %7.2f     [%6.2f, %6.2f]     Sample\n",
            "Unweighted PGM", results$pgm$estimate, results$pgm$ci[1], results$pgm$ci[2]))
cat(sprintf("%-30s %7.2f     [%6.2f, %6.2f]     Sample\n",
            "Unweighted PSM", results$psm$estimate, results$psm$ci[1], results$psm$ci[2]))
cat(sprintf("%-30s %7.2f     [%6.2f, %6.2f]     Population\n",
            "Survey-Weighted PS Full", results$ps_full$estimate, 
            results$ps_full$ci[1], results$ps_full$ci[2]))
cat(sprintf("%-30s %7.2f     [%6.2f, %6.2f]     Population\n",
            "WDSM", results$wdsm$estimate, results$wdsm$ci[1], results$wdsm$ci[2]))

cat("───────────────────────────────────────────────────────────────────────────\n")
cat("Estimates = Mean difference in triglycerides (mg/dL): Smokers vs Non-smokers\n\n")

# Summary
sample_avg <- mean(c(results$dsm$estimate, results$pgm$estimate, results$psm$estimate))
pop_avg <- mean(c(results$ps_full$estimate, results$wdsm$estimate))
bias_pct <- (sample_avg - pop_avg) / pop_avg * 100

cat("Summary Statistics:\n")
cat("  Sample average (3 unweighted):", round(sample_avg, 2), "mg/dL\n")
cat("  Population average (2 weighted):", round(pop_avg, 2), "mg/dL\n")
cat("  Bias:", sprintf("%+.1f%%", bias_pct), "\n\n")

# Save results
save(data_complete, results, sample_avg, pop_avg, bias_pct,
     file = "ANALYSIS_06_SMOKING_TRIGLYCERIDES_COMPLETE.rda")

cat("✅ Results saved: ANALYSIS_06_SMOKING_TRIGLYCERIDES_COMPLETE.rda\n")

cat("\n===============================================================================\n")
cat("   ANALYSIS 6 COMPLETE - ALL 5 METHODS\n")
cat("===============================================================================\n")

