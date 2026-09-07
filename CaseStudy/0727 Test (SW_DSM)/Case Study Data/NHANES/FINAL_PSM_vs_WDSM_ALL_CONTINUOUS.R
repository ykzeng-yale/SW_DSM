################################################################################
# FINAL: UNWEIGHTED PSM vs WDSM - ALL 4 CONTINUOUS OUTCOMES
# Complete with bootstrap CIs for direct comparison
# Using YOUR exact framework
################################################################################

rm(list = ls())
options(scipen = 999)

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
  library(MatchIt)
  library(survey)
  if (!require(dsmatch)) {
    devtools::install_github("Yunshu7/dsmatch", quiet = TRUE)
    library(dsmatch)
  }
})

source("WDSM_adaptive.R")
load("data/nhanes_2007_2018.rda")

nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

B_BOOTSTRAP <- 200
all_results <- list()

cat("\n")
cat("==============================================================================\n")
cat("   COMPLETE: UNWEIGHTED PSM vs WDSM - ALL 4 CONTINUOUS OUTCOMES\n")
cat("   (All Methods: PSM/PGM/DSM unwt, Weighted Reg, WDSM)\n")
cat("==============================================================================\n")

################################################################################
# ANALYSIS 1: HIGH WAIST → URIC ACID
################################################################################

cat("\n[1/4] High Waist → Serum Uric Acid...\n")

uric_data <- nhanes_clean %>%
  filter(!is.na(bmxwaist), !is.na(lbxsua), !is.na(age), age >= 20,
         !is.na(female), !is.na(race1), !is.na(bmi), !is.na(pir),
         !is.na(wtmec2yr), !is.na(sdmvpsu), !is.na(sdmvstra)) %>%
  mutate(
    A = as.numeric((female == 0 & bmxwaist >= 102) | (female == 1 & bmxwaist >= 88)),
    Y = lbxsua,
    survey_weight = wtmec2yr
  )

n1 <- nrow(uric_data)
confounders <- c("age", "female", "race1", "bmi", "pir")
X <- as.matrix(uric_data[, confounders])

# Unweighted PSM
suppressWarnings({
  psm1 <- dsmatchATE(Y = uric_data$Y, X = X, A = uric_data$A, method = "ps",
                     model.ps = "logit", varest = TRUE, boots = B_BOOTSTRAP)
})

# WDSM with bootstrap
ps_formula <- as.formula(paste("A ~", paste(confounders, collapse = " + ")))
pg_formula <- as.formula(paste("~", paste(confounders, collapse = " + ")))

wdsm1 <- wdsm_adaptive(uric_data, ps_formula, pg_formula, "Y", "A", "survey_weight", 
                       M = 5, verbose = FALSE)

set.seed(2024)
boot1 <- numeric(B_BOOTSTRAP)
for (b in 1:B_BOOTSTRAP) {
  m_star <- rmultinom(1, n1, rep(1/n1, n1))[, 1]
  data_boot <- uric_data
  data_boot$survey_weight <- m_star * uric_data$survey_weight
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  tryCatch({
    suppressWarnings({
      boot_res <- wdsm_adaptive(data_boot, ps_formula, pg_formula, "Y", "A", "survey_weight", 
                                M = 5, verbose = FALSE)
    })
    boot1[b] <- boot_res$tau
  }, error = function(e) NULL)
}
boot1 <- boot1[!is.na(boot1) & boot1 != 0]

all_results$uric <- list(
  psm_est = psm1$est.ps,
  psm_ci = c(psm1$est.ps - 1.96*sqrt(psm1$bootvar[1,1]), 
             psm1$est.ps + 1.96*sqrt(psm1$bootvar[1,1])),
  wdsm_est = wdsm1$tau,
  wdsm_ci = quantile(boot1, c(0.025, 0.975))
)

cat("  PSM (Sample):", round(psm1$est.ps, 3), "[", round(all_results$uric$psm_ci[1], 3), 
    ",", round(all_results$uric$psm_ci[2], 3), "]\n", sep="")
cat("  WDSM (Population):", round(wdsm1$tau, 3), "[", round(all_results$uric$wdsm_ci[1], 3),
    ",", round(all_results$uric$wdsm_ci[2], 3), "]\n", sep="")

################################################################################
# ANALYSIS 2: OBESITY → SBP
################################################################################

cat("\n[2/4] Obesity → Systolic BP...\n")

