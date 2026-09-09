#!/usr/bin/env Rscript

#' Complete White et al. (2023) Replication
#' Using CIGMENTH30 variable found in NSDUH 2023

library(tidyverse)
library(survey)

cat("\n=== WHITE ET AL. (2023) REPLICATION ===\n\n")

load("Data & Doc/NSDUH_2023.Rdata")

# Sample: Past-month smokers
smokers <- data %>%
  filter(CATAGE >= 2, CIGMON == 1) %>%
  mutate(
    menthol = CIGMENTH30,
    ami = AMIPY,
    smi = SMIPY,
    male = ifelse(IRSEX == 1, 1, 0),
    race = factor(case_when(
      NEWRACE2 == 1 ~ "NH White",
      NEWRACE2 == 2 ~ "NH Black",
      NEWRACE2 == 7 ~ "Hispanic",
      TRUE ~ "Other"
    ), levels = c("NH White", "NH Black", "Hispanic", "Other")),
    age = AGE3,
    education = EDUHIGHCAT,
    poverty = POVERTY3
  ) %>%
  filter(!is.na(menthol))

cat("Sample: N =", nrow(smokers), "\n")
cat("Target: N = 76,211\n\n")

design <- svydesign(
  ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
  data = smokers, nest = TRUE
)

# Overall model
m_overall <- svyglm(
  ami ~ menthol + male + factor(age) + race + factor(education) + factor(poverty),
  design = design, family = quasibinomial()
)

or_overall <- exp(coef(m_overall)["menthol"])
ci_overall <- exp(confint(m_overall)["menthol",])

cat("OVERALL: Menthol → AMI\n")
cat(sprintf("  Target: aOR = 1.12 (1.06-1.19)\n"))
cat(sprintf("  Ours:   aOR = %.2f (%.2f-%.2f)\n\n", or_overall, ci_overall[1], ci_overall[2]))

# Black smokers only
black_smokers <- smokers %>% filter(race == "NH Black")
design_black <- svydesign(
  ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
  data = black_smokers, nest = TRUE
)

m_black <- svyglm(
  ami ~ menthol + male + factor(age) + factor(education) + factor(poverty),
  design = design_black, family = quasibinomial()
)

or_black <- exp(coef(m_black)["menthol"])
ci_black <- exp(confint(m_black)["menthol",])

cat("BLACK SMOKERS: Menthol → AMI\n")
cat(sprintf("  Target: aOR = 0.74 (0.65-0.84) PROTECTIVE\n"))
cat(sprintf("  Ours:   aOR = %.2f (%.2f-%.2f)\n\n", or_black, ci_black[1], ci_black[2]))

saveRDS(list(overall = or_overall, black = or_black), 
        "Analysis/Results/white_2023_complete.rds")

cat("WHITE 2023 COMPLETE!\n\n")

