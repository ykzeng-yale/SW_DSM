# Analyze WDSM Simulation Results
# This script loads and analyzes the simulation results with focus on coverage rates

cat("=====================================\n")
cat("WDSM SIMULATION RESULTS ANALYSIS\n")
cat("=====================================\n\n")

# Load the results
results_file <- "WDSM_SW_PSW_simulation_results_2025-07-26.RData"
load(results_file)
cat("Loaded results from:", results_file, "\n\n")

# Function to calculate coverage
calc_coverage <- function(estimates, ses, true_value, alpha = 0.05) {
  z_crit <- qnorm(1 - alpha/2)
  lower <- estimates - z_crit * ses
  upper <- estimates + z_crit * ses
  coverage <- mean(lower <= true_value & upper >= true_value)
  return(coverage * 100)
}

# Analyze Prospective Sampling Results
cat("=== PROSPECTIVE SAMPLING ANALYSIS ===\n")
cat("Valid replications:", nrow(results_prospective), "\n\n")

if (nrow(results_prospective) > 0) {
  # True values
  ate_true <- results_prospective$ate_true[1]
  att_true <- results_prospective$att_true[1]
  
  # PATE Analysis
  cat("POPULATION AVERAGE TREATMENT EFFECT (PATE)\n")
  cat("True PATE:", round(ate_true, 4), "\n")
  cat("-" * 40, "\n")
  
  # WDSM PATE
  wdsm_pate_bias <- mean(results_prospective$wdsm_pate - ate_true)
  wdsm_pate_rel_bias <- (wdsm_pate_bias / ate_true) * 100
  wdsm_pate_coverage <- calc_coverage(results_prospective$wdsm_pate, 
                                      results_prospective$wdsm_pate_se, 
                                      ate_true)
  
  cat("WDSM:\n")
  cat("  Mean estimate:", round(mean(results_prospective$wdsm_pate), 4), "\n")
  cat("  Bias:", round(wdsm_pate_bias, 4), "\n")
  cat("  Relative bias:", round(wdsm_pate_rel_bias, 2), "%\n")
  cat("  95% CI Coverage:", round(wdsm_pate_coverage, 1), "%\n")
  cat("  Mean SE:", round(mean(results_prospective$wdsm_pate_se), 4), "\n\n")
  
  # PSW PATE (if available)
  if (!all(is.na(results_prospective$psw_pate))) {
    psw_pate_bias <- mean(results_prospective$psw_pate - ate_true, na.rm = TRUE)
    psw_pate_rel_bias <- (psw_pate_bias / ate_true) * 100
    psw_pate_coverage <- calc_coverage(results_prospective$psw_pate[!is.na(results_prospective$psw_pate)], 
                                       results_prospective$psw_pate_se[!is.na(results_prospective$psw_pate)], 
                                       ate_true)
    
    cat("PSW (for comparison):\n")
    cat("  Mean estimate:", round(mean(results_prospective$psw_pate, na.rm = TRUE), 4), "\n")
    cat("  Bias:", round(psw_pate_bias, 4), "\n")
    cat("  Relative bias:", round(psw_pate_rel_bias, 2), "%\n")
    cat("  95% CI Coverage:", round(psw_pate_coverage, 1), "%\n")
    cat("  Mean SE:", round(mean(results_prospective$psw_pate_se, na.rm = TRUE), 4), "\n\n")
  }
  
  # PATT Analysis
  cat("\nPOPULATION AVERAGE TREATMENT EFFECT ON TREATED (PATT)\n")
  cat("True PATT:", round(att_true, 4), "\n")
  cat("-" * 40, "\n")
  
  # WDSM PATT
  wdsm_patt_bias <- mean(results_prospective$wdsm_patt - att_true)
  wdsm_patt_rel_bias <- (wdsm_patt_bias / att_true) * 100
  wdsm_patt_coverage <- calc_coverage(results_prospective$wdsm_patt, 
                                      results_prospective$wdsm_patt_se, 
                                      att_true)
  
  cat("WDSM:\n")
  cat("  Mean estimate:", round(mean(results_prospective$wdsm_patt), 4), "\n")
  cat("  Bias:", round(wdsm_patt_bias, 4), "\n")
  cat("  Relative bias:", round(wdsm_patt_rel_bias, 2), "%\n")
  cat("  95% CI Coverage:", round(wdsm_patt_coverage, 1), "%\n")
  cat("  Mean SE:", round(mean(results_prospective$wdsm_patt_se), 4), "\n\n")
  
  # PSW PATT (if available)
  if (!all(is.na(results_prospective$psw_patt))) {
    psw_patt_bias <- mean(results_prospective$psw_patt - att_true, na.rm = TRUE)
    psw_patt_rel_bias <- (psw_patt_bias / att_true) * 100
    psw_patt_coverage <- calc_coverage(results_prospective$psw_patt[!is.na(results_prospective$psw_patt)], 
                                       results_prospective$psw_patt_se[!is.na(results_prospective$psw_patt)], 
                                       att_true)
    
    cat("PSW (for comparison):\n")
    cat("  Mean estimate:", round(mean(results_prospective$psw_patt, na.rm = TRUE), 4), "\n")
    cat("  Bias:", round(psw_patt_bias, 4), "\n")
    cat("  Relative bias:", round(psw_patt_rel_bias, 2), "%\n")
    cat("  95% CI Coverage:", round(psw_patt_coverage, 1), "%\n")
    cat("  Mean SE:", round(mean(results_prospective$psw_patt_se, na.rm = TRUE), 4), "\n\n")
  }
}

