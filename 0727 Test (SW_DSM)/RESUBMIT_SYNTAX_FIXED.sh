#!/bin/bash

echo "════════════════════════════════════════════════════════════════"
echo "  RESUBMITTING WITH SYNTAX ERROR FIXED"
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

# Upload and submit for each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "Processing $scenario scenario..."
    
    LOCAL_DIR="PATE Retrospective Goodoverlap M5 ${scenario} 1000rep CORRECTED GLM"
    scenario_lower=$(to_lower "$scenario")
    REMOTE_DIR="${REMOTE_BASE}/pate_retrospective_goodoverlap_m5_${scenario_lower}_1000rep_final"
    
    echo "  Uploading corrected script..."
    # Upload only the corrected R script
    scp "${LOCAL_DIR}/compare_methods_pate_retrospective_mccleary.R" \
        "$USER@$SERVER:$REMOTE_DIR/"
    
    # Submit job
    echo "  Resubmitting job..."
    ssh "$USER@$SERVER" "cd $REMOTE_DIR && sbatch run_${scenario}_final.sh"
    
    echo "  $scenario resubmitted successfully!"
    echo ""
done

echo "════════════════════════════════════════════════════════════════"
echo "All 4 scenarios resubmitted with syntax error fixed!"
echo "Use 'squeue -u yz2324' to monitor job status"
echo "════════════════════════════════════════════════════════════════"


