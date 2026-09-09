# Analyze Results from 1000 Replicate Simulations with Relative Efficiency
library(tidyverse)
library(knitr)

# Load all results
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
all_results <- list()

for (scenario in scenarios) {
  file_name <- paste0("comprehensive_patt_comparison_", scenario, 
                     "_M5_1000rep_Pooroverlap_FINAL_results.RData")
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
        
        # WDSM metrics (using Wald CI, not percentile)
        bias_wdsm = est_wdsm - true_patt,
        rel_bias_wdsm = (est_wdsm - true_patt) / true_patt,
        ci_lower_wdsm = est_wdsm - z_crit * se_wdsm,
        ci_upper_wdsm = est_wdsm + z_crit * se_wdsm,
        coverage_wdsm = (ci_lower_wdsm <= true_patt) & (ci_upper_wdsm >= true_patt)
      )
    
    all_results[[scenario]] <- results_df
    cat("\n", scenario, "loaded - Replicates:", nrow(results_df), "\n")
  }
}

# Function to summarize results with relative efficiency
summarize_results <- function(results, scenario_name) {
  cat("\n", rep("=", 60), "\n")
  cat("SCENARIO:", scenario_name, "\n")
  cat(rep("=", 60), "\n")
  cat("True PATT:", true_patt, "\n")
  
  # Check validity
  validity_summary <- results %>%
    summarise(
      DSM = sum(valid_dsm, na.rm = TRUE),
      PG = sum(valid_pg, na.rm = TRUE),
      PS = sum(valid_ps, na.rm = TRUE),
      PS_Full = sum(valid_ps_full, na.rm = TRUE),
      WDSM = sum(valid_wdsm, na.rm = TRUE)
    )
  
  cat("\n📊 VALIDITY (out of", nrow(results), "replicates):\n")
  print(validity_summary)
  
  # Calculate performance metrics
  metrics <- results %>%
    summarise(
      # DSM (Unweighted)
      dsm_bias = mean(bias_dsm, na.rm = TRUE),
      dsm_rel_bias = mean(rel_bias_dsm, na.rm = TRUE),
      dsm_coverage = mean(coverage_dsm, na.rm = TRUE),
      dsm_emp_se = sd(est_dsm, na.rm = TRUE),
      dsm_avg_se = mean(se_dsm, na.rm = TRUE),
      dsm_se_ratio = mean(se_dsm, na.rm = TRUE) / sd(est_dsm, na.rm = TRUE),
      
      # PG (Unweighted) 
      pg_bias = mean(bias_pg, na.rm = TRUE),
      pg_rel_bias = mean(rel_bias_pg, na.rm = TRUE),
      pg_coverage = mean(coverage_pg, na.rm = TRUE),
      pg_emp_se = sd(est_pg, na.rm = TRUE),
      pg_avg_se = mean(se_pg, na.rm = TRUE),
      pg_se_ratio = mean(se_pg, na.rm = TRUE) / sd(est_pg, na.rm = TRUE),
      
      # PS (Unweighted) - REFERENCE METHOD
      ps_bias = mean(bias_ps, na.rm = TRUE),
      ps_rel_bias = mean(rel_bias_ps, na.rm = TRUE),
      ps_coverage = mean(coverage_ps, na.rm = TRUE),
      ps_emp_se = sd(est_ps, na.rm = TRUE),
      ps_avg_se = mean(se_ps, na.rm = TRUE),
      ps_se_ratio = mean(se_ps, na.rm = TRUE) / sd(est_ps, na.rm = TRUE),
      
      # PS Full (Survey-Weighted)
      ps_full_bias = mean(bias_ps_full, na.rm = TRUE),
      ps_full_rel_bias = mean(rel_bias_ps_full, na.rm = TRUE),
      ps_full_coverage = mean(coverage_ps_full, na.rm = TRUE),
      ps_full_emp_se = sd(est_ps_full, na.rm = TRUE),
      ps_full_avg_se = mean(se_ps_full, na.rm = TRUE),
      ps_full_se_ratio = mean(se_ps_full, na.rm = TRUE) / sd(est_ps_full, na.rm = TRUE),
      
      # WDSM
      wdsm_bias = mean(bias_wdsm, na.rm = TRUE),
      wdsm_rel_bias = mean(rel_bias_wdsm, na.rm = TRUE),
      wdsm_coverage = mean(coverage_wdsm, na.rm = TRUE),
      wdsm_emp_se = sd(est_wdsm, na.rm = TRUE),
      wdsm_avg_se = mean(se_wdsm, na.rm = TRUE),
      wdsm_se_ratio = mean(se_wdsm, na.rm = TRUE) / sd(est_wdsm, na.rm = TRUE)
    )
  
  # Calculate relative efficiency (variance ratio) compared to PS
  # Relative efficiency = Var(PS) / Var(method) = (empirical_SE_PS)^2 / (empirical_SE_method)^2
  metrics <- metrics %>%
    mutate(
      dsm_rel_eff = (ps_emp_se^2) / (dsm_emp_se^2),
      pg_rel_eff = (ps_emp_se^2) / (pg_emp_se^2),
      ps_rel_eff = 1.00,  # PS is the reference
      ps_full_rel_eff = (ps_emp_se^2) / (ps_full_emp_se^2),
      wdsm_rel_eff = (ps_emp_se^2) / (wdsm_emp_se^2)
    )
  
  cat("\n🎯 PERFORMANCE METRICS:\n")
  
  # Format results for display
  performance_df <- data.frame(
    Method = c("DSM", "PG", "PS", "PS Full", "WDSM"),
    `Rel Bias` = sprintf("%.3f", c(metrics$dsm_rel_bias, metrics$pg_rel_bias, 
                                   metrics$ps_rel_bias, metrics$ps_full_rel_bias, 
                                   metrics$wdsm_rel_bias)),
    Coverage = sprintf("%.3f", c(metrics$dsm_coverage, metrics$pg_coverage,
                                 metrics$ps_coverage, metrics$ps_full_coverage,
                                 metrics$wdsm_coverage)),
    `SE Ratio` = sprintf("%.3f", c(metrics$dsm_se_ratio, metrics$pg_se_ratio,
                                   metrics$ps_se_ratio, metrics$ps_full_se_ratio,
                                   metrics$wdsm_se_ratio)),
    `Rel Eff` = sprintf("%.3f", c(metrics$dsm_rel_eff, metrics$pg_rel_eff,
                                  metrics$ps_rel_eff, metrics$ps_full_rel_eff,
                                  metrics$wdsm_rel_eff))
  )
  
  print(kable(performance_df, format = "simple"))
  
  return(metrics)
}

