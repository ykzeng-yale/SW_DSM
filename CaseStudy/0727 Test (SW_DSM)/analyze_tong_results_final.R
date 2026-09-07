# Final Analysis of Tong Account M5 100-rep Results

library(dplyr)
library(tidyr)

cat("=============================================================\n")
cat("TONG ACCOUNT M5 100-REP RESULTS - DETAILED ANALYSIS\n")
cat("=============================================================\n\n")

# Process each file separately
results_list <- list()

# Process CorCor
cat("Processing CorCor...\n")
env1 <- new.env()
load("Tong_M5_100rep_Results/corcor_results.RData", envir = env1)
if ("summary_data" %in% names(env1)) {
  corcor_df <- env1$summary_data %>%
    filter(M == 5) %>%
    mutate(Scenario = "CorCor") %>%
    select(Scenario, Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
  results_list[["CorCor"]] <- corcor_df
}

# Process MisCor
cat("Processing MisCor...\n")
env2 <- new.env()
load("Tong_M5_100rep_Results/miscor_results.RData", envir = env2)
if ("summary_data" %in% names(env2)) {
  miscor_df <- env2$summary_data %>%
    filter(M == 5) %>%
    mutate(Scenario = "MisCor") %>%
    select(Scenario, Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
  results_list[["MisCor"]] <- miscor_df
}

# Process CorMis (different format)
cat("Processing CorMis...\n")
env3 <- new.env()
load("Tong_M5_100rep_Results/cormis_results.RData", envir = env3)
if ("summary_stats" %in% names(env3)) {
  cormis_df <- env3$summary_stats %>%
    mutate(
      Scenario = "CorMis",
      N_Valid = 100,
      Rel_Bias = Relative_Bias,
      SE_Ratio = Relative_Efficiency
    ) %>%
    select(Scenario, Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
  results_list[["CorMis"]] <- cormis_df
}

# Process MisMis
cat("Processing MisMis...\n")
env4 <- new.env()
load("Tong_M5_100rep_Results/mismis_results.RData", envir = env4)
if ("summary_data" %in% names(env4)) {
  mismis_df <- env4$summary_data %>%
    filter(M == 5) %>%
    mutate(Scenario = "MisMis") %>%
    select(Scenario, Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
  results_list[["MisMis"]] <- mismis_df
}

# Combine all results
combined_df <- bind_rows(results_list)

# Clean up method names for consistency
combined_df <- combined_df %>%
  mutate(
    Method = case_when(
      grepl("dsm|DSM", Method) ~ "1. Unweighted DSM",
      grepl("pg|PG", Method) ~ "2. Unweighted PG",
      grepl("ps_unweighted|PS.*Unweighted", Method) ~ "3. Unweighted PS",
      grepl("ps_survey|PS.*Survey", Method) ~ "4. Survey-weighted PS",
      grepl("wdsm|WDSM", Method) ~ "5. WDSM",
      TRUE ~ Method
    ),
    Rel_Bias = round(as.numeric(Rel_Bias), 3),
    SE_Ratio = round(as.numeric(SE_Ratio), 3),
    Coverage = round(as.numeric(Coverage), 3),
    N_Valid = as.integer(N_Valid)
  )

cat("\n=============================================================\n")
cat("DETAILED RESULTS BY SCENARIO (M=5, 100 replications)\n")
cat("=============================================================\n\n")

# Print results for each scenario
for (scenario in c("CorCor", "MisCor", "CorMis", "MisMis")) {
  cat("---", scenario, "---\n")
  df <- combined_df %>% 
    filter(Scenario == scenario) %>%
    select(Method, N_Valid, Rel_Bias, SE_Ratio, Coverage) %>%
    arrange(Method)
  print(df, row.names = FALSE)
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

cat("\n=============================================================\n")
cat("PERFORMANCE SUMMARY\n")
cat("=============================================================\n\n")

# Average performance across scenarios
avg_performance <- combined_df %>%
  group_by(Method) %>%
  summarise(
    Avg_Abs_Bias = round(mean(abs(Rel_Bias)), 3),
    Avg_SE_Ratio = round(mean(SE_Ratio), 3),
    Avg_Coverage = round(mean(Coverage), 3),
    Worst_Bias = round(max(abs(Rel_Bias)), 3),
    Worst_Coverage = round(min(Coverage), 3)
  ) %>%
  arrange(Method)

cat("Average Performance Across All Scenarios:\n")
print(as.data.frame(avg_performance), row.names = FALSE)

cat("\n--- Method Rankings ---\n")

# Rank by average absolute bias
bias_rank <- avg_performance %>% 
  arrange(Avg_Abs_Bias) %>%
  mutate(Rank = row_number()) %>%
  select(Rank, Method, Avg_Abs_Bias)
cat("\nLowest Average Absolute Bias:\n")
print(as.data.frame(bias_rank), row.names = FALSE)

# Rank by average coverage
coverage_rank <- avg_performance %>%
  mutate(Coverage_Dev = abs(Avg_Coverage - 0.950)) %>%
  arrange(Coverage_Dev) %>%
  mutate(Rank = row_number()) %>%
  select(Rank, Method, Avg_Coverage)
cat("\nBest Average Coverage (closest to 0.950):\n")
print(as.data.frame(coverage_rank), row.names = FALSE)

cat("\n=============================================================\n")
cat("IMPACT OF MODEL MISSPECIFICATION\n")
cat("=============================================================\n\n")

# Compare each misspecification scenario to CorCor
baseline <- combined_df %>% filter(Scenario == "CorCor")

for (mis_scenario in c("MisCor", "CorMis", "MisMis")) {
  cat("\n---", mis_scenario, "vs CorCor (Change from Baseline) ---\n")
  mis_data <- combined_df %>% filter(Scenario == mis_scenario)
  
  comparison <- inner_join(
    baseline %>% select(Method, Rel_Bias, SE_Ratio, Coverage),
    mis_data %>% select(Method, Rel_Bias, SE_Ratio, Coverage),
    by = "Method",
    suffix = c("_Base", "_Mis")
  ) %>%
    mutate(
      Bias_Change = round(Rel_Bias_Mis - Rel_Bias_Base, 3),
      SE_Change = round(SE_Ratio_Mis - SE_Ratio_Base, 3),
      Coverage_Change = round(Coverage_Mis - Coverage_Base, 3)
    ) %>%
    select(Method, Bias_Change, SE_Change, Coverage_Change) %>%
    arrange(Method)
  
  print(comparison, row.names = FALSE)
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
