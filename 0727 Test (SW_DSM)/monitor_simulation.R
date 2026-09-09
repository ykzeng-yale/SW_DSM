# Monitor WDSM Simulation Progress
# This script checks the status of the running simulation

cat("=====================================\n")
cat("WDSM SIMULATION MONITOR\n")
cat("=====================================\n\n")

# Check if results file exists
results_file <- paste0("WDSM_SW_PSW_simulation_results_", Sys.Date(), ".RData")

if (file.exists(results_file)) {
  cat("✓ Simulation completed!\n")
  cat("Results file:", results_file, "\n\n")
  
  # Load and summarize results
  load(results_file)
  
  cat("FINAL RESULTS SUMMARY:\n")
  cat(rep("-", 40), "\n", sep = "")
  
  # Prospective results
  if (exists("summary_prospective")) {
    cat("\nPROSPECTIVE SAMPLING:\n")
    cat("Valid replications:", summary_prospective$n_valid, "\n")
    cat("WDSM PATE relative bias:", round(summary_prospective$wdsm_pate_rel_bias, 2), "%\n")
    cat("WDSM PATT relative bias:", round(summary_prospective$wdsm_patt_rel_bias, 2), "%\n")
    if (!is.na(summary_prospective$psw_pate_rel_bias)) {
      cat("PSW PATE relative bias:", round(summary_prospective$psw_pate_rel_bias, 2), "%\n")
      cat("PSW PATT relative bias:", round(summary_prospective$psw_patt_rel_bias, 2), "%\n")
    }
  }
  
  # Retrospective results
  if (exists("summary_retrospective")) {
    cat("\nRETROSPECTIVE SAMPLING:\n")
    cat("Valid replications:", summary_retrospective$n_valid, "\n")
    cat("WDSM PATE relative bias:", round(summary_retrospective$wdsm_pate_rel_bias, 2), "%\n")
    cat("WDSM PATT relative bias:", round(summary_retrospective$wdsm_patt_rel_bias, 2), "%\n")
    if (!is.na(summary_retrospective$psw_pate_rel_bias)) {
      cat("PSW PATE relative bias:", round(summary_retrospective$psw_pate_rel_bias, 2), "%\n")
      cat("PSW PATT relative bias:", round(summary_retrospective$psw_patt_rel_bias, 2), "%\n")
    }
  }
  
} else {
  # Check if process is running
  process_check <- system("ps aux | grep 'run_WDSM_full_simulation.R' | grep -v grep", intern = TRUE)
  
  if (length(process_check) > 0) {
    cat("⏳ Simulation is running...\n\n")
    
    # Extract process info
    process_info <- strsplit(process_check[1], "\\s+")[[1]]
    pid <- process_info[2]
    cpu_usage <- process_info[3]
    mem_usage <- process_info[4]
    start_time <- paste(process_info[9:10], collapse = " ")
    
    cat("Process ID:", pid, "\n")
    cat("CPU usage:", cpu_usage, "%\n")
    cat("Memory usage:", mem_usage, "%\n")
    cat("Started:", start_time, "\n\n")
    
    # Check log file
    if (file.exists("WDSM_simulation_log.txt")) {
      log_lines <- readLines("WDSM_simulation_log.txt")
      
      # Look for progress indicators
      if (any(grepl("Running prospective", log_lines))) {
        cat("Status: Running prospective sampling simulations\n")
      }
      if (any(grepl("Running retrospective", log_lines))) {
        cat("Status: Running retrospective sampling simulations\n")
      }
      
      # Check for any completed results in log
      results_lines <- grep("RESULTS|Mean estimate|Relative bias", log_lines, value = TRUE)
      if (length(results_lines) > 0) {
        cat("\nPartial results found in log:\n")
        cat(tail(results_lines, 10), sep = "\n")
      }
    }
    
    cat("\n💡 Tip: The simulation typically takes 20-30 minutes for 100 replications.\n")
    cat("   Check back in a few minutes.\n")
    
  } else {
    cat("❌ Simulation is not running.\n")
    cat("   Check WDSM_simulation_log.txt for any errors.\n\n")
    
    if (file.exists("WDSM_simulation_log.txt")) {
      log_lines <- readLines("WDSM_simulation_log.txt")
      error_lines <- grep("Error|error", log_lines, value = TRUE)
      
      if (length(error_lines) > 0) {
        cat("Found errors in log:\n")
        cat(tail(error_lines, 5), sep = "\n")
      } else {
        cat("Last few lines of log:\n")
        cat(tail(log_lines, 10), sep = "\n")
      }
    }
  }
} 