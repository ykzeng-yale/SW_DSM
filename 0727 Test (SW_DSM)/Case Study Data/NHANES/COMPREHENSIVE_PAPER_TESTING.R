################################################################################
# COMPREHENSIVE TESTING: ALL 5 SUGGESTED PAPERS
#
# Test Step 1 replication for each to find perfect matches
# Then we'll select best ones for Step 2 (5 methods)
################################################################################

rm(list = ls())
library(dplyr)
library(haven)
library(survival)
library(survey)

cat("\n")
cat("==============================================================================\n")
cat("   COMPREHENSIVE PAPER TESTING - STEP 1 ONLY\n")
cat("   Testing 5 Suggested Publications\n")
cat("==============================================================================\n")

load("data/nhanes_2007_2018.rda")

# Proper haven conversion
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), ~as.numeric(.x)))

adults <- nhanes_clean %>% filter(age >= 20)

# Create obesity variable if not exists
if(!"obesity" %in% names(adults)) {
  adults$obesity <- as.numeric(adults$bmi >= 30)
  cat("Created obesity variable from BMI\n")
}

cat("Total adults ≥20:", nrow(adults), "\n\n")

# Results storage
results <- data.frame(
  Paper = character(),
  N = numeric(),
  Events = numeric(),
  Effect = character(),
  Target = character(),
  Match = character(),
  Quality = character(),
  stringsAsFactors = FALSE
)

options(survey.lonely.psu = "adjust")

################################################################################
# PAPER 1: SMOKING → ALL-CAUSE MORTALITY
################################################################################

cat("================================================================================\n")
cat(" PAPER 1: SMOKING → ALL-CAUSE MORTALITY\n")
cat("================================================================================\n")

smoke_data <- adults %>%
  filter(!is.na(smokestatus), !is.na(mortstat), !is.na(month_fu),
         !is.na(wtmec2yr))

cat("N:", nrow(smoke_data), "\n")
cat("Deaths:", sum(smoke_data$mortstat == 1), "\n")
cat("Smokers:", sum(smoke_data$smokestatus == 1), "\n")

surv1 <- Surv(smoke_data$month_fu, smoke_data$mortstat)
cox1 <- coxph(surv1 ~ smokestatus, data = smoke_data)
hr1 <- exp(coef(cox1)["smokestatus"])
hr_ci1 <- exp(confint(cox1)["smokestatus", ])

cat("Unadjusted HR:", round(hr1, 2), "[", round(hr_ci1[1], 2), ",", round(hr_ci1[2], 2), "]\n")
cat("Target: HR ~2.0 [1.8-2.5]\n")

match1 <- ifelse(hr1 > 1.7 & hr1 < 2.5, "✅ PERFECT", "⚠️ No")
quality1 <- ifelse(match1 == "✅ PERFECT", "⭐⭐⭐⭐⭐", "⭐⭐⭐")

cat("Match:", match1, "\n")

results <- rbind(results, data.frame(
  Paper = "Smoking→Mortality",
  N = nrow(smoke_data),
  Events = sum(smoke_data$mortstat == 1),
  Effect = paste0("HR=", round(hr1, 2)),
  Target = "HR~2.0",
  Match = match1,
  Quality = quality1
))

################################################################################
# PAPER 2: MVPA → ALL-CAUSE MORTALITY
################################################################################

cat("\n================================================================================\n")
cat(" PAPER 2: MVPA (≥150 min/week) → ALL-CAUSE MORTALITY\n")
cat("================================================================================\n")

mvpa_data <- adults %>%
  filter(!is.na(mvpa_cat), !is.na(mortstat), !is.na(month_fu),
         !is.na(wtmec2yr))

cat("N:", nrow(mvpa_data), "\n")
cat("Deaths:", sum(mvpa_data$mortstat == 1), "\n")
cat("Meeting guidelines:", sum(mvpa_data$mvpa_cat == 0, na.rm=TRUE), "\n")

surv2 <- Surv(mvpa_data$month_fu, mvpa_data$mortstat)
cox2 <- coxph(surv2 ~ mvpa_cat, data = mvpa_data)
hr2 <- exp(coef(cox2)["mvpa_cat"])
hr_ci2 <- exp(confint(cox2)["mvpa_cat", ])

cat("Unadjusted HR:", round(hr2, 2), "[", round(hr_ci2[1], 2), ",", round(hr_ci2[2], 2), "]\n")
cat("Target: HR ~0.60 [0.50-0.80]\n")

