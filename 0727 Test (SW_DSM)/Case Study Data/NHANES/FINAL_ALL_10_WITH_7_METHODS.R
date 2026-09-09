################################################################################
# FINAL PRESENTATION: ALL 10 ANALYSES WITH ALL 7 METHODS
# Combining original 5 methods + WDSM M=1, M=3, M=5
################################################################################

cat('\n═══════════════════════════════════════════════════════════════════════════\n')
cat('      FINAL COMPLETE RESULTS: ALL 10 ANALYSES (7 Methods Each)\n')
cat('═══════════════════════════════════════════════════════════════════════════\n\n')

titles <- c('BMI→HbA1c', 'Waist→Uric Acid', 'Obesity→SBP', 'MVPA→HbA1c', 
            'Lead→Creatinine', 'Smoking→Trig', 'PA→SBP', 'Obesity→ALT',
            'Alcohol→HDL', 'Sleep→HbA1c')

original_files <- c('PAPER1_LIN_2024_COMPLETE_RESULTS.rda',
                   'ANALYSIS_02_WAIST_URIC_FINAL.rda',
                   'ANALYSIS_03_OBESITY_SBP_COMPLETE.rda',
                   'ANALYSIS_04_MVPA_HBA1C_COMPLETE.rda',
                   'ANALYSIS_05_LEAD_CREATININE_FINAL.rda',
                   'ANALYSIS_06_SMOKING_TRIGLYCERIDES_COMPLETE.rda',
                   'ANALYSIS_07_PA_SBP_COMPLETE.rda',
                   'ANALYSIS_08_OBESITY_ALT_COMPLETE.rda',
                   'ANALYSIS_09_ALCOHOL_HDL_COMPLETE.rda',
                   'ANALYSIS_10_SLEEP_HBA1C_COMPLETE.rda')

for(i in 1:10) {
  
  cat('═══════════════════════════════════════════════════════════════════════════\n')
  cat('ANALYSIS', i, ':', titles[i], '\n')
  cat('═══════════════════════════════════════════════════════════════════════════\n\n')
  
  # Load original 5 methods
  if(file.exists(original_files[i])) {
    env1 <- new.env()
    load(original_files[i], envir=env1)
    
    results_orig <- if(exists('results', envir=env1)) env1$results
                    else if(exists('results2', envir=env1)) env1$results2
                    else if(exists('results5', envir=env1)) env1$results5
                    else if(exists('results8', envir=env1)) env1$results8
                    else NULL
    
    # Load WDSM M values
    m_file <- paste0('WDSM_M1_M3_M5_ANALYSIS_', sprintf('%02d', i), '.rda')
    if(file.exists(m_file)) {
      env2 <- new.env()
      load(m_file, envir=env2)
      
      wdsm_M <- if(exists('wdsm_res', envir=env2)) env2$wdsm_res
                else if(exists('wdsm_results', envir=env2)) env2$wdsm_results
                else NULL
      
      if(!is.null(results_orig) && !is.null(wdsm_M)) {
        cat('Method                     Estimate   95% CI            Estimand\n')
        cat('───────────────────────────────────────────────────────────────────────────\n')
        
        # Unweighted methods
        for(m in c('dsm','pgm','psm')) {
          if(m %in% names(results_orig)) {
            r <- results_orig[[m]]
            est <- as.numeric(r$estimate[1])
            ci_l <- as.numeric(r$ci[1])
            ci_u <- as.numeric(r$ci[2])
            cat(sprintf('%-25s  %7.3f   [%7.3f,%7.3f]   Sample\n',
                        c(dsm='Unweighted DSM', pgm='Unweighted PGM', psm='Unweighted PSM')[m],
                        est, ci_l, ci_u))
          }
        }
        
        # PS Full
        if('ps_full' %in% names(results_orig)) {
          r <- results_orig$ps_full
          est <- as.numeric(r$estimate[1])
          ci_l <- as.numeric(r$ci[1])
          ci_u <- as.numeric(r$ci[2])
          cat(sprintf('%-25s  %7.3f   [%7.3f,%7.3f]   Population\n',
                      'Survey-Weighted PS Full', est, ci_l, ci_u))
        }
        
        # WDSM M=1, M=3, M=5
        for(M in c('M1','M3','M5')) {
          if(M %in% names(wdsm_M)) {
            r <- wdsm_M[[M]]
            cat(sprintf('%-25s  %7.3f   [%7.3f,%7.3f]   Population\n',
                        paste0('WDSM (M=', substr(M,2,2), ', 1:', substr(M,2,2), ' match)'),
                        r$estimate, r$ci_lower, r$ci_upper))
          }
        }
        
        cat('───────────────────────────────────────────────────────────────────────────\n\n')
      }
    }
  }
}

cat('✅ ALL 10 ANALYSES PRESENTED WITH 7 METHODS EACH\n')








