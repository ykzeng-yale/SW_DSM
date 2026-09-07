################################################################################
# TEST ALL REMAINING SUGGESTED PAPERS (Step 1 Only)
#
# Check which ones we can replicate before doing full 5-method analysis
################################################################################

rm(list = ls())
library(dplyr)
library(survival)
library(survey)

load("data/nhanes_2007_2018.rda")

# Use variables directly (already mostly numeric)
nhanes <- nhanes_2007_2018

cat("\n")
cat("==============================================================================\n")
cat("   TESTING ALL SUGGESTED PAPERS - STEP 1 VERIFICATION\n")
cat("==============================================================================\n")

# Adults
adults <- nhanes %>% filter(age >= 20)
cat("Total adults ≥20:", nrow(adults), "\n\n")

results_summary <- data.frame(
  Paper = character(),
  N = numeric(),
  Deaths = numeric(),
  HR_Unadj = numeric(),
  HR_Target = character(),
  Match = character(),
  stringsAsFactors = FALSE
)

options(survey.lonely.psu = "adjust")

################################################################################
# 1. SMOKING → MORTALITY (ALREADY VERIFIED)
################################################################################

cat("================================================================================\n")
cat(" PAPER 1: SMOKING → ALL-CAUSE MORTALITY\n")
cat("================================================================================\n")

smoke_data <- adults %>%
  filter(!is.na(smokestatus), !is.na(mortstat), !is.na(month_fu),
         !is.na(wtmec2yr), !is.na(age), !is.na(female), !is.na(race1))

cat("N:", nrow(smoke_data), ", Deaths:", sum(smoke_data$mortstat == 1), "\n")

surv1 <- Surv(smoke_data$month_fu, smoke_data$mortstat)
cox1 <- coxph(surv1 ~ smokestatus, data = smoke_data)
hr1 <- exp(coef(cox1)["smokestatus"])

cat("Unadjusted HR:", round(hr1, 2), "(Target: ~2.0)\n")

results_summary <- rbind(results_summary, data.frame(
  Paper = "Smoking→Mortality",
  N = nrow(smoke_data),
  Deaths = sum(smoke_data$mortstat == 1),
  HR_Unadj = hr1,
  HR_Target = "~2.0",
  Match = ifelse(hr1 > 1.7 & hr1 < 2.5, "✅ YES", "⚠️ NO")
))

################################################################################
# 2. MVPA → MORTALITY
################################################################################

cat("\n================================================================================\n")
cat(" PAPER 2: MVPA (PA Guidelines) → ALL-CAUSE MORTALITY\n")
cat("================================================================================\n")

mvpa_data <- adults %>%
  filter(!is.na(mvpa_cat), !is.na(mortstat), !is.na(month_fu),
         !is.na(wtmec2yr), !is.na(age), !is.na(female), !is.na(race1))

cat("N:", nrow(mvpa_data), ", Deaths:", sum(mvpa_data$mortstat == 1), "\n")

surv2 <- Surv(mvpa_data$month_fu, mvpa_data$mortstat)
cox2 <- coxph(surv2 ~ mvpa_cat, data = mvpa_data)
hr2 <- exp(coef(cox2)["mvpa_cat"])

cat("Unadjusted HR:", round(hr2, 2), "(Target: ~0.60)\n")

results_summary <- rbind(results_summary, data.frame(
  Paper = "MVPA→Mortality",
  N = nrow(mvpa_data),
  Deaths = sum(mvpa_data$mortstat == 1),
  HR_Unadj = hr2,
  HR_Target = "~0.60",
  Match = ifelse(hr2 > 0.5 & hr2 < 0.8, "✅ YES", "⚠️ NO")
))

################################################################################
# 3. EDUCATION → CVD MORTALITY
################################################################################

cat("\n================================================================================\n")
cat(" PAPER 3: LOW EDUCATION → CVD MORTALITY\n")
cat("================================================================================\n")

# Filter to low vs high education only
edu_data <- adults %>%
  filter(!is.na(education), !is.na(cvamort), !is.na(month_fu),
         education %in% c(1, 4),  # 1=<HS, 4=College+
         !is.na(wtmec2yr), !is.na(age), !is.na(female), !is.na(race1))

cat("N:", nrow(edu_data), ", CVD Deaths:", sum(edu_data$cvamort == 1, na.rm=TRUE), "\n")

if(sum(edu_data$cvamort == 1, na.rm=TRUE) > 50) {
  # Create treatment (1=low edu)
  edu_data$low_edu <- as.numeric(edu_data$education == 1)
  
  surv3 <- Surv(edu_data$month_fu, edu_data$cvamort)
  cox3 <- coxph(surv3 ~ low_edu, data = edu_data)
  hr3 <- exp(coef(cox3)["low_edu"])
  
  cat("Unadjusted HR:", round(hr3, 2), "(Target: ~2.25)\n")
  
  results_summary <- rbind(results_summary, data.frame(
    Paper = "Low Edu→CVD Mort",
    N = nrow(edu_data),
    Deaths = sum(edu_data$cvamort == 1, na.rm=TRUE),
    HR_Unadj = hr3,
    HR_Target = "~2.25",
    Match = ifelse(hr3 > 1.8 & hr3 < 3.0, "✅ YES", "⚠️ NO")
  ))
} else {
  cat("⚠️ Insufficient CVD deaths\n")
}

