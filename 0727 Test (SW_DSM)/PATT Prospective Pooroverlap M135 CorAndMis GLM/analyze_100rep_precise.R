# Precise Analysis of 100 Replicate Results with 2 Decimal Places
library(tidyverse)
library(knitr)

# Load all results
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
all_results <- list()
all_metrics <- list()

cat("\n", rep("=", 80), "\n")
cat("COMPREHENSIVE ANALYSIS - 100 REPLICATES WITH 1:1 MATCHING\n")
cat(rep("=", 80), "\n\n")

for (scenario in scenarios) {
  file_name <- paste0("comprehensive_patt_comparison_", scenario, 
                     "_M5_100rep_Pooroverlap_FINAL_results.RData")
  if (file.exists(file_name)) {
    load(file_name)
    
    # Convert method_results to data frame format
    n_reps <- length(method_results$DSM$estimates)
    
    # Create data frame from method_results
    results_df <- data.frame(
      rep = 1:n_reps,
      
      # DSM results
      est_dsm = method_results$DSM$estimates,
      se_dsm = method_results$DSM$ses,
      valid_dsm = !is.na(method_results$DSM$estimates),
      
      # PG results
      est_pg = method_results$PG$estimates,
      se_pg = method_results$PG$ses,
      valid_pg = !is.na(method_results$PG$estimates),
      
      # PS results (reference method for efficiency)
      est_ps = method_results$PS$estimates,
      se_ps = method_results$PS$ses,
      valid_ps = !is.na(method_results$PS$estimates),
      
      # PS Full results
      est_ps_full = method_results$PS_Full$estimates,
      se_ps_full = method_results$PS_Full$ses,
      valid_ps_full = !is.na(method_results$PS_Full$estimates),
      
      # WDSM results
      est_wdsm = method_results$WDSM$estimates,
      se_wdsm = method_results$WDSM$ses,
      valid_wdsm = !is.na(method_results$WDSM$estimates)
    )
    
    # Calculate bias, coverage, etc.
    z_crit <- qnorm(0.975)
    
    results_df <- results_df %>%
      mutate(
        # DSM metrics
        bias_dsm = est_dsm - true_patt,
        rel_bias_dsm = (est_dsm - true_patt) / true_patt,
        ci_lower_dsm = est_dsm - z_crit * se_dsm,
        ci_upper_dsm = est_dsm + z_crit * se_dsm,
        coverage_dsm = (ci_lower_dsm <= true_patt) & (ci_upper_dsm >= true_patt),
        
        # PG metrics
        bias_pg = est_pg - true_patt,
        rel_bias_pg = (est_pg - true_patt) / true_patt,
        ci_lower_pg = est_pg - z_crit * se_pg,
        ci_upper_pg = est_pg + z_crit * se_pg,
        coverage_pg = (ci_lower_pg <= true_patt) & (ci_upper_pg >= true_patt),
        
        # PS metrics
        bias_ps = est_ps - true_patt,
        rel_bias_ps = (est_ps - true_patt) / true_patt,
        ci_lower_ps = est_ps - z_crit * se_ps,
        ci_upper_ps = est_ps + z_crit * se_ps,
        coverage_ps = (ci_lower_ps <= true_patt) & (ci_upper_ps >= true_patt),
        
        # PS Full metrics
        bias_ps_full = est_ps_full - true_patt,
        rel_bias_ps_full = (est_ps_full - true_patt) / true_patt,
        ci_lower_ps_full = est_ps_full - z_crit * se_ps_full,
        ci_upper_ps_full = est_ps_full + z_crit * se_ps_full,
        coverage_ps_full = (ci_lower_ps_full <= true_patt) & (ci_upper_ps_full >= true_patt),
        
        # WDSM metrics (using Wald CI)
        bias_wdsm = est_wdsm - true_patt,
        rel_bias_wdsm = (est_wdsm - true_patt) / true_patt,
        ci_lower_wdsm = est_wdsm - z_crit * se_wdsm,
        ci_upper_wdsm = est_wdsm + z_crit * se_wdsm,
        coverage_wdsm = (ci_lower_wdsm <= true_patt) & (ci_upper_wdsm >= true_patt)
      )
    
    all_results[[scenario]] <- results_df
    
    # Calculate performance metrics
    metrics <- results_df %>%
      summarise(
        # DSM (Unweighted)
        dsm_mean_est = mean(est_dsm, na.rm = TRUE),
        dsm_bias = mean(bias_dsm, na.rm = TRUE),
        dsm_rel_bias = mean(rel_bias_dsm, na.rm = TRUE) * 100,  # Convert to percentage
        dsm_coverage = mean(coverage_dsm, na.rm = TRUE) * 100,  # Convert to percentage
        dsm_emp_var = var(est_dsm, na.rm = TRUE),  # Monte Carlo variance
        dsm_emp_se = sd(est_dsm, na.rm = TRUE),
        dsm_avg_se = mean(se_dsm, na.rm = TRUE),
        dsm_se_ratio = mean(se_dsm, na.rm = TRUE) / sd(est_dsm, na.rm = TRUE),
        
        # PG (Unweighted) 
        pg_mean_est = mean(est_pg, na.rm = TRUE),
        pg_bias = mean(bias_pg, na.rm = TRUE),
        pg_rel_bias = mean(rel_bias_pg, na.rm = TRUE) * 100,
        pg_coverage = mean(coverage_pg, na.rm = TRUE) * 100,
        pg_emp_var = var(est_pg, na.rm = TRUE),
        pg_emp_se = sd(est_pg, na.rm = TRUE),
        pg_avg_se = mean(se_pg, na.rm = TRUE),
        pg_se_ratio = mean(se_pg, na.rm = TRUE) / sd(est_pg, na.rm = TRUE),
        
        # PS (Unweighted) - REFERENCE METHOD
        ps_mean_est = mean(est_ps, na.rm = TRUE),
        ps_bias = mean(bias_ps, na.rm = TRUE),
        ps_rel_bias = mean(rel_bias_ps, na.rm = TRUE) * 100,
        ps_coverage = mean(coverage_ps, na.rm = TRUE) * 100,
        ps_emp_var = var(est_ps, na.rm = TRUE),
        ps_emp_se = sd(est_ps, na.rm = TRUE),
        ps_avg_se = mean(se_ps, na.rm = TRUE),
        ps_se_ratio = mean(se_ps, na.rm = TRUE) / sd(est_ps, na.rm = TRUE),
        
        # PS Full (Survey-Weighted)
        ps_full_mean_est = mean(est_ps_full, na.rm = TRUE),
        ps_full_bias = mean(bias_ps_full, na.rm = TRUE),
        ps_full_rel_bias = mean(rel_bias_ps_full, na.rm = TRUE) * 100,
        ps_full_coverage = mean(coverage_ps_full, na.rm = TRUE) * 100,
        ps_full_emp_var = var(est_ps_full, na.rm = TRUE),
        ps_full_emp_se = sd(est_ps_full, na.rm = TRUE),
        ps_full_avg_se = mean(se_ps_full, na.rm = TRUE),
        ps_full_se_ratio = mean(se_ps_full, na.rm = TRUE) / sd(est_ps_full, na.rm = TRUE),
        
        # WDSM
        wdsm_mean_est = mean(est_wdsm, na.rm = TRUE),
        wdsm_bias = mean(bias_wdsm, na.rm = TRUE),
        wdsm_rel_bias = mean(rel_bias_wdsm, na.rm = TRUE) * 100,
        wdsm_coverage = mean(coverage_wdsm, na.rm = TRUE) * 100,
        wdsm_emp_var = var(est_wdsm, na.rm = TRUE),
        wdsm_emp_se = sd(est_wdsm, na.rm = TRUE),
        wdsm_avg_se = mean(se_wdsm, na.rm = TRUE),
        wdsm_se_ratio = mean(se_wdsm, na.rm = TRUE) / sd(est_wdsm, na.rm = TRUE)
      )
    
    # Calculate relative efficiency (PS variance / method variance)
    metrics <- metrics %>%
      mutate(
        dsm_rel_eff = ps_emp_var / dsm_emp_var,
        pg_rel_eff = ps_emp_var / pg_emp_var,
        ps_rel_eff = 1.00,  # PS is the reference
        ps_full_rel_eff = ps_emp_var / ps_full_emp_var,
        wdsm_rel_eff = ps_emp_var / wdsm_emp_var
      )
    
    all_metrics[[scenario]] <- metrics
    
    cat("\n", scenario, "loaded - Valid replicates:", sum(results_df$valid_dsm), "\n")
  }
}

