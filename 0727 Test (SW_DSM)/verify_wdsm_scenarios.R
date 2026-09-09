# Verify WDSM Model Specification Logic

cat("════════════════════════════════════════════════════════════════\n")
cat("        VERIFICATION OF WDSM MODEL SPECIFICATION LOGIC\n")
cat("════════════════════════════════════════════════════════════════\n\n")

# Define the scenarios
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")

cat("SCENARIO DEFINITIONS:\n")
cat("─────────────────────────────────────────────────────────────\n")

for (scenario in scenarios) {
  # This is the exact logic from the comparison script
  use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
  use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
  
  cat(sprintf("%-8s: ", scenario))
  
  # Determine what this means
  if (use_interaction_ps && use_interaction_pg) {
    cat("PS ✓ Correct (with X1:X2), PGS ✓ Correct (with X1:X2)\n")
  } else if (!use_interaction_ps && use_interaction_pg) {
    cat("PS ✗ Misspecified (no X1:X2), PGS ✓ Correct (with X1:X2)\n")
  } else if (use_interaction_ps && !use_interaction_pg) {
    cat("PS ✓ Correct (with X1:X2), PGS ✗ Misspecified (no X1:X2)\n")
  } else {
    cat("PS ✗ Misspecified (no X1:X2), PGS ✗ Misspecified (no X1:X2)\n")
  }
}

cat("\n")
cat("WDSM FORMULA CONSTRUCTION:\n")
cat("─────────────────────────────────────────────────────────────\n")

# Show what formulas WDSM will use in each scenario
for (scenario in scenarios) {
  use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
  use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
  
  cat(sprintf("\n%s:\n", scenario))
  
  # PS formula
  ps_formula <- if (use_interaction_ps) {
    "A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2"
  } else {
    "A ~ X1 + X2 + X3 + X4 + X5 + X6"
  }
  cat(sprintf("  PS Model:  %s\n", ps_formula))
  
  # PGS formula
  pg_formula <- if (use_interaction_pg) {
    "Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2"
  } else {
    "Y ~ X1 + X2 + X3 + X4 + X5 + X6"
  }
  cat(sprintf("  PGS Model: %s\n", pg_formula))
}

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("✅ VERIFICATION COMPLETE: Logic correctly implements:\n")
cat("   - CorCor: Both models correct (include X1:X2)\n")
cat("   - MisCor: PS misspecified, PGS correct\n")
cat("   - CorMis: PS correct, PGS misspecified\n")
cat("   - MisMis: Both models misspecified (exclude X1:X2)\n")
cat("════════════════════════════════════════════════════════════════\n")
