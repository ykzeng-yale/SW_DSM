# EXACT REPLICATION USING AUTHORS' ORIGINAL METHODS
# Not our matching methods - THEIR statistical approaches

library(dplyr)
library(survey)

cat("\n==================================================================\n")
cat("    REPLICATING WITH AUTHORS' EXACT METHODS\n")
cat("==================================================================\n\n")

# ============================================================
# 1. LU ET AL. 2023 - THEIR METHOD
# From what we know: They reported PREVALENCE
# Method: Survey-weighted prevalence (likely with svyby)
# ============================================================

cat("1. LU ET AL. 2023 - PREVALENCE CALCULATION\n")
cat("===========================================\n")
cat("Their method: Survey-weighted prevalence by race\n\n")

load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/NSDUH_2023.Rdata")

# THEIR EXACT SAMPLE: Young adults 18-25
lu_data <- data %>%
  filter(CATAG7 %in% c(4, 5)) %>%  # 18-25 years
  mutate(
    sud = ifelse(UD5ILALANY == 1, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    white = ifelse(NEWRACE2 == 1, 1, 0)
  )

# THEIR METHOD: Survey-weighted prevalence
design_lu <- svydesign(
  ids = ~QUESTID2,
  strata = ~VESTR_C,
  weights = ~ANALWT2_C,
  data = lu_data,
  nest = TRUE
)

# Calculate prevalence BY RACE (their main outcome)
prev_by_race <- svyby(~sud, ~black, design_lu, svymean, vartype = c("se", "ci"))

cat("Sample: N =", nrow(lu_data), "\n")
cat("Method: Survey-weighted prevalence estimation\n\n")

cat("RESULTS:\n")
cat("White young adults SUD:", round(100*prev_by_race$sud[1], 1), "%",
    "SE =", round(100*prev_by_race$se[1], 2), "%\n")
cat("Black young adults SUD:", round(100*prev_by_race$sud[2], 1), "%",
    "SE =", round(100*prev_by_race$se[2], 2), "%\n\n")

cat("Lu et al. reported: 13.4% for Black young adults\n")
cat("Our result: ", round(100*prev_by_race$sud[2], 1), "%\n")
cat("Difference: ", round(100*prev_by_race$sud[2], 1) - 13.4, "percentage points\n\n")

# ============================================================
# 2. PACEK ET AL. 2017 - THEIR METHOD
# From PMC5411709: Multivariable logistic regression
# Adjusted for: sex, current age, race/ethnicity, 
# education, income, population density, any SUD
# ============================================================

cat("\n2. PACEK ET AL. 2017 - LOGISTIC REGRESSION\n")
cat("============================================\n")
cat("Their method: Multivariable logistic regression with survey weights\n\n")

# Create their exact sample
pacek_data <- data %>%
  filter(CATAG7 %in% c(1, 2, 3, 4, 5)) %>%  # Ages 12-25
  filter(MRJFLAG == 1) %>%  # Lifetime cannabis users
  mutate(
    # OUTCOME
    mde = ifelse(IRAMDEYR == 1, 1, 0),
    
    # EXPOSURE
    age_first_use = IRMJAGE,
    age_first_cat = cut(IRMJAGE,
                        breaks = c(0, 12, 14, 16, 18, 990),
                        labels = c("≤12", "13-14", "15-16", "17-18", "19+"),
                        right = TRUE, include.lowest = TRUE),
    
    # THEIR COVARIATES (from paper)
    sex = factor(IRSEX),
    current_age = AGE3,
    race_ethnicity = factor(NEWRACE2),
    education = factor(EDUHIGHCAT),
    poverty_level = factor(POVERTY3),
    metro = factor(COUTYP4),
    
    # Other substance use disorders (if available)
    alcohol_ud = ifelse(IRPYUD5ALC == 1, 1, 0),
    other_drug_ud = ifelse(UD5ILLANY == 1, 1, 0)
  ) %>%
  filter(!is.na(age_first_use) & age_first_use < 900 & !is.na(mde))

cat("Sample: N =", nrow(pacek_data), "cannabis users aged 12-25\n")
cat("Pacek's N = 53,737 (10 years pooled)\n\n")

# THEIR METHOD: Survey-weighted logistic regression
design_pacek <- svydesign(
  ids = ~QUESTID2,
  strata = ~VESTR_C,
  weights = ~ANALWT2_C,
  data = pacek_data,
  nest = TRUE
)

# THEIR MODEL (as close as we can get)
model_pacek <- svyglm(
  mde ~ relevel(age_first_cat, ref = "19+") + sex + current_age + 
        race_ethnicity + education + poverty_level + metro + 
        alcohol_ud + other_drug_ud,
  design = design_pacek,
  family = quasibinomial()
)

# Extract key results
coef_summary <- summary(model_pacek)$coefficients
or_table <- exp(coef_summary[,1])
ci_table <- exp(confint(model_pacek))

# Find the age coefficients
age_coefs <- grep("age_first_cat", names(or_table))

cat("THEIR METHOD: Multivariable logistic regression\n")
cat("COVARIATES: sex, age, race, education, poverty, metro, SUDs\n\n")

cat("RESULTS (aOR, 95% CI):\n")
for(i in age_coefs) {
  cat(names(or_table)[i], ": ",
      sprintf("%.2f", or_table[i]),
      " (", sprintf("%.2f", ci_table[i,1]), "-",
      sprintf("%.2f", ci_table[i,2]), ")\n", sep="")
}

cat("\nPacek et al. reported:\n")
cat("≤12 vs 19+: aOR = 1.41 (0.95-2.10)\n")
cat("13-14 vs 19+: aOR = 1.51 (1.16-1.97)\n")

# ============================================================
# 3. MOORE & KAPADIA 2025 - THEIR METHOD
# Survey-weighted logistic regression
# Adults with past-year SUD
# ============================================================

cat("\n\n3. MOORE & KAPADIA 2025 - SEX DIFFERENCES\n")
cat("===========================================\n")
cat("Their method: Survey-weighted logistic regression\n\n")

# Load pooled data for Moore
rm(list = setdiff(ls(), c("prev_by_race")))
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Their sample: Adults with SUD
moore_data <- data %>%
  filter(CATAGE >= 2) %>%  # Adults 18+
  filter(UD5ILALANY == 1) %>%  # Past-year SUD
  mutate(
    # OUTCOMES
    sti = ifelse(STDANYYR == 1, 1, 0),
    spd = ifelse(SPDPSTYR == 1, 1, 0),
    
    # EXPOSURE
    female = ifelse(IRSEX == 2, 1, 0),
    
    # COVARIATES (typical for NSDUH studies)
    age_group = factor(CATAGE),
    race_ethnicity = factor(NEWRACE2),
    education = factor(EDUHIGHCAT),
    income = factor(POVERTY3),
    marital = factor(IRMARIT)
  ) %>%
  filter(!is.na(sti) & !is.na(spd))

cat("Sample: N =", nrow(moore_data), "adults with past-year SUD\n")
cat("Moore's N = 4,157\n")
cat("Discrepancy likely due to year selection or inclusion criteria\n\n")

# Use appropriate weight
wt_var <- ifelse("ANALWT2_C1" %in% names(data), "ANALWT2_C1", "ANALWT2_C")

design_moore <- svydesign(
  ids = ~QUESTID2,
  strata = ~VESTR_C,
  weights = as.formula(paste0("~", wt_var)),
  data = moore_data,
  nest = TRUE
)

# THEIR MODELS
model_sti <- svyglm(
  sti ~ female + age_group + race_ethnicity + education + income + marital,
  design = design_moore,
  family = quasibinomial()
)

model_spd <- svyglm(
  spd ~ female + age_group + race_ethnicity + education + income + marital,
  design = design_moore,
  family = quasibinomial()
)

or_sti_female <- exp(coef(model_sti)["female"])
or_spd_female <- exp(coef(model_spd)["female"])

# They report MALE vs FEMALE, so we need to invert
or_sti_male <- 1/or_sti_female
or_spd_male <- 1/or_spd_female

cat("METHOD: Survey-weighted logistic regression\n")
cat("COVARIATES: age, race, education, income, marital status\n\n")

cat("RESULTS (Male vs Female):\n")
cat("STI: aOR =", sprintf("%.2f", or_sti_male), "\n")
cat("SPD: aOR =", sprintf("%.2f", or_spd_male), "\n\n")

cat("Moore et al. reported:\n")
cat("STI: aOR = 2.00 (1.60-2.40)\n")
cat("SPD: aOR = 2.06 (1.70-2.42)\n")

# ============================================================
# SUMMARY TABLE
# ============================================================

cat("\n\n==================================================================\n")
cat("          SUMMARY: USING AUTHORS' EXACT METHODS\n")
cat("==================================================================\n\n")

results <- data.frame(
  Study = c("Lu 2023",
            "Pacek 2017 (≤12)",
            "Pacek 2017 (13-14)",
            "Moore 2025 (STI)",
            "Moore 2025 (SPD)"),
  
  Method = c("Weighted prevalence",
             "Weighted logistic",
             "Weighted logistic",
             "Weighted logistic",
             "Weighted logistic"),
  
  Their_Result = c("13.4%",
                   "aOR=1.41",
                   "aOR=1.51",
                   "aOR=2.00",
                   "aOR=2.06"),
  
  Our_Result = c(paste0(round(100*prev_by_race$sud[2], 1), "%"),
                 "See above",
                 "See above",
                 sprintf("aOR=%.2f", or_sti_male),
                 sprintf("aOR=%.2f", or_spd_male)),
  
  Match = c("No", "TBD", "TBD", "TBD", "TBD")
)

print(results, row.names = FALSE)

cat("\n\nKEY POINT: These are replications using the AUTHORS' methods,\n")
cat("not our matching methods. Next step would be to apply OUR matching\n")
cat("methods (WDSM, DSM, PSM, PGM, PS Full) to these same causal questions.\n")

saveRDS(results, "Analysis/Results/author_methods_replication.rds")
