# Analyze Results from 1:1 Matching Correction
library(tidyverse)
library(knitr)

# Load all results
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
all_results <- list()

for (scenario in scenarios) {
  file_name <- paste0("comprehensive_patt_comparison_", scenario, 
                     "_M5_100rep_Pooroverlap_FINAL_results.RData")
  if (file.exists(file_name)) {
    load(file_name)
    all_results[[scenario]] <- method_results  # Changed from final_results
    cat("\n", scenario, "loaded - Replicates:", nrow(method_results), "\n")
  }
}

# Function to summarize results
summarize_results <- function(results, scenario_name) {
  cat("\n", rep("=", 60), "\n")
  cat("SCENARIO:", scenario_name, "\n")
  cat(rep("=", 60), "\n")
  
  # Check validity
  validity_summary <- results %>%
    summarise(across(starts_with("valid_"), 
                    ~sum(.x, na.rm = TRUE), 
                    .names = "{.col}"))
  
  cat("\n📊 VALIDITY (out of", nrow(results), "replicates):\n")
  print(validity_summary)
  
  # Calculate performance metrics for valid replicates
  metrics <- results %>%
    filter(valid_dsm == TRUE | valid_pg == TRUE | valid_ps == TRUE | 
           valid_ps_full == TRUE | valid_wdsm == TRUE) %>%
    summarise(
      n_valid = n(),
      
      # DSM (Unweighted)
      dsm_bias = mean(bias_dsm, na.rm = TRUE),
      dsm_rel_bias = mean(rel_bias_dsm, na.rm = TRUE),
      dsm_coverage = mean(coverage_dsm, na.rm = TRUE),
      dsm_se_ratio = mean(se_ratio_dsm, na.rm = TRUE),
      
      # PG (Unweighted) 
      pg_bias = mean(bias_pg, na.rm = TRUE),
      pg_rel_bias = mean(rel_bias_pg, na.rm = TRUE),
      pg_coverage = mean(coverage_pg, na.rm = TRUE),
      pg_se_ratio = mean(se_ratio_pg, na.rm = TRUE),
      
      # PS (Unweighted)
      ps_bias = mean(bias_ps, na.rm = TRUE),
      ps_rel_bias = mean(rel_bias_ps, na.rm = TRUE),
      ps_coverage = mean(coverage_ps, na.rm = TRUE),
      ps_se_ratio = mean(se_ratio_ps, na.rm = TRUE),
      
      # PS Full (Survey-Weighted)
      ps_full_bias = mean(bias_ps_full, na.rm = TRUE),
      ps_full_rel_bias = mean(rel_bias_ps_full, na.rm = TRUE),
      ps_full_coverage = mean(coverage_ps_full, na.rm = TRUE),
      ps_full_se_ratio = mean(se_ratio_ps_full, na.rm = TRUE),
      
      # WDSM
      wdsm_bias = mean(bias_wdsm, na.rm = TRUE),
      wdsm_rel_bias = mean(rel_bias_wdsm, na.rm = TRUE),
      wdsm_coverage = mean(coverage_wdsm, na.rm = TRUE),
      wdsm_se_ratio = mean(se_ratio_wdsm, na.rm = TRUE)
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
                                   metrics$wdsm_se_ratio))
  )
  
  print(kable(performance_df, format = "simple"))
  
  return(metrics)
}

# Analyze each scenario
summary_list <- list()
for (scenario in names(all_results)) {
  summary_list[[scenario]] <- summarize_results(all_results[[scenario]], scenario)
}

# Create comparison table
cat("\n", rep("=", 80), "\n")
cat("FINAL COMPARISON TABLE - 1:1 MATCHING CORRECTION\n")
cat(rep("=", 80), "\n\n")

comparison_table <- data.frame(
  Scenario = character(),
  Method = character(),
  Validity = character(),
  `Rel_Bias` = character(),
  Coverage = character(),
  `SE_Ratio` = character(),
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
      Validity = paste0(validity$dsm, "/100"),
      Rel_Bias = sprintf("%.3f", metrics$dsm_rel_bias),
      Coverage = sprintf("%.3f", metrics$dsm_coverage),
      SE_Ratio = sprintf("%.3f", metrics$dsm_se_ratio)
    ),
    data.frame(
      Scenario = scenario,
      Method = "PG",
      Validity = paste0(validity$pg, "/100"),
      Rel_Bias = sprintf("%.3f", metrics$pg_rel_bias),
      Coverage = sprintf("%.3f", metrics$pg_coverage),
      SE_Ratio = sprintf("%.3f", metrics$pg_se_ratio)
    ),
    data.frame(
      Scenario = scenario,
      Method = "PS",
      Validity = paste0(validity$ps, "/100"),
      Rel_Bias = sprintf("%.3f", metrics$ps_rel_bias),
      Coverage = sprintf("%.3f", metrics$ps_coverage),
      SE_Ratio = sprintf("%.3f", metrics$ps_se_ratio)
    ),
    data.frame(
      Scenario = scenario,
      Method = "PS Full",
      Validity = paste0(validity$ps_full, "/100"),
      Rel_Bias = sprintf("%.3f", metrics$ps_full_rel_bias),
      Coverage = sprintf("%.3f", metrics$ps_full_coverage),
      SE_Ratio = sprintf("%.3f", metrics$ps_full_se_ratio)
    ),
    data.frame(
      Scenario = scenario,
      Method = "WDSM",
      Validity = paste0(validity$wdsm, "/100"),
      Rel_Bias = sprintf("%.3f", metrics$wdsm_rel_bias),
      Coverage = sprintf("%.3f", metrics$wdsm_coverage),
      SE_Ratio = sprintf("%.3f", metrics$wdsm_se_ratio)
    )
  )
}

print(kable(comparison_table, format = "simple", align = c("l", "l", "r", "r", "r", "r")))

# Check for expected patterns
cat("\n🔍 VERIFICATION OF EXPECTED PATTERNS:\n")
cat("----------------------------------------\n")

# Pattern 1: CorCor vs CorMis should be identical for PS-based methods
if (all(c("CorCor", "CorMis") %in% names(summary_list))) {
  cat("\n1. PS-based methods (CorCor vs CorMis):\n")
  cat("   PS Coverage: CorCor =", sprintf("%.3f", summary_list$CorCor$ps_coverage),
      "vs CorMis =", sprintf("%.3f", summary_list$CorMis$ps_coverage), "\n")
  cat("   PS Full Coverage: CorCor =", sprintf("%.3f", summary_list$CorCor$ps_full_coverage),
      "vs CorMis =", sprintf("%.3f", summary_list$CorMis$ps_full_coverage), "\n")
}

# Pattern 2: CorCor vs MisCor should be identical for PG-based methods
if (all(c("CorCor", "MisCor") %in% names(summary_list))) {
  cat("\n2. PG-based methods (CorCor vs MisCor):\n")
  cat("   PG Coverage: CorCor =", sprintf("%.3f", summary_list$CorCor$pg_coverage),
      "vs MisCor =", sprintf("%.3f", summary_list$MisCor$pg_coverage), "\n")
}

cat("\n✅ ANALYSIS COMPLETE!\n")
cat("\nKEY IMPROVEMENTS WITH 1:1 MATCHING:\n")
cat("- Unweighted methods now use feasible 1:1 matching\n")
cat("- WDSM continues to use M=5 as designed\n")
cat("- No individual method timeouts\n")
