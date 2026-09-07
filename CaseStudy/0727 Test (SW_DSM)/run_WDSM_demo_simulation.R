# Demo WDSM Simulation with SW_PSW Design
# This runs a demonstration with 10 replications to show results analysis

cat("=====================================\n")
cat("WDSM DEMO SIMULATION (10 reps)\n")
cat("=====================================\n\n")

# Set parameters for demo
n_reps <- 10
n_cores <- 2
RUN_SIMULATION <- TRUE

# Record start time
start_time <- Sys.time()

cat("Demo parameters:\n")
cat("- Replications:", n_reps, "\n")
cat("- Cores:", n_cores, "\n")
cat("- Start time:", format(start_time, "%Y-%m-%d %H:%M:%S"), "\n\n")

# Source and run the simulation
source("test_WDSM_with_SW_PSW_design.R", echo = FALSE)

# Record end time
end_time <- Sys.time()
duration <- difftime(end_time, start_time, units = "mins")

cat("\n=====================================\n")
cat("DEMO SIMULATION COMPLETED\n")
cat("=====================================\n")
cat("Duration:", round(duration, 2), "minutes\n")
cat("\nResults saved to:", paste0("WDSM_SW_PSW_simulation_results_", Sys.Date(), ".RData"), "\n")

# Load and display results
load(paste0("WDSM_SW_PSW_simulation_results_", Sys.Date(), ".RData"))

cat("\n\n=== RESULTS SUMMARY ===\n")

# Prospective Sampling Results
cat("\nPROSPECTIVE SAMPLING RESULTS:\n")
cat("-----------------------------\n")
cat("Valid replications:", summary_prospective$n_valid, "out of", n_reps, "\n\n")

cat("PATE Estimation:\n")
cat("- WDSM: Rel. Bias =", round(summary_prospective$rel_bias_wdsm_pate, 2), "%, Coverage =", 
    round(summary_prospective$coverage_wdsm_pate, 2), "%\n")
if (!is.na(summary_prospective$rel_bias_psw_pate)) {
  cat("- PSW:  Rel. Bias =", round(summary_prospective$rel_bias_psw_pate, 2), "%, Coverage =", 
      round(summary_prospective$coverage_psw_pate, 2), "%\n")
}

cat("\nPATT Estimation:\n")
cat("- WDSM: Rel. Bias =", round(summary_prospective$rel_bias_wdsm_patt, 2), "%, Coverage =", 
    round(summary_prospective$coverage_wdsm_patt, 2), "%\n")
if (!is.na(summary_prospective$rel_bias_psw_patt)) {
  cat("- PSW:  Rel. Bias =", round(summary_prospective$rel_bias_psw_patt, 2), "%, Coverage =", 
      round(summary_prospective$coverage_psw_patt, 2), "%\n")
}

# Retrospective Sampling Results
cat("\n\nRETROSPECTIVE SAMPLING RESULTS:\n")
cat("--------------------------------\n")
cat("Valid replications:", summary_retrospective$n_valid, "out of", n_reps, "\n\n")

cat("PATE Estimation:\n")
cat("- WDSM: Rel. Bias =", round(summary_retrospective$rel_bias_wdsm_pate, 2), "%, Coverage =", 
    round(summary_retrospective$coverage_wdsm_pate, 2), "%\n")
if (!is.na(summary_retrospective$rel_bias_psw_pate)) {
  cat("- PSW:  Rel. Bias =", round(summary_retrospective$rel_bias_psw_pate, 2), "%, Coverage =", 
      round(summary_retrospective$coverage_psw_pate, 2), "%\n")
}

cat("\nPATT Estimation:\n")
cat("- WDSM: Rel. Bias =", round(summary_retrospective$rel_bias_wdsm_patt, 2), "%, Coverage =", 
    round(summary_retrospective$coverage_wdsm_patt, 2), "%\n")
if (!is.na(summary_retrospective$rel_bias_psw_patt)) {
  cat("- PSW:  Rel. Bias =", round(summary_retrospective$rel_bias_psw_patt, 2), "%, Coverage =", 
      round(summary_retrospective$coverage_psw_patt, 2), "%\n")
}

cat("\n\nKey Insights:\n")
cat("- Coverage should be close to 95% for valid confidence intervals\n")
cat("- Lower relative bias indicates better unbiased estimation\n")
cat("- WDSM handles complex survey weights in both sampling designs\n") 