# Analyze Retrospective Sampling Results
cat("\n=== RETROSPECTIVE SAMPLING ANALYSIS ===\n")
cat("Valid replications:", nrow(results_retrospective), "\n\n")

if (nrow(results_retrospective) > 0) {
  # True values
  ate_true <- results_retrospective$ate_true[1]
  att_true <- results_retrospective$att_true[1]
  
  # PATE Analysis
  cat("POPULATION AVERAGE TREATMENT EFFECT (PATE)\n")
  cat("True PATE:", round(ate_true, 4), "\n")
  cat("-" * 40, "\n")
  
  # WDSM PATE
  wdsm_pate_bias <- mean(results_retrospective$wdsm_pate - ate_true)
  wdsm_pate_rel_bias <- (wdsm_pate_bias / ate_true) * 100
  wdsm_pate_coverage <- calc_coverage(results_retrospective$wdsm_pate, 
                                      results_retrospective$wdsm_pate_se, 
                                      ate_true)
  
  cat("WDSM:\n")
  cat("  Mean estimate:", round(mean(results_retrospective$wdsm_pate), 4), "\n")
  cat("  Bias:", round(wdsm_pate_bias, 4), "\n")
  cat("  Relative bias:", round(wdsm_pate_rel_bias, 2), "%\n")
  cat("  95% CI Coverage:", round(wdsm_pate_coverage, 1), "%\n")
  cat("  Mean SE:", round(mean(results_retrospective$wdsm_pate_se), 4), "\n\n")
  
  # PSW PATE (if available)
  if (!all(is.na(results_retrospective$psw_pate))) {
    psw_pate_bias <- mean(results_retrospective$psw_pate - ate_true, na.rm = TRUE)
    psw_pate_rel_bias <- (psw_pate_bias / ate_true) * 100
    psw_pate_coverage <- calc_coverage(results_retrospective$psw_pate[!is.na(results_retrospective$psw_pate)], 
                                       results_retrospective$psw_pate_se[!is.na(results_retrospective$psw_pate)], 
                                       ate_true)
    
    cat("PSW (for comparison):\n")
    cat("  Mean estimate:", round(mean(results_retrospective$psw_pate, na.rm = TRUE), 4), "\n")
    cat("  Bias:", round(psw_pate_bias, 4), "\n")
    cat("  Relative bias:", round(psw_pate_rel_bias, 2), "%\n")
    cat("  95% CI Coverage:", round(psw_pate_coverage, 1), "%\n")
    cat("  Mean SE:", round(mean(results_retrospective$psw_pate_se, na.rm = TRUE), 4), "\n\n")
  }
  
  # PATT Analysis
  cat("\nPOPULATION AVERAGE TREATMENT EFFECT ON TREATED (PATT)\n")
  cat("True PATT:", round(att_true, 4), "\n")
  cat("-" * 40, "\n")
  
  # WDSM PATT
  wdsm_patt_bias <- mean(results_retrospective$wdsm_patt - att_true)
  wdsm_patt_rel_bias <- (wdsm_patt_bias / att_true) * 100
  wdsm_patt_coverage <- calc_coverage(results_retrospective$wdsm_patt, 
                                      results_retrospective$wdsm_patt_se, 
                                      att_true)
  
  cat("WDSM:\n")
  cat("  Mean estimate:", round(mean(results_retrospective$wdsm_patt), 4), "\n")
  cat("  Bias:", round(wdsm_patt_bias, 4), "\n")
  cat("  Relative bias:", round(wdsm_patt_rel_bias, 2), "%\n")
  cat("  95% CI Coverage:", round(wdsm_patt_coverage, 1), "%\n")
  cat("  Mean SE:", round(mean(results_retrospective$wdsm_patt_se), 4), "\n\n")
  
  # PSW PATT (if available)
  if (!all(is.na(results_retrospective$psw_patt))) {
    psw_patt_bias <- mean(results_retrospective$psw_patt - att_true, na.rm = TRUE)
    psw_patt_rel_bias <- (psw_patt_bias / att_true) * 100
    psw_patt_coverage <- calc_coverage(results_retrospective$psw_patt[!is.na(results_retrospective$psw_patt)], 
                                       results_retrospective$psw_patt_se[!is.na(results_retrospective$psw_patt)], 
                                       att_true)
    
    cat("PSW (for comparison):\n")
    cat("  Mean estimate:", round(mean(results_retrospective$psw_patt, na.rm = TRUE), 4), "\n")
    cat("  Bias:", round(psw_patt_bias, 4), "\n")
    cat("  Relative bias:", round(psw_patt_rel_bias, 2), "%\n")
    cat("  95% CI Coverage:", round(psw_patt_coverage, 1), "%\n")
    cat("  Mean SE:", round(mean(results_retrospective$psw_patt_se, na.rm = TRUE), 4), "\n\n")
  }
}

# Summary
cat("\n=== SUMMARY ===\n")
cat("This simulation tested WDSM under complex survey designs:\n")
cat("- Prospective sampling: Multi-stage sampling independent of treatment\n")
cat("- Retrospective sampling: Outcome-dependent sampling\n")
cat("- Both designs incorporate survey weights properly\n")
cat("- Coverage rates should be close to 95% for valid inference\n")
cat("- Small relative bias indicates approximately unbiased estimation\n") 