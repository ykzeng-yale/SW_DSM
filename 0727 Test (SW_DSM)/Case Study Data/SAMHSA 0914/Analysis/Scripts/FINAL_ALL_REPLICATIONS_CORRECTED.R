#!/usr/bin/env Rscript

#' =============================================================================
#' FINAL CORRECTED REPLICATIONS - All 4 Remaining Publications
#' Based on search results from Gemini
#' Date: October 22, 2025
#' =============================================================================

cat("\n================================================================\n")
cat("FINAL CORRECTED REPLICATIONS\n")
cat("================================================================\n\n")

library(tidyverse)
library(survey)

# =============================================================================
# REPLICATION 1: Waddell 2021 - CORRECTED (Cannabis-only as reference!)
# =============================================================================

cat("\n### REPLICATION 1: Waddell 2021 (CORRECTED) ###\n\n")

load("Data & Doc/NSDUH_2023.Rdata")

adults <- data %>%
  filter(CATAGE >= 2) %>%
  mutate(
    alcohol_use = ifelse(ALCYR == 1, 1, 0),
    cannabis_use = ifelse(MRJYR == 1, 1, 0),
    use_group = case_when(
      alcohol_use == 1 & cannabis_use == 1 ~ "Co-use",
      alcohol_use == 1 & cannabis_use == 0 ~ "Alcohol-only",
      alcohol_use == 0 & cannabis_use == 1 ~ "Cannabis-only",
      TRUE ~ "Neither"
    ),
    aud = IRPYUD5ALC,
    cud = IRPYUD5MRJ
  ) %>%
  filter(!is.na(use_group))

design <- svydesign(ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
                    data = adults, nest = TRUE)

# AUD model (Alcohol-only as reference)
adults_aud <- adults %>% 
  mutate(use_group = relevel(factor(use_group), ref = "Alcohol-only"))
design_aud <- svydesign(ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
                        data = adults_aud, nest = TRUE)

m_aud <- svyglm(aud ~ use_group, design_aud, family = quasibinomial())
or_aud_couse <- exp(coef(m_aud)["use_groupCo-use"])
ci_aud_couse <- exp(confint(m_aud)["use_groupCo-use",])

# CUD model (Cannabis-only as reference) - CORRECTED!
adults_cud <- adults %>% 
  mutate(use_group = relevel(factor(use_group), ref = "Cannabis-only"))
design_cud <- svydesign(ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
                        data = adults_cud, nest = TRUE)

m_cud <- svyglm(cud ~ use_group, design_cud, family = quasibinomial())
or_cud_couse <- exp(coef(m_cud)["use_groupCo-use"])
ci_cud_couse <- exp(confint(m_cud)["use_groupCo-use",])

cat("WADDELL 2021 RESULTS (CORRECTED):\n\n")
cat("                    Target              Our Result          Match?\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat(sprintf("AUD (Co vs Alc):  2.45 (2.37-2.53)   %.2f (%.2f-%.2f)   ", 
            or_aud_couse, ci_aud_couse[1], ci_aud_couse[2]))
if(abs(or_aud_couse - 2.45) < 0.3) cat("✅\n") else cat("⚠️\n")

cat(sprintf("CUD (Co vs Can):  1.93 (1.84-2.02)   %.2f (%.2f-%.2f)   ", 
            or_cud_couse, ci_cud_couse[1], ci_cud_couse[2]))
if(abs(or_cud_couse - 1.93) < 0.3) cat("✅\n\n") else cat("⚠️\n\n")

# =============================================================================
# REPLICATION 2: Moore 2025 - Using 2021 data, adults 18+ only
# =============================================================================

cat("\n### REPLICATION 2: Moore & Kapadia 2025 ###\n\n")

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")
data_2021 <- data %>% filter(YEAR == 2021)

# Sample: ADULTS 18+ only (not adolescents) with past-year SUD
sud_adults <- data_2021 %>%
  filter(
    CATAGE >= 2,  # Adults 18+ ONLY
    UD5ILALANY == 1  # Past-year SUD
  ) %>%
  mutate(
    female = ifelse(IRSEX == 2, 1, 0),
    sti = ifelse(STDANYYR == 1, 1, 0),
    spd = ifelse(SPDPSTYR == 1, 1, 0),  # Serious psych distress
    financial = ifelse(COFINANC == 1, 1, 0)
  )

cat("Sample: Adults 18+ with SUD (2021)\n")
cat("  Our N:", nrow(sud_adults), "\n")
cat("  Target N: 4,157\n")
cat("  Match:", round(100*nrow(sud_adults)/4157, 1), "%\n\n")

# Run regressions
design_moore <- svydesign(ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C1,
                          data = sud_adults, nest = TRUE)

# STI model
m_sti <- svyglm(sti ~ female, design_moore, family = quasibinomial())
or_sti <- exp(coef(m_sti)["female"])
ci_sti <- exp(confint(m_sti)["female",])

