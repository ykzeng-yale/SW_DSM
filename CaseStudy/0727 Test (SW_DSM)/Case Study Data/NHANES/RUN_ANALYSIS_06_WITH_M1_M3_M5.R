################################################################################
# ANALYSIS 6: Smoking → Triglycerides
# WITH WDSM M=1, M=3, M=5 COMPARISON
################################################################################

rm(list=ls())
library(dplyr)
source("WDSM_adaptive.R")
set.seed(2024)

cat('\n═══════════════════════════════════════════════════════════════════════════\n')
cat('ANALYSIS 6: Smoking → Triglycerides - WDSM M=1, M=3, M=5\n')
cat('═══════════════════════════════════════════════════════════════════════════\n\n')

# Load existing complete results
load('ANALYSIS_06_SMOKING_TRIGLYCERIDES_COMPLETE.rda')

cat('Existing results loaded. N =', nrow(data_complete), '\n')
cat('Now adding WDSM with M=1 and M=3...\n\n')

# Prepare data for WDSM
Y <- data_complete$lbxtr
A <- data_complete$current_smoker
sw <- data_complete$wtmec2yr

covars <- c("ridageyr", "riagendr", "ridreth1", "dmdeduc2", "indfmpir", "bmxbmi")
ps_formula <- as.formula(paste("A ~", paste(covars, collapse=" + ")))
pg_formula <- as.formula(paste("~", paste(covars, collapse=" + ")))

wdsm_data <- data_complete
wdsm_data$Y <- Y
wdsm_data$A <- A
wdsm_data$survey_weight <- sw

# Run WDSM for M=1, 3, 5
wdsm_by_M <- list()

for(M_val in c(1, 3, 5)) {
  cat('WDSM M=', M_val, '...\n', sep='')
  
  wdsm_boot <- bootstrap_adaptive_wdsm(
    data = wdsm_data,
    ps_formula = ps_formula,
    pg_formula = pg_formula,
    outcome_var = "Y",
    treatment_var = "A",
    weight_var = "survey_weight",
    n_bootstrap = 50,
    M = M_val,
    use_bias_correction = TRUE,
    verbose = FALSE
  )
  
  wdsm_by_M[[paste0("M", M_val)]] <- list(
    estimate = wdsm_boot$point_estimate$tau,
    ci_lower = wdsm_boot$ci_lower,
    ci_upper = wdsm_boot$ci_upper
  )
  
  cat('  Estimate:', round(wdsm_boot$point_estimate$tau, 2), 
      ' [', round(wdsm_boot$ci_lower, 2), ',', round(wdsm_boot$ci_upper, 2), ']\n\n')
}

# Add to existing results
results$wdsm_M1 <- wdsm_by_M$M1
results$wdsm_M3 <- wdsm_by_M$M3
results$wdsm_M5 <- wdsm_by_M$M5

# Save updated results
save(data_complete, results, wdsm_by_M,
     file="ANALYSIS_06_WITH_M1_M3_M5.rda")

cat('═══════════════════════════════════════════════════════════════════════════\n')
cat('COMPLETE RESULTS TABLE WITH WDSM M=1, M=3, M=5\n')
cat('═══════════════════════════════════════════════════════════════════════════\n\n')

cat('Method                     Estimate   95% CI            Estimand\n')
cat('───────────────────────────────────────────────────────────────────────────\n')
cat(sprintf('Unweighted DSM             %6.2f    [%6.2f,%6.2f]    Sample\n',
            results$dsm$estimate, results$dsm$ci[1], results$dsm$ci[2]))
cat(sprintf('Unweighted PGM             %6.2f    [%6.2f,%6.2f]    Sample\n',
            results$pgm$estimate, results$pgm$ci[1], results$pgm$ci[2]))
cat(sprintf('Unweighted PSM             %6.2f    [%6.2f,%6.2f]    Sample\n',
            results$psm$estimate, results$psm$ci[1], results$psm$ci[2]))
cat(sprintf('Survey-Weighted PS Full    %6.2f    [%6.2f,%6.2f]    Population\n',
            results$ps_full$estimate, results$ps_full$ci[1], results$ps_full$ci[2]))
cat(sprintf('WDSM (M=1, 1:1 match)      %6.2f    [%6.2f,%6.2f]    Population\n',
            wdsm_by_M$M1$estimate, wdsm_by_M$M1$ci_lower, wdsm_by_M$M1$ci_upper))
cat(sprintf('WDSM (M=3, 1:3 match)      %6.2f    [%6.2f,%6.2f]    Population\n',
            wdsm_by_M$M3$estimate, wdsm_by_M$M3$ci_lower, wdsm_by_M$M3$ci_upper))
cat(sprintf('WDSM (M=5, 1:5 match)      %6.2f    [%6.2f,%6.2f]    Population\n',
            wdsm_by_M$M5$estimate, wdsm_by_M$M5$ci_lower, wdsm_by_M$M5$ci_upper))
cat('───────────────────────────────────────────────────────────────────────────\n\n')

cat('WDSM Comparison Across Matching Ratios:\n')
cat('  M=1 (1:1): Most conservative, smallest effective sample\n')
cat('  M=3 (1:3): Balance between precision and variance\n')
cat('  M=5 (1:5): Current default, better precision\n\n')

cat('✅ COMPLETE\n')



