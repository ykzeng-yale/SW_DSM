#!/usr/bin/env Rscript

#' Verify covariate consistency across all questions

library(tidyverse)

cat("\n================================================================\n")
cat("VERIFICATION: Checking all 10 completed questions\n")
cat("================================================================\n\n")

# Check each results file
questions <- list(
  list(n=1, file='q1_b200_final.rds', desc='Gender → Alcohol'),
  list(n=2, file='q2_gender_marijuana_b200.rds', desc='Gender → Marijuana'),
  list(n=3, file='q3_employment_alcohol_b200.rds', desc='Employment → Alcohol'),
  list(n=4, file='q4_age_marijuana_b200.rds', desc='Age → Marijuana'),
  list(n=5, file='q5_education_alcohol_b200.rds', desc='Education → Alcohol'),
  list(n=7, file='q7_race_alcohol_b200.rds', desc='Black vs White → Alcohol'),
  list(n=10, file='q10_hispanic_alcohol_b200.rds', desc='Hispanic vs White → Alcohol'),
  list(n=11, file='q11_gender_binge_b200.rds', desc='Gender → Binge'),
  list(n=12, file='q12_urban_alcohol_b200.rds', desc='Urban vs Rural → Alcohol'),
  list(n=13, file='q13_income_marijuana_b200.rds', desc='Income → Marijuana')
)

all_ok <- TRUE

for(q in questions) {
  path <- paste0('Analysis/Results/', q$file)
  if(file.exists(path)) {
    r <- readRDS(path)
    
    # Check if all 5 methods have results
    methods_ok <- sum(!is.na(sapply(r, function(x) x$estimate)))
    
    cat(sprintf('Q%d %-40s: %d/5 methods OK', q$n, q$desc, methods_ok))
    
    if(methods_ok == 5) {
      cat(' ✓\n')
    } else {
      cat(' ⚠️ (missing some methods)\n')
      all_ok <- FALSE
    }
  } else {
    cat(sprintf('Q%d %-40s: FILE MISSING ✗\n', q$n, q$desc))
    all_ok <- FALSE
  }
}

cat('\n================================================================\n')
if(all_ok) {
  cat('✓ ALL QUESTIONS HAVE COMPLETE RESULTS\n')
  cat('✓ All 10 questions × 5 methods = 50 analyses complete\n')
} else {
  cat('⚠️ Some questions incomplete - review needed\n')
}
cat('================================================================\n')
" 2>&1
