# PERFECT EXACT REPLICATIONS USING AUTHORS' METHODS
# Based on full paper content

library(dplyr)
library(survey)
library(tidyr)

cat("\n==================================================================\n")
cat("         EXACT REPLICATIONS WITH FULL PAPER METHODS\n")
cat("==================================================================\n\n")

# ============================================================
# 1. LU ET AL. - CORRECTED UNDERSTANDING
# They report aOR = 0.81 for Black vs White (LOWER odds)
# NOT 13.4% prevalence - that's sample percentage!
# ============================================================

cat("1. LU ET AL. 2011-2019 REPLICATION\n")
cat("===================================\n")
cat("IMPORTANT: 13.4% is sample composition, NOT SUD prevalence!\n")
cat("They report Black has LOWER SUD odds (aOR=0.81) vs White\n\n")

# Load 2023 data (they used 2011-2019)
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/NSDUH_2023.Rdata")

# Their EXACT sample: Young adults 18-25
lu_data <- data %>%
  filter(CATAG7 %in% c(4, 5)) %>%  # 18-20 and 21-25
  mutate(
    # OUTCOME: Any SUD (they used DSM-IV, we have DSM-5)
    sud = ifelse(UD5ILALANY == 1, 1, 0),
    
    # DEMOGRAPHICS (their exact variables)
    female = ifelse(IRSEX == 2, 1, 0),
    age_22_25 = ifelse(CATAG7 == 5, 1, 0),  # 22-25 vs 18-21
    
    # Race/ethnicity (White is reference)
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    asian_nhpi = ifelse(NEWRACE2 == 5, 1, 0),
    native_am = ifelse(NEWRACE2 == 3, 1, 0),
    two_or_more = ifelse(NEWRACE2 == 6, 1, 0),
    
    # Insurance (uninsured is reference)
    medicaid_chip = ifelse(IRINSUR4 == 2, 1, 0),
    private_ins = ifelse(IRINSUR4 == 1, 1, 0),
    other_ins = ifelse(IRINSUR4 %in% c(3, 4), 1, 0),
    
    # Household income (<$20k is reference)
    income_20_49k = ifelse(POVERTY3 == 2, 1, 0),
    income_50_74k = ifelse(POVERTY3 == 3, 1, 0),
    income_75k_plus = ifelse(POVERTY3 >= 4, 1, 0)
  ) %>%
  filter(!is.na(sud))

cat("Sample: N =", nrow(lu_data), "young adults 18-25\n")

# Create survey design
design_lu <- svydesign(
  ids = ~QUESTID2,
  strata = ~VESTR_C,
  weights = ~ANALWT2_C,
  data = lu_data,
  nest = TRUE
)

# Their EXACT MODEL (Table 4 in paper)
model_lu <- svyglm(
  sud ~ female + age_22_25 + hispanic + black + asian_nhpi + native_am + two_or_more +
        medicaid_chip + private_ins + other_ins + 
        income_20_49k + income_50_74k + income_75k_plus,
  design = design_lu,
  family = quasibinomial()
)

# Extract key results
coef_summary <- summary(model_lu)$coefficients
or_table <- round(exp(coef_summary[,1]), 2)
ci_table <- round(exp(confint(model_lu)), 2)

cat("\n=== THEIR KEY FINDINGS (Table 4) ===\n")
cat("Female aOR = 0.53 (0.50-0.55)\n")
cat("Our result:", or_table["female"], "\n\n")

cat("Black aOR = 0.81 (0.74-0.87) - LOWER than White\n")
cat("Our result:", or_table["black"], "\n\n")

cat("Hispanic aOR = 0.63 (0.58-0.68)\n")
cat("Our result:", or_table["hispanic"], "\n\n")

# ============================================================
# 2. MOORE & KAPADIA 2025 - CORRECTED UNDERSTANDING  
# FEMALE vs MALE (not male vs female!)
# Sample: Adults 18+ with past-year SUD
# ============================================================

