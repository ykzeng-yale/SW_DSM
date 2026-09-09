# Verify Model Specification Logic

scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")

cat("=====================================\n")
cat("Model Specification Verification\n")
cat("=====================================\n\n")

for (scenario in scenarios) {
  # Logic from comparison scripts
  use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
  use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
  
  cat(sprintf("Scenario: %s\n", scenario))
  cat(sprintf("  PS includes X1:X2? %s (use_interaction_ps = %s)\n", 
              ifelse(use_interaction_ps, "YES", "NO"), use_interaction_ps))
  cat(sprintf("  PG includes X1:X2? %s (use_interaction_pg = %s)\n", 
              ifelse(use_interaction_pg, "YES", "NO"), use_interaction_pg))
  
  # Interpret
  ps_status <- ifelse(use_interaction_ps, "Correct", "Misspecified")
  pg_status <- ifelse(use_interaction_pg, "Correct", "Misspecified")
  
  cat(sprintf("  => PS model: %s\n", ps_status))
  cat(sprintf("  => PG model: %s\n", pg_status))
  cat("\n")
}

cat("=====================================\n")
cat("Expected Patterns:\n")
cat("=====================================\n\n")

cat("For PS-based methods (PS matching, PS Full):\n")
cat("  - CorCor and CorMis should have similar results (PS correct in both)\n")
cat("  - MisCor and MisMis should have similar results (PS miss in both)\n\n")

cat("For PG-based methods (PG matching):\n")
cat("  - CorCor and MisCor should have similar results (PG correct in both)\n")
cat("  - CorMis and MisMis should have similar results (PG miss in both)\n\n")

cat("For DSM and WDSM:\n")
cat("  - CorCor should perform best (both correct)\n")
cat("  - MisMis should perform worst (both miss)\n")
cat("  - MisCor and CorMis intermediate\n\n")

# Check each script has correct scenario value
cat("=====================================\n")
cat("Checking Script Configurations:\n")
cat("=====================================\n\n")

for (scenario in scenarios) {
  script_path <- sprintf("PATE Retrospective Pooroverlap M135 %s GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED.R", scenario)
  
  if (file.exists(script_path)) {
    lines <- readLines(script_path, n = 50)
    scenario_line <- grep('^scenarios <- c\\("', lines, value = TRUE)
    
    if (length(scenario_line) > 0) {
      # Extract the scenario value
      configured_scenario <- gsub('scenarios <- c\\("(.+)"\\)', "\\1", scenario_line[1])
      
      if (configured_scenario == scenario) {
        cat(sprintf("✅ %s: Correctly configured\n", scenario))
      } else {
        cat(sprintf("❌ %s: MISMATCH! Script has '%s'\n", scenario, configured_scenario))
      }
    } else {
      cat(sprintf("⚠️  %s: Could not find scenario configuration\n", scenario))
    }
  } else {
    cat(sprintf("⚠️  %s: Script file not found\n", scenario))
  }
}

cat("\n=====================================\n")
cat("VERIFICATION COMPLETE\n")
cat("=====================================\n")
