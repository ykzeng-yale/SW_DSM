# Inspect the results data
cat("Inspecting simulation results data...\n\n")

# Load the results
load("WDSM_SW_PSW_simulation_results_2025-07-26.RData")

# Check prospective results
cat("=== PROSPECTIVE RESULTS DATA ===\n")
cat("First few rows:\n")
print(head(results_prospective_df))
cat("\nData types:\n")
print(str(results_prospective_df))

# Check retrospective results
cat("\n\n=== RETROSPECTIVE RESULTS DATA ===\n")
cat("First few rows:\n")
print(head(results_retrospective_df))
cat("\nData types:\n")
print(str(results_retrospective_df))

# Check summary objects
cat("\n\n=== SUMMARY OBJECTS ===\n")
cat("Prospective summary:\n")
print(summary_prospective)
cat("\nRetrospective summary:\n")
print(summary_retrospective) 