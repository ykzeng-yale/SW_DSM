################################################################################
# RUN ALL 10 ANALYSES WITH WDSM M=1, M=3, M=5
# Compact version - runs all 3 M values for each analysis
################################################################################

library(dplyr)
source("WDSM_adaptive.R")
if(!require(dsmatch)) install.packages("dsmatch")

set.seed(2024)

cat('\n═══════════════════════════════════════════════════════════════════════════\n')
cat('RUNNING ALL 10 ANALYSES WITH WDSM M=1, M=3, M=5\n')
cat('═══════════════════════════════════════════════════════════════════════════\n\n')

load("data/nhanes_2007_2018.rda")

# Helper function to run one analysis with all M values
run_analysis_all_M <- function(num, title, data_filter, treatment_def, outcome_var, covars) {
  
  cat('───────────────────────────────────────────────────────────────────────────\n')
  cat('ANALYSIS', num, ':', title, '\n')
  cat('───────────────────────────────────────────────────────────────────────────\n')
  
  # Prepare data
  data_prep <- data_filter(nhanes_2007_2018)
  Y <- data_prep[[outcome_var]]
  A <- treatment_def(data_prep)
  sw <- data_prep$wtmec2yr
  
  # Complete cases
  complete_idx <- complete.cases(data_prep[, c(outcome_var, covars, "wtmec2yr")])
  data_complete <- data_prep[complete_idx, ]
  Y <- data_complete[[outcome_var]]
  A <- treatment_def(data_complete)
  sw <- data_complete$wtmec2yr
  
  cat('N =', nrow(data_complete), '| Treated:', sum(A==1), '| Control:', sum(A==0), '\n\n')
  
  # Prepare for WDSM
  wdsm_data <- data_complete
  wdsm_data$Y <- Y
  wdsm_data$A <- A
  wdsm_data$survey_weight <- sw
  
  ps_formula <- as.formula(paste("A ~", paste(covars, collapse=" + ")))
  pg_formula <- as.formula(paste("~", paste(covars, collapse=" + ")))
  
  # Run for M=1, 3, 5
  wdsm_results <- list()
  
  for(M_val in c(1, 3, 5)) {
    cat('  M=', M_val, '...', sep='')
    
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
    
    wdsm_results[[paste0("M", M_val)]] <- list(
      estimate = wdsm_boot$point_estimate$tau,
      ci_lower = wdsm_boot$ci_lower,
      ci_upper = wdsm_boot$ci_upper
    )
    
    cat(' ', round(wdsm_boot$point_estimate$tau, 3), 
        ' [', round(wdsm_boot$ci_lower, 3), ',', round(wdsm_boot$ci_upper, 3), ']\n')
  }
  
  cat('\n')
  
  # Save
  save(data_complete, wdsm_results, file=paste0("WDSM_M1_M3_M5_ANALYSIS_", sprintf("%02d", num), ".rda"))
  
  return(wdsm_results)
}

################################################################################
# Define each analysis
################################################################################

# Analysis 1: BMI → HbA1c
all_results <- list()

all_results[[1]] <- run_analysis_all_M(
  1, "BMI → HbA1c",
  data_filter = function(d) d %>% filter(!is.na(bmxbmi), !is.na(lbxgh), ridageyr>=20, !is.na(diq010), diq010!=1),
  treatment_def = function(d) ifelse(d$bmxbmi >= median(d$bmxbmi, na.rm=TRUE), 1, 0),
  outcome_var = "lbxgh",
  covars = c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","smq020")
)

# Analysis 2: Waist → Uric
all_results[[2]] <- run_analysis_all_M(
  2, "Waist → Uric Acid",
  data_filter = function(d) d %>% filter(!is.na(bmxwaist), !is.na(lbxsua), ridageyr>=40, ridageyr<=70),
  treatment_def = function(d) ifelse(d$bmxwaist >= median(d$bmxwaist, na.rm=TRUE), 1, 0),
  outcome_var = "lbxsua",
  covars = c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi")
)

