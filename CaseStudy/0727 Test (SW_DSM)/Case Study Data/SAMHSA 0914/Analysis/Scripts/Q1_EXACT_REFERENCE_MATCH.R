#!/usr/bin/env Rscript

#' Q1: Gender → Alcohol Frequency
#' EXACTLY matching 11_complete_both_outcomes.R methodology

suppressPackageStartupMessages({
  library(tidyverse)
  library(survey)
  library(MatchIt)
  library(marginaleffects)
  library(Matching)
})

# Source functions EXACTLY as reference
source("dsmatch-master/R/is.lp.R")
source("dsmatch-master/R/is.ps.R")
source("dsmatch-master/R/is.pg.R")
source("dsmatch-master/R/estforboot_dsATE.R")
source("dsmatch-master/R/estforboot_psATE.R")
source("dsmatch-master/R/estforboot_pgATE.R")
source("dsmatch-master/R/estforboot_covATE.R")
source("dsmatch-master/R/dsmatchATE.R")
source("Analysis/Scripts/wdsm_flexible.R")

# Load data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Prepare - using subset for speed
set.seed(2025)
d <- data %>%
  filter(YEAR == 2023) %>%
  mutate(
    alcohol_days = ifelse(ALCDAYS >= 1 & ALCDAYS <= 365, as.numeric(ALCDAYS), NA),
    female = ifelse(IRSEX == 2, 1, ifelse(IRSEX == 1, 0, NA)),
    age_26_34 = ifelse(AGE3 == 9, 1, 0),
    age_35_49 = ifelse(AGE3 == 10, 1, 0),
    age_50_64 = ifelse(AGE3 == 11, 1, 0),
    age_65plus = ifelse(AGE3 == 12, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    native_am = ifelse(NEWRACE2 == 3, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    college_grad = ifelse(EDUHIGHCAT == 4, 1, 0),
    insured = ifelse(IRINSUR4 %in% c(1,2,3,4), 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    poverty_200plus = ifelse(!is.na(POVERTY3) & POVERTY3 >= 3, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(alcohol_days), !is.na(female), !is.na(w), alcohol_days > 0) %>%
  group_by(female) %>%
  slice_sample(n = 3000) %>%  # 3000 per group = 6000 total
  ungroup()

cat("\n================================================================\n")
cat("Q1: Gender → Alcohol Use Frequency (B=50)\n")
cat("================================================================\n\n")
cat("Sample N:", nrow(d), "(stratified sample from full N=56,705)\n")
cat("Female:", sum(d$female == 1), "Male:", sum(d$female == 0), "\n\n")

# Extract components EXACTLY as reference
Y <- d$alcohol_days
A <- d$female
w <- d$w
X <- as.matrix(d[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                      "black", "native_am", "hispanic", "college_grad",
                      "insured", "unemployed", "poverty_200plus")])

# Formulas
ps_formula <- as.formula("A ~ age_26_34 + age_35_49 + age_50_64 + age_65plus + black + native_am + hispanic + college_grad + insured + unemployed + poverty_200plus")
pgs_formula <- as.formula("Y ~ age_26_34 + age_35_49 + age_50_64 + age_65plus + black + native_am + hispanic + college_grad + insured + unemployed + poverty_200plus")

results <- list()

# METHOD 1: WDSM
cat("--- METHOD 1: WDSM (M=5, weighted, B=50) ---\n")
set.seed(2025)
tryCatch({
  wdsm_result <- wdsm_flexible(
    data = d %>% mutate(Y = alcohol_days, Treatment = female),
    outcome_var = "Y",
    treatment_var = "Treatment",
    ps_formula = ps_formula,
    pgs_formula = pgs_formula,
    weight_var = "w",
    M = 5,
    B = 50,
    alpha = 0.05,
    verbose = FALSE
  )
  results$wdsm <- wdsm_result
  cat("  Estimate:", round(wdsm_result$estimate, 4), "\n")
  cat("  SE:", round(wdsm_result$se, 4), "\n")
}, error = function(e) {
  cat("  Error:", e$message, "\n")
  results$wdsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 2: DSM (EXACTLY as reference - varest = TRUE)
cat("\n--- METHOD 2: DSM (M=1, unweighted, B=50) ---\n")
set.seed(2025)
tryCatch({
  dsm_result <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = TRUE,  # EXACTLY as reference
    boots = 50,
    mc = FALSE,
    ncpus = 1
  )
  
  results$dsm <- list(
    estimate = dsm_result$est.ds,
    se = sqrt(dsm_result$bootvar[1,1]),  # EXACTLY as reference
    ci_lower = dsm_result$est.ds - 1.96 * sqrt(dsm_result$bootvar[1,1]),
    ci_upper = dsm_result$est.ds + 1.96 * sqrt(dsm_result$bootvar[1,1])
  )
  
  cat("  Estimate:", round(results$dsm$estimate, 4), "\n")
  cat("  SE:", round(results$dsm$se, 4), "\n")
}, error = function(e) {
  cat("  Error:", e$message, "\n")
  results$dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 3: PSM (EXACTLY as reference)
cat("\n--- METHOD 3: PSM (M=1, unweighted, B=50) ---\n")
set.seed(2025)
tryCatch({
  psm_result <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = TRUE,  # EXACTLY as reference
    boots = 50,
    mc = FALSE,
    ncpus = 1
  )
  
  results$psm <- list(
    estimate = psm_result$est.ps,
    se = sqrt(psm_result$bootvar[1,1]),  # EXACTLY as reference
    ci_lower = psm_result$est.ps - 1.96 * sqrt(psm_result$bootvar[1,1]),
    ci_upper = psm_result$est.ps + 1.96 * sqrt(psm_result$bootvar[1,1])
  )
  
  cat("  Estimate:", round(results$psm$estimate, 4), "\n")
  cat("  SE:", round(results$psm$se, 4), "\n")
}, error = function(e) {
  cat("  Error:", e$message, "\n")
  results$psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 4: PGM (EXACTLY as reference)
cat("\n--- METHOD 4: PGM (M=1, unweighted, B=50) ---\n")
set.seed(2025)
tryCatch({
  pgm_result <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "pg",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = TRUE,  # EXACTLY as reference
    boots = 50,
    mc = FALSE,
    ncpus = 1
  )
  
  results$pgm <- list(
    estimate = pgm_result$est.pg,
    se = sqrt(pgm_result$bootvar[1,1]),  # EXACTLY as reference
    ci_lower = pgm_result$est.pg - 1.96 * sqrt(pgm_result$bootvar[1,1]),
    ci_upper = pgm_result$est.pg + 1.96 * sqrt(pgm_result$bootvar[1,1])
  )
  
  cat("  Estimate:", round(results$pgm$estimate, 4), "\n")
  cat("  SE:", round(results$pgm$se, 4), "\n")
}, error = function(e) {
  cat("  Error:", e$message, "\n")
  results$pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 5: PS Full (EXACTLY as reference)
cat("\n--- METHOD 5: PS Full (weighted) ---\n")
set.seed(2025)
tryCatch({
  # Normalize weights
  w_normalized <- w * length(w) / sum(w)
  
  match_data <- data.frame(
    Y = Y,
    A = A,
    d[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
          "black", "native_am", "hispanic", "college_grad",
          "insured", "unemployed", "poverty_200plus")],
    sw = w_normalized
  )
  
  matchit_formula <- A ~ age_26_34 + age_35_49 + age_50_64 + age_65plus +
                         black + native_am + hispanic + college_grad +
                         insured + unemployed + poverty_200plus
  
  m_ps <- matchit(
    matchit_formula,
    data = match_data,
    method = "full",
    distance = "glm",
    link = "logit",
    s.weights = ~ sw,
    estimand = "ATE"
  )
  
  md <- match.data(m_ps)
  md$weights_final <- md$weights * md$sw
  
  # Outcome model
  fit <- lm(
    Y ~ A * (age_26_34 + age_35_49 + age_50_64 + age_65plus +
             black + native_am + hispanic + college_grad +
             insured + unemployed + poverty_200plus),
    data = md,
    weights = weights_final
  )
  
  ate <- avg_comparisons(
    fit,
    variables = "A",
    vcov = ~subclass,
    wts = "sw"
  )
  
  results$ps_full <- list(
    estimate = ate$estimate[1],
    se = ate$std.error[1],
    ci_lower = ate$conf.low[1],
    ci_upper = ate$conf.high[1]
  )
  
  cat("  Estimate:", round(results$ps_full$estimate, 4), "\n")
  cat("  SE:", round(results$ps_full$se, 4), "\n")
}, error = function(e) {
  cat("  Error:", e$message, "\n")
  results$ps_full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# FINAL TABLE
cat("\n\n================================================================\n")
cat("Q1 FINAL RESULTS: Gender → Alcohol Use Frequency\n")
cat("================================================================\n\n")

cat("Method                   | Estimate |   SE   | 95% CI\n")
cat("-------------------------|----------|--------|-------------------\n")

method_names <- c("WDSM (M=5, weighted)", "DSM (M=1, unweighted)", 
                  "PSM (M=1, unweighted)", "PGM (M=1, unweighted)", 
                  "PS Full (weighted)")

for (i in 1:5) {
  r <- results[[c("wdsm", "dsm", "psm", "pgm", "ps_full")[i]]]
  if (!is.null(r) && !is.na(r$estimate)) {
    cat(sprintf("%-24s | %8.2f | %6.2f | [%7.2f, %7.2f]\n",
                method_names[i], r$estimate, r$se, r$ci_lower, r$ci_upper))
  } else {
    cat(sprintf("%-24s | %8s | %6s | %18s\n", method_names[i], "FAILED", "---", "---"))
  }
}

cat("\n================================================================\n")

saveRDS(results, "Analysis/Results/q1_final.rds")
cat("\n✓ Results saved to Analysis/Results/q1_final.rds\n")