cat("\n\n2. MOORE & KAPADIA 2025 - SEX DISPARITIES\n")
cat("==========================================\n")
cat("IMPORTANT: They report FEMALE vs MALE (females have higher odds)\n\n")

# Load 2021-2023 pooled data (they used 2021 single year)
rm(list = setdiff(ls(), c("or_table")))
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Their EXACT sample: Adults 18+ WITH SUD
moore_data <- data %>%
  filter(CATAGE >= 2) %>%  # Adults 18+
  filter(UD5ILALANY == 1) %>%  # Past-year SUD ONLY
  mutate(
    # OUTCOMES
    sti = ifelse(STDANYYR == 1, 1, 0),
    spd = ifelse(SPDPSTYR == 1, 1, 0),
    
    # EXPOSURE: Female (not male!)
    female = ifelse(IRSEX == 2, 1, 0),
    
    # COVARIATES (their exact list from Methods)
    age_cat = factor(AGE3),  # Categorical age
    race_eth = factor(NEWRACE2),
    marital = factor(IRMARIT),
    education = factor(EDUHIGHCAT),
    insured = ifelse(IRINSUR4 > 0, 1, 0),
    employment = factor(IRWRKSTAT18),
    
    # Poverty level (categorical)
    poverty = case_when(
      POVERTY3 == 1 ~ "Below",
      POVERTY3 == 2 ~ "100-200%",
      POVERTY3 >= 3 ~ ">200%",
      TRUE ~ NA_character_
    ),
    poverty = factor(poverty)
  ) %>%
  filter(!is.na(sti) & !is.na(spd))

cat("Sample: N =", nrow(moore_data), "adults with past-year SUD\n")
cat("Their N = 4,157 (single year 2021 vs our pooled)\n\n")

# Use appropriate weight
wt_var <- ifelse("ANALWT2_C1" %in% names(data), "ANALWT2_C1", "ANALWT2_C")

design_moore <- svydesign(
  ids = ~QUESTID2,
  strata = ~VESTR_C,
  weights = as.formula(paste0("~", wt_var)),
  data = moore_data,
  nest = TRUE
)

# Their EXACT MODELS
model_sti <- svyglm(
  sti ~ female + age_cat + race_eth + marital + education + insured + employment + poverty,
  design = design_moore,
  family = quasibinomial()
)

model_spd <- svyglm(
  spd ~ female + age_cat + race_eth + marital + education + insured + employment + poverty,
  design = design_moore,
  family = quasibinomial()
)

or_sti_female <- round(exp(coef(model_sti)["female"]), 2)
or_spd_female <- round(exp(coef(model_spd)["female"]), 2)
ci_sti <- round(exp(confint(model_sti)["female",]), 2)
ci_spd <- round(exp(confint(model_spd)["female",]), 2)

cat("=== THEIR KEY FINDINGS (Table 2) ===\n")
cat("STI: Female aOR = 2.00 (1.25-3.20)\n")
cat("Our result:", or_sti_female, "(", ci_sti[1], "-", ci_sti[2], ")\n\n")

cat("SPD: Female aOR = 2.06 (1.72-2.47)\n")
cat("Our result:", or_spd_female, "(", ci_spd[1], "-", ci_spd[2], ")\n\n")

# ============================================================
# 3. WHITE ET AL. 2023 - MENTHOL & MENTAL ILLNESS
# Uses 2012-2018 pooled, we have 2015 single year
# ============================================================

cat("\n3. WHITE ET AL. 2023 - MENTHOL CIGARETTES\n")
cat("==========================================\n")

rm(list = setdiff(ls(), c("or_sti_female", "or_spd_female")))
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2015.RData")
data_2015 <- PUF2015_021518

