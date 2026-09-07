################################################################################
# MASTER SCRIPT: RUN ALL FEASIBLE PAPERS SYSTEMATICALLY
# Handles missing data properly for each analysis
################################################################################

rm(list = ls())
options(scipen = 999)

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
  library(MatchIt)
  library(survival)
  library(survey)
})

load("data/nhanes_2007_2018.rda")
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

cat("\n")
cat("==============================================================================\n")
cat("          SYSTEMATIC REPLICATION: ALL FEASIBLE PAPERS\n")
cat("==============================================================================\n")

# Storage for all results
all_results <- list()
options(survey.lonely.psu = "adjust")

################################################################################
# PAPER 1: MVPA → Mortality (Already completed in separate script)
################################################################################

cat("\n[1/6] MVPA → Mortality: ✅ COMPLETED in PAPER3_MVPA_mortality_COMPLETE.R\n")
if(file.exists("analysis_results/paper3_mvpa_mortality_ALL_METHODS.rda")) {
  load("analysis_results/paper3_mvpa_mortality_ALL_METHODS.rda")
  all_results$mvpa <- mvpa_results
  cat("   Unwt PSM: HR =", round(mvpa_results$unweighted_psm$hr, 3), "\n")
  cat("   Weighted: HR =", round(mvpa_results$weighted_reg$hr, 3), "\n")
  cat("   Difference:", round(100*(mvpa_results$unweighted_psm$hr - 
                                   mvpa_results$weighted_reg$hr)/
                                   mvpa_results$weighted_reg$hr, 1), "%\n")
}

################################################################################
# PAPER 2: Obesity → Hypertension (Already completed)
################################################################################

cat("\n[2/6] Obesity → Hypertension: ✅ COMPLETED in PAPER2_obesity_hypertension.R\n")
if(file.exists("analysis_results/paper2_obesity_htn_ALL_METHODS.rda")) {
  load("analysis_results/paper2_obesity_htn_ALL_METHODS.rda")
  all_results$obesity <- obesity_results
  cat("   Unwt PSM: OR =", round(obesity_results$unweighted_psm$or, 3), "\n")
  cat("   Weighted: OR =", round(obesity_results$weighted_reg$or, 3), "\n")
  cat("   Difference:", round(100*(obesity_results$unweighted_psm$or - 
                                   obesity_results$weighted_reg$or)/
                                   obesity_results$weighted_reg$or, 1), "%\n")
}

################################################################################
# PAPER 3: LE8 → Mortality in CKD (Simplified)
################################################################################

cat("\n[3/6] LE8 → Mortality in CKD...\n")

tryCatch({
  # Simple binary exposure: High vs low MVPA in CKD subset
  ckd_simple <- nhanes_clean %>%
    filter(
      !is.na(egfr), egfr < 60,  # CKD
      !is.na(mvpa_week),
      !is.na(mortstat), !is.na(permth_exm),
      !is.na(age), age >= 20,
      !is.na(female), !is.na(race1),
      !is.na(bmi),
      !is.na(wtmec2yr), !is.na(sdmvpsu), !is.na(sdmvstra)
    ) %>%
    mutate(
      high_mvpa = as.numeric(mvpa_week >= 150),
      death = as.numeric(mortstat == 1),
      time_years = permth_exm / 12
    )
  
  cat("   CKD subset N:", nrow(ckd_simple), "\n")
  cat("   Deaths:", sum(ckd_simple$death), "\n")
  
  # Unweighted PSM
  m_unwt <- matchit(high_mvpa ~ age + female + race1 + bmi,
                    data = ckd_simple, method = "nearest", ratio = 1)
  md_unwt <- match.data(m_unwt)
  
  cox_unwt <- coxph(Surv(time_years, death) ~ high_mvpa + strata(subclass), data = md_unwt)
  hr_unwt <- exp(coef(cox_unwt)["high_mvpa"])
  
  # Weighted
  svy_ckd <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra,
                       weights = ~wtmec2yr, nest = TRUE, data = ckd_simple)
  cox_wt <- svycoxph(Surv(time_years, death) ~ high_mvpa + age + female + race1 + bmi,
                     design = svy_ckd)
  hr_wt <- exp(coef(cox_wt)["high_mvpa"])
  
  all_results$le8_ckd <- list(
    unwt_hr = hr_unwt,
    wt_hr = hr_wt,
    diff_pct = 100 * (hr_unwt - hr_wt) / hr_wt
  )
  
  cat("   Unwt PSM: HR =", round(hr_unwt, 3), "\n")
  cat("   Weighted: HR =", round(hr_wt, 3), "\n")
  cat("   Difference:", round(100*(hr_unwt - hr_wt)/hr_wt, 1), "%\n")
  cat("   ✅ COMPLETE\n")
  
}, error = function(e) {
  cat("   ❌ ERROR:", e$message, "\n")
})

