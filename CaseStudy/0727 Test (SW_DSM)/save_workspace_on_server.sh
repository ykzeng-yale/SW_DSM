#!/bin/bash

echo "════════════════════════════════════════════════════════════════"
echo "  SAVING WORKSPACE FILES ON SERVER"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Configuration
SERVER="login2.mccleary.ycrc.yale.edu"
USER="yz2324"
REMOTE_BASE="/gpfs/gibbs/project/li_fan/yz2324"

# Function to convert to lowercase
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Create R script to extract and save results
cat > extract_results.R << 'EOF'
# Script to extract results from completed simulations

# Get command line argument for scenario
args <- commandArgs(trailingOnly = TRUE)
scenario <- args[1]

# Try to find the most recent output file
output_files <- list.files(pattern = paste0("output_", scenario, "_.*\\.txt"), full.names = TRUE)
if (length(output_files) == 0) {
  stop("No output file found")
}

# Check if simulation completed
output_content <- readLines(output_files[1])
if (any(grepl("Successful runs: 1000 out of 1000", output_content))) {
  cat("Simulation completed successfully\n")
  
  # Look for any RData files that might have been saved
  rdata_files <- list.files(pattern = "\\.RData$", full.names = TRUE)
  rdata_files <- rdata_files[!grepl("SuperPopGen", rdata_files)]
  
  if (length(rdata_files) > 0) {
    cat("Found RData file:", rdata_files[1], "\n")
    # File already exists, no need to recreate
  } else {
    cat("No results RData file found. Results may be lost if R session terminated.\n")
  }
} else {
  cat("Simulation did not complete successfully\n")
}
EOF

# Upload and run the extraction script for each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "Processing $scenario scenario..."
    
    scenario_lower=$(to_lower "$scenario")
    REMOTE_DIR="${REMOTE_BASE}/pate_retrospective_goodoverlap_m5_${scenario_lower}_1000rep_final"
    
    # Upload extraction script
    scp extract_results.R "$USER@$SERVER:$REMOTE_DIR/"
    
    # Run extraction
    ssh "$USER@$SERVER" << EOF
cd $REMOTE_DIR
Rscript extract_results.R $scenario
EOF
    
    echo "  $scenario processed"
    echo ""
done

# Clean up
rm extract_results.R

echo "════════════════════════════════════════════════════════════════"
echo "Server-side processing complete"
echo "════════════════════════════════════════════════════════════════"