# Create final results table with 2 decimal places
cat("\n", rep("=", 100), "\n")
cat("FINAL RESULTS TABLE - 100 REPLICATES (True PATT = 1.182)\n")
cat(rep("=", 100), "\n\n")

# Create comprehensive comparison table
results_table <- data.frame()

for (scenario in names(all_metrics)) {
  metrics <- all_metrics[[scenario]]
  
  # DSM row
  results_table <- rbind(results_table,
    data.frame(
      Scenario = scenario,
      Method = "DSM",
      `Rel_Bias_Pct` = sprintf("%.2f", metrics$dsm_rel_bias),
      `Coverage_Pct` = sprintf("%.2f", metrics$dsm_coverage),
      `Rel_Efficiency` = sprintf("%.2f", metrics$dsm_rel_eff),
      `Emp_SE` = sprintf("%.4f", metrics$dsm_emp_se),
      `MC_Variance` = sprintf("%.6f", metrics$dsm_emp_var)
    )
  )
  
  # PG row
  results_table <- rbind(results_table,
    data.frame(
      Scenario = scenario,
      Method = "PG",
      `Rel_Bias_Pct` = sprintf("%.2f", metrics$pg_rel_bias),
      `Coverage_Pct` = sprintf("%.2f", metrics$pg_coverage),
      `Rel_Efficiency` = sprintf("%.2f", metrics$pg_rel_eff),
      `Emp_SE` = sprintf("%.4f", metrics$pg_emp_se),
      `MC_Variance` = sprintf("%.6f", metrics$pg_emp_var)
    )
  )
  
  # PS row (reference)
  results_table <- rbind(results_table,
    data.frame(
      Scenario = scenario,
      Method = "PS (Ref)",
      `Rel_Bias_Pct` = sprintf("%.2f", metrics$ps_rel_bias),
      `Coverage_Pct` = sprintf("%.2f", metrics$ps_coverage),
      `Rel_Efficiency` = "1.00",
      `Emp_SE` = sprintf("%.4f", metrics$ps_emp_se),
      `MC_Variance` = sprintf("%.6f", metrics$ps_emp_var)
    )
  )
  
  # PS Full row
  results_table <- rbind(results_table,
    data.frame(
      Scenario = scenario,
      Method = "PS Full",
      `Rel_Bias_Pct` = sprintf("%.2f", metrics$ps_full_rel_bias),
      `Coverage_Pct` = sprintf("%.2f", metrics$ps_full_coverage),
      `Rel_Efficiency` = sprintf("%.2f", metrics$ps_full_rel_eff),
      `Emp_SE` = sprintf("%.4f", metrics$ps_full_emp_se),
      `MC_Variance` = sprintf("%.6f", metrics$ps_full_emp_var)
    )
  )
  
  # WDSM row
  results_table <- rbind(results_table,
    data.frame(
      Scenario = scenario,
      Method = "WDSM",
      `Rel_Bias_Pct` = sprintf("%.2f", metrics$wdsm_rel_bias),
      `Coverage_Pct` = sprintf("%.2f", metrics$wdsm_coverage),
      `Rel_Efficiency` = sprintf("%.2f", metrics$wdsm_rel_eff),
      `Emp_SE` = sprintf("%.4f", metrics$wdsm_emp_se),
      `MC_Variance` = sprintf("%.6f", metrics$wdsm_emp_var)
    )
  )
}

