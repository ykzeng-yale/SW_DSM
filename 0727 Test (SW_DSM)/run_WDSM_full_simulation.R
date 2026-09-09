# Full WDSM Simulation with SW_PSW Design
# This runs the complete simulation with 100 replications

cat("=====================================\n")
cat("WDSM SIMULATION WITH SW_PSW DESIGN\n")
cat("=====================================\n\n")

# Set parameters for full simulation
n_reps <- 100
n_cores <- 4
RUN_SIMULATION <- TRUE

# Record start time
start_time <- Sys.time()

cat("Simulation parameters:\n")
cat("- Replications:", n_reps, "\n")
cat("- Cores:", n_cores, "\n")
cat("- Start time:", format(start_time, "%Y-%m-%d %H:%M:%S"), "\n\n")

# Source and run the simulation
source("test_WDSM_with_SW_PSW_design.R", echo = FALSE)

# Record end time
end_time <- Sys.time()
duration <- difftime(end_time, start_time, units = "mins")

cat("\n=====================================\n")
cat("SIMULATION COMPLETED\n")
cat("=====================================\n")
cat("End time:", format(end_time, "%Y-%m-%d %H:%M:%S"), "\n")
cat("Total duration:", round(duration, 2), "minutes\n")
cat("\nResults saved to:", paste0("WDSM_SW_PSW_simulation_results_", Sys.Date(), ".RData"), "\n") 