# Analyze each scenario
summary_list <- list()
for (scenario in names(all_results)) {
  summary_list[[scenario]] <- summarize_results(all_results[[scenario]], scenario)
}

# Create comprehensive comparison table
cat("\n", rep("=", 90), "\n")
cat("FINAL COMPARISON TABLE - 1000 REPLICATES WITH RELATIVE EFFICIENCY\n")
cat(rep("=", 90), "\n\n")

comparison_table <- data.frame(
  Scenario = character(),
  Method = character(),
  Validity = character(),
  `Rel_Bias` = character(),
  Coverage = character(),
  `SE_Ratio` = character(),
  `Rel_Efficiency` = character(),
  stringsAsFactors = FALSE
)

for (scenario in names(summary_list)) {
  results <- all_results[[scenario]]
  metrics <- summary_list[[scenario]]
  
  # Get validity counts
  validity <- results %>%
    summarise(
      dsm = sum(valid_dsm, na.rm = TRUE),
      pg = sum(valid_pg, na.rm = TRUE),
      ps = sum(valid_ps, na.rm = TRUE),
      ps_full = sum(valid_ps_full, na.rm = TRUE),
      wdsm = sum(valid_wdsm, na.rm = TRUE)
    )
  
  # Add rows for each method
  comparison_table <- rbind(comparison_table,
    data.frame(
      Scenario = scenario,
      Method = "DSM",
      Validity = paste0(validity$dsm, "/1000"),
      Rel_Bias = sprintf("%.3f", metrics$dsm_rel_bias),
      Coverage = sprintf("%.3f", metrics$dsm_coverage),
      SE_Ratio = sprintf("%.3f", metrics$dsm_se_ratio),
      Rel_Efficiency = sprintf("%.3f", metrics$dsm_rel_eff)
    ),
    data.frame(
      Scenario = scenario,
      Method = "PG",
      Validity = paste0(validity$pg, "/1000"),
      Rel_Bias = sprintf("%.3f", metrics$pg_rel_bias),
      Coverage = sprintf("%.3f", metrics$pg_coverage),
      SE_Ratio = sprintf("%.3f", metrics$pg_se_ratio),
      Rel_Efficiency = sprintf("%.3f", metrics$pg_rel_eff)
    ),
    data.frame(
      Scenario = scenario,
      Method = "PS (Ref)",
      Validity = paste0(validity$ps, "/1000"),
      Rel_Bias = sprintf("%.3f", metrics$ps_rel_bias),
      Coverage = sprintf("%.3f", metrics$ps_coverage),
      SE_Ratio = sprintf("%.3f", metrics$ps_se_ratio),
      Rel_Efficiency = "1.000"
    ),
    data.frame(
      Scenario = scenario,
      Method = "PS Full",
      Validity = paste0(validity$ps_full, "/1000"),
      Rel_Bias = sprintf("%.3f", metrics$ps_full_rel_bias),
      Coverage = sprintf("%.3f", metrics$ps_full_coverage),
      SE_Ratio = sprintf("%.3f", metrics$ps_full_se_ratio),
      Rel_Efficiency = sprintf("%.3f", metrics$ps_full_rel_eff)
    ),
    data.frame(
      Scenario = scenario,
      Method = "WDSM",
      Validity = paste0(validity$wdsm, "/1000"),
      Rel_Bias = sprintf("%.3f", metrics$wdsm_rel_bias),
      Coverage = sprintf("%.3f", metrics$wdsm_coverage),
      SE_Ratio = sprintf("%.3f", metrics$wdsm_se_ratio),
      Rel_Efficiency = sprintf("%.3f", metrics$wdsm_rel_eff)
    )
  )
}

