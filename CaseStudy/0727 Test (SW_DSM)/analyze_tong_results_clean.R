# Clean Analysis of Tong Account M5 100-rep Results

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
  df <- env1$summary_data %>%
    filter(M == 5) %>%
    mutate(Scenario = "CorCor")
  cat("  Found", nrow(df), "rows\n")
  cat("  Methods:", paste(unique(df$Method), collapse = ", "), "\n")
  results_list[["CorCor"]] <- df
}

# Process MisCor
cat("Processing MisCor...\n")
env2 <- new.env()
load("Tong_M5_100rep_Results/miscor_results.RData", envir = env2)
if ("summary_data" %in% names(env2)) {
  df <- env2$summary_data %>%
    filter(M == 5) %>%
    mutate(Scenario = "MisCor")
  cat("  Found", nrow(df), "rows\n")
  cat("  Methods:", paste(unique(df$Method), collapse = ", "), "\n")
  results_list[["MisCor"]] <- df
}

# Process CorMis (different format)
cat("Processing CorMis...\n")
env3 <- new.env()
load("Tong_M5_100rep_Results/cormis_results.RData", envir = env3)
if ("summary_stats" %in% names(env3)) {
  df <- env3$summary_stats %>%
    rename(
      Rel_Bias = Relative_Bias,
      SE_Ratio = Relative_Efficiency,
      Mean_SE = Mean_SE,
      Empirical_SE = Empirical_SD
    ) %>%
    mutate(
      Scenario = "CorMis",
      M = 5,
      N_Valid = 100,
      RMSE = sqrt(Bias^2 + Empirical_SE^2)
    )
  
  # Standardize method names
  df <- df %>%
    mutate(Method = case_when(
      grepl("DSM", Method) ~ "dsm_unweighted",
      grepl("PG", Method) ~ "pg_unweighted", 
      grepl("PS.*Unweighted", Method) ~ "ps_unweighted",
      grepl("PS.*Survey", Method) ~ "ps_weighted",
      grepl("WDSM", Method) ~ "wdsm",
      TRUE ~ Method
    ))
  
  cat("  Found", nrow(df), "rows\n")
  cat("  Methods:", paste(unique(df$Method), collapse = ", "), "\n")
  results_list[["CorMis"]] <- df
}

# Process MisMis
cat("Processing MisMis...\n")
env4 <- new.env()
load("Tong_M5_100rep_Results/mismis_results.RData", envir = env4)
if ("summary_data" %in% names(env4)) {
  df <- env4$summary_data %>%
    filter(M == 5) %>%
    mutate(Scenario = "MisMis")
  cat("  Found", nrow(df), "rows\n")
  cat("  Methods:", paste(unique(df$Method), collapse = ", "), "\n")
  results_list[["MisMis"]] <- df
}

# Combine all results - select only common columns
common_cols <- c("Scenario", "Method", "N_Valid", "Mean_Estimate", "Bias", 
                 "Rel_Bias", "Empirical_SE", "Mean_SE", "SE_Ratio", "Coverage")

combined_list <- list()
for (i in seq_along(results_list)) {
  df <- results_list[[i]]
  # Select common columns that exist
  cols_to_select <- intersect(common_cols, names(df))
  combined_list[[i]] <- df[, cols_to_select]
}

combined_df <- bind_rows(combined_list)

# Standardize method names
combined_df <- combined_df %>%
  mutate(
    Method_Clean = case_when(
      Method == "dsm_unweighted" ~ "1. Unweighted DSM",
      Method == "pg_unweighted" ~ "2. Unweighted PG",
      Method == "ps_unweighted" ~ "3. Unweighted PS",
      Method == "ps_weighted" ~ "4. Survey-weighted PS",
      Method == "wdsm" ~ "5. WDSM",
      TRUE ~ Method
    ),
    Rel_Bias = round(as.numeric(Rel_Bias), 3),
    SE_Ratio = round(as.numeric(SE_Ratio), 3),
    Coverage = round(as.numeric(Coverage), 3)
  ) %>%
  filter(!is.na(Method_Clean))  # Remove any unmatched methods

cat("\n=============================================================\n")
cat("DETAILED RESULTS BY SCENARIO (M=5, 100 replications)\n")
cat("=============================================================\n\n")

# Print results for each scenario [[memory:5776163]]
for (scenario in c("CorCor", "MisCor", "CorMis", "MisMis")) {
  cat("---", scenario, "---\n")
  df <- combined_df %>% 
    filter(Scenario == scenario) %>%
    select(Method_Clean, N_Valid, Rel_Bias, SE_Ratio, Coverage) %>%
    arrange(Method_Clean)
  names(df)[1] <- "Method"
  print(df, row.names = FALSE)
  cat("\n")
}

cat("=============================================================\n")
cat("COMPARISON ACROSS SCENARIOS\n")
cat("=============================================================\n\n")

cat("--- RELATIVE BIAS (Target: Close to 0) ---\n")
bias_table <- combined_df %>%
  select(Method_Clean, Scenario, Rel_Bias) %>%
  distinct() %>%  # Remove duplicates
  pivot_wider(names_from = Scenario, values_from = Rel_Bias) %>%
  arrange(Method_Clean)
names(bias_table)[1] <- "Method"
print(as.data.frame(bias_table), row.names = FALSE)