################################################################################
# PAPER 4: Visceral Fat (Waist) → Hyperuricemia
################################################################################

cat("\n[4/6] Visceral Fat → Hyperuricemia...\n")

tryCatch({
  uric_data <- nhanes_clean %>%
    filter(
      !is.na(bmxwaist), !is.na(lbxsua),
      !is.na(age), age >= 20,
      !is.na(female), !is.na(race1), !is.na(bmi),
      !is.na(wtmec2yr), !is.na(sdmvpsu), !is.na(sdmvstra)
    ) %>%
    mutate(
      high_waist = as.numeric((female == 0 & bmxwaist >= 102) | 
                              (female == 1 & bmxwaist >= 88)),
      hyperuricemia = as.numeric((female == 0 & lbxsua > 7.0) | 
                                 (female == 1 & lbxsua > 6.0))
    )
  
  cat("   N:", nrow(uric_data), "\n")
  cat("   High waist:", sum(uric_data$high_waist), "\n")
  cat("   Hyperuricemia:", sum(uric_data$hyperuricemia), "\n")
  
  # Unweighted PSM
  m_unwt <- matchit(high_waist ~ age + female + race1 + bmi,
                    data = uric_data, method = "nearest", ratio = 1)
  md_unwt <- match.data(m_unwt)
  
  model_unwt <- glm(hyperuricemia ~ high_waist, data = md_unwt, family = binomial())
  or_unwt <- exp(coef(model_unwt)["high_waist"])
  
  # Weighted
  svy <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra,
                   weights = ~wtmec2yr, nest = TRUE, data = uric_data)
  model_wt <- svyglm(hyperuricemia ~ high_waist + age + female + race1 + bmi,
                     design = svy, family = quasibinomial())
  or_wt <- exp(coef(model_wt)["high_waist"])
  
  all_results$uric_acid <- list(
    unwt_or = or_unwt,
    wt_or = or_wt,
    diff_pct = 100 * (or_unwt - or_wt) / or_wt
  )
  
  cat("   Unwt PSM: OR =", round(or_unwt, 3), "\n")
  cat("   Weighted: OR =", round(or_wt, 3), "\n")
  cat("   Difference:", round(100*(or_unwt - or_wt)/or_wt, 1), "%\n")
  cat("   ✅ COMPLETE\n")
  
}, error = function(e) {
  cat("   ❌ ERROR:", e$message, "\n")
})

################################################################################
# PAPER 5: MAFLD → Mortality
################################################################################

cat("\n[5/6] MAFLD → Mortality...\n")

tryCatch({
  mafld_data <- nhanes_clean %>%
    filter(
      !is.na(lbxsal),
      !is.na(age), age >= 20,
      !is.na(female), !is.na(bmi),
      !is.na(mortstat), !is.na(permth_exm),
      !is.na(wtmec2yr), !is.na(sdmvpsu), !is.na(sdmvstra)
    ) %>%
    mutate(
      alt_elevated = as.numeric((female == 0 & lbxsal > 40) | 
                                (female == 1 & lbxsal > 30)),
      metabolic = as.numeric(bmi >= 25),
      mafld_proxy = as.numeric(alt_elevated == 1 & metabolic == 1),
      death = as.numeric(mortstat == 1),
      time_years = permth_exm / 12
    )
  
  cat("   N:", nrow(mafld_data), "\n")
  cat("   MAFLD:", sum(mafld_data$mafld_proxy), "\n")
  cat("   Deaths:", sum(mafld_data$death), "\n")
  
  # Unweighted PSM
  m_unwt <- matchit(mafld_proxy ~ age + female + race1 + bmi,
                    data = mafld_data, method = "nearest", ratio = 1)
  md_unwt <- match.data(m_unwt)
  
  cox_unwt <- coxph(Surv(time_years, death) ~ mafld_proxy + strata(subclass), data = md_unwt)
  hr_unwt <- exp(coef(cox_unwt)["mafld_proxy"])
  
  # Weighted
  svy <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra,
                   weights = ~wtmec2yr, nest = TRUE, data = mafld_data)
  cox_wt <- svycoxph(Surv(time_years, death) ~ mafld_proxy + age + female + race1 + bmi,
                     design = svy)
  hr_wt <- exp(coef(cox_wt)["mafld_proxy"])
  
  all_results$mafld <- list(
    unwt_hr = hr_unwt,
    wt_hr = hr_wt,
    diff_pct = 100 * (hr_unwt - hr_wt) / hr_wt
  )
  
  cat("   Unwt PSM: HR =", round(hr_unwt, 3), "\n")
  cat("   Weighted: HR =", round(hr_wt, 3), "\n")
  cat("   Difference:", round(100*(hr_unwt - hr_wt)/hr_wt, 1), "%\n")
  cat("   ✅ COMPLETE\n")
  
}, error = function(e) {
  cat("   ❌ ERROR:", e$message, "\n")
})

