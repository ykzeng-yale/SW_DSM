################################################################################
# FINAL PRESENTATION: ALL 10 ANALYSES - COMPLETE VERIFIED RESULTS
################################################################################

cat('\n\n')
cat('═══════════════════════════════════════════════════════════════════════════\n')
cat('         FINAL COMPLETE RESULTS: ALL 10 ANALYSES\n')
cat('         All 5 Methods + Null Hypothesis Testing\n')
cat('═══════════════════════════════════════════════════════════════════════════\n\n')

# Helper function
present_analysis <- function(num, title, file, h0_text) {
  if(!file.exists(file)) {
    cat('Analysis', num, ':', title, '- FILE NOT FOUND\n\n')
    return()
  }
  
  load(file, envir = environment())
  
  # Get N
  n_val <- if(exists('data_complete', envir=environment())) nrow(get('data_complete', envir=environment()))
           else if(exists('data2', envir=environment())) nrow(get('data2', envir=environment()))
           else if(exists('d8', envir=environment())) nrow(get('d8', envir=environment()))
           else NA
  
  cat('───────────────────────────────────────────────────────────────────────────\n')
  cat('ANALYSIS', num, ':', title, '(N=', n_val, ')\n')
  cat('───────────────────────────────────────────────────────────────────────────\n')
  cat('H0:', h0_text, '\n\n')
  
  # Get results
  results_obj <- if(exists('results', envir=environment())) get('results', envir=environment())
                 else if(exists('results2', envir=environment())) get('results2', envir=environment())
                 else if(exists('results5', envir=environment())) get('results5', envir=environment())
                 else if(exists('results8', envir=environment())) get('results8', envir=environment())
                 else NULL
  
  if(is.null(results_obj)) {
    cat('Results not found in file\n\n')
    return()
  }
  
  cat('Method                     Estimate   95% CI            CI excludes 0?   Estimand\n')
  cat('────────────────────────────────────────────────────────────────────────────────\n')
  
  for(m in c('dsm','pgm','psm','ps_full','wdsm')) {
    if(m %in% names(results_obj)) {
      r <- results_obj[[m]]
      est <- as.numeric(r$estimate[1])
      ci_l <- as.numeric(r$ci[1])
      ci_u <- as.numeric(r$ci[2])
      
      # Check if CI excludes 0
      sig <- if(!is.na(ci_l) && !is.na(ci_u)) {
        if(ci_l > 0 || ci_u < 0) 'YES ✓' else 'NO'
      } else 'NA'
      
      estimand <- if(m %in% c('ps_full','wdsm')) 'Population' else 'Sample'
      method_name <- c(dsm='Unweighted DSM', pgm='Unweighted PGM', 
                       psm='Unweighted PSM', ps_full='Survey-Weighted PS Full',
                       wdsm='WDSM')[m]
      
      cat(sprintf('%-25s  %7.3f  [%7.3f,%7.3f]  %6s       %s\n',
                  method_name, est, ci_l, ci_u, sig, estimand))
    }
  }
  
  # Summary stats
  sample_avg_val <- if(exists('sample_avg', envir=environment())) get('sample_avg', envir=environment()) else NA
  pop_avg_val <- if(exists('pop_avg', envir=environment())) get('pop_avg', envir=environment()) else NA
  bias_pct_val <- if(exists('bias_pct', envir=environment())) get('bias_pct', envir=environment()) else NA
  
  cat('────────────────────────────────────────────────────────────────────────────────\n')
  if(!is.na(sample_avg_val) && !is.na(pop_avg_val)) {
    cat('Sample avg:', round(sample_avg_val,3), '| Pop avg:', round(pop_avg_val,3), 
        '| Bias:', sprintf('%+.1f%%', bias_pct_val), '\n')
  }
  cat('\n')
}

# Present all 10
present_analysis(1, 'BMI→HbA1c', 'PAPER1_LIN_2024_COMPLETE_RESULTS.rda', 
                 'Mean difference in HbA1c = 0')
present_analysis(2, 'Waist→Uric Acid', 'ANALYSIS_02_WAIST_URIC_FINAL.rda',
                 'Mean difference in uric acid = 0')
present_analysis(3, 'Obesity→SBP', 'ANALYSIS_03_OBESITY_SBP_COMPLETE.rda',
                 'Mean difference in SBP = 0')
present_analysis(4, 'MVPA→HbA1c', 'ANALYSIS_04_MVPA_HBA1C_COMPLETE.rda',
                 'Mean difference in HbA1c = 0')
present_analysis(5, 'Lead→Creatinine', 'ANALYSIS_05_LEAD_CREATININE_FINAL.rda',
                 'Mean difference in creatinine = 0')
present_analysis(6, 'Smoking→Trig', 'ANALYSIS_06_SMOKING_TRIGLYCERIDES_COMPLETE.rda',
                 'Mean difference in triglycerides = 0')
present_analysis(7, 'PA→SBP', 'ANALYSIS_07_PA_SBP_COMPLETE.rda',
                 'Mean difference in SBP = 0')
present_analysis(8, 'Obesity→ALT', 'ANALYSIS_08_OBESITY_ALT_COMPLETE.rda',
                 'Mean difference in ALT = 0')
present_analysis(9, 'Alcohol→HDL', 'ANALYSIS_09_ALCOHOL_HDL_COMPLETE.rda',
                 'Mean difference in HDL = 0')
present_analysis(10, 'Sleep→HbA1c', 'ANALYSIS_10_SLEEP_HBA1C_COMPLETE.rda',
                 'Mean difference in HbA1c = 0')

cat('═══════════════════════════════════════════════════════════════════════════\n')
cat('                    ALL 10 ANALYSES COMPLETE\n')
cat('═══════════════════════════════════════════════════════════════════════════\n')

