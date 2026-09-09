################################################################################
# FINAL SUMMARY: ALL COMPLETE ANALYSES
################################################################################

cat('\n═══════════════════════════════════════════════════════════════════════════\n')
cat('       FINAL COMPREHENSIVE RESULTS: ALL COMPLETED ANALYSES\n')
cat('═══════════════════════════════════════════════════════════════════════════\n\n')

cat('Analysis                   N        Sample    Pop      Bias     Sig\n')
cat('───────────────────────────────────────────────────────────────────────────\n')
cat(' 1. BMI→HbA1c           3,481      0.174    0.161    +8.4%    5/5 ✓\n')
cat(' 2. Waist→Uric         13,967      0.257    0.197   +30.0%    3/5\n')
cat(' 3. Obesity→SBP        14,021      2.49     3.19    -22.0%    5/5 ✓\n')
cat(' 4. MVPA→HbA1c         12,164     -0.028   -0.031   -10.0%    2/5\n')
cat(' 5. Lead→Creatinine     5,876     -2.38    -1.05   +127%     0/5\n')
cat(' 6. Smoking→Trig       13,415     17.17    17.18     0.0%    5/5 ✓\n')
cat(' 7. PA→SBP             [check]      TBD      TBD      TBD     TBD\n')
cat(' 8. Obesity→ALT         8,937      2.69     3.02    -11.0%    4/5\n')
cat(' 9. Alcohol→HDL        [check]      TBD      TBD      TBD     TBD\n')
cat('10. Sleep→HbA1c        [check]      TBD      TBD      TBD     TBD\n')
cat('───────────────────────────────────────────────────────────────────────────\n\n')

cat('STATUS: 8 analyses CONFIRMED complete (1-6, 8)\n')
cat('        2-3 analyses may be complete (7, 9, 10) - checking files...\n\n')

# Check which files exist
files <- c('ANALYSIS_07_PA_SBP_COMPLETE.rda',
           'ANALYSIS_09_ALCOHOL_HDL_COMPLETE.rda',
           'ANALYSIS_10_SLEEP_HBA1C_COMPLETE.rda')

for(f in files) {
  if(file.exists(f)) {
    cat('✅', f, 'EXISTS\n')
  } else {
    cat('❌', f, 'MISSING\n')
  }
}

cat('\n═══════════════════════════════════════════════════════════════════════════\n')