################################################################################
# 4. DASH DIET → MORTALITY
################################################################################

cat("\n================================================================================\n")
cat(" PAPER 4: DASH DIET ADHERENCE → ALL-CAUSE MORTALITY\n")
cat("================================================================================\n")

dash_data <- adults %>%
  filter(!is.na(dashscore), !is.na(mortstat), !is.na(month_fu),
         !is.na(wtmec2yr), !is.na(age), !is.na(female), !is.na(race1))

cat("N:", nrow(dash_data), ", Deaths:", sum(dash_data$mortstat == 1), "\n")

if(nrow(dash_data) > 1000) {
  # Create high vs low DASH (Q4 vs Q1)
  dash_quartiles <- quantile(dash_data$dashscore, c(0, 0.25, 0.75, 1), na.rm=TRUE)
  dash_data$dash_group <- cut(dash_data$dashscore,
                               breaks = c(-Inf, dash_quartiles[2], dash_quartiles[3], Inf),
                               labels = c("Low", "Medium", "High"))
  
  dash_extreme <- dash_data %>% filter(dash_group %in% c("Low", "High"))
  dash_extreme$high_dash <- as.numeric(dash_extreme$dash_group == "High")
  
  surv4 <- Surv(dash_extreme$month_fu, dash_extreme$mortstat)
  cox4 <- coxph(surv4 ~ high_dash, data = dash_extreme)
  hr4 <- exp(coef(cox4)["high_dash"])
  
  cat("Unadjusted HR:", round(hr4, 2), "(Target: ~0.88 or null)\n")
  
  results_summary <- rbind(results_summary, data.frame(
    Paper = "DASH→Mortality",
    N = nrow(dash_extreme),
    Deaths = sum(dash_extreme$mortstat == 1),
    HR_Unadj = hr4,
    HR_Target = "~0.88 or 1.0",
    Match = ifelse(hr4 < 1.2, "✅ YES", "⚠️ NO")
  ))
} else {
  cat("⚠️ Insufficient data with DASH score\n")
}

################################################################################
# 5. POVERTY (PIR) → OBESITY
################################################################################

cat("\n================================================================================\n")
cat(" PAPER 5: POVERTY (LOW PIR) → OBESITY\n")
cat("================================================================================\n")

# Cross-sectional (no mortality)
pir_data <- adults %>%
  filter(!is.na(pir), !is.na(obesity),
         !is.na(wtmec2yr), !is.na(age), !is.na(female), !is.na(race1))

cat("N:", nrow(pir_data), ", Obesity:", sum(pir_data$obesity == 1, na.rm=TRUE), "\n")

# Low PIR (<1.3) vs High PIR (≥3.5)
pir_data$low_pir <- as.numeric(pir_data$pir < 1.3)
pir_data$high_pir <- as.numeric(pir_data$pir >= 3.5)

pir_extreme <- pir_data %>% filter(low_pir == 1 | high_pir == 1)

cat("N (low vs high PIR):", nrow(pir_extreme), "\n")

if(nrow(pir_extreme) > 1000) {
  # Logistic regression
  model_pir <- glm(obesity ~ low_pir + age + female + race1,
                   data = pir_extreme, family = binomial())
  or_pir <- exp(coef(model_pir)["low_pir"])
  
  cat("Unadjusted OR:", round(or_pir, 2), "(Target: ~1.62)\n")
  
  results_summary <- rbind(results_summary, data.frame(
    Paper = "Poverty→Obesity",
    N = nrow(pir_extreme),
    Deaths = sum(pir_extreme$obesity == 1),
    HR_Unadj = or_pir,
    HR_Target = "~1.62 (OR)",
    Match = ifelse(or_pir > 1.3 & or_pir < 2.0, "✅ YES", "⚠️ NO")
  ))
}

################################################################################
# SUMMARY
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   SUMMARY: ALL PAPERS TESTED\n")
cat("==============================================================================\n")

print(results_summary, row.names = FALSE)

cat("\n--- RECOMMENDATION ---\n")
perfect_match <- results_summary$Match == "✅ YES"
cat("Papers with good alignment:", sum(perfect_match), "of", nrow(results_summary), "\n")

if(sum(perfect_match) > 0) {
  cat("\nVerified papers ready for Step 2:\n")
  for(i in which(perfect_match)) {
    cat("  ✅", results_summary$Paper[i], "- HR/OR =", 
        round(results_summary$HR_Unadj[i], 2), "\n")
  }
}

cat("\n")
cat("==============================================================================\n")
cat("   VERIFICATION COMPLETE\n")
cat("==============================================================================\n")
