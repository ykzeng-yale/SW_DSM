# Analyze PROPERLY_SOURCED results
# Poor Overlap scenario with corrected WDSM implementation

# Read all scenario results
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
all_results <- list()

for (scenario in scenarios) {
  file_path <- paste0("pooroverlap_PROPER_", scenario, "_FINAL.csv")
  if (file.exists(file_path)) {
    df <- read.csv(file_path)
    df$Scenario <- scenario
    all_results[[scenario]] <- df
  }
}

# Combine all results
combined_results <- do.call(rbind, all_results)

# Display results by scenario
cat("=" , rep("=", 78), "\n", sep="")
cat("PROPERLY_SOURCED POOR OVERLAP RESULTS - 100 Replicates, M=5\n")
cat("=" , rep("=", 78), "\n\n", sep="")

# Format for pretty printing
format_value <- function(x, digits=3) {
  if (is.numeric(x)) {
    return(sprintf(paste0("%.", digits, "f"), x))
  }
  return(x)
}

# Create comparison table by scenario
for (scenario in scenarios) {
  cat("\n", rep("-", 60), "\n", sep="")
  cat("SCENARIO: ", scenario, "\n", sep="")
  if (scenario == "CorCor") cat("(Both PS and PGS models correctly specified with X1:X2)\n")
  if (scenario == "MisCor") cat("(PS misspecified without X1:X2, PGS correct with X1:X2)\n")
  if (scenario == "CorMis") cat("(PS correct with X1:X2, PGS misspecified without X1:X2)\n")
  if (scenario == "MisMis") cat("(Both PS and PGS misspecified without X1:X2)\n")
  cat(rep("-", 60), "\n", sep="")
  
  scenario_data <- combined_results[combined_results$Scenario == scenario, ]
  
  # Print header
  cat(sprintf("%-25s %8s %8s %8s %8s\n", 
              "Method", "Rel.Bias", "SE.Ratio", "Coverage", "RMSE"))
  cat(rep("-", 60), "\n", sep="")
  
  # Print each method
  for (i in 1:nrow(scenario_data)) {
    cat(sprintf("%-25s %8s %8s %8s %8s\n",
                scenario_data$Method[i],
                format_value(scenario_data$Relative_Bias[i]),
                format_value(scenario_data$SE_Ratio[i]),
                format_value(scenario_data$Coverage[i]),
                format_value(scenario_data$RMSE[i])))
  }
}

# Key comparisons
cat("\n", rep("=", 78), "\n", sep="")
cat("KEY PERFORMANCE METRICS\n")
cat(rep("=", 78), "\n\n", sep="")

# Check WDSM performance in CorCor (should be good now)
wdsm_corcor <- combined_results[combined_results$Scenario == "CorCor" & 
                                 combined_results$Method == "WDSM_Multinomial", ]
if (nrow(wdsm_corcor) > 0) {
  cat("WDSM in CorCor (Both Correct):\n")
  cat("  Relative Bias: ", format_value(wdsm_corcor$Relative_Bias[1]), 
      " (target: <1%)\n", sep="")
  cat("  Coverage: ", format_value(wdsm_corcor$Coverage[1]), 
      " (target: ~95%)\n", sep="")
  cat("  SE Ratio: ", format_value(wdsm_corcor$SE_Ratio[1]), 
      " (target: ~1.0)\n\n", sep="")
  
  if (abs(wdsm_corcor$Relative_Bias[1]) < 1 && 
      wdsm_corcor$Coverage[1] > 90 && wdsm_corcor$Coverage[1] < 98) {
    cat("✅ WDSM PERFORMANCE FIXED! Bug resolved successfully.\n\n")
  } else {
    cat("⚠️ WDSM still showing issues. Further investigation needed.\n\n")
  }
}

# Check PS-based methods patterns (should be same in CorCor and CorMis)
cat("Model Specification Pattern Checks:\n")
cat(rep("-", 40), "\n", sep="")

for (method in c("DSM", "PS", "PS_Weighted")) {
  corcor_val <- combined_results[combined_results$Scenario == "CorCor" & 
                                  combined_results$Method == method, "Relative_Bias"]
  cormis_val <- combined_results[combined_results$Scenario == "CorMis" & 
                                  combined_results$Method == method, "Relative_Bias"]
  
  if (length(corcor_val) > 0 && length(cormis_val) > 0) {
    diff <- abs(corcor_val - cormis_val)
    cat(sprintf("%s: CorCor bias = %.3f, CorMis bias = %.3f, diff = %.3f %s\n",
                method, corcor_val, cormis_val, diff,
                ifelse(diff < 0.5, "✓", "✗")))
  }
}

cat("\n")

# Check PG-based method patterns (should be same in CorCor and MisCor)
for (method in c("PG")) {
  corcor_val <- combined_results[combined_results$Scenario == "CorCor" & 
                                  combined_results$Method == method, "Relative_Bias"]
  miscor_val <- combined_results[combined_results$Scenario == "MisCor" & 
                                  combined_results$Method == method, "Relative_Bias"]
  
  if (length(corcor_val) > 0 && length(miscor_val) > 0) {
    diff <- abs(corcor_val - miscor_val)
    cat(sprintf("%s: CorCor bias = %.3f, MisCor bias = %.3f, diff = %.3f %s\n",
                method, corcor_val, miscor_val, diff,
                ifelse(diff < 0.5, "✓", "✗")))
  }
}

# Summary statistics
cat("\n", rep("=", 78), "\n", sep="")
cat("SUMMARY STATISTICS\n")
cat(rep("=", 78), "\n\n", sep="")

# Best performing method per scenario
for (scenario in scenarios) {
  scenario_data <- combined_results[combined_results$Scenario == scenario, ]
  best_method <- scenario_data[which.min(abs(scenario_data$Relative_Bias)), "Method"]
  best_bias <- scenario_data[which.min(abs(scenario_data$Relative_Bias)), "Relative_Bias"]
  cat(sprintf("%-10s: Best method = %-20s (Bias = %.3f)\n", 
              scenario, best_method, best_bias))
}

# Save summary
write.csv(combined_results, "pooroverlap_PROPERLY_SOURCED_all_results.csv", row.names = FALSE)
cat("\n✅ Results saved to pooroverlap_PROPERLY_SOURCED_all_results.csv\n")
