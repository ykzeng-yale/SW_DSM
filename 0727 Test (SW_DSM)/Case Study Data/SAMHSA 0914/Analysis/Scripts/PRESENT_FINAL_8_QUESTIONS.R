#!/usr/bin/env Rscript

q1 <- readRDS('Analysis/Results/q1_b200_final.rds')
q2 <- readRDS('Analysis/Results/q2_gender_marijuana_b200.rds')
q3 <- readRDS('Analysis/Results/q3_employment_alcohol_b200.rds')
q4 <- readRDS('Analysis/Results/q4_age_marijuana_b200.rds')
q5 <- readRDS('Analysis/Results/q5_education_alcohol_b200.rds')
q7 <- readRDS('Analysis/Results/q7_race_alcohol_b200.rds')
q10 <- readRDS('Analysis/Results/q10_hispanic_alcohol_b200.rds')
q11 <- readRDS('Analysis/Results/q11_gender_binge_b200.rds')

cat('\n================================================================\n')
cat('COMPLETE FINAL RESULTS: ALL 8 RESEARCH QUESTIONS\n')
cat('================================================================\n')
cat('Data: NSDUH 2023 | Bootstrap: B=200 | Sample: N=2,000 each\n')
cat('================================================================\n\n')

pq <- function(n, title, r) {
  cat('================================================================\n')
  cat(sprintf('Q%d: %s\n', n, title))
  cat('================================================================\n\n')
  cat('Method                   | Estimate |   SE   | 95% CI              | p-value\n')
  cat('-------------------------|----------|--------|---------------------|----------\n')
  
  for(i in 1:5) {
    nm <- c('WDSM (M=5, weighted)', 'DSM (M=1, unweighted)', 'PSM (M=1, unweighted)', 
            'PGM (M=1, unweighted)', 'PS Full (weighted)')[i]
    res <- r[[c('wdsm', 'dsm', 'psm', 'pgm', 'ps_full')[i]]]
    if(!is.na(res$estimate)) {
      p <- 2*(1-pnorm(abs(res$estimate/res$se)))
      pv <- ifelse(p<0.001, '<0.001', ifelse(p<0.01, '<0.01', ifelse(p<0.05, '<0.05', sprintf('%.3f', p))))
      cat(sprintf('%-24s | %8.2f | %6.2f | [%7.2f, %7.2f] | %s\n',
                  nm, res$estimate, res$se, res$ci_lower, res$ci_upper, pv))
    }
  }
  cat('\n')
}

pq(1, 'Gender → Alcohol Frequency (days/year)', q1)
pq(2, 'Gender → Marijuana Frequency (days/month)', q2)
pq(3, 'Employment → Alcohol Frequency (days/year)', q3)
pq(4, 'Age Group → Marijuana Frequency (days/month)', q4)
pq(5, 'Education → Alcohol Frequency (days/year)', q5)
pq(7, 'Race (Black vs White) → Alcohol (days/year)', q7)
pq(10, 'Race (Hispanic vs White) → Alcohol (days/year)', q10)
pq(11, 'Gender → Binge Drinking Frequency (days/month)', q11)

cat('================================================================\n')
cat('SUMMARY OF ALL FINDINGS\n')
cat('================================================================\n\n')

cat('HIGHLY SIGNIFICANT (p<0.001):\n')
cat('  ✓ Q3: Unemployed drink +15-19 days MORE/year\n')
cat('  ✓ Q5: College grads drink -13 to -25 days LESS/year\n')
cat('  ✓ Q2: Females use marijuana ~2 days LESS/month\n')
cat('  ✓ Q10: Hispanic drink +8-21 days MORE/year than White\n\n')

cat('SIGNIFICANT (p<0.05):\n')
cat('  ✓ Q7: Black adults drink +4-12 days MORE/year than White\n\n')

cat('NO SIGNIFICANT DIFFERENCE:\n')
cat('  • Q1: Gender → Alcohol frequency\n')
cat('  • Q4: Age → Marijuana frequency\n')
cat('  • Q11: Gender → Binge drinking frequency\n\n')

cat('================================================================\n')
cat('TOTAL: 8 Questions | 40 Analyses | 5 Significant Findings\n')
cat('================================================================\n')
