#!/usr/bin/env Rscript

cat("\n=== CHECKING FIXED 3 METHODS RESULTS ===\n\n")

# Load the fixed results
results <- readRDS("Analysis/Results/moore_2025_3methods_fixed.rds")

# Check what we have
cat("Structure of results:\n")
str(results)

cat("\n--- STI Results ---\n")
if (!is.null(results$STI)) {
  for (method in c("dsm", "psm", "pgm")) {
    if (!is.null(results$STI[[method]])) {
      est <- results$STI[[method]]$estimate
      se <- results$STI[[method]]$se
      ci_l <- results$STI[[method]]$ci_lower
      ci_u <- results$STI[[method]]$ci_upper
      
      if (!is.na(est)) {
        cat(sprintf("%s: %.4f (SE: %.4f) CI: [%.4f, %.4f]\n", 
                    toupper(method), est, se, ci_l, ci_u))
      } else {
        cat(sprintf("%s: FAILED\n", toupper(method)))
      }
    }
  }
}

cat("\n--- SPD Results ---\n")
if (!is.null(results$SPD)) {
  for (method in c("dsm", "psm", "pgm")) {
    if (!is.null(results$SPD[[method]])) {
      est <- results$SPD[[method]]$estimate
      se <- results$SPD[[method]]$se
      ci_l <- results$SPD[[method]]$ci_lower
      ci_u <- results$SPD[[method]]$ci_upper
      
      if (!is.na(est)) {
        cat(sprintf("%s: %.4f (SE: %.4f) CI: [%.4f, %.4f]\n", 
                    toupper(method), est, se, ci_l, ci_u))
      } else {
        cat(sprintf("%s: FAILED\n", toupper(method)))
      }
    }
  }
}

# Also check the original results
cat("\n\n=== COMPARING WITH WDSM/PS FULL RESULTS ===\n")
orig <- readRDS("Analysis/Results/moore_2025_all_5_methods_final.rds")

cat("\n--- STI ---\n")
cat("WDSM: ", orig$STI$wdsm$estimate, "\n")
cat("PS Full: ", orig$STI$ps_full$estimate, "\n")

cat("\n--- SPD ---\n")
cat("WDSM: ", orig$SPD$wdsm$estimate, "\n")
cat("PS Full: ", orig$SPD$ps_full$estimate, "\n")