# Analysis 3: Obesity → SBP
all_results[[3]] <- run_analysis_all_M(
  3, "Obesity → SBP",
  data_filter = function(d) d %>% filter(!is.na(bmxbmi), !is.na(bpxsy1), ridageyr>=40, ridageyr<=70),
  treatment_def = function(d) ifelse(d$bmxbmi >= 30, 1, 0),
  outcome_var = "bpxsy1",
  covars = c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir")
)

# Analysis 6: Smoking → Trig
all_results[[6]] <- run_analysis_all_M(
  6, "Smoking → Triglycerides",
  data_filter = function(d) {
    d %>% mutate(current_smoker = case_when(
      smq020==2 ~ 0, smq020==1 & smq040 %in% c(1,2) ~ 1,
      smq020==1 & smq040==3 ~ 0, TRUE ~ NA_real_
    )) %>% filter(!is.na(current_smoker), !is.na(lbxtr), ridageyr>=20)
  },
  treatment_def = function(d) d$current_smoker,
  outcome_var = "lbxtr",
  covars = c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi")
)

# Analysis 4: MVPA → HbA1c
all_results[[4]] <- run_analysis_all_M(
  4, "MVPA → HbA1c",
  data_filter = function(d) d %>% filter(!is.na(paq650), !is.na(lbxgh), ridageyr>=40, ridageyr<=70, !is.na(diq010), diq010!=1),
  treatment_def = function(d) ifelse(d$paq650 == 1, 1, 0),
  outcome_var = "lbxgh",
  covars = c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi")
)

# Analysis 5: Lead → Creatinine
all_results[[5]] <- run_analysis_all_M(
  5, "Lead → Creatinine",
  data_filter = function(d) d %>% filter(!is.na(lbxapb), !is.na(lbdscrsi), ridageyr>=40, ridageyr<=70),
  treatment_def = function(d) ifelse(d$lbxapb >= median(d$lbxapb, na.rm=TRUE), 1, 0),
  outcome_var = "lbdscrsi",
  covars = c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi")
)

# Analysis 7: PA → SBP
all_results[[7]] <- run_analysis_all_M(
  7, "PA → SBP",
  data_filter = function(d) d %>% filter(!is.na(paq605), !is.na(bpxsy1), ridageyr>=40, ridageyr<=70),
  treatment_def = function(d) ifelse(d$paq605 == 1, 1, 0),
  outcome_var = "bpxsy1",
  covars = c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi")
)

# Analysis 8: Obesity → ALT
all_results[[8]] <- run_analysis_all_M(
  8, "Obesity → ALT",
  data_filter = function(d) d %>% filter(!is.na(bmxbmi), !is.na(lbxsatsi), ridageyr>=40, ridageyr<=70, lbxsatsi>0, lbxsatsi<300),
  treatment_def = function(d) ifelse(d$bmxbmi >= 30, 1, 0),
  outcome_var = "lbxsatsi",
  covars = c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir")
)

# Analysis 9: Alcohol → HDL
all_results[[9]] <- run_analysis_all_M(
  9, "Alcohol → HDL",
  data_filter = function(d) d %>% filter(!is.na(alq130), !is.na(lbdhdd), ridageyr>=40, ridageyr<=70),
  treatment_def = function(d) ifelse(d$alq130 >= median(d$alq130, na.rm=TRUE), 1, 0),
  outcome_var = "lbdhdd",
  covars = c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi")
)

# Analysis 10: Sleep → HbA1c
all_results[[10]] <- run_analysis_all_M(
  10, "Sleep → HbA1c",
  data_filter = function(d) d %>% filter(!is.na(sld012), !is.na(lbxgh), ridageyr>=40, ridageyr<=70, !is.na(diq010), diq010!=1),
  treatment_def = function(d) ifelse(d$sld012 < 7, 1, 0),
  outcome_var = "lbxgh",
  covars = c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi")
)

cat('═══════════════════════════════════════════════════════════════════════════\n')
cat('ALL 10 ANALYSES COMPLETE WITH M=1, M=3, M=5!\n')
cat('═══════════════════════════════════════════════════════════════════════════\n')

save(all_results, file="ALL_10_ANALYSES_WDSM_M1_M3_M5.rda")
cat('\n✅ Master file saved: ALL_10_ANALYSES_WDSM_M1_M3_M5.rda\n')

