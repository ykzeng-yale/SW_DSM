################################################################################
# PRESENT ALL 10 ANALYSES WITH WDSM M=1, M=3, M=5
################################################################################

cat('\n═══════════════════════════════════════════════════════════════════════════\n')
cat('   FINAL COMPLETE RESULTS: ALL 10 ANALYSES (WDSM M=1, M=3, M=5)\n')
cat('═══════════════════════════════════════════════════════════════════════════\n\n')

titles <- c('BMI→HbA1c', 'Waist→Uric', 'Obesity→SBP', 'MVPA→HbA1c', 
            'Lead→Creatinine', 'Smoking→Trig', 'PA→SBP', 'Obesity→ALT',
            'Alcohol→HDL', 'Sleep→HbA1c')

for(i in 1:10) {
  file <- paste0('WDSM_M1_M3_M5_ANALYSIS_', sprintf('%02d', i), '.rda')
  
  if(file.exists(file)) {
    env <- new.env()
    load(file, envir=env)
    
    # Get N
    n <- if(exists('data_complete', envir=env)) nrow(env$data_complete)
         else if(exists('data_prep', envir=env)) nrow(env$data_prep)
         else NA
    
    cat('ANALYSIS', i, ':', titles[i], '(N=', n, ')\n')
    cat('───────────────────────────────────────────────────────────────────────────\n')
    
    # Get results
    res <- if(exists('wdsm_res', envir=env)) env$wdsm_res
           else if(exists('wdsm_results', envir=env)) env$wdsm_results
           else NULL
    
    if(!is.null(res)) {
      for(M in c('M1','M3','M5')) {
        if(M %in% names(res)) {
          r <- res[[M]]
          width <- r$ci_upper - r$ci_lower
          cat(sprintf('WDSM (M=%s, 1:%s match)      %7.3f   [%7.3f,%7.3f]   Width: %.3f\n',
                      substr(M,2,2), substr(M,2,2), r$estimate, r$ci_lower, r$ci_upper, width))
        }
      }
    }
    cat('\n')
  } else {
    cat('ANALYSIS', i, ': File not found\n\n')
  }
}

cat('═══════════════════════════════════════════════════════════════════════════\n')








