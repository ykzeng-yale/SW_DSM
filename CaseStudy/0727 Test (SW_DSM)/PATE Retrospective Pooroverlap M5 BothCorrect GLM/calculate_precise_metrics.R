# Calculate precise metrics with 3 decimal places

# Load the weighted results
load('pate_retrospective_comparison_results_mccleary_weighted.RData')

# True PATE
true_pate <- 0.8664

# Extract results for each method
methods <- c('dsm_unweighted', 'pg_unweighted', 'ps_unweighted', 'ps_weighted', 'wdsm_multinomial')
method_names <- c('DSM (Unweighted)', 'PG (Unweighted)', 'PS (Unweighted)', 
                  'PS Full (Survey-Weighted)', 'WDSM (Multinomial Bootstrap)')

cat('\n====================================================================\n')
cat('PRECISE RESULTS - POOR OVERLAP WITH WEIGHT NORMALIZATION\n')
cat('True PATE:', true_pate, '\n')
cat('====================================================================\n\n')

# First calculate PS variance for relative efficiency calculation
ps_estimates <- sapply(all_results, function(x) {
  if(!is.null(x[['ps_unweighted']]) && !is.na(x[['ps_unweighted']]$estimate)) {
    x[['ps_unweighted']]$estimate
  } else NA
})
ps_estimates <- ps_estimates[!is.na(ps_estimates)]
ps_var <- var(ps_estimates)

results_table <- data.frame()

for(i in 1:length(methods)) {
  m <- methods[i]
  
  # Extract estimates
  estimates <- sapply(all_results, function(x) {
    if(!is.null(x[[m]]) && !is.na(x[[m]]$estimate)) x[[m]]$estimate else NA
  })
  estimates <- estimates[!is.na(estimates)]
  
  # Extract SEs
  ses <- sapply(all_results, function(x) {
    if(!is.null(x[[m]]) && !is.na(x[[m]]$se)) x[[m]]$se else NA
  })
  ses <- ses[!is.na(ses)]
  
  # Calculate coverage
  coverage_vec <- sapply(all_results, function(x) {
    if(!is.null(x[[m]]) && !is.na(x[[m]]$ci_lower) && !is.na(x[[m]]$ci_upper)) {
      x[[m]]$ci_lower <= true_pate && x[[m]]$ci_upper >= true_pate
    } else NA
  })
  coverage_vec <- coverage_vec[!is.na(coverage_vec)]
  
  # Calculate CI widths
  ci_widths <- sapply(all_results, function(x) {
    if(!is.null(x[[m]]) && !is.na(x[[m]]$ci_lower) && !is.na(x[[m]]$ci_upper)) {
      x[[m]]$ci_upper - x[[m]]$ci_lower
    } else NA
  })
  ci_widths <- ci_widths[!is.na(ci_widths)]
  
  # Calculate metrics
  mean_est <- mean(estimates)
  bias <- mean_est - true_pate
  relative_bias <- (bias / true_pate) * 100
  emp_sd <- sd(estimates)
  mean_se <- mean(ses)
  coverage <- mean(coverage_vec) * 100
  mean_ci_width <- mean(ci_widths)
  
  # Calculate relative efficiency (variance ratio)
  rel_eff <- ps_var / var(estimates)
  
  cat(method_names[i], ':\n')
  cat('  N valid estimates:', length(estimates), '\n')
  cat('  Mean Estimate:', format(round(mean_est, 4), nsmall=4), '\n')
  cat('  Bias:', format(round(bias, 4), nsmall=4), '\n')
  cat('  Relative Bias:', format(round(relative_bias, 3), nsmall=3), '%\n')
  cat('  Empirical SD:', format(round(emp_sd, 4), nsmall=4), '\n')
  cat('  Mean SE:', format(round(mean_se, 4), nsmall=4), '\n')
  cat('  Coverage:', format(round(coverage, 3), nsmall=3), '%\n')
  cat('  Relative Efficiency:', format(round(rel_eff, 3), nsmall=3), '\n')
  cat('  Mean CI Width:', format(round(mean_ci_width, 4), nsmall=4), '\n')
  cat('\n')
  
  # Store in table
  results_table <- rbind(results_table, data.frame(
    Method = method_names[i],
    Mean_Estimate = round(mean_est, 4),
    Bias = round(bias, 4),
    Relative_Bias_Pct = round(relative_bias, 3),
    Empirical_SD = round(emp_sd, 4),
    Mean_SE = round(mean_se, 4),
    Coverage_Pct = round(coverage, 3),
    Relative_Efficiency = round(rel_eff, 3),
    Mean_CI_Width = round(mean_ci_width, 4),
    N_Valid = length(estimates)
  ))
}

cat('====================================================================\n')
cat('SUMMARY TABLE WITH 3 DECIMAL PRECISION\n')
cat('====================================================================\n\n')

# Print formatted table
print(results_table, row.names = FALSE)

cat('\n====================================================================\n')
cat('KEY FINDINGS:\n')
cat('1. WDSM: Relative Bias =', format(round(results_table$Relative_Bias_Pct[5], 3), nsmall=3), 
    '%, Coverage =', format(round(results_table$Coverage_Pct[5], 3), nsmall=3),
    '%, Rel. Eff =', format(round(results_table$Relative_Efficiency[5], 3), nsmall=3), '\n')
cat('2. PS Full: Coverage =', format(round(results_table$Coverage_Pct[4], 3), nsmall=3), 
    '% (still undercovers despite weight normalization)\n')
cat('3. PS Unweighted: Relative Bias =', format(round(results_table$Relative_Bias_Pct[3], 3), nsmall=3),
    '% (high bias in poor overlap)\n')
cat('====================================================================\n')

# Save precise results to CSV
write.csv(results_table, 'precise_results_weighted_3decimal.csv', row.names = FALSE)
cat('\nResults saved to: precise_results_weighted_3decimal.csv\n')