# SPD model
m_spd <- svyglm(spd ~ female, design_moore, family = quasibinomial())
or_spd <- exp(coef(m_spd)["female"])
ci_spd <- exp(confint(m_spd)["female",])

cat("MOORE 2025 RESULTS:\n\n")
cat("                    Target              Our Result          Match?\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat(sprintf("STI:              2.00 (1.25-3.20)   %.2f (%.2f-%.2f)   ",
            or_sti, ci_sti[1], ci_sti[2]))
if(abs(or_sti - 2.00) < 0.5) cat("✅\n") else cat("⚠️\n")

cat(sprintf("Psych Distress:   2.06 (1.72-2.47)   %.2f (%.2f-%.2f)   ",
            or_spd, ci_spd[1], ci_spd[2]))
if(abs(or_spd - 2.06) < 0.5) cat("✅\n\n") else cat("⚠️\n\n")

# =============================================================================
# REPLICATION 3: White 2023 - CORRECTED (CIGTYPE variable)
# =============================================================================

cat("\n### REPLICATION 3: White 2023 (CORRECTED) ###\n\n")

load("Data & Doc/NSDUH_2023.Rdata")

# Check if CIGTYPE exists in 2023
if("CIGTYPE" %in% names(data)) {
  cat("✅ CIGTYPE found in 2023 data!\n\n")
  
  smokers <- data %>%
    filter(CATAGE >= 2, CIGMON == 1, !is.na(CIGTYPE)) %>%
    mutate(
      menthol = CIGTYPE,  # Use CIGTYPE as identified in search
      ami = AMIPY,
      race = factor(case_when(
        NEWRACE2 == 1 ~ "NH White",
        NEWRACE2 == 2 ~ "NH Black",
        NEWRACE2 == 7 ~ "Hispanic",
        TRUE ~ "Other"
      ))
    )
  
  design_white <- svydesign(ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
                            data = smokers, nest = TRUE)
  
  m_overall <- svyglm(ami ~ menthol, design_white, family = quasibinomial())
  or_overall <- exp(coef(m_overall)["menthol"])
  ci_overall <- exp(confint(m_overall)["menthol",])
  
  cat("WHITE 2023 RESULTS (CORRECTED):\n\n")
  cat("                    Target              Our Result          Match?\n")
  cat("─────────────────────────────────────────────────────────────────\n")
  cat(sprintf("Overall Menth→AMI: 1.12 (1.06-1.19)   %.2f (%.2f-%.2f)   ",
              or_overall, ci_overall[1], ci_overall[2]))
  if(abs(or_overall - 1.12) < 0.1) cat("✅\n\n") else cat("⚠️\n\n")
  
} else {
  cat("❌ CIGTYPE not in 2023 data\n")
  cat("White used 2012-2018 data where CIGTYPE existed\n")
  cat("2023 uses CIGMENTH30 (different coding)\n")
  cat("Cannot exactly replicate without 2012-2018 data\n\n")
}

# =============================================================================
# REPLICATION 4: Ali 2022 - Using TXYRRECV
# =============================================================================

cat("\n### REPLICATION 4: Ali 2022 ###\n\n")

load("Data & Doc/NSDUH_2023.Rdata")

# Sample: Adults 18+ with CUD (2023 as proxy for 2019)
cud_sample <- data %>%
  filter(CATAGE >= 2, IRPYUD5MRJ == 1) %>%
  mutate(
    has_mde = IRAMDEYR,
    treatment = ifelse(!is.na(TXYRRECV) & TXYRRECV == 1, 1, 0)
  )

cat("Sample: Adults with CUD\n")
cat("  Our N:", nrow(cud_sample), "\n")
cat("  Target: 3,425 (NSDUH 2019)\n")
cat("  Match:", round(100*nrow(cud_sample)/3425, 1), "%\n\n")

if("TXYRRECV" %in% names(data)) {
  design_ali <- svydesign(ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
                          data = cud_sample, nest = TRUE)
  
  m_tx <- svyglm(treatment ~ has_mde, design_ali, family = quasibinomial())
  or_tx <- exp(coef(m_tx)["has_mde"])
  ci_tx <- exp(confint(m_tx)["has_mde",])
  
  cat("ALI 2022 RESULTS:\n\n")
  cat("                    Target              Our Result          Match?\n")
  cat("─────────────────────────────────────────────────────────────────\n")
  cat(sprintf("MDE→Treatment:    1.45 (1.07-1.97)   %.2f (%.2f-%.2f)   ",
              or_tx, ci_tx[1], ci_tx[2]))
  if(abs(or_tx - 1.45) < 0.3) cat("✅\n\n") else cat("⚠️\n\n")
} else {
  cat("❌ TXYRRECV not found in 2023 data\n")
  cat("Need to check if variable name changed\n\n")
}

cat("================================================================\n")
cat("ALL REPLICATIONS COMPLETE\n")
cat("================================================================\n\n")

