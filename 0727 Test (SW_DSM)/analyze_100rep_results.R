#!/usr/bin/env Rscript

#=============================================================================
# Analyze 100-Replication Results from All-Fixed Scripts
#=============================================================================

cat("===============================================================\n")
cat("Analyzing 100-Replication Production Results\n")
cat("===============================================================\n\n")

# Load required libraries
library(dplyr)
library(tidyr)

# Set true PATE for poor overlap
true_pate <- 0.8664

# Initialize results storage
all_results_list <- list()

# Load all scenario results
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
for (scenario in scenarios) {
  file_path <- paste0("pooroverlap_100rep_", scenario, ".RData")
  if (file.exists(file_path)) {
    cat("Loading", scenario, "results...\n")
    load(file_path)
    all_results_list[[scenario]] <- all_results
  } else {
    cat("WARNING: File not found for", scenario, "\n")
  }
}

# Function to extract method results
extract_method_results <- function(scenario_results, scenario_name, M = 5) {
  n_reps <- length(scenario_results)
  methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", 
               "ps_weighted", "wdsm_multinomial")
  
  results_df <- data.frame()
  
  for (i in 1:n_reps) {
    if (is.null(scenario_results[[i]])) next
    
    # Access the nested structure
    rep_data <- scenario_results[[i]][[paste0(scenario_name, "_M", M)]]
    if (is.null(rep_data)) next
    
    for (method in methods) {
      if (!is.null(rep_data[[method]]) && !is.na(rep_data[[method]]$estimate)) {
        results_df <- rbind(results_df, data.frame(
          scenario = scenario_name,
          method = method,
          replicate = i,
          estimate = rep_data[[method]]$estimate,
          se = rep_data[[method]]$se,
          ci_lower = rep_data[[method]]$ci_lower,
          ci_upper = rep_data[[method]]$ci_upper,
          stringsAsFactors = FALSE
        ))
      }
    }
  }
  
  return(results_df)
}

# Extract results for all scenarios
all_results_df <- data.frame()
for (scenario in names(all_results_list)) {
  scenario_df <- extract_method_results(all_results_list[[scenario]], scenario)
  all_results_df <- rbind(all_results_df, scenario_df)
}

# Calculate performance metrics
performance_metrics <- all_results_df %>%
  group_by(scenario, method) %>%
  summarise(
    n_valid = n(),
    mean_estimate = mean(estimate, na.rm = TRUE),
    bias = mean_estimate - true_pate,
    relative_bias = (bias / true_pate) * 100,
    empirical_se = sd(estimate, na.rm = TRUE),
    mean_se = mean(se, na.rm = TRUE),
    se_ratio = mean_se / empirical_se,
    coverage = mean(ci_lower <= true_pate & ci_upper >= true_pate, na.rm = TRUE) * 100,
    rmse = sqrt(mean((estimate - true_pate)^2, na.rm = TRUE)),
    .groups = "drop"
  )

# Calculate relative efficiency using PS Full as reference
reference_method <- "ps_weighted"
efficiency_df <- all_results_df %>%
  group_by(scenario, method) %>%
  summarise(empirical_var = var(estimate, na.rm = TRUE), .groups = "drop")

reference_vars <- efficiency_df %>%
  filter(method == reference_method) %>%
  select(scenario, ref_var = empirical_var)

efficiency_df <- efficiency_df %>%
  left_join(reference_vars, by = "scenario") %>%
  mutate(relative_efficiency = ref_var / empirical_var)

# Combine metrics
final_metrics <- performance_metrics %>%
  left_join(efficiency_df %>% select(scenario, method, relative_efficiency), 
            by = c("scenario", "method"))

# Print results by scenario
cat("\n===============================================================\n")
cat("PERFORMANCE METRICS BY SCENARIO (100 Replications)\n")
cat("===============================================================\n")
cat("True PATE:", true_pate, "\n\n")

for (scenario in scenarios) {
  cat("\n", scenario, "Scenario:\n")
  cat(strrep("-", 60), "\n")
  
  scenario_metrics <- final_metrics %>%
    filter(scenario == !!scenario) %>%
    arrange(method)
  
  # Print formatted table
  cat(sprintf("%-20s %6s %8s %8s %8s %8s %8s %8s\n",
              "Method", "N", "Bias", "Rel.Bias", "SE.Ratio", "Coverage", "RMSE", "Rel.Eff"))
  cat(strrep("-", 100), "\n")
  
  for (i in 1:nrow(scenario_metrics)) {
    cat(sprintf("%-20s %6d %8.4f %7.2f%% %8.3f %7.1f%% %8.4f %8.3f\n",
                scenario_metrics$method[i],
                scenario_metrics$n_valid[i],
                scenario_metrics$bias[i],
                scenario_metrics$relative_bias[i],
                scenario_metrics$se_ratio[i],
                scenario_metrics$coverage[i],
                scenario_metrics$rmse[i],
                scenario_metrics$relative_efficiency[i]))
  }
}

