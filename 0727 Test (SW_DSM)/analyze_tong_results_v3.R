# Analyze Tong Account M5 100-rep Results - Version 3
# Load and present detailed results for all 4 scenarios

library(dplyr)
library(tidyr)

# Initialize results list
all_results <- list()

cat("=============================================================\n")
cat("TONG ACCOUNT M5 100-REP RESULTS - DETAILED ANALYSIS\n")
cat("=============================================================\n\n")

# Load and process each scenario
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")

for (scenario in scenarios) {
  file_name <- tolower(scenario)
  file_path <- paste0("Tong_M5_100rep_Results/", file_name, "_results.RData")
  
  # Clear workspace except essentials
  rm(list = setdiff(ls(), c("all_results", "scenarios", "scenario", "file_name", "file_path")))
  
  # Load the file
  load(file_path)
  
  if (scenario %in% c("CorCor", "MisCor", "MisMis")) {
    # These files have summary_data
    if (exists("summary_data")) {
      df <- summary_data %>%
        filter(M == 5) %>%
        mutate(
          Scenario = scenario,
          Rel_Bias = as.numeric(Rel_Bias),
          SE_Ratio = as.numeric(SE_Ratio),
          Coverage = as.numeric(Coverage)
        ) %>%
        select(Scenario, Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
      
      all_results[[scenario]] <- df
      cat(scenario, ": Loaded", nrow(df), "methods\n")
    }
  } else if (scenario == "CorMis") {
    # CorMis has summary_stats with different column names
    if (exists("summary_stats")) {
      df <- summary_stats %>%
        mutate(
          Scenario = scenario,
          N_Valid = 100,
          Rel_Bias = as.numeric(Relative_Bias),
          SE_Ratio = as.numeric(Relative_Efficiency),
          Coverage = as.numeric(Coverage)
        ) %>%
        select(Scenario, Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
      
      all_results[[scenario]] <- df
      cat(scenario, ": Loaded", nrow(df), "methods\n")
    }
  }
}

cat("\n=============================================================\n")
cat("DETAILED RESULTS BY SCENARIO (M=5, 100 replications)\n")
cat("=============================================================\n\n")

# Combine all results
combined_df <- do.call(rbind, all_results)
rownames(combined_df) <- NULL

# Round numeric columns
combined_df$Rel_Bias <- round(combined_df$Rel_Bias, 3)
combined_df$SE_Ratio <- round(combined_df$SE_Ratio, 3)
combined_df$Coverage <- round(combined_df$Coverage, 3)

# Print results for each scenario
for (scenario in unique(combined_df$Scenario)) {
  cat("---", scenario, "---\n")
  df <- combined_df %>% filter(Scenario == scenario)
  print(df %>% select(-Scenario), row.names = FALSE)
  cat("\n")
}

cat("=============================================================\n")
cat("COMPARISON ACROSS SCENARIOS\n")
cat("=============================================================\n\n")

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

# Average performance across scenarios
avg_performance <- combined_df %>%
  group_by(Method) %>%
  summarise(
    Avg_Abs_Bias = round(mean(abs(Rel_Bias)), 3),
    Avg_SE_Ratio_Dev = round(mean(abs(SE_Ratio - 1)), 3),
    Avg_Coverage_Dev = round(mean(abs(Coverage - 0.95)), 3),
    Avg_Coverage = round(mean(Coverage), 3)
  ) %>%
  arrange(Avg_Abs_Bias)

cat("Average Performance Across All Scenarios:\n")
print(as.data.frame(avg_performance), row.names = FALSE)

cat("\n--- Best Performers ---\n")
cat("Lowest Average Absolute Bias:", avg_performance$Method[1], 
    "(", avg_performance$Avg_Abs_Bias[1], ")\n")

best_se <- avg_performance %>% arrange(Avg_SE_Ratio_Dev)
cat("Best Average SE Ratio:", best_se$Method[1], 
    "(deviation from 1:", best_se$Avg_SE_Ratio_Dev[1], ")\n")

best_cov <- avg_performance %>% arrange(Avg_Coverage_Dev)
cat("Best Average Coverage:", best_cov$Method[1], 
    "(", round(avg_performance %>% filter(Method == best_cov$Method[1]) %>% pull(Avg_Coverage), 3), ")\n")

# Model misspecification impact
cat("\n=============================================================\n")
cat("IMPACT OF MODEL MISSPECIFICATION\n")
cat("=============================================================\n\n")

# Calculate deterioration from CorCor to other scenarios
corcor_baseline <- combined_df %>% filter(Scenario == "CorCor")

for (mis_scenario in c("MisCor", "CorMis", "MisMis")) {
  cat("\n---", mis_scenario, "vs CorCor ---\n")
  mis_data <- combined_df %>% filter(Scenario == mis_scenario)
  
  comparison <- merge(
    corcor_baseline %>% select(Method, Rel_Bias, SE_Ratio, Coverage),
    mis_data %>% select(Method, Rel_Bias, SE_Ratio, Coverage),
    by = "Method",
    suffixes = c("_CorCor", paste0("_", mis_scenario))
  )
  
  comparison$Bias_Change <- round(comparison[[paste0("Rel_Bias_", mis_scenario)]] - comparison$Rel_Bias_CorCor, 3)
  comparison$SE_Change <- round(comparison[[paste0("SE_Ratio_", mis_scenario)]] - comparison$SE_Ratio_CorCor, 3)
  comparison$Coverage_Change <- round(comparison[[paste0("Coverage_", mis_scenario)]] - comparison$Coverage_CorCor, 3)
  
  print(comparison %>% select(Method, Bias_Change, SE_Change, Coverage_Change), row.names = FALSE)
}

# Save results
write.csv(combined_df, "Tong_M5_100rep_Results/detailed_results.csv", row.names = FALSE)
write.csv(bias_table, "Tong_M5_100rep_Results/bias_comparison.csv", row.names = FALSE)
write.csv(se_table, "Tong_M5_100rep_Results/se_ratio_comparison.csv", row.names = FALSE)
write.csv(coverage_table, "Tong_M5_100rep_Results/coverage_comparison.csv", row.names = FALSE)
write.csv(avg_performance, "Tong_M5_100rep_Results/average_performance.csv", row.names = FALSE)

cat("\n=============================================================\n")
cat("Results saved to Tong_M5_100rep_Results/ directory\n")
cat("=============================================================\n")
