# Small test of WDSM simulation
# This runs a few replications to ensure everything works before full simulation

cat("Running small WDSM simulation test...\n\n")

# Set simulation parameters
n_reps <- 5  # Just 5 replications for testing
n_cores <- 2  # Use only 2 cores for testing
RUN_SIMULATION <- TRUE  # Set to TRUE to actually run the simulation

# Source and run the simulation
source("test_WDSM_with_SW_PSW_design.R", echo = FALSE)

cat("\nSmall simulation test completed!\n")
cat("Check for any errors above before running full simulation.\n") 