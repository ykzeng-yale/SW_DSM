# FIX MOORE REPLICATION - CORRECT DIRECTION

library(dplyr)
library(survey)

cat("\nMOORE & KAPADIA 2025 - CORRECTED\n")
cat("=================================\n")

load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Their sample: Adults with SUD
moore_data <- data %>%
  filter(CATAGE >= 2) %>%  # Adults 18+
  filter(UD5ILALANY == 1) %>%  # Past-year SUD
  mutate(
    # OUTCOMES
    sti = ifelse(STDANYYR == 1, 1, 0),
    spd = ifelse(SPDPSTYR == 1, 1, 0),
    
    # EXPOSURE - MALE as the exposure (not female)
    male = ifelse(IRSEX == 1, 1, 0),
    
    # COVARIATES
    age_group = factor(CATAGE),
    race_ethnicity = factor(NEWRACE2),
    education = factor(EDUHIGHCAT),
    income = factor(POVERTY3),
    marital = factor(IRMARIT)
  ) %>%
  filter(!is.na(sti) & !is.na(spd))

cat("Sample: N =", nrow(moore_data), "adults with past-year SUD\n")
cat("Moore's N = 4,157 (they likely used 2021-2022 only)\n\n")

wt_var <- ifelse("ANALWT2_C1" %in% names(data), "ANALWT2_C1", "ANALWT2_C")

design_moore <- svydesign(
  ids = ~QUESTID2,
  strata = ~VESTR_C,
  weights = as.formula(paste0("~", wt_var)),
  data = moore_data,
  nest = TRUE
)

# CORRECT MODELS - MALE as exposure
model_sti <- svyglm(
  sti ~ male + age_group + race_ethnicity + education + income + marital,
  design = design_moore,
  family = quasibinomial()
)

model_spd <- svyglm(
  spd ~ male + age_group + race_ethnicity + education + income + marital,
  design = design_moore,
  family = quasibinomial()
)

or_sti <- round(exp(coef(model_sti)["male"]), 2)
or_spd <- round(exp(coef(model_spd)["male"]), 2)
ci_sti <- round(exp(confint(model_sti)["male",]), 2)
ci_spd <- round(exp(confint(model_spd)["male",]), 2)

cat("CORRECTED RESULTS (Male vs Female):\n")
cat("STI: aOR =", or_sti, "(", ci_sti[1], "-", ci_sti[2], ")\n")
cat("SPD: aOR =", or_spd, "(", ci_spd[1], "-", ci_spd[2], ")\n\n")

cat("Moore et al. reported:\n")
cat("STI: aOR = 2.00 (1.60-2.40)\n")
cat("SPD: aOR = 2.06 (1.70-2.42)\n\n")

# Check match
sti_match <- abs(or_sti - 2.00)/2.00 * 100
spd_match <- abs(or_spd - 2.06)/2.06 * 100

cat("Match quality:\n")
cat("STI:", ifelse(sti_match < 15, "GOOD ✅", ifelse(sti_match < 25, "FAIR ⚠️", "POOR ❌")),
    "(", round(sti_match, 1), "% difference)\n")
cat("SPD:", ifelse(spd_match < 15, "GOOD ✅", ifelse(spd_match < 25, "FAIR ⚠️", "POOR ❌")),
    "(", round(spd_match, 1), "% difference)\n")
