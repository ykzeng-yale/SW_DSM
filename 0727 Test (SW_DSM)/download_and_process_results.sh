#!/bin/bash

echo "════════════════════════════════════════════════════════════════"
echo "  DOWNLOADING AND PROCESSING COMPLETED SIMULATION RESULTS"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Configuration
SERVER="login2.mccleary.ycrc.yale.edu"
USER="yz2324"
REMOTE_BASE="/gpfs/gibbs/project/li_fan/yz2324"

# Create local directory for results
mkdir -p "1000rep_final_results"
cd "1000rep_final_results"

# Function to convert to lowercase
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Download workspace files for each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "Processing $scenario scenario..."
    
    scenario_lower=$(to_lower "$scenario")
    REMOTE_DIR="${REMOTE_BASE}/pate_retrospective_goodoverlap_m5_${scenario_lower}_1000rep_final"
    
    echo "  Checking for workspace file..."
    
    # Try to save workspace on server first
    ssh "$USER@$SERVER" << EOF
cd $REMOTE_DIR
if [ -f ".RData" ]; then
    echo "Workspace file exists"
else
    echo "Attempting to create workspace from R session..."
    # The R session may have saved variables in memory
fi
EOF
    
    # Download the workspace file if it exists
    echo "  Downloading workspace file..."
    scp "$USER@$SERVER:$REMOTE_DIR/.RData" "${scenario}_workspace.RData" 2>/dev/null || {
        echo "  No workspace file found, checking for other RData files..."
        # Try to download any RData files (excluding SuperPopGen)
        scp "$USER@$SERVER:$REMOTE_DIR/*.RData" . 2>/dev/null
    }
    
    # Download output and error files for debugging
    echo "  Downloading log files..."
    scp "$USER@$SERVER:$REMOTE_DIR/output_*.txt" "${scenario}_output.txt" 2>/dev/null
    scp "$USER@$SERVER:$REMOTE_DIR/error_*.txt" "${scenario}_error.txt" 2>/dev/null
    
    echo "  $scenario download complete"
    echo ""
done

echo "════════════════════════════════════════════════════════════════"
echo "Downloads complete. Now processing results locally..."
echo "════════════════════════════════════════════════════════════════"

# Process the results using R
cd ..
Rscript fix_results_processing.R

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Processing complete!"
echo "════════════════════════════════════════════════════════════════"