print(kable(comparison_table, format = "simple", align = c("l", "l", "r", "r", "r", "r", "r")))

# Check for expected patterns
cat("\n🔍 VERIFICATION OF EXPECTED PATTERNS:\n")
cat("----------------------------------------\n")

# Pattern 1: CorCor vs CorMis should be similar for PS-based methods
if (all(c("CorCor", "CorMis") %in% names(summary_list))) {
  cat("\n1. PS-based methods (CorCor vs CorMis - should be similar since PS is correct in both):\n")
  cat("   PS Coverage: CorCor =", sprintf("%.3f", summary_list$CorCor$ps_coverage),
      "vs CorMis =", sprintf("%.3f", summary_list$CorMis$ps_coverage), "\n")
  cat("   PS Full Coverage: CorCor =", sprintf("%.3f", summary_list$CorCor$ps_full_coverage),
      "vs CorMis =", sprintf("%.3f", summary_list$CorMis$ps_full_coverage), "\n")
}

# Pattern 2: CorCor vs MisCor should be similar for PG-based methods
if (all(c("CorCor", "MisCor") %in% names(summary_list))) {
  cat("\n2. PG-based methods (CorCor vs MisCor - should be similar since PG is correct in both):\n")
  cat("   PG Coverage: CorCor =", sprintf("%.3f", summary_list$CorCor$pg_coverage),
      "vs MisCor =", sprintf("%.3f", summary_list$MisCor$pg_coverage), "\n")
}

# Pattern 3: DSM should perform well when either PS or PG is correct
cat("\n3. DSM Performance (should be good when either PS or PG is correct):\n")
for (scenario in names(summary_list)) {
  cat("   ", scenario, ": Coverage =", sprintf("%.3f", summary_list[[scenario]]$dsm_coverage),
      ", Rel Eff =", sprintf("%.3f", summary_list[[scenario]]$dsm_rel_eff), "\n")
}

# Pattern 4: Relative efficiency patterns
cat("\n4. Relative Efficiency Summary (compared to PS):\n")
cat("   Higher values indicate better precision (lower variance)\n")
for (scenario in names(summary_list)) {
  cat("\n   ", scenario, ":\n")
  cat("     DSM:", sprintf("%.3f", summary_list[[scenario]]$dsm_rel_eff), "\n")
  cat("     PG:", sprintf("%.3f", summary_list[[scenario]]$pg_rel_eff), "\n")
  cat("     PS Full:", sprintf("%.3f", summary_list[[scenario]]$ps_full_rel_eff), "\n")
  cat("     WDSM:", sprintf("%.3f", summary_list[[scenario]]$wdsm_rel_eff), "\n")
}

cat("\n✅ ANALYSIS COMPLETE!\n")
cat("\nKEY POINTS:\n")
cat("- Relative Efficiency = Var(PS) / Var(Method)\n")
cat("- Values > 1 indicate better efficiency than PS\n")
cat("- Coverage uses Wald CI for all methods (including WDSM)\n")
cat("- All methods use feasible matching parameters\n")