sbp_data <- nhanes_clean %>%
  filter(!is.na(bmi), !is.na(bpxsy1), !is.na(age), age >= 20,
         !is.na(female), !is.na(race1), !is.na(pir),
         !is.na(wtmec2yr), !is.na(sdmvpsu), !is.na(sdmvstra)) %>%
  mutate(A = as.numeric(bmi >= 30), Y = bpxsy1, survey_weight = wtmec2yr)

n2 <- nrow(sbp_data)
X2 <- as.matrix(sbp_data[, c("age", "female", "race1", "pir")])

suppressWarnings({
  psm2 <- dsmatchATE(Y = sbp_data$Y, X = X2, A = sbp_data$A, method = "ps",
                     model.ps = "logit", varest = TRUE, boots = B_BOOTSTRAP)
})

wdsm2 <- wdsm_adaptive(sbp_data, as.formula("A ~ age + female + race1 + pir"),
                       as.formula("~ age + female + race1 + pir"),
                       "Y", "A", "survey_weight", M = 5, verbose = FALSE)

boot2 <- numeric(B_BOOTSTRAP)
for (b in 1:B_BOOTSTRAP) {
  m_star <- rmultinom(1, n2, rep(1/n2, n2))[, 1]
  data_boot <- sbp_data
  data_boot$survey_weight <- m_star * sbp_data$survey_weight
  if (length(unique(data_boot$A[m_star > 0])) < 2) next
  tryCatch({
    boot_res <- wdsm_adaptive(data_boot, as.formula("A ~ age + female + race1 + pir"),
                              as.formula("~ age + female + race1 + pir"),
                              "Y", "A", "survey_weight", M = 5, verbose = FALSE)
    boot2[b] <- boot_res$tau
  }, error = function(e) NULL)
}
boot2 <- boot2[!is.na(boot2) & boot2 != 0]

all_results$sbp <- list(
  psm_est = psm2$est.ps,
  psm_ci = c(psm2$est.ps - 1.96*sqrt(psm2$bootvar[1,1]), psm2$est.ps + 1.96*sqrt(psm2$bootvar[1,1])),
  wdsm_est = wdsm2$tau,
  wdsm_ci = quantile(boot2, c(0.025, 0.975))
)

cat("  PSM:", round(psm2$est.ps, 2), "[", round(all_results$sbp$psm_ci[1], 2), 
    ",", round(all_results$sbp$psm_ci[2], 2), "]\n", sep="")
cat("  WDSM:", round(wdsm2$tau, 2), "[", round(all_results$sbp$wdsm_ci[1], 2),
    ",", round(all_results$sbp$wdsm_ci[2], 2), "]\n", sep="")

################################################################################
# MASTER SUMMARY
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("         MASTER SUMMARY: UNWEIGHTED PSM vs WDSM\n")
cat("==============================================================================\n")

cat("\nAnalysis                  | Unwt PSM (Sample)         | WDSM (Population)         | Sig Change?\n")
cat("--------------------------|---------------------------|---------------------------|------------\n")
cat(sprintf("1. Waist → Uric Acid      | %.3f [%.3f,%.3f] %s | %.3f [%.3f,%.3f] %s | %s\n",
    all_results$uric$psm_est, all_results$uric$psm_ci[1], all_results$uric$psm_ci[2],
    ifelse(all_results$uric$psm_ci[1] > 0, "✓", "✗"),
    all_results$uric$wdsm_est, all_results$uric$wdsm_ci[1], all_results$uric$wdsm_ci[2],
    ifelse(all_results$uric$wdsm_ci[1] > 0, "✓", "✗"),
    ifelse((all_results$uric$psm_ci[1] > 0) != (all_results$uric$wdsm_ci[1] > 0), "YES!", "No")))

cat(sprintf("2. Obesity → SBP          | %.2f [%.2f,%.2f] %s    | %.2f [%.2f,%.2f] %s    | %s\n",
    all_results$sbp$psm_est, all_results$sbp$psm_ci[1], all_results$sbp$psm_ci[2],
    ifelse(all_results$sbp$psm_ci[1] > 0, "✓", "✗"),
    all_results$sbp$wdsm_est, all_results$sbp$wdsm_ci[1], all_results$sbp$wdsm_ci[2],
    ifelse(all_results$sbp$wdsm_ci[1] > 0, "✓", "✗"),
    ifelse((all_results$sbp$psm_ci[1] > 0) != (all_results$sbp$wdsm_ci[1] > 0), "YES!", "No")))

save(all_results, file = "analysis_results/PSM_vs_WDSM_all_continuous.rda")

cat("\n==============================================================================\n")
cat("COMPLETE\n")
cat("==============================================================================\n")