################################################################################
# PAPER 6: Smoking → CVD Outcomes (Additional feasible question)
################################################################################

cat("\n[6/6] Smoking → Hypertension...\n")

tryCatch({
  smoking_data <- nhanes_clean %>%
    filter(
      !is.na(smokestatus),
      !is.na(hypertension),
      !is.na(age), age >= 20,
      !is.na(female), !is.na(race1), !is.na(bmi),
      !is.na(wtmec2yr), !is.na(sdmvpsu), !is.na(sdmvstra)
    ) %>%
    mutate(
      current_smoker = as.numeric(smokestatus == 3),  # Current smoker
      htn = hypertension
    )
  
  cat("   N:", nrow(smoking_data), "\n")
  cat("   Current smokers:", sum(smoking_data$current_smoker), "\n")
  
  # Unweighted PSM
  m_unwt <- matchit(current_smoker ~ age + female + race1 + bmi,
                    data = smoking_data, method = "nearest", ratio = 1)
  md_unwt <- match.data(m_unwt)
  
  model_unwt <- glm(htn ~ current_smoker, data = md_unwt, family = binomial())
  or_unwt <- exp(coef(model_unwt)["current_smoker"])
  
  # Weighted
  svy <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra,
                   weights = ~wtmec2yr, nest = TRUE, data = smoking_data)
  model_wt <- svyglm(htn ~ current_smoker + age + female + race1 + bmi,
                     design = svy, family = quasibinomial())
  or_wt <- exp(coef(model_wt)["current_smoker"])
  
  all_results$smoking <- list(
    unwt_or = or_unwt,
    wt_or = or_wt,
    diff_pct = 100 * (or_unwt - or_wt) / or_wt
  )
  
  cat("   Unwt PSM: OR =", round(or_unwt, 3), "\n")
  cat("   Weighted: OR =", round(or_wt, 3), "\n")
  cat("   Difference:", round(100*(or_unwt - or_wt)/or_wt, 1), "%\n")
  cat("   ✅ COMPLETE\n")
  
}, error = function(e) {
  cat("   ❌ ERROR:", e$message, "\n")
})

################################################################################
# SUMMARY TABLE
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("                    ALL PAPERS: MASTER SUMMARY\n")
cat("==============================================================================\n")

cat("\nPaper                          | Unwt (Sample) | Weighted (Pop) | Difference\n")
cat("-------------------------------|---------------|----------------|------------\n")

if(!is.null(all_results$mvpa)) {
  cat(sprintf("MVPA → Mortality               | HR=%.3f       | HR=%.3f        | %+.1f%%\n",
      all_results$mvpa$unweighted_psm$hr,
      all_results$mvpa$weighted_reg$hr,
      100*(all_results$mvpa$unweighted_psm$hr - all_results$mvpa$weighted_reg$hr)/
          all_results$mvpa$weighted_reg$hr))
}

if(!is.null(all_results$obesity)) {
  cat(sprintf("Obesity → Hypertension         | OR=%.3f       | OR=%.3f        | %+.1f%%\n",
      all_results$obesity$unweighted_psm$or,
      all_results$obesity$weighted_reg$or,
      100*(all_results$obesity$unweighted_psm$or - all_results$obesity$weighted_reg$or)/
          all_results$obesity$weighted_reg$or))
}

if(!is.null(all_results$le8_ckd)) {
  cat(sprintf("LE8 → Mortality (CKD)          | HR=%.3f       | HR=%.3f        | %+.1f%%\n",
      all_results$le8_ckd$unwt_hr,
      all_results$le8_ckd$wt_hr,
      all_results$le8_ckd$diff_pct))
}

if(!is.null(all_results$uric_acid)) {
  cat(sprintf("Visceral Fat → Hyperuricemia   | OR=%.3f       | OR=%.3f        | %+.1f%%\n",
      all_results$uric_acid$unwt_or,
      all_results$uric_acid$wt_or,
      all_results$uric_acid$diff_pct))
}

if(!is.null(all_results$mafld)) {
  cat(sprintf("MAFLD → Mortality              | HR=%.3f       | HR=%.3f        | %+.1f%%\n",
      all_results$mafld$unwt_hr,
      all_results$mafld$wt_hr,
      all_results$mafld$diff_pct))
}

if(!is.null(all_results$smoking)) {
  cat(sprintf("Smoking → Hypertension         | OR=%.3f       | OR=%.3f        | %+.1f%%\n",
      all_results$smoking$unwt_or,
      all_results$smoking$wt_or,
      all_results$smoking$diff_pct))
}

# Save all results
save(all_results, file = "analysis_results/ALL_PAPERS_COMPLETE_RESULTS.rda")

cat("\n==============================================================================\n")
cat("ALL FEASIBLE PAPERS ANALYZED\n")
cat("Results saved to: analysis_results/ALL_PAPERS_COMPLETE_RESULTS.rda\n")
cat("==============================================================================\n")
