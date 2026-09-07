# Debug and analyze Tong Account M5 100-rep Results

library(dplyr)
library(tidyr)

# Check structure of each file
cat("=============================================================\n")
cat("CHECKING DATA STRUCTURE OF EACH FILE\n")
cat("=============================================================\n\n")

scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")

for (scenario in scenarios) {
  cat("\n---", scenario, "---\n")
  file_name <- tolower(scenario)
  file_path <- paste0("Tong_M5_100rep_Results/", file_name, "_results.RData")
  
  # Clear workspace
  rm(list = setdiff(ls(), c("scenarios", "scenario", "file_name", "file_path")))
  
  # Load the file
  load(file_path)
  
  if (exists("summary_data")) {
    cat("Has summary_data with columns:\n")
    print(names(summary_data))
    cat("\nFirst few rows:\n")
    print(head(summary_data %>% filter(M == 5), 2))
  }
  
  if (exists("summary_stats")) {
    cat("Has summary_stats with columns:\n")
    print(names(summary_stats))
    cat("\nFirst few rows:\n")
    print(head(summary_stats, 2))
  }
}

cat("\n=============================================================\n")
cat("EXTRACTING AND ALIGNING DATA\n")
cat("=============================================================\n\n")

# Now extract with proper column alignment
all_results <- list()

# CorCor
load("Tong_M5_100rep_Results/corcor_results.RData")
if (exists("summary_data")) {
  df <- summary_data %>%
    filter(M == 5) %>%
    mutate(Scenario = "CorCor") %>%
    select(Scenario, Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
  all_results[["CorCor"]] <- df
  cat("CorCor: Extracted", nrow(df), "rows\n")
}

# MisCor
load("Tong_M5_100rep_Results/miscor_results.RData")
if (exists("summary_data")) {
  df <- summary_data %>%
    filter(M == 5) %>%
    mutate(Scenario = "MisCor") %>%
    select(Scenario, Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
  all_results[["MisCor"]] <- df
  cat("MisCor: Extracted", nrow(df), "rows\n")
}

# CorMis - different structure
load("Tong_M5_100rep_Results/cormis_results.RData")
if (exists("summary_stats")) {
  df <- summary_stats %>%
    mutate(
      Scenario = "CorMis",
      N_Valid = 100,
      Rel_Bias = Relative_Bias,
      SE_Ratio = Relative_Efficiency
    ) %>%
    select(Scenario, Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
  all_results[["CorMis"]] <- df
  cat("CorMis: Extracted", nrow(df), "rows\n")
}

# MisMis
load("Tong_M5_100rep_Results/mismis_results.RData")
if (exists("summary_data")) {
  df <- summary_data %>%
    filter(M == 5) %>%
    mutate(Scenario = "MisMis") %>%
    select(Scenario, Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
  all_results[["MisMis"]] <- df
  cat("MisMis: Extracted", nrow(df), "rows\n")
}

# Check if all have same columns
cat("\nChecking column consistency:\n")
for (scenario in names(all_results)) {
  cat(scenario, "columns:", paste(names(all_results[[scenario]]), collapse = ", "), "\n")
}

# Combine all results
combined_df <- do.call(rbind, all_results)
rownames(combined_df) <- NULL

# Convert to numeric and round
combined_df$Rel_Bias <- round(as.numeric(combined_df$Rel_Bias), 3)
combined_df$SE_Ratio <- round(as.numeric(combined_df$SE_Ratio), 3)
combined_df$Coverage <- round(as.numeric(combined_df$Coverage), 3)
combined_df$N_Valid <- as.integer(combined_df$N_Valid)

cat("\n=============================================================\n")
cat("DETAILED RESULTS BY SCENARIO (M=5, 100 replications)\n")
cat("=============================================================\n\n")

# Print results for each scenario
for (scenario in unique(combined_df$Scenario)) {
  cat("---", scenario, "---\n")
  df <- combined_df %>% 
    filter(Scenario == scenario) %>%
    select(Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)
  print(df, row.names = FALSE)
  cat("\n")
}