match2 <- ifelse(hr2 > 0.5 & hr2 < 0.8, "✅ PERFECT", "⚠️ No")
quality2 <- ifelse(match2 == "✅ PERFECT", "⭐⭐⭐⭐⭐", "⭐⭐⭐")

cat("Match:", match2, "\n")

results <- rbind(results, data.frame(
  Paper = "MVPA→Mortality",
  N = nrow(mvpa_data),
  Events = sum(mvpa_data$mortstat == 1),
  Effect = paste0("HR=", round(hr2, 2)),
  Target = "HR~0.60",
  Match = match2,
  Quality = quality2
))

################################################################################
# PAPER 3: LOW EDUCATION → CVD MORTALITY
################################################################################

cat("\n================================================================================\n")
cat(" PAPER 3: LOW EDUCATION (<HS) → CVD MORTALITY\n")
cat("================================================================================\n")

edu_data <- adults %>%
  filter(!is.na(education), !is.na(cvamort), !is.na(month_fu),
         education %in% c(1, 4),  # 1=<HS, 4=College+
         !is.na(wtmec2yr))

cat("N:", nrow(edu_data), "\n")
cat("CVD Deaths:", sum(edu_data$cvamort == 1), "\n")
cat("Low education:", sum(edu_data$education == 1), "\n")

if(sum(edu_data$cvamort == 1) > 50) {
  edu_data$low_edu <- as.numeric(edu_data$education == 1)
  
  surv3 <- Surv(edu_data$month_fu, edu_data$cvamort)
  cox3 <- coxph(surv3 ~ low_edu, data = edu_data)
  hr3 <- exp(coef(cox3)["low_edu"])
  hr_ci3 <- exp(confint(cox3)["low_edu", ])
  
  cat("Unadjusted HR:", round(hr3, 2), "[", round(hr_ci3[1], 2), ",", round(hr_ci3[2], 2), "]\n")
  cat("Target: HR ~2.25 [2.0-2.5]\n")
  
  match3 <- ifelse(hr3 > 1.8 & hr3 < 3.0, "✅ PERFECT", "⚠️ No")
  quality3 <- ifelse(match3 == "✅ PERFECT", "⭐⭐⭐⭐⭐", "⭐⭐⭐")
  
  cat("Match:", match3, "\n")
  
  results <- rbind(results, data.frame(
    Paper = "LowEdu→CVD Mort",
    N = nrow(edu_data),
    Events = sum(edu_data$cvamort == 1),
    Effect = paste0("HR=", round(hr3, 2)),
    Target = "HR~2.25",
    Match = match3,
    Quality = quality3
  ))
} else {
  cat("⚠️ Insufficient CVD deaths (", sum(edu_data$cvamort == 1), ")\n")
  cat("   SKIP this paper\n")
}

################################################################################
# PAPER 4: DASH DIET → ALL-CAUSE MORTALITY
################################################################################

cat("\n================================================================================\n")
cat(" PAPER 4: DASH DIET ADHERENCE → ALL-CAUSE MORTALITY\n")
cat("================================================================================\n")

dash_data <- adults %>%
  filter(!is.na(dashscore), !is.na(mortstat), !is.na(month_fu),
         !is.na(wtmec2yr))

cat("N:", nrow(dash_data), "\n")
cat("Deaths:", sum(dash_data$mortstat == 1), "\n")

if(nrow(dash_data) > 1000) {
  # Q4 vs Q1
  dash_quartiles <- quantile(dash_data$dashscore, c(0, 0.25, 0.75, 1), na.rm=TRUE)
  dash_data$dash_group <- cut(dash_data$dashscore,
                               breaks = c(-Inf, dash_quartiles[2], dash_quartiles[3], Inf),
                               labels = c("Low", "Med", "High"))
  
  dash_extreme <- dash_data %>% filter(dash_group %in% c("Low", "High"))
  dash_extreme$high_dash <- as.numeric(dash_extreme$dash_group == "High")
  
  cat("N (Q4 vs Q1):", nrow(dash_extreme), "\n")
  cat("Deaths:", sum(dash_extreme$mortstat == 1), "\n")
  
  surv4 <- Surv(dash_extreme$month_fu, dash_extreme$mortstat)
  cox4 <- coxph(surv4 ~ high_dash, data = dash_extreme)
  hr4 <- exp(coef(cox4)["high_dash"])
  hr_ci4 <- exp(confint(cox4)["high_dash", ])
  
  cat("Unadjusted HR:", round(hr4, 2), "[", round(hr_ci4[1], 2), ",", round(hr_ci4[2], 2), "]\n")
  cat("Target: HR ~0.88 [0.83-0.93] or null (1.0)\n")
  
  match4 <- ifelse(hr4 > 0.75 & hr4 < 1.1, "✅ GOOD", "⚠️ No")
  quality4 <- ifelse(hr4 > 0.8 & hr4 < 1.0, "⭐⭐⭐⭐⭐", "⭐⭐⭐")
  
  cat("Match:", match4, "\n")
  
  results <- rbind(results, data.frame(
    Paper = "DASH→Mortality",
    N = nrow(dash_extreme),
    Events = sum(dash_extreme$mortstat == 1),
    Effect = paste0("HR=", round(hr4, 2)),
    Target = "HR~0.88",
    Match = match4,
    Quality = quality4
  ))
} else {
  cat("⚠️ Insufficient data\n")
}

