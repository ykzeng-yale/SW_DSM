#!/usr/bin/env Rscript

# Load all results
q1 <- readRDS('Analysis/Results/q1_b200_final.rds')
q2 <- readRDS('Analysis/Results/q2_gender_marijuana_b200.rds')
q3 <- readRDS('Analysis/Results/q3_employment_alcohol_b200.rds')
q4 <- readRDS('Analysis/Results/q4_age_marijuana_b200.rds')
q5 <- readRDS('Analysis/Results/q5_education_alcohol_b200.rds')

cat('\n================================================================\n')
cat('ALL 5 RESEARCH QUESTIONS - COMPLETE FINAL RESULTS\n')
cat('================================================================\n')
cat('Data: NSDUH 2023\n')
cat('Methods: WDSM, DSM, PSM, PGM, PS Full\n')
cat('Bootstrap: B = 200 iterations\n')
cat('Sample: N = 2,000 per question (stratified)\n')
cat('================================================================\n\n')

# Function to format and print table
print_q <- function(num, title, res, sample_info) {
  cat('================================================================\n')
  cat(sprintf('Q%d: %s\n', num, title))
  cat('================================================================\n')
  cat(sample_info, '\n\n')
  
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

# Print all questions
print_q(1, 'Gender → Alcohol Use Frequency',
        q1, 'Outcome: Days of alcohol use/year | Treatment: Female vs. Male')

print_q(2, 'Gender → Marijuana Use Frequency',
        q2, 'Outcome: Days of marijuana use/month | Treatment: Female vs. Male')

print_q(3, 'Employment → Alcohol Use Frequency',
        q3, 'Outcome: Days of alcohol use/year | Treatment: Unemployed vs. Full-time')

print_q(4, 'Age Group → Marijuana Use Frequency',
        q4, 'Outcome: Days of marijuana use/month | Treatment: Age 18-25 vs. 26+')

print_q(5, 'Education → Alcohol Use Frequency',
        q5, 'Outcome: Days of alcohol use/year | Treatment: College grad vs. HS grad')

cat('================================================================\n')
cat('SUMMARY OF FINDINGS\n')
cat('================================================================\n\n')

cat('SIGNIFICANT FINDINGS (p<0.05 for majority of methods):\n')
cat('  ✓ Q2: Females use marijuana ~2 days LESS per month than males\n')
cat('  ✓ Q3: Unemployed drink ~15-19 days MORE per year than employed\n')
cat('  ✓ Q5: College grads drink ~13-25 days LESS per year than HS grads\n\n')

cat('NO SIGNIFICANT FINDINGS:\n')
cat('  • Q1: No gender difference in alcohol frequency among users\n')
cat('  • Q4: No age difference in marijuana frequency among users\n\n')

cat('================================================================\n')
cat('METHODOLOGICAL NOTES\n')
cat('================================================================\n')
cat('• All methods use SAME covariates within each question\n')
cat('• Weighted methods (WDSM, PS Full) provide population inference\n')
cat('• Unweighted methods (DSM, PSM, PGM) provide sample inference\n')
cat('• Bootstrap B=200 provides robust confidence intervals\n')
cat('• All analyses properly adjust for confounding\n')
cat('================================================================\n')
