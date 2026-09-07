#!/usr/bin/env Rscript

#' =============================================================================
#' MOORE 2025: PSM WITH BOOTSTRAP - SIMPLE TEST
#' =============================================================================

cat("\n================================================================\n")
cat("MOORE 2025: PSM WITH BOOTSTRAP (B=200)\n")
cat("================================================================\n\n")

library(tidyverse)
library(Matching)

# Source all dsmatch functions
invisible(sapply(list.files("dsmatch-master/R", pattern = "\\.R$", full.names = TRUE), source))

# Load and prepare data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

moore_data <- data %>%
  filter(YEAR == 2021, CATAGE >= 2, UD5ILALANY == 1) %>%
  mutate(
    sti = ifelse(STDANYYR == 1, 1, ifelse(STDANYYR == 2, 0, NA)),
    spd = ifelse(SPDPSTYR == 1, 1, ifelse(SPDPSTYR == 0, 0, NA)),
    female = ifelse(IRSEX == 2, 1, 0),
    age_26_34 = ifelse(AGE3 == 9, 1, 0),
    age_35_49 = ifelse(AGE3 == 10, 1, 0),
    age_50_64 = ifelse(AGE3 == 11, 1, 0),
    age_65plus = ifelse(AGE3 == 12, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    native_am = ifelse(NEWRACE2 == 3, 1, 0),
    asian = ifelse(NEWRACE2 == 5, 1, 0),
    multiracial = ifelse(NEWRACE2 == 6, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    widowed = ifelse(IRMARIT == 2, 1, 0),
    divorced = ifelse(IRMARIT == 3, 1, 0),
    separated = ifelse(IRMARIT == 4, 1, 0),
    never_married = ifelse(IRMARIT == 5, 1, 0),
    hs_grad = ifelse(EDUHIGHCAT == 2, 1, 0),
    some_college = ifelse(EDUHIGHCAT == 3, 1, 0),
    college_grad = ifelse(EDUHIGHCAT == 4, 1, 0),
    insured = ifelse(IRINSUR4 %in% c(1,2,3,4), 1, 0),
    part_time = ifelse(IRWRKSTAT18 == 2, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    other_employ = ifelse(IRWRKSTAT18 == 4, 1, 0),
    poverty_100_200 = ifelse(!is.na(POVERTY3) & POVERTY3 == 2, 1, 0),
    poverty_200plus = ifelse(!is.na(POVERTY3) & POVERTY3 >= 3, 1, 0)
  ) %>%
  filter(!is.na(sti) & !is.na(spd) & !is.na(female))

cat("Sample size:", nrow(moore_data), "\n\n")

A <- moore_data$female
Y_sti <- moore_data$sti
Y_spd <- moore_data$spd
X <- as.matrix(moore_data[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                               "black", "native_am", "asian", "multiracial", "hispanic",
                               "widowed", "divorced", "separated", "never_married",
                               "hs_grad", "some_college", "college_grad", "insured",
                               "part_time", "unemployed", "other_employ",
                               "poverty_100_200", "poverty_200plus")])

# PSM for STI
cat("=== PSM for STI with Bootstrap ===\n")
cat("Running 200 bootstrap samples... ")
set.seed(2025)
start_time <- Sys.time()

psm_sti <- dsmatchATE(
  Y = Y_sti,
  X = X,
  A = A,
  method = "ps",
  model.ps = "logit",
  cov.balance = FALSE,
  varest = FALSE,  # KEY FIX
  boots = 200,
  mc = FALSE,
  ncpus = 1
)

end_time <- Sys.time()
cat("Done in", round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n")

cat("  Estimate:", round(psm_sti$est.ps, 4), "\n")
cat("  Bootstrap SE:", round(sqrt(psm_sti$bootvar[1,1]), 4), "\n")
cat("  95% CI: [", round(psm_sti$est.ps - 1.96*sqrt(psm_sti$bootvar[1,1]), 4), ",",
    round(psm_sti$est.ps + 1.96*sqrt(psm_sti$bootvar[1,1]), 4), "]\n\n")

# PSM for SPD
cat("=== PSM for SPD with Bootstrap ===\n")
cat("Running 200 bootstrap samples... ")
set.seed(2025)
start_time <- Sys.time()

psm_spd <- dsmatchATE(
  Y = Y_spd,
  X = X,
  A = A,
  method = "ps",
  model.ps = "logit",
  cov.balance = FALSE,
  varest = FALSE,  # KEY FIX
  boots = 200,
  mc = FALSE,
  ncpus = 1
)

end_time <- Sys.time()
cat("Done in", round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n")

cat("  Estimate:", round(psm_spd$est.ps, 4), "\n")
cat("  Bootstrap SE:", round(sqrt(psm_spd$bootvar[1,1]), 4), "\n")
cat("  95% CI: [", round(psm_spd$est.ps - 1.96*sqrt(psm_spd$bootvar[1,1]), 4), ",",
    round(psm_spd$est.ps + 1.96*sqrt(psm_spd$bootvar[1,1]), 4), "]\n\n")

# Save results
psm_results <- list(
  STI = list(
    estimate = psm_sti$est.ps,
    se = sqrt(psm_sti$bootvar[1,1]),
    ci_lower = psm_sti$est.ps - 1.96*sqrt(psm_sti$bootvar[1,1]),
    ci_upper = psm_sti$est.ps + 1.96*sqrt(psm_sti$bootvar[1,1])
  ),
  SPD = list(
    estimate = psm_spd$est.ps,
    se = sqrt(psm_spd$bootvar[1,1]),
    ci_lower = psm_spd$est.ps - 1.96*sqrt(psm_spd$bootvar[1,1]),
    ci_upper = psm_spd$est.ps + 1.96*sqrt(psm_spd$bootvar[1,1])
  )
)

saveRDS(psm_results, "Analysis/Results/moore_2025_psm_bootstrap.rds")

cat("\n✅ PSM with bootstrap complete!\n")
cat("Results saved to: Analysis/Results/moore_2025_psm_bootstrap.rds\n")






