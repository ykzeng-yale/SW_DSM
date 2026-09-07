################################################################################
# PAPER 2: OBESITY → HYPERTENSION (Generic - Multiple Published Papers)
#
# Representative of 20+ NHANES papers using unweighted PSM for obesity outcomes
#
# Published Pattern: OR typically 2.0-3.0 for obesity→HTN
# Method: 1:1 unweighted PSM
#
# Our Analysis: Complete 6-method comparison
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

# Convert labelled data
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

cat("\n")
cat("==============================================================================\n")
cat("   PAPER 2: OBESITY → HYPERTENSION (Multiple Published Papers)\n")
cat("==============================================================================\n")

################################################################################
# DATA PREPARATION  
################################################################################

cat("\n=== DATA PREPARATION ===\n")

obesity_data <- nhanes_clean %>%
  filter(
    !is.na(bmi),
    !is.na(hypertension),
    !is.na(age),
    age >= 20,  # Adults only
    !is.na(female),
    !is.na(race1),
    !is.na(education),
    !is.na(pir),
    !is.na(wtmec2yr),
    !is.na(sdmvpsu),
    !is.na(sdmvstra)
  ) %>%
  mutate(
    obesity = as.numeric(bmi >= 30),
    A = obesity,
    Y = hypertension,
    survey_weight = wtmec2yr,
    n = n(),
    sw = wtmec2yr * n / sum(wtmec2yr)
  )

# Add smoking and diabetes if available
if("smokestatus" %in% names(obesity_data)) {
  obesity_data <- obesity_data %>% filter(!is.na(smokestatus))
}
if("diabetes" %in% names(obesity_data)) {
  obesity_data <- obesity_data %>% filter(!is.na(diabetes))
}

n <- nrow(obesity_data)
cat("Total N:", n, "\n")
cat("Obese (BMI≥30):", sum(obesity_data$obesity), 
    "(", round(100*mean(obesity_data$obesity), 1), "%)\n")
cat("Hypertension prevalence:", round(100*mean(obesity_data$hypertension), 1), "%\n")

# Weighted proportions
prop_obese_wt <- sum(obesity_data$wtmec2yr[obesity_data$obesity==1]) / sum(obesity_data$wtmec2yr)
cat("Weighted % obese:", round(100*prop_obese_wt, 1), "%\n")

# Define confounders
confounders <- c("age", "female", "race1", "education", "pir")
if("smokestatus" %in% names(obesity_data)) {
  confounders <- c(confounders, "smokestatus")
}
if("diabetes" %in% names(obesity_data)) {
  confounders <- c(confounders, "diabetes")
}

ps_formula <- as.formula(paste("obesity ~", paste(confounders, collapse = " + ")))
pg_formula <- as.formula(paste("~", paste(confounders, collapse = " + ")))

obesity_results <- list()

################################################################################
# METHOD 1: UNWEIGHTED PSM (Published Approach)
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 1: Unweighted PSM (Published Approach)\n")
cat("========================================================================\n")
cat("Replicates typical NHANES obesity studies using MatchIt without weights\n")

m_unwt_psm <- matchit(
  ps_formula,
  data = obesity_data,
  method = "nearest",
  distance = "glm",
  link = "logit",
  ratio = 1,
  replace = FALSE
)

md_unwt_psm <- match.data(m_unwt_psm)
cat("Matched sample size:", nrow(md_unwt_psm), "\n")

# Logistic regression on matched data
model_unwt_psm <- glm(Y ~ obesity, data = md_unwt_psm, family = binomial())
or_unwt_psm <- exp(coef(model_unwt_psm)["obesity"])
ci_unwt_psm <- exp(confint(model_unwt_psm)["obesity", ])

obesity_results$unweighted_psm <- list(
  or = or_unwt_psm,
  ci_lower = ci_unwt_psm[1],
  ci_upper = ci_unwt_psm[2],
  estimand = "Sample ATE"
)

cat("\n📊 RESULTS (Unweighted PSM):\n")
cat("  OR =", round(or_unwt_psm, 3), "\n")
cat("  95% CI: [", round(ci_unwt_psm[1], 3), ", ", round(ci_unwt_psm[2], 3), "]\n", sep="")

################################################################################
# METHOD 2: WEIGHTED REGRESSION
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 2: Survey-Weighted Logistic Regression\n")
cat("========================================================================\n")