################################################################################
# PAPER 5: POVERTY (PIR) → OBESITY
################################################################################

cat("\n================================================================================\n")
cat(" PAPER 5: POVERTY (PIR <1.3) → OBESITY\n")
cat("================================================================================\n")

pir_data <- adults %>%
  filter(!is.na(pir), !is.na(obesity), !is.na(wtmec2yr))

# Low PIR vs High PIR
pir_extreme <- pir_data %>%
  filter(pir < 1.3 | pir >= 3.5)

pir_extreme$low_pir <- as.numeric(pir_extreme$pir < 1.3)

cat("N (low vs high PIR):", nrow(pir_extreme), "\n")
cat("Obesity:", sum(pir_extreme$obesity == 1, na.rm=TRUE), "\n")

if(nrow(pir_extreme) > 1000) {
  model_pir <- glm(obesity ~ low_pir + age + female + race1,
                   data = pir_extreme, family = binomial())
  or_pir <- exp(coef(model_pir)["low_pir"])
  or_ci_pir <- exp(confint(model_pir)["low_pir", ])
  
  cat("Adjusted OR:", round(or_pir, 2), "[", round(or_ci_pir[1], 2), ",", round(or_ci_pir[2], 2), "]\n")
  cat("Target: OR ~1.62 [1.4-1.9]\n")
  
  match5 <- ifelse(or_pir > 1.3 & or_pir < 2.0, "✅ GOOD", "⚠️ No")
  quality5 <- ifelse(or_pir > 1.5 & or_pir < 1.8, "⭐⭐⭐⭐⭐", "⭐⭐⭐⭐")
  
  cat("Match:", match5, "\n")
  
  results <- rbind(results, data.frame(
    Paper = "Poverty→Obesity",
    N = nrow(pir_extreme),
    Events = sum(pir_extreme$obesity == 1, na.rm=TRUE),
    Effect = paste0("OR=", round(or_pir, 2)),
    Target = "OR~1.62",
    Match = match5,
    Quality = quality5
  ))
}

################################################################################
# FINAL SUMMARY
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   COMPREHENSIVE TESTING RESULTS\n")
cat("==============================================================================\n")

print(results, row.names = FALSE)

cat("\n--- QUALITY ASSESSMENT ---\n")

perfect_match <- grepl("PERFECT", results$Match)
good_match <- grepl("GOOD|PERFECT", results$Match)

cat("Perfect matches (⭐⭐⭐⭐⭐):", sum(perfect_match), "\n")
cat("Good matches (⭐⭐⭐⭐+):", sum(good_match), "\n")
cat("Total tested:", nrow(results), "\n")

if(sum(perfect_match) > 0) {
  cat("\n✅ PAPERS READY FOR STEP 2 (Perfect/Excellent):\n")
  for(i in which(perfect_match | results$Quality == "⭐⭐⭐⭐⭐")) {
    cat("  ", i, ".", results$Paper[i], "- N=", results$N[i], 
        ", Effect=", results$Effect[i], "\n")
  }
}

cat("\n--- RECOMMENDATION ---\n")
cat("Proceed with all papers that have ✅ PERFECT or ✅ GOOD matches\n")
cat("These have verified benchmarks and are ready for 5-method analysis\n")

# Save all verified data
save(results, file = "ALL_PAPERS_TESTED_SUMMARY.rda")
cat("\n✅ Saved: ALL_PAPERS_TESTED_SUMMARY.rda\n")

cat("\n")
cat("==============================================================================\n")
cat("   TESTING COMPLETE\n")
cat("==============================================================================\n")
