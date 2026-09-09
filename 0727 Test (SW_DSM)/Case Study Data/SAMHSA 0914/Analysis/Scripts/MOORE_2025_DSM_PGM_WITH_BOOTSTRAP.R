#!/usr/bin/env Rscript

#' =============================================================================
#' MOORE 2025: DSM AND PGM WITH BOOTSTRAP (B=200)
#' =============================================================================

cat("\n================================================================\n")
cat("MOORE 2025: DSM AND PGM WITH BOOTSTRAP\n")
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

# Store results
results <- list()

# ====================
#     DSM - STI
# ====================
cat("=== DSM for STI with Bootstrap ===\n")
cat("Running 200 bootstrap samples... ")
set.seed(2025)
start_time <- Sys.time()

dsm_sti <- dsmatchATE(
  Y = Y_sti,
  X = X,
  A = A,
  method = "dsm",
  model.ps = "logit",
  model.pg = "linpred",
  lp.pg = X,
  cov.balance = FALSE,
  varest = FALSE,  # KEY FIX
  boots = 200,
  mc = FALSE,
  ncpus = 1
)

end_time <- Sys.time()
cat("Done in", round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n")

results$sti_dsm <- list(
  estimate = dsm_sti$est.ds,
  se = sqrt(dsm_sti$bootvar[1,1]),
  ci_lower = dsm_sti$est.ds - 1.96*sqrt(dsm_sti$bootvar[1,1]),
  ci_upper = dsm_sti$est.ds + 1.96*sqrt(dsm_sti$bootvar[1,1])
)

cat("  Estimate:", round(results$sti_dsm$estimate, 4), "\n")
cat("  Bootstrap SE:", round(results$sti_dsm$se, 4), "\n")
cat("  95% CI: [", round(results$sti_dsm$ci_lower, 4), ",",
    round(results$sti_dsm$ci_upper, 4), "]\n\n")

# ====================
#     DSM - SPD
# ====================
cat("=== DSM for SPD with Bootstrap ===\n")
cat("Running 200 bootstrap samples... ")
set.seed(2025)
start_time <- Sys.time()

dsm_spd <- dsmatchATE(
  Y = Y_spd,
  X = X,
  A = A,
  method = "dsm",
  model.ps = "logit",
  model.pg = "linpred",
  lp.pg = X,
  cov.balance = FALSE,
  varest = FALSE,  # KEY FIX
  boots = 200,
  mc = FALSE,
  ncpus = 1
)

end_time <- Sys.time()
cat("Done in", round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n")

results$spd_dsm <- list(
  estimate = dsm_spd$est.ds,
  se = sqrt(dsm_spd$bootvar[1,1]),
  ci_lower = dsm_spd$est.ds - 1.96*sqrt(dsm_spd$bootvar[1,1]),
  ci_upper = dsm_spd$est.ds + 1.96*sqrt(dsm_spd$bootvar[1,1])
)

cat("  Estimate:", round(results$spd_dsm$estimate, 4), "\n")
cat("  Bootstrap SE:", round(results$spd_dsm$se, 4), "\n")
cat("  95% CI: [", round(results$spd_dsm$ci_lower, 4), ",",
    round(results$spd_dsm$ci_upper, 4), "]\n\n")

# ====================
#     PGM - STI
# ====================
cat("=== PGM for STI with Bootstrap ===\n")
cat("Running 200 bootstrap samples... ")
set.seed(2025)
start_time <- Sys.time()

pgm_sti <- dsmatchATE(
  Y = Y_sti,
  X = X,
  A = A,
  method = "pg",
  model.pg = "linpred",
  lp.pg = X,
  cov.balance = FALSE,
  varest = FALSE,  # KEY FIX
  boots = 200,
  mc = FALSE,
  ncpus = 1
)

end_time <- Sys.time()
cat("Done in", round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n")

results$sti_pgm <- list(
  estimate = pgm_sti$est.pg,
  se = sqrt(pgm_sti$bootvar[1,1]),
  ci_lower = pgm_sti$est.pg - 1.96*sqrt(pgm_sti$bootvar[1,1]),
  ci_upper = pgm_sti$est.pg + 1.96*sqrt(pgm_sti$bootvar[1,1])
)

cat("  Estimate:", round(results$sti_pgm$estimate, 4), "\n")
cat("  Bootstrap SE:", round(results$sti_pgm$se, 4), "\n")
cat("  95% CI: [", round(results$sti_pgm$ci_lower, 4), ",",
    round(results$sti_pgm$ci_upper, 4), "]\n\n")

# ====================
#     PGM - SPD
# ====================
cat("=== PGM for SPD with Bootstrap ===\n")
cat("Running 200 bootstrap samples... ")
set.seed(2025)
start_time <- Sys.time()

pgm_spd <- dsmatchATE(
  Y = Y_spd,
  X = X,
  A = A,
  method = "pg",
  model.pg = "linpred",
  lp.pg = X,
  cov.balance = FALSE,
  varest = FALSE,  # KEY FIX
  boots = 200,
  mc = FALSE,
  ncpus = 1
)

end_time <- Sys.time()
cat("Done in", round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n")

results$spd_pgm <- list(
  estimate = pgm_spd$est.pg,
  se = sqrt(pgm_spd$bootvar[1,1]),
  ci_lower = pgm_spd$est.pg - 1.96*sqrt(pgm_spd$bootvar[1,1]),
  ci_upper = pgm_spd$est.pg + 1.96*sqrt(pgm_spd$bootvar[1,1])
)

cat("  Estimate:", round(results$spd_pgm$estimate, 4), "\n")
cat("  Bootstrap SE:", round(results$spd_pgm$se, 4), "\n")
cat("  95% CI: [", round(results$spd_pgm$ci_lower, 4), ",",
    round(results$spd_pgm$ci_upper, 4), "]\n\n")

# Save results
saveRDS(results, "Analysis/Results/moore_2025_dsm_pgm_bootstrap.rds")

cat("\n✅ DSM and PGM with bootstrap complete!\n")
cat("Results saved to: Analysis/Results/moore_2025_dsm_pgm_bootstrap.rds\n")

# Print summary
cat("\n============================================================\n")
cat("SUMMARY OF DSM AND PGM RESULTS\n")
cat("============================================================\n")

cat("\nSTI Results:\n")
cat("  DSM: ", sprintf("%.4f [%.4f, %.4f]", 
    results$sti_dsm$estimate,
    results$sti_dsm$ci_lower,
    results$sti_dsm$ci_upper), "\n")
cat("  PGM: ", sprintf("%.4f [%.4f, %.4f]", 
    results$sti_pgm$estimate,
    results$sti_pgm$ci_lower,
    results$sti_pgm$ci_upper), "\n")

cat("\nSPD Results:\n")
cat("  DSM: ", sprintf("%.4f [%.4f, %.4f]", 
    results$spd_dsm$estimate,
    results$spd_dsm$ci_lower,
    results$spd_dsm$ci_upper), "\n")
cat("  PGM: ", sprintf("%.4f [%.4f, %.4f]", 
    results$spd_pgm$estimate,
    results$spd_pgm$ci_lower,
    results$spd_pgm$ci_upper), "\n")