options(survey.lonely.psu = "adjust")
svy_design <- svydesign(
  ids = ~sdmvpsu,
  strata = ~sdmvstra,
  weights = ~wtmec2yr,
  nest = TRUE,
  data = obesity_data
)

formula_adj <- as.formula(paste("hypertension ~ obesity +", paste(confounders, collapse = " + ")))
model_wt_reg <- svyglm(formula_adj, design = svy_design, family = quasibinomial())

or_wt_reg <- exp(coef(model_wt_reg)["obesity"])
ci_wt_reg <- exp(confint(model_wt_reg)["obesity", ])

obesity_results$weighted_reg <- list(
  or = or_wt_reg,
  ci_lower = ci_wt_reg[1],
  ci_upper = ci_wt_reg[2],
  estimand = "Population ATE"
)

cat("\n📊 RESULTS (Weighted Regression):\n")
cat("  OR =", round(or_wt_reg, 3), "\n")
cat("  95% CI: [", round(ci_wt_reg[1], 3), ", ", round(ci_wt_reg[2], 3), "]\n", sep="")

################################################################################
# METHOD 3: PS FULL (Survey-Weighted)
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 3: PS Full Matching (Survey-Weighted)\n")
cat("========================================================================\n")

m_ps_full <- matchit(
  ps_formula,
  data = obesity_data,
  method = "full",
  distance = "glm",
  link = "logit",
  estimand = "ATE",
  s.weights = obesity_data$sw
)

md_ps_full <- match.data(m_ps_full)

outcome_formula <- as.formula(paste("Y ~ obesity +", paste(confounders, collapse = " + ")))
fit_ps_full <- glm(outcome_formula, data = md_ps_full, 
                   weights = weights, family = quasibinomial())

ate_ps_full <- avg_comparisons(fit_ps_full,
                                variables = "obesity",
                                vcov = ~subclass,
                                wts = "sw",
                                comparison = "lnor")

or_ps_full <- exp(ate_ps_full$estimate)
ci_ps_full <- exp(c(ate_ps_full$conf.low, ate_ps_full$conf.high))

obesity_results$ps_full <- list(
  or = or_ps_full,
  ci_lower = ci_ps_full[1],
  ci_upper = ci_ps_full[2],
  estimand = "Population ATE"
)

cat("\n📊 RESULTS (PS Full):\n")
cat("  OR =", round(or_ps_full, 3), "\n")
cat("  95% CI: [", round(ci_ps_full[1], 3), ", ", round(ci_ps_full[2], 3), "]\n", sep="")

################################################################################
# METHOD 4: IPTW (Survey-Weighted)
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 4: IPTW (Survey-Weighted)\n")
cat("========================================================================\n")

ps_model <- svyglm(ps_formula, design = svy_design, family = quasibinomial())
e_score <- predict(ps_model, type = "response", newdata = obesity_data)

iptw_weights <- ifelse(obesity_data$obesity == 1, 1/e_score, 1/(1-e_score))

cat("IPTW weight distribution:\n")
cat("  Max:", round(max(iptw_weights, na.rm=TRUE), 1), "\n")
cat("  % > 10:", round(100*mean(iptw_weights > 10, na.rm=TRUE), 1), "%\n")

combined_weights <- iptw_weights * obesity_data$wtmec2yr

model_iptw <- glm(Y ~ obesity, data = obesity_data, 
                  weights = combined_weights, family = quasibinomial())
or_iptw <- exp(coef(model_iptw)["obesity"])
ci_iptw <- exp(confint(model_iptw)["obesity", ])

obesity_results$iptw <- list(
  or = or_iptw,
  ci_lower = ci_iptw[1],
  ci_upper = ci_iptw[2],
  max_weight = max(iptw_weights, na.rm=TRUE),
  estimand = "Population ATE"
)

cat("\n📊 RESULTS (IPTW):\n")
cat("  OR =", round(or_iptw, 3), "\n")
cat("  95% CI: [", round(ci_iptw[1], 3), ", ", round(ci_iptw[2], 3), "]\n", sep="")

################################################################################
# METHOD 5: UNWEIGHTED DSM
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 5: Unweighted DSM\n")
cat("========================================================================\n")

X_ps_df <- obesity_data[, confounders]
for (col in names(X_ps_df)) {
  if (is.factor(X_ps_df[[col]])) {
    X_ps_df[[col]] <- as.numeric(X_ps_df[[col]])
  }
}
X_ps <- as.matrix(X_ps_df)
X_pg <- X_ps