# Print the table
print(kable(results_table, format = "simple", 
            col.names = c("Scenario", "Method", "Rel Bias (%)", "Coverage (%)", 
                         "Rel Efficiency", "Emp SE", "MC Variance")))

# Summary table by method across scenarios
cat("\n", rep("=", 80), "\n")
cat("SUMMARY BY METHOD (2 Decimal Places)\n")
cat(rep("=", 80), "\n\n")

methods <- c("DSM", "PG", "PS", "PS Full", "WDSM")
summary_table <- data.frame()

for (method in methods) {
  for (scenario in names(all_metrics)) {
    metrics <- all_metrics[[scenario]]
    
    method_lower <- tolower(gsub(" ", "_", method))
    if (method == "PS") method_lower <- "ps"
    if (method == "PS Full") method_lower <- "ps_full"
    
    rel_bias <- metrics[[paste0(method_lower, "_rel_bias")]]
    coverage <- metrics[[paste0(method_lower, "_coverage")]]
    rel_eff <- ifelse(method == "PS", 1.00, metrics[[paste0(method_lower, "_rel_eff")]])
    
    summary_table <- rbind(summary_table,
      data.frame(
        Method = method,
        Scenario = scenario,
        `Rel_Bias` = sprintf("%.2f", rel_bias),
        `Coverage` = sprintf("%.2f", coverage),
        `Rel_Eff` = sprintf("%.2f", rel_eff)
      )
    )
  }
}

# Reshape to wide format for better readability
library(tidyr)
summary_wide <- summary_table %>%
  pivot_wider(names_from = Scenario, 
              values_from = c(Rel_Bias, Coverage, Rel_Eff),
              names_sep = "_")

print(summary_wide)

cat("\n", rep("=", 80), "\n")
cat("KEY METRICS EXPLANATION:\n")
cat("- Relative Bias (%): 100 × (Mean Estimate - True PATT) / True PATT\n")
cat("- Coverage (%): Percentage of 95% Wald CIs containing true PATT\n")
cat("- Relative Efficiency: Var(PS) / Var(Method) [>1 = more efficient than PS]\n")
cat("- MC Variance: Monte Carlo variance from 100 replicates\n")
cat("- All results based on 1:1 matching for unweighted methods, M=5 for WDSM\n")
cat(rep("=", 80), "\n")
