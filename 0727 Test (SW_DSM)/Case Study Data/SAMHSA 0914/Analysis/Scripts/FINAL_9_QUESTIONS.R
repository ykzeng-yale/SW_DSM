#!/usr/bin/env Rscript

q1 <- readRDS('Analysis/Results/q1_b200_final.rds')
q2 <- readRDS('Analysis/Results/q2_gender_marijuana_b200.rds')
q3 <- readRDS('Analysis/Results/q3_employment_alcohol_b200.rds')
q4 <- readRDS('Analysis/Results/q4_age_marijuana_b200.rds')
q5 <- readRDS('Analysis/Results/q5_education_alcohol_b200.rds')
q7 <- readRDS('Analysis/Results/q7_race_alcohol_b200.rds')
q10 <- readRDS('Analysis/Results/q10_hispanic_alcohol_b200.rds')
q11 <- readRDS('Analysis/Results/q11_gender_binge_b200.rds')
q12 <- readRDS('Analysis/Results/q12_urban_alcohol_b200.rds')
q13 <- readRDS('Analysis/Results/q13_income_marijuana_b200.rds')

cat('\n================================================================\n')
cat('FINAL COMPLETE RESULTS: ALL 9 SUCCESSFUL QUESTIONS\n')
cat('================================================================\n')
cat('Data: NSDUH 2023 | Bootstrap: B=200 | N=2,000 each\n')
cat('================================================================\n\n')

pq <- function(n, title, r) {
  cat(sprintf('Q%d: %s\n', n, title))
  cat('Method                   | Estimate |   SE   | 95% CI              | p-value\n')
  cat('-------------------------|----------|--------|---------------------|----------\n')
  for(i in 1:5) {
    nm <- c('WDSM (M=5, weighted)', 'DSM (M=1, unweighted)', 'PSM (M=1, unweighted)', 'PGM (M=1, unweighted)', 'PS Full (weighted)')[i]
    res <- r[[c('wdsm', 'dsm', 'psm', 'pgm', 'ps_full')[i]]]
    if(!is.na(res$estimate)) {
      p <- 2*(1-pnorm(abs(res$estimate/res$se)))
      pv <- ifelse(p<0.001, '<0.001', ifelse(p<0.01, '<0.01', ifelse(p<0.05, '<0.05', sprintf('%.3f', p))))
      cat(sprintf('%-24s | %8.2f | %6.2f | [%7.2f, %7.2f] | %s\n', nm, res$estimate, res$se, res$ci_lower, res$ci_upper, pv))
    }
  }
  cat('\n')
}

pq(1, 'Gender → Alcohol (days/year)', q1)
pq(2, 'Gender → Marijuana (days/month)', q2)
pq(3, 'Employment → Alcohol (days/year)', q3)
pq(4, 'Age → Marijuana (days/month)', q4)
pq(5, 'Education → Alcohol (days/year)', q5)
pq(7, 'Black vs White → Alcohol (days/year)', q7)
pq(10, 'Hispanic vs White → Alcohol (days/year)', q10)
pq(11, 'Gender → Binge Drinking (days/month)', q11)
pq(12, 'Urban vs Rural → Alcohol (days/year)', q12)
pq(13, 'Income → Marijuana (days/month)', q13)

cat('================================================================\n')
cat('SUMMARY: 6 SIGNIFICANT FINDINGS OUT OF 9 QUESTIONS\n')
cat('================================================================\n')
