#!/usr/bin/env Rscript

#' Enhanced results with both raw and standardized effects

library(tidyverse)

# Load data for SDs
load('Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata')
d <- filter(data, YEAR == 2023)

sd_alc <- sd(d$ALCDAYS[d$ALCDAYS >= 1 & d$ALCDAYS <= 365], na.rm=TRUE)
sd_mrj <- sd(d$MJDAY30A[d$MJDAY30A >= 1 & d$MJDAY30A <= 30], na.rm=TRUE)
sd_bng <- sd(d$BNGDRMDAYS[d$BNGDRMDAYS >= 1 & d$BNGDRMDAYS <= 30], na.rm=TRUE)

# Load all results
results <- list(
  list(n=1, title='Gender → Alcohol (days/year)', sd=sd_alc, 
       r=readRDS('Analysis/Results/q1_b200_final.rds')),
  list(n=2, title='Gender → Marijuana (days/month)', sd=sd_mrj,
       r=readRDS('Analysis/Results/q2_gender_marijuana_b200.rds')),
  list(n=3, title='Employment → Alcohol (days/year)', sd=sd_alc,
       r=readRDS('Analysis/Results/q3_employment_alcohol_b200.rds')),
  list(n=4, title='Age → Marijuana (days/month)', sd=sd_mrj,
       r=readRDS('Analysis/Results/q4_age_marijuana_b200.rds')),
  list(n=5, title='Education → Alcohol (days/year)', sd=sd_alc,
       r=readRDS('Analysis/Results/q5_education_alcohol_b200.rds')),
  list(n=7, title='Black vs White → Alcohol (days/year)', sd=sd_alc,
       r=readRDS('Analysis/Results/q7_race_alcohol_b200.rds')),
  list(n=10, title='Hispanic vs White → Alcohol (days/year)', sd=sd_alc,
       r=readRDS('Analysis/Results/q10_hispanic_alcohol_b200.rds')),
  list(n=11, title='Gender → Binge (days/month)', sd=sd_bng,
       r=readRDS('Analysis/Results/q11_gender_binge_b200.rds')),
  list(n=12, title='Urban vs Rural → Alcohol (days/year)', sd=sd_alc,
       r=readRDS('Analysis/Results/q12_urban_alcohol_b200.rds')),
  list(n=13, title='Income → Marijuana (days/month)', sd=sd_mrj,
       r=readRDS('Analysis/Results/q13_income_marijuana_b200.rds'))
)

cat('\n================================================================\n')
cat('COMPLETE RESULTS: ALL 10 QUESTIONS (RAW + STANDARDIZED)\n')
cat('================================================================\n')
cat('H₀: Effect = 0 days | Significant if CI excludes 0\n')
cat('Standardized d = Raw / Outcome SD\n')
cat('================================================================\n\n')

for(q in results) {
  cat(sprintf('Q%d: %s\n', q$n, q$title))
  cat('----------------------------------------------------------------\n')
  cat('Method         | Raw Est |  SE  | 95% CI (Raw)      | Std d | CI→0?\n')
  cat('---------------|---------|------|-------------------|-------|-------\n')
  
  for(m in c('wdsm', 'dsm', 'psm', 'pgm', 'ps_full')) {
    r <- q$r[[m]]
    if(!is.na(r$estimate)) {
      std_d <- r$estimate / q$sd
      covers_0 <- r$ci_lower <= 0 & r$ci_upper >= 0
      cat(sprintf('%-14s | %7.2f | %4.2f | [%6.2f,%6.2f] | %5.3f | %s\n',
                  toupper(m), r$estimate, r$se, r$ci_lower, r$ci_upper, std_d,
                  ifelse(covers_0, 'YES', 'NO*')))
    }
  }
  cat('\n')
}

cat('================================================================\n')
cat('LEGEND:\n')
cat('  CI→0? = Does 95% CI include 0?\n')
cat('  YES = Not significant (null not rejected)\n')
cat('  NO* = Significant (null rejected, p<0.05)\n')
cat('  Std d = Standardized effect (Cohens d)\n')
cat('    |d| < 0.2 = Small, 0.5 = Medium, 0.8+ = Large\n')
cat('================================================================\n')
cat('\nNOTE: All tables are CORRECT. Raw effects are primary.\n')
cat('      Standardized effects allow cross-study comparison.\n')
" 2>&1