cat("\n--- RELATIVE EFFICIENCY / SE RATIO (Target: Close to 1) ---\n")
se_table <- combined_df %>%
  select(Method_Clean, Scenario, SE_Ratio) %>%
  distinct() %>%  # Remove duplicates
  pivot_wider(names_from = Scenario, values_from = SE_Ratio) %>%
  arrange(Method_Clean)
names(se_table)[1] <- "Method"
print(as.data.frame(se_table), row.names = FALSE)

cat("\n--- COVERAGE (Target: 0.950) ---\n")
coverage_table <- combined_df %>%
  select(Method_Clean, Scenario, Coverage) %>%
  distinct() %>%  # Remove duplicates
  pivot_wider(names_from = Scenario, values_from = Coverage) %>%
  arrange(Method_Clean)
names(coverage_table)[1] <- "Method"
print(as.data.frame(coverage_table), row.names = FALSE)

cat("\n=============================================================\n")
cat("PERFORMANCE SUMMARY\n")
cat("=============================================================\n\n")

# Average performance across scenarios
avg_performance <- combined_df %>%
  select(Method_Clean, Scenario, Rel_Bias, SE_Ratio, Coverage) %>%
  distinct() %>%
  group_by(Method_Clean) %>%
  summarise(
    N_Scenarios = n(),
    Avg_Abs_Bias = round(mean(abs(Rel_Bias), na.rm = TRUE), 3),
    Avg_SE_Ratio = round(mean(SE_Ratio, na.rm = TRUE), 3),
    Avg_Coverage = round(mean(Coverage, na.rm = TRUE), 3),
    Min_Coverage = round(min(Coverage, na.rm = TRUE), 3),
    Max_Abs_Bias = round(max(abs(Rel_Bias), na.rm = TRUE), 3)
  ) %>%
  arrange(Method_Clean)
names(avg_performance)[1] <- "Method"

cat("Average Performance Across Scenarios:\n")
print(as.data.frame(avg_performance), row.names = FALSE)

cat("\n--- Best Overall Performers ---\n")

# Calculate composite score (lower is better)
avg_performance <- avg_performance %>%
  mutate(
    Coverage_Dev = abs(Avg_Coverage - 0.950),
    SE_Ratio_Dev = abs(Avg_SE_Ratio - 1.000),
    Composite_Score = Avg_Abs_Bias + Coverage_Dev * 100 + SE_Ratio_Dev * 10
  ) %>%
  arrange(Composite_Score)

cat("\nComposite Performance Score (lower is better):\n")
cat("Score = Avg_Abs_Bias + 100*|Coverage-0.95| + 10*|SE_Ratio-1|\n\n")
print(avg_performance %>% 
        select(Method, Composite_Score, Avg_Abs_Bias, Avg_Coverage, Avg_SE_Ratio) %>%
        as.data.frame(), 
      row.names = FALSE)

cat("\n=============================================================\n")
cat("IMPACT OF MODEL MISSPECIFICATION\n")
cat("=============================================================\n\n")

# Calculate deterioration for each misspecification type
baseline <- combined_df %>% 
  filter(Scenario == "CorCor") %>%
  select(Method_Clean, Rel_Bias, SE_Ratio, Coverage) %>%
  distinct()

for (mis_scenario in c("MisCor", "CorMis", "MisMis")) {
  cat("\n---", mis_scenario, "vs CorCor ---\n")
  cat("(Change from correct specification)\n\n")
  
  mis_data <- combined_df %>% 
    filter(Scenario == mis_scenario) %>%
    select(Method_Clean, Rel_Bias, SE_Ratio, Coverage) %>%
    distinct()
  
  comparison <- inner_join(
    baseline,
    mis_data,
    by = "Method_Clean",
    suffix = c("_Base", "_Mis")
  ) %>%
    mutate(
      Bias_Change = round(Rel_Bias_Mis - Rel_Bias_Base, 3),
      SE_Change = round(SE_Ratio_Mis - SE_Ratio_Base, 3),
      Coverage_Change = round(Coverage_Mis - Coverage_Base, 3)
    ) %>%
    select(Method_Clean, Bias_Change, SE_Change, Coverage_Change) %>%
    arrange(Method_Clean)
  
  names(comparison)[1] <- "Method"
  print(comparison, row.names = FALSE)
  
  # Identify most robust method
  robust_score <- comparison %>%
    mutate(
      Total_Impact = abs(Bias_Change) + abs(Coverage_Change) + abs(SE_Change) * 10
    ) %>%
    arrange(Total_Impact)
  
  cat("\nMost robust to", mis_scenario, "misspecification:", 
      robust_score$Method[1], "\n")
}

# Save clean results
write.csv(combined_df %>% select(-Method) %>% rename(Method = Method_Clean), 
          "Tong_M5_100rep_Results/detailed_results.csv", row.names = FALSE)
write.csv(bias_table, "Tong_M5_100rep_Results/bias_comparison.csv", row.names = FALSE)
write.csv(se_table, "Tong_M5_100rep_Results/se_ratio_comparison.csv", row.names = FALSE)
write.csv(coverage_table, "Tong_M5_100rep_Results/coverage_comparison.csv", row.names = FALSE)
write.csv(avg_performance, "Tong_M5_100rep_Results/performance_summary.csv", row.names = FALSE)

cat("\n=============================================================\n")
cat("All results saved to Tong_M5_100rep_Results/ directory\n")
cat("=============================================================\n")
