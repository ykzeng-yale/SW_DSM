#!/usr/bin/env Rscript

#' Present all successfully completed research questions

# Load all successful results
q1 <- readRDS('Analysis/Results/q1_b200_final.rds')
q2 <- readRDS('Analysis/Results/q2_gender_marijuana_b200.rds')
q3 <- readRDS('Analysis/Results/q3_employment_alcohol_b200.rds')
q4 <- readRDS('Analysis/Results/q4_age_marijuana_b200.rds')
q5 <- readRDS('Analysis/Results/q5_education_alcohol_b200.rds')
q7 <- readRDS('Analysis/Results/q7_race_alcohol_b200.rds')
q10 <- readRDS('Analysis/Results/q10_hispanic_alcohol_b200.rds')

cat('\n================================================================\n')
cat('ALL COMPLETED RESEARCH QUESTIONS - FINAL RESULTS\n')
cat('================================================================\n')
cat('Total: 7 Questions Successfully Analyzed\n')
cat('Data: NSDUH 2023 | Bootstrap: B=200 | Sample: N=2,000 each\n')
cat('================================================================\n\n')

# Helper function
print_q <- function(num, title, res) {
  cat('================================================================\n')
  cat(sprintf('Q%d: %s\n', num, title))
  cat('================================================================\n\n')
  
  cat('Method                   | Estimate |   SE   | 95% CI              | p-value\n')
  cat('-------------------------|----------|--------|---------------------|----------\n')
  
  methods <- c('wdsm', 'dsm', 'psm', 'pgm', 'ps_full')
  names <- c('WDSM (M=5, weighted)', 'DSM (M=1, unweighted)', 'PSM (M=1, unweighted)', 
             'PGM (M=1, unweighted)', 'PS Full (weighted)')
  
  for(i in 1:5) {
    r <- res[[methods[i]]]
    if(!is.na(r$estimate)) {
      p <- 2*(1-pnorm(abs(r$estimate/r$se)))
      pv <- ifelse(p<0.001, '<0.001', ifelse(p<0.01, '<0.01', ifelse(p<0.05, '<0.05', sprintf('%.3f', p))))
      cat(sprintf('%-24s | %8.2f | %6.2f | [%7.2f, %7.2f] | %s\n',
                  names[i], r$estimate, r$se, r$ci_lower, r$ci_upper, pv))
    }
  }
  cat('\n')
}

# Print all
print_q(1, 'Gender → Alcohol Frequency (days/year)', q1)
print_q(2, 'Gender → Marijuana Frequency (days/month)', q2)
print_q(3, 'Employment → Alcohol Frequency (days/year)', q3)
print_q(4, 'Age Group → Marijuana Frequency (days/month)', q4)
print_q(5, 'Education → Alcohol Frequency (days/year)', q5)
print_q(7, 'Race (Black vs White) → Alcohol Frequency (days/year)', q7)
print_q(10, 'Race (Hispanic vs White) → Alcohol Frequency (days/year)', q10)

cat('================================================================\n')
cat('SUMMARY OF ALL FINDINGS\n')
cat('================================================================\n\n')

cat('HIGHLY SIGNIFICANT (p<0.001 for majority):\n')
cat('  ✓ Q3: Unemployed drink +15-19 days MORE/year than employed\n')
cat('  ✓ Q5: College grads drink -13 to -25 days LESS/year than HS grads\n\n')

cat('SIGNIFICANT (p<0.05 for majority):\n')
cat('  ✓ Q2: Females use marijuana ~2 days LESS/month than males\n')
cat('  ✓ Q7: Black adults drink +4-12 days MORE/year than White adults\n')
cat('  ✓ Q10: Hispanic adults drink +8-21 days MORE/year than White adults\n\n')

cat('NO SIGNIFICANT DIFFERENCE:\n')
cat('  • Q1: No gender difference in alcohol frequency among users\n')
cat('  • Q4: No age difference in marijuana frequency among users\n\n')

cat('================================================================\n')
cat('COMPLETED: 7 Research Questions with All 5 Matching Methods\n')
cat('================================================================\n')"