suppressWarnings({
  dsm_result <- dsmatchATE(
    Y = obesity_data$Y,
    X = X_ps,
    A = obesity_data$A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X_pg,
    cov.balance = FALSE,
    varest = TRUE,
    boots = 100,
    mc = FALSE,
    ncpus = 1
  )
})

obesity_results$dsm <- list(
  ate = dsm_result$est.ds,
  se = sqrt(dsm_result$bootvar[1,1]),
  ci_lower = dsm_result$est.ds - 1.96*sqrt(dsm_result$bootvar[1,1]),
  ci_upper = dsm_result$est.ds + 1.96*sqrt(dsm_result$bootvar[1,1])
)

cat("\n📊 RESULTS (DSM):\n")
cat("  ATE =", round(obesity_results$dsm$ate, 3), "\n")
cat("  95% CI: [", round(obesity_results$dsm$ci_lower, 3), ", ", 
    round(obesity_results$dsm$ci_upper, 3), "]\n", sep="")

################################################################################
# METHOD 6: WDSM
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 6: WDSM (Our Method)\n")
cat("========================================================================\n")

suppressWarnings({
  wdsm_result <- wdsm_adaptive(
    data = obesity_data,
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

obesity_results$wdsm <- list(
  ate = wdsm_result$tau,
  estimand = "Population ATE"
)

cat("\n📊 RESULTS (WDSM):\n")
cat("  ATE =", round(obesity_results$wdsm$ate, 3), "\n")

################################################################################
# COMPREHENSIVE COMPARISON
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("         COMPREHENSIVE COMPARISON: OBESITY → HYPERTENSION\n")
cat("==============================================================================\n")

comparison_table <- data.frame(
  Method = c(
    "1. Unwt PSM (Published pattern)",
    "2. Unwt DSM",
    "3. Weighted Logistic Reg",
    "4. PS Full (Weighted)",
    "5. IPTW (Weighted)",
    "6. WDSM (Our Method)"
  ),
  Result = c(
    sprintf("OR=%.3f [%.3f,%.3f]", obesity_results$unweighted_psm$or,
            obesity_results$unweighted_psm$ci_lower, obesity_results$unweighted_psm$ci_upper),
    sprintf("ATE=%.3f [%.3f,%.3f]", obesity_results$dsm$ate,
            obesity_results$dsm$ci_lower, obesity_results$dsm$ci_upper),
    sprintf("OR=%.3f [%.3f,%.3f]", obesity_results$weighted_reg$or,
            obesity_results$weighted_reg$ci_lower, obesity_results$weighted_reg$ci_upper),
    sprintf("OR=%.3f [%.3f,%.3f]", obesity_results$ps_full$or,
            obesity_results$ps_full$ci_lower, obesity_results$ps_full$ci_upper),
    sprintf("OR=%.3f [%.3f,%.3f]", obesity_results$iptw$or,
            obesity_results$iptw$ci_lower, obesity_results$iptw$ci_upper),
    sprintf("ATE=%.3f", obesity_results$wdsm$ate)
  ),
  Estimand = c("Sample", "Sample", "Population", "Population", "Population", "Population"),
  `Survey Weights?` = c("NO", "NO", "YES", "YES", "YES", "YES"),
  check.names = FALSE
)

print(comparison_table, row.names = FALSE)

cat("\n=== KEY FINDINGS ===\n")

pct_diff <- 100 * (obesity_results$unweighted_psm$or - obesity_results$weighted_reg$or) / 
             obesity_results$weighted_reg$or

cat("\n1. SAMPLE vs POPULATION:\n")
cat("   Unweighted PSM OR:", round(obesity_results$unweighted_psm$or, 3), "\n")
cat("   Weighted Reg OR:", round(obesity_results$weighted_reg$or, 3), "\n")
cat("   Difference:", round(abs(pct_diff), 1), "%\n")

cat("\n2. EXTREME WEIGHTS:\n")
cat("   IPTW max weight:", round(obesity_results$iptw$max_weight, 1), "\n")

save(obesity_results, comparison_table, obesity_data,
     file = "analysis_results/paper2_obesity_htn_ALL_METHODS.rda")

cat("\n==============================================================================\n")
cat("PAPER 2: COMPLETE\n")
cat("==============================================================================\n")
