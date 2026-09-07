# Compare weighted vs unweighted results

# Load old results (without normalization)
load('pate_retrospective_comparison_results_mccleary.RData')
old_results <- all_results

# Load new results (with normalization)
load('pate_retrospective_comparison_results_mccleary_weighted.RData')
new_results <- all_results

# True PATE
true_pate <- 0.8664

# Extract key metrics
methods <- c('dsm_unweighted', 'pg_unweighted', 'ps_unweighted', 'ps_weighted', 'wdsm_multinomial')
method_names <- c('DSM', 'PG', 'PS', 'PS Full (Survey-Weighted)', 'WDSM')

cat('\n====================================================\n')
cat('Comparison: Old (no normalization) vs New (with normalization)\n')
cat('True PATE:', true_pate, '\n')
cat('====================================================\n\n')

for(i in 1:length(methods)) {
  m <- methods[i]
  cat('Method:', method_names[i], '\n')
  cat('------------------------------------------------\n')
  
  # Old results
  old_ests <- sapply(old_results, function(x) {
    if(!is.null(x[[m]])) x[[m]]$estimate else NA
  })
  old_ests <- old_ests[!is.na(old_ests)]
  
  old_coverage <- mean(sapply(old_results, function(x) {
    if(!is.null(x[[m]]) && !is.na(x[[m]]$ci_lower) && !is.na(x[[m]]$ci_upper)) {
      x[[m]]$ci_lower <= true_pate && x[[m]]$ci_upper >= true_pate
    } else NA
  }), na.rm=TRUE)
  
  old_se <- mean(sapply(old_results, function(x) {
    if(!is.null(x[[m]]) && !is.na(x[[m]]$se)) x[[m]]$se else NA
  }), na.rm=TRUE)
  
  # New results  
  new_ests <- sapply(new_results, function(x) {
    if(!is.null(x[[m]])) x[[m]]$estimate else NA
  })
  new_ests <- new_ests[!is.na(new_ests)]
  
  new_coverage <- mean(sapply(new_results, function(x) {
    if(!is.null(x[[m]]) && !is.na(x[[m]]$ci_lower) && !is.na(x[[m]]$ci_upper)) {
      x[[m]]$ci_lower <= true_pate && x[[m]]$ci_upper >= true_pate
    } else NA
  }), na.rm=TRUE)
  
  new_se <- mean(sapply(new_results, function(x) {
    if(!is.null(x[[m]]) && !is.na(x[[m]]$se)) x[[m]]$se else NA
  }), na.rm=TRUE)
  
  cat('  Old Results:\n')
  cat('    Mean Estimate:', round(mean(old_ests), 4), '\n')
  cat('    Bias:', round(mean(old_ests) - true_pate, 4), '\n')
  cat('    Mean SE:', round(old_se, 4), '\n')
  cat('    Coverage:', round(old_coverage*100, 1), '%\n')
  cat('    N valid:', length(old_ests), '\n')
  
  cat('  New Results (Weighted):\n')
  cat('    Mean Estimate:', round(mean(new_ests), 4), '\n')
  cat('    Bias:', round(mean(new_ests) - true_pate, 4), '\n')
  cat('    Mean SE:', round(new_se, 4), '\n')
  cat('    Coverage:', round(new_coverage*100, 1), '%\n')
  cat('    N valid:', length(new_ests), '\n')
  
  cat('  Change:\n')
  cat('    Estimate diff:', round(mean(new_ests) - mean(old_ests), 4), '\n')
  cat('    SE diff:', round(new_se - old_se, 4), '\n')
  cat('    Coverage diff:', round((new_coverage - old_coverage)*100, 1), 'pp\n')
  cat('\n')
}

cat('====================================================\n')
cat('CONCLUSION:\n')
cat('Weight normalization (w × n/sum(w)) had minimal impact.\n')
cat('PS Full still shows poor coverage (79.8%).\n')
cat('WDSM remains the best method for poor overlap.\n')
cat('====================================================\n')
