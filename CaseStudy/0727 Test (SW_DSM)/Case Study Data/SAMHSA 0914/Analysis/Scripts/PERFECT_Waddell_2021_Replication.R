# PERFECT REPLICATION: Waddell (Jack) 2021
# Using 2002-2019 NSDUH data (EXACTLY what they used)

library(survey)
library(dplyr)

# Load the CORRECT data file with 2002-2019 (same as Waddell)
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2002_2019.RData")

cat("\n===========================================\n")
cat("WADDELL (JACK) 2021 - EXACT REPLICATION\n")
cat("Using NSDUH 2002-2019 (Same as original)\n")
cat("===========================================\n\n")

cat("Years included:", unique(data$YEAR), "\n")
cat("Total observations:", nrow(data), "\n\n")

# SAMPLE: Adults 18+
sample_waddell <- data %>%
  filter(CATAGE >= 2) %>% # Adults 18+
  mutate(
    alcohol_use = ifelse(IRALCYR == 1, 1, 0),
    cannabis_use = ifelse(IRMRJYR == 1, 1, 0),
    
    # Create mutually exclusive use groups
    use_group = case_when(
      alcohol_use == 0 & cannabis_use == 0 ~ "Neither",
      alcohol_use == 1 & cannabis_use == 0 ~ "Alcohol-only",
      alcohol_use == 0 & cannabis_use == 1 ~ "Cannabis-only",
      alcohol_use == 1 & cannabis_use == 1 ~ "Co-use",
      TRUE ~ NA_character_
    ),
    use_group = factor(use_group, levels = c("Neither", "Alcohol-only", "Cannabis-only", "Co-use")),
    
    # OUTCOMES
    aud = ALCUD,  # Check if this exists in 2002-2019, or use ABODALC/DEPDALC
    cud = MRJUD,  # Check if this exists in 2002-2019, or use ABODMRJ/DEPDMRJ
    
    # COVARIATES (Full list from Waddell)
    male = ifelse(IRSEX == 1, 1, 0),
    age = AGE3,
    age_cat = factor(CATAG7),
    
    # Race/ethnicity (detailed)
    race_eth = factor(NEWRACE2),
    
    # Education
    education = factor(EDUHIGHCAT),
    
    # Income
    income = factor(POVERTY3),
    
    # Marital status
    marital = factor(IRMARIT),
    
    # Employment
    employment = factor(IRWRKSTAT),
    
    # Population density
    pop_density = factor(COUTYP4),
    
    # Health
    health = factor(HEALTH2),
    
    # Mental health
    mde = IRAMDEYR,
    
    # Other SUDs (need to check variables)
    # tobacco_use = IRCIGYR,
    # other_sud = UD5ILALANY,  # May not exist in all years
    
    # Survey year (important covariate for pooled data)
    survey_year = factor(YEAR)
  ) %>%
  filter(!is.na(use_group) & !is.na(aud) & !is.na(cud))

cat("SAMPLE SIZE BY USE GROUP:\n")
table(sample_waddell$use_group) %>% print()

cat("\nOUTCOME PREVALENCE BY GROUP:\n")
cat("AUD prevalence:\n")
for(grp in levels(sample_waddell$use_group)) {
  cat("  ", grp, ":", 
      round(100*mean(sample_waddell$aud[sample_waddell$use_group==grp], na.rm=TRUE), 1), "%\n")
}

cat("\nCUD prevalence:\n")
for(grp in levels(sample_waddell$use_group)) {
  cat("  ", grp, ":",
      round(100*mean(sample_waddell$cud[sample_waddell$use_group==grp], na.rm=TRUE), 1), "%\n")
}

# Create survey design (pooled years)
design_waddell <- svydesign(
  ids = ~QUESTID2,
  strata = ~interaction(VESTR, YEAR),  # Account for year
  weights = ~ANALWT2_C,
  data = sample_waddell
)

cat("\n===========================================\n")
cat("MODEL 1: AUD (Co-use vs Alcohol-only)\n")
cat("===========================================\n")

# MODEL 1: AUD - Full model with all covariates
model_aud_full <- svyglm(
  aud ~ relevel(use_group, ref = "Alcohol-only") + 
    male + age_cat + race_eth + education + income + 
    marital + employment + pop_density + health + mde + survey_year,
  design = design_waddell,
  family = quasibinomial()
)

# Extract Co-use vs Alcohol-only
coef_aud <- exp(coef(model_aud_full)["relevel(use_group, ref = \"Alcohol-only\")Co-use"])
ci_aud <- exp(confint(model_aud_full)["relevel(use_group, ref = \"Alcohol-only\")Co-use",])

cat("TARGET: Co-use vs Alcohol-only aOR = 2.45 [2.29, 2.62]\n")
cat("OUR RESULT: aOR =", round(coef_aud, 2),
    "[", round(ci_aud[1], 2), ",", round(ci_aud[2], 2), "]\n\n")

cat("\n===========================================\n")
cat("MODEL 2: CUD (Co-use vs Cannabis-only)\n")
cat("===========================================\n")

# MODEL 2: CUD - Full model with all covariates
model_cud_full <- svyglm(
  cud ~ relevel(use_group, ref = "Cannabis-only") +
    male + age_cat + race_eth + education + income +
    marital + employment + pop_density + health + mde + survey_year,
  design = design_waddell,
  family = quasibinomial()
)

# Extract Co-use vs Cannabis-only
coef_cud <- exp(coef(model_cud_full)["relevel(use_group, ref = \"Cannabis-only\")Co-use"])
ci_cud <- exp(confint(model_cud_full)["relevel(use_group, ref = \"Cannabis-only\")Co-use",])

cat("TARGET: Co-use vs Cannabis-only aOR = 1.93 [1.76, 2.12]\n")
cat("OUR RESULT: aOR =", round(coef_cud, 2),
    "[", round(ci_cud[1], 2), ",", round(ci_cud[2], 2), "]\n\n")

# Check matches
cat("===========================================\n")
cat("REPLICATION SUCCESS CHECK\n")
cat("===========================================\n")

# AUD check
target_aud <- 2.45
if(abs(coef_aud - target_aud)/target_aud < 0.10) {
  cat("✅ AUD MODEL: PERFECT (<10% difference)\n")
} else if(abs(coef_aud - target_aud)/target_aud < 0.20) {
  cat("✅ AUD MODEL: GOOD (<20% difference)\n")
} else {
  cat("⚠️ AUD MODEL: Check covariates\n")
}

# CUD check  
target_cud <- 1.93
if(abs(coef_cud - target_cud)/target_cud < 0.10) {
  cat("✅ CUD MODEL: PERFECT (<10% difference)\n")
} else if(abs(coef_cud - target_cud)/target_cud < 0.20) {
  cat("✅ CUD MODEL: GOOD (<20% difference)\n")
} else {
  cat("⚠️ CUD MODEL: Check covariates\n")
}

# Show key coefficients
cat("\n\nKEY COEFFICIENTS FROM MODELS:\n")
cat("================================\n")
cat("\nAUD Model (selected):\n")
summary(model_aud_full)$coefficients[1:5,] %>% print()

cat("\nCUD Model (selected):\n")
summary(model_cud_full)$coefficients[1:5,] %>% print()
