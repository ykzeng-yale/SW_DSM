#!/usr/bin/env Rscript
# NHANES Case Study: WDSM analysis using wdsmatch package
# Sampling design: RETROSPECTIVE (informative)
# Treatment: Short sleep duration (<7 hours)
# Outcome: HbA1c (% glycated hemoglobin)

library(wdsmatch)
library(dplyr)

load("data/nhanes_2007_2018.rda")

analytic_data <- nhanes_2007_2018 %>%
  filter(!is.na(sld012), !is.na(lbxgh), ridageyr >= 40, ridageyr <= 70,
         !is.na(diq010), diq010 != 1)

ps_vars <- c("ridageyr", "riagendr", "ridreth1", "bmxbmi", "dmdeduc2", "indfmpir")
if ("smq020" %in% names(analytic_data)) ps_vars <- c(ps_vars, "smq020")

complete_idx <- complete.cases(analytic_data[, c("lbxgh", "sld012", ps_vars, "wtmec2yr")])
data_complete <- analytic_data[complete_idx, ]

Y <- data_complete$lbxgh
Z <- ifelse(data_complete$sld012 < 7, 1, 0)
w <- data_complete$wtmec2yr
X <- data_complete[, ps_vars]

ps_formula <- as.formula(paste("Z ~", paste(ps_vars, collapse = " + ")))
pg_formula <- as.formula(paste("Y ~", paste(ps_vars, collapse = " + ")))

cat("N:", nrow(data_complete), "Short sleep:", sum(Z == 1), "Adequate:", sum(Z == 0), "\n\n")

for (M in c(1, 3, 5)) {
  cat(sprintf("=== WDSM (M=%d) ===\n", M))

  set.seed(2024)
  fit <- wdsmatchATE(
    Y = Y, X = X, Z = Z, weights = w, M = M,
    model.ps = ps_formula, model.pg = pg_formula,
    sampling = "retrospective",
    varest = TRUE, boots = 200
  )

  cat(sprintf("  Estimate: %.4f\n  SE: %.4f\n  95%% CI: [%.4f, %.4f]\n\n",
              fit$estimate, fit$se, fit$ci[1], fit$ci[2]))
}