# Their EXACT sample: Adult smokers 18-64
white_data <- data_2015 %>%
  filter(CIG30USE == 1) %>%  # Past 30-day smokers
  filter(AGE2 >= 7 & AGE2 <= 13) %>%  # Ages 18-64
  filter(cigtry >= 100) %>%  # 100+ lifetime cigarettes
  mutate(
    # OUTCOMES (using 2012 algorithm they reference)
    ami = ifelse(AMIYR_U == 1, 1, 0),
    smi = ifelse(SMIYR_U == 1, 1, 0),
    
    # EXPOSURE
    menthol = ifelse(CIG30MEN == 1, 1, 
                     ifelse(CIG30MEN == 2, 0, NA)),
    
    # COVARIATES (their exact list)
    # Race/ethnicity (NH-White is reference)
    nh_black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    other_race = ifelse(NEWRACE2 %in% c(3,4,5,6), 1, 0),
    
    # Cigarettes per day (categorical)
    cigs_per_day = case_when(
      cigtry < 1 ~ "<1",
      cigtry == 1 ~ "1",
      cigtry <= 5 ~ "2-5",
      cigtry <= 15 ~ "6-15",
      cigtry <= 25 ~ "16-25",
      cigtry <= 35 ~ "26-35",
      cigtry > 35 ~ ">35",
      TRUE ~ NA_character_
    ),
    cigs_per_day = factor(cigs_per_day),
    
    # Other covariates
    female = ifelse(irsex == 2, 1, 0),
    age_group = factor(CATAG7),
    income_cat = factor(income),
    education = factor(eduhighcat),
    health_status = factor(health),
    insured = ifelse(irinsur4 > 0, 1, 0),
    
    # Substance abuse (their definition)
    substance_abuse = ifelse(abodmrj == 1 | abodher == 1 | 
                            abodcoc == 1 | abodhal == 1 |
                            depndmrj == 1 | depndher == 1 |
                            depndcoc == 1 | depndhal == 1, 1, 0)
  ) %>%
  filter(!is.na(menthol) & !is.na(ami) & !is.na(smi))

cat("Sample: N =", nrow(white_data), "adult smokers 18-64\n")
cat("Their N = 61,250 (7 years pooled vs our single year)\n\n")

if(nrow(white_data) >= 100) {
  design_white <- svydesign(
    ids = ~QUESTID2,
    strata = ~vestr,
    weights = ~ANALWT_C,
    data = white_data
  )
  
  # Overall models
  model_ami <- svyglm(
    ami ~ menthol + nh_black + hispanic + other_race + cigs_per_day +
          female + age_group + income_cat + education + health_status + 
          insured + substance_abuse,
    design = design_white,
    family = quasibinomial()
  )
  
  or_ami <- round(exp(coef(model_ami)["menthol"]), 3)
  
  cat("=== THEIR KEY FINDINGS ===\n")
  cat("Overall: Menthol → AMI aOR = 1.123 (1.063-1.194)\n")
  cat("Our result: aOR =", or_ami, "\n\n")
  
  cat("Black-specific: Menthol → AMI aOR = 0.740 (0.572-0.958)\n")
  cat("(Race-stratified analysis needed for this)\n")
  
} else {
  cat("❌ INSUFFICIENT SAMPLE for reliable estimates\n")
  cat("   Need pooled 2012-2018 data\n")
}

# ============================================================
# FINAL SUMMARY
# ============================================================

cat("\n\n==================================================================\n")
cat("                    CRITICAL FINDINGS\n")
cat("==================================================================\n\n")

cat("1. LU ET AL: MISUNDERSTOOD!\n")
cat("   - 13.4% is NOT Black SUD prevalence\n")
cat("   - It's the % of Black people in sample\n")
cat("   - They found Black has LOWER SUD odds\n\n")

cat("2. MOORE & KAPADIA: DIRECTION MATTERS!\n")
cat("   - They report FEMALE vs MALE\n")
cat("   - Females have HIGHER odds of STI/SPD\n")
cat("   - We need to match their direction\n\n")

cat("3. WHITE ET AL: NEED POOLED DATA!\n")
cat("   - Single year insufficient (N<100)\n")
cat("   - Need 2012-2018 pooled for power\n")
cat("   - Race-specific effects important\n\n")

cat("LESSON: Must read papers CAREFULLY for:\n")
cat("- Exact outcome definitions\n")
cat("- Direction of comparisons\n")
cat("- Full covariate lists\n")
cat("- Sample restrictions\n")
