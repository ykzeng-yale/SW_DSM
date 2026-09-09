# Analyze Tong Account M5 100-rep Results - Version 2
# Load and present detailed results for all 4 scenarios

library(dplyr)
library(tidyr)

# Initialize results list
all_results <- list()

cat("=============================================================\n")
cat("TONG ACCOUNT M5 100-REP RESULTS - DETAILED ANALYSIS\n")
cat("=============================================================\n\n")

# Load CorCor results
load("Tong_M5_100rep_Results/corcor_results.RData")
if (exists("summary_data")) {
  corcor_results <- summary_data %>%
    filter(M == 5) %>%
    select(Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
  all_results[["CorCor"]] <- corcor_results
  cat("CorCor: Loaded", nrow(corcor_results), "methods\n")
}

# Load MisCor results
load("Tong_M5_100rep_Results/miscor_results.RData")
if (exists("summary_data")) {
  miscor_results <- summary_data %>%
    filter(M == 5) %>%
    select(Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
  all_results[["MisCor"]] <- miscor_results
  cat("MisCor: Loaded", nrow(miscor_results), "methods\n")
}

# Load CorMis results (different format)
load("Tong_M5_100rep_Results/cormis_results.RData")
if (exists("summary_stats")) {
  cormis_results <- summary_stats %>%
    select(Method, Relative_Bias, Relative_Efficiency, Coverage) %>%
    rename(Rel_Bias = Relative_Bias, SE_Ratio = Relative_Efficiency)
  cormis_results$N_Valid <- 100  # Assuming 100 valid runs
  cormis_results <- cormis_results[, c("Method", "N_Valid", "Rel_Bias", "SE_Ratio", "Coverage")]
  all_results[["CorMis"]] <- cormis_results
  cat("CorMis: Loaded", nrow(cormis_results), "methods\n")
}

# Load MisMis results
load("Tong_M5_100rep_Results/mismis_results.RData")
if (exists("summary_data")) {
  mismis_results <- summary_data %>%
    filter(M == 5) %>%
    select(Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
  all_results[["MisMis"]] <- mismis_results
  cat("MisMis: Loaded", nrow(mismis_results), "methods\n")
}

cat("\n=============================================================\n")
cat("DETAILED RESULTS BY SCENARIO (M=5, 100 replications)\n")
cat("=============================================================\n\n")

# Print results for each scenario
for (scenario in names(all_results)) {
  cat("---", scenario, "---\n")
  df <- all_results[[scenario]]
  # Format the results with 3 decimal places
  df$Rel_Bias <- round(df$Rel_Bias, 3)
  df$SE_Ratio <- round(df$SE_Ratio, 3)
  df$Coverage <- round(df$Coverage, 3)
  print(df, row.names = FALSE)
  cat("\n")
}

# Create comparison tables
cat("=============================================================\n")
cat("COMPARISON ACROSS SCENARIOS\n")
cat("=============================================================\n\n")

# Combine all results into a single dataframe
combined_df <- data.frame()
for (scenario in names(all_results)) {
  df <- all_results[[scenario]]
  df$Scenario <- scenario
  combined_df <- rbind(combined_df, df)
}

# Reorder columns
combined_df <- combined_df %>%
  select(Scenario, Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)

cat("--- RELATIVE BIAS (Target: Close to 0) ---\n")
bias_table <- combined_df %>%
  select(Method, Scenario, Rel_Bias) %>%
  pivot_wider(names_from = Scenario, values_from = Rel_Bias) %>%
  arrange(Method)
print(as.data.frame(bias_table), row.names = FALSE)

cat("\n--- RELATIVE EFFICIENCY / SE RATIO (Target: Close to 1) ---\n")
se_table <- combined_df %>%
  select(Method, Scenario, SE_Ratio) %>%
  pivot_wider(names_from = Scenario, values_from = SE_Ratio) %>%
  arrange(Method)
print(as.data.frame(se_table), row.names = FALSE)

cat("\n--- COVERAGE (Target: 0.950) ---\n")
coverage_table <- combined_df %>%
  select(Method, Scenario, Coverage) %>%
  pivot_wider(names_from = Scenario, values_from = Coverage) %>%
  arrange(Method)
print(as.data.frame(coverage_table), row.names = FALSE)

# Calculate performance metrics
cat("\n=============================================================\n")
cat("PERFORMANCE SUMMARY\n")
cat("=============================================================\n\n")

# Best performance by metric
cat("Best Relative Bias (closest to 0) by Scenario:\n")
for (scenario in unique(combined_df$Scenario)) {
  scenario_df <- combined_df %>% filter(Scenario == scenario)
  best_method <- scenario_df[which.min(abs(scenario_df$Rel_Bias)), "Method"]
  best_value <- scenario_df[which.min(abs(scenario_df$Rel_Bias)), "Rel_Bias"]
  cat("  ", scenario, ":", best_method, "(", best_value, ")\n")
}

cat("\nBest SE Ratio (closest to 1) by Scenario:\n")
for (scenario in unique(combined_df$Scenario)) {
  scenario_df <- combined_df %>% filter(Scenario == scenario)
  best_method <- scenario_df[which.min(abs(scenario_df$SE_Ratio - 1)), "Method"]
  best_value <- scenario_df[which.min(abs(scenario_df$SE_Ratio - 1)), "SE_Ratio"]
  cat("  ", scenario, ":", best_method, "(", best_value, ")\n")
}

cat("\nBest Coverage (closest to 0.950) by Scenario:\n")
for (scenario in unique(combined_df$Scenario)) {
  scenario_df <- combined_df %>% filter(Scenario == scenario)
  best_method <- scenario_df[which.min(abs(scenario_df$Coverage - 0.95)), "Method"]
  best_value <- scenario_df[which.min(abs(scenario_df$Coverage - 0.95)), "Coverage"]
  cat("  ", scenario, ":", best_method, "(", best_value, ")\n")
}

# Save results
write.csv(combined_df, "Tong_M5_100rep_Results/detailed_results.csv", row.names = FALSE)
write.csv(bias_table, "Tong_M5_100rep_Results/bias_comparison.csv", row.names = FALSE)
write.csv(se_table, "Tong_M5_100rep_Results/se_ratio_comparison.csv", row.names = FALSE)
write.csv(coverage_table, "Tong_M5_100rep_Results/coverage_comparison.csv", row.names = FALSE)

cat("\n=============================================================\n")
cat("Results saved to Tong_M5_100rep_Results/ directory\n")
cat("=============================================================\n")
