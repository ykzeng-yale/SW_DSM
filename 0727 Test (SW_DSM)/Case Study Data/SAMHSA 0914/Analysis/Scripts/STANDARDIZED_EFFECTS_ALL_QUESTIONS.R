#!/usr/bin/env Rscript

#' Compute standardized effects (Cohen's d) for all questions

library(tidyverse)

# Load all results
results_list <- list(
  q1 = readRDS('Analysis/Results/q1_b200_final.rds'),
  q2 = readRDS('Analysis/Results/q2_gender_marijuana_b200.rds'),
  q3 = readRDS('Analysis/Results/q3_employment_alcohol_b200.rds'),
  q4 = readRDS('Analysis/Results/q4_age_marijuana_b200.rds'),
  q5 = readRDS('Analysis/Results/q5_education_alcohol_b200.rds'),
  q7 = readRDS('Analysis/Results/q7_race_alcohol_b200.rds'),
  q10 = readRDS('Analysis/Results/q10_hispanic_alcohol_b200.rds'),
  q11 = readRDS('Analysis/Results/q11_gender_binge_b200.rds'),
  q12 = readRDS('Analysis/Results/q12_urban_alcohol_b200.rds'),
  q13 = readRDS('Analysis/Results/q13_income_marijuana_b200.rds')
)

# Load data to compute outcome SDs
load('Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata')
d <- filter(data, YEAR == 2023)

# Compute pooled SDs for each outcome type
sd_alcohol <- sd(d\$ALCDAYS[d\$ALCDAYS >= 1 & d\$ALCDAYS <= 365], na.rm=TRUE)
sd_marijuana <- sd(d\$MJDAY30A[d\$MJDAY30A >= 1 & d\$MJDAY30A <= 30], na.rm=TRUE)
sd_binge <- sd(d\$BNGDRMDAYS[d\$BNGDRMDAYS >= 1 & d\$BNGDRMDAYS <= 30], na.rm=TRUE)

cat('\n================================================================\n')
cat('OUTCOME STANDARD DEVIATIONS (for standardization)\n')
cat('================================================================\n')
cat('Alcohol days/year: SD =', round(sd_alcohol, 2), '\n')
cat('Marijuana days/month: SD =', round(sd_marijuana, 2), '\n')
cat('Binge days/month: SD =', round(sd_binge, 2), '\n\n')

cat('================================================================\n')
cat('COMPLETE RESULTS WITH STANDARDIZED EFFECTS\n')
cat('================================================================\n\n')

# Question details
questions <- list(
  list(num=1, title='Gender → Alcohol (days/year)', sd=sd_alcohol, sig=FALSE),
  list(num=2, title='Gender → Marijuana (days/month)', sd=sd_marijuana, sig=TRUE),
  list(num=3, title='Employment → Alcohol (days/year)', sd=sd_alcohol, sig=TRUE),
  list(num=4, title='Age → Marijuana (days/month)', sd=sd_marijuana, sig=FALSE),
  list(num=5, title='Education → Alcohol (days/year)', sd=sd_alcohol, sig=TRUE),
  list(num=7, title='Black vs White → Alcohol (days/year)', sd=sd_alcohol, sig=TRUE),
  list(num=10, title='Hispanic vs White → Alcohol (days/year)', sd=sd_alcohol, sig=TRUE),
  list(num=11, title='Gender → Binge (days/month)', sd=sd_binge, sig=FALSE),
  list(num=12, title='Urban vs Rural → Alcohol (days/year)', sd=sd_alcohol, sig=FALSE),
  list(num=13, title='Income → Marijuana (days/month)', sd=sd_marijuana, sig=FALSE)
)

for(q in questions) {
  res <- results_list[[paste0('q', q\$num)]]
  
  cat(sprintf('Q%d: %s %s\n', q\$num, q\$title, ifelse(q\$sig, '✅', '❌')))
  cat('Method         | Raw Est | Std Effect (d) | 95% CI (raw)        | CI covers 0?\n')
  cat('---------------|---------|----------------|---------------------|--------------\n')
  
  for(m in c('wdsm', 'dsm', 'psm', 'pgm', 'ps_full')) {
    r <- res[[m]]
    if(!is.na(r\$estimate)) {
      std_eff <- r\$estimate / q\$sd
      covers_zero <- r\$ci_lower <= 0 & r\$ci_upper >= 0
      cat(sprintf('%-14s | %7.2f | %14.3f | [%7.2f, %7.2f] | %s\n',
                  toupper(m), r\$estimate, std_eff, r\$ci_lower, r\$ci_upper,
                  ifelse(covers_zero, 'YES (NS)', 'NO (SIG)')))
    }
  }
  cat('\n')
}

cat('================================================================\n')
cat('INTERPRETATION GUIDE\n')
cat('================================================================\n')
cat('NULL HYPOTHESIS: Treatment effect = 0 days (no difference)\n')
cat('SIGNIFICANT: 95% CI does NOT include 0\n\n')

cat('STANDARDIZED EFFECT (Cohens d) INTERPRETATION:\n')
cat('  |d| < 0.20  = Negligible/Very small\n')
cat('  |d| = 0.20  = Small effect\n')
cat('  |d| = 0.50  = Medium effect\n')
cat('  |d| = 0.80+ = Large effect\n\n')

cat('CLINICAL vs STATISTICAL SIGNIFICANCE:\n')
cat('  - Raw estimates (days) = Clinical interpretation\n')
cat('  - Standardized effects = Cross-outcome comparison\n')
cat('  - Both are important for complete understanding\n')
cat('================================================================\n')
" 2>&1