# Summary across scenarios
cat("\n\n===============================================================\n")
cat("SUMMARY: WDSM Performance Across Scenarios\n")
cat("===============================================================\n")

wdsm_summary <- final_metrics %>%
  filter(method == "wdsm_multinomial") %>%
  select(scenario, n_valid, relative_bias, se_ratio, coverage, rmse, relative_efficiency)

cat("\nWDSM (Survey-Weighted Double Score Matching):\n")
cat(strrep("-", 80), "\n")
cat(sprintf("%-10s %6s %10s %10s %10s %10s %10s\n",
            "Scenario", "N", "Rel.Bias", "SE.Ratio", "Coverage", "RMSE", "Rel.Eff"))
cat(strrep("-", 80), "\n")

for (i in 1:nrow(wdsm_summary)) {
  cat(sprintf("%-10s %6d %9.2f%% %10.3f %9.1f%% %10.4f %10.3f\n",
              wdsm_summary$scenario[i],
              wdsm_summary$n_valid[i],
              wdsm_summary$relative_bias[i],
              wdsm_summary$se_ratio[i],
              wdsm_summary$coverage[i],
              wdsm_summary$rmse[i],
              wdsm_summary$relative_efficiency[i]))
}

# Expected patterns verification
cat("\n\n===============================================================\n")
cat("THEORETICAL PATTERNS VERIFICATION\n")
cat("===============================================================\n")

# Check PS-based methods: CorCor should equal CorMis
ps_methods <- c("ps_unweighted", "ps_weighted")
cat("\nPS-based methods (should have CorCor ≈ CorMis):\n")
for (method in ps_methods) {
  corcor_bias <- final_metrics %>% filter(scenario == "CorCor", method == !!method) %>% pull(relative_bias)
  cormis_bias <- final_metrics %>% filter(scenario == "CorMis", method == !!method) %>% pull(relative_bias)
  if (length(corcor_bias) > 0 && length(cormis_bias) > 0) {
    cat(sprintf("  %s: CorCor = %.2f%%, CorMis = %.2f%% (diff = %.2f%%)\n", 
                method, corcor_bias, cormis_bias, abs(corcor_bias - cormis_bias)))
  }
}

# Check PG-based methods: CorCor should equal MisCor
pg_methods <- c("pg_unweighted")
cat("\nPG-based methods (should have CorCor ≈ MisCor):\n")
for (method in pg_methods) {
  corcor_bias <- final_metrics %>% filter(scenario == "CorCor", method == !!method) %>% pull(relative_bias)
  miscor_bias <- final_metrics %>% filter(scenario == "MisCor", method == !!method) %>% pull(relative_bias)
  if (length(corcor_bias) > 0 && length(miscor_bias) > 0) {
    cat(sprintf("  %s: CorCor = %.2f%%, MisCor = %.2f%% (diff = %.2f%%)\n", 
                method, corcor_bias, miscor_bias, abs(corcor_bias - miscor_bias)))
  }
}

# Save results
save(final_metrics, all_results_df, file = "pooroverlap_100rep_analysis.RData")
write.csv(final_metrics, "pooroverlap_100rep_metrics.csv", row.names = FALSE)

cat("\n\n===============================================================\n")
cat("Analysis Complete!\n")
cat("Results saved to:\n")
cat("  - pooroverlap_100rep_analysis.RData\n")
cat("  - pooroverlap_100rep_metrics.csv\n")
cat("===============================================================\n")

# Check for any concerning patterns
cat("\n\nKEY FINDINGS:\n")
cat(strrep("-", 40), "\n")

# Check WDSM in CorCor
wdsm_corcor <- final_metrics %>% 
  filter(scenario == "CorCor", method == "wdsm_multinomial")
if (nrow(wdsm_corcor) > 0) {
  cat(sprintf("1. WDSM in CorCor: Bias = %.2f%%, Coverage = %.1f%%\n",
              wdsm_corcor$relative_bias, wdsm_corcor$coverage))
  if (abs(wdsm_corcor$relative_bias) < 1) {
    cat("   ✅ Bias is within target (<1%)\n")
  } else {
    cat("   ⚠️ Bias exceeds 1% target\n")
  }
  if (wdsm_corcor$coverage >= 93 && wdsm_corcor$coverage <= 97) {
    cat("   ✅ Coverage is nominal (93-97%)\n")
  } else {
    cat("   ⚠️ Coverage outside nominal range\n")
  }
}

# Count successful methods
n_methods_per_scenario <- final_metrics %>%
  group_by(scenario) %>%
  summarise(n_methods = n_distinct(method), .groups = "drop")

cat("\n2. Method completion:\n")
for (i in 1:nrow(n_methods_per_scenario)) {
  cat(sprintf("   %s: %d/5 methods produced results\n",
              n_methods_per_scenario$scenario[i],
              n_methods_per_scenario$n_methods[i]))
}

cat("\n===============================================================\n